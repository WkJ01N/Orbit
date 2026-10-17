"""Build pinned, independently downloadable resource packs (no publishing)."""
import argparse, hashlib, json, zipfile, urllib.request, io, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_JAR_SHA256 = {
 'arm64-v8a': '4363dfa5d3d415b91c1f16f6fb90c3fe59a77dfd3f9b824d2b24b492d6b09df9',
 'armeabi-v7a': '8ead114fc5a43348d89dc0eb8f41823e549b15115c29f73ee26973f973620995',
 'x86_64': '90268cd15f0766e07fb8e427388c621161177c9eb343c544f327bd63232bb236',
}
RELEASE_TAG = 'v1.6.1'

def digest(data): return hashlib.sha256(data).hexdigest()

def build_pack(output, identifier, title, files, *, platform='any', abi=None, entrypoint=None):
    name = f'orbit-component-{identifier}-1.orbitpack'
    path = output / name
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name_in_pack, source in sorted(files.items()):
            info = zipfile.ZipInfo(name_in_pack, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, source)
    data = path.read_bytes()
    return dict(id=identifier, name=title, version=1, minBuild=31, runtimeApi=1, platform=platform, abi=abi,
        entrypoint=entrypoint, size=len(data), sha256=digest(data),
        url=f'https://github.com/WkJ01N/Orbit/releases/download/{RELEASE_TAG}/{path.name}',
        files={name: dict(size=len(value), sha256=digest(value)) for name,value in sorted(files.items())})

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'release/v1.6.1/components')
    parser.add_argument('--android-apk', type=Path)
    parser.add_argument('--android-jars',type=Path,default=ROOT/'build/media_kit_libs_android_video/v1.1.7')
    parser.add_argument('--release-tag')
    parser.add_argument('--windows-input', type=Path, default=ROOT/'.dart_tool/component-inputs/windows')
    parser.add_argument('--platform', choices=['all','android','windows'], default='all')
    args = parser.parse_args()
    global RELEASE_TAG
    version=re.search(r'^version:\s*(\d+\.\d+\.\d+)\+', (ROOT/'pubspec.yaml').read_text(encoding='utf-8'),re.M).group(1)
    RELEASE_TAG = args.release_tag or 'v'+version
    if RELEASE_TAG != 'v'+version: raise SystemExit('Release tag differs from pubspec.yaml')
    args.output.mkdir(parents=True, exist_ok=True)
    resources = []
    font_root = ROOT/'resources/fonts'
    for identifier,title,names,license_name in [
        ('rounded','Resource Han Rounded',['ResourceHanRoundedCN-Regular.ttf','ResourceHanRoundedCN-Bold.ttf'],'ResourceHanRounded-OFL.txt'),
        ('huninn','jf open huninn',['Huninn.ttf'],'Huninn-OFL.txt'),
        ('maiyuan','Kingnam Maiyuan',['Maiyuan.ttf'],'Maiyuan-OFL.txt')]:
        files={name:(font_root/name).read_bytes() for name in names}
        files[license_name]=(font_root/license_name).read_text(encoding='utf-8').encode('utf-8')
        resources.append(build_pack(args.output,identifier,title,files))
    notices=(ROOT/'resources/video/NOTICE.txt').read_text(encoding='utf-8').encode('utf-8')
    licenses={'LICENSE-'+f.name:f.read_text(encoding='utf-8').encode('utf-8') for f in (ROOT/'resources/video/licenses').glob('*.txt')}
    if args.platform in ['all','android']:
        for abi in ['arm64-v8a','armeabi-v7a','x86_64']:
            if args.android_apk:
                with zipfile.ZipFile(args.android_apk) as archive:
                    library=archive.read(f'lib/{abi}/libmpv.so')
            else:
                jar=args.android_jars/f'default-{abi}.jar'
                if not jar.exists():
                    jar.parent.mkdir(parents=True,exist_ok=True)
                    url=f'https://github.com/media-kit/libmpv-android-video-build/releases/download/v1.1.7/default-{abi}.jar'
                    with urllib.request.urlopen(url,timeout=120) as response: jar.write_bytes(response.read())
                data=jar.read_bytes()
                if digest(data) != ANDROID_JAR_SHA256[abi]: raise SystemExit(f'Upstream checksum mismatch: {jar}')
                with zipfile.ZipFile(io.BytesIO(data)) as archive:
                    library=archive.read(f'lib/{abi}/libmpv.so')
            files={'libmpv.so':library,'NOTICE.txt':notices,**licenses}
            resources.append(build_pack(args.output,'video-android-'+abi,'Video playback',files,
                platform='android',abi=abi,entrypoint='libmpv.so'))
    if args.platform in ['all','windows']:
        names=['orbit_video_backend.dll','libmpv-2.dll','libEGL.dll','libGLESv2.dll','d3dcompiler_47.dll','vk_swiftshader.dll','vulkan-1.dll','zlib.dll']
        files={name:(args.windows_input/name).read_bytes() for name in names}
        files['NOTICE.txt']=notices
        files.update(licenses)
        resources.append(build_pack(args.output,'video-win-x64','Video playback',files,
            platform='windows',abi='x64',entrypoint='libmpv-2.dll'))
    catalog=ROOT/'assets/components/catalog.json'
    catalog.parent.mkdir(parents=True,exist_ok=True)
    if catalog.exists() and args.platform != 'all':
        replaced={item['id'] for item in resources}
        resources.extend(item for item in json.loads(catalog.read_text(encoding='utf-8'))['components'] if item['id'] not in replaced)
    catalog.write_text(json.dumps(dict(schema=1,components=resources),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (args.output/'component-catalog.json').write_bytes(catalog.read_bytes())
    checks=[]
    for item in resources:
        file=args.output/Path(item['url']).name
        if file.exists():
            data=file.read_bytes()
            if len(data) != item['size'] or digest(data) != item['sha256']: raise SystemExit(f'Pack/catalog mismatch: {file}')
            checks.append(f"{item['sha256']}  {file.name}\n")
    checks.append(f"{digest(catalog.read_bytes())}  component-catalog.json\n")
    (args.output/'COMPONENT_SHA256SUMS.txt').write_text(''.join(checks),encoding='utf-8')
    print('Built',len(resources),'verified component packs in',args.output)
if __name__=='__main__': main()
