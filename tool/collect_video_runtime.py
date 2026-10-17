"""Collect the separately built Windows renderer and pinned dependencies."""
import argparse, shutil
from pathlib import Path
parser=argparse.ArgumentParser(__doc__)
parser.add_argument('--build',type=Path,default=Path('build/windows/x64'))
parser.add_argument('--configuration',default='Release',choices=['Profile','Release'])
parser.add_argument('--output',type=Path,default=Path('.dart_tool/component-inputs/windows'))
args=parser.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
sources={'orbit_video_backend.dll':args.build/'plugins/media_kit_video'/args.configuration/'orbit_video_backend.dll',
         'libmpv-2.dll':args.build/'libmpv/libmpv-2.dll'}
for name in ['libEGL.dll','libGLESv2.dll','d3dcompiler_47.dll','vk_swiftshader.dll','vulkan-1.dll','zlib.dll']:
    sources[name]=args.build/'ANGLE'/name
for name,source in sources.items():
    if not source.is_file(): raise SystemExit(f'Missing native input: {source}')
    shutil.copy2(source,args.output/name)
print('Collected',len(sources),'Windows video runtime files')
