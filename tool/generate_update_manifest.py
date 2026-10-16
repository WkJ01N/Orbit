"""Generate release metadata from the actual, already signed/package assets."""
import argparse
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("release_directory", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
version, build = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)", (root / "pubspec.yaml").read_text(encoding="utf-8"), re.M).groups()
def describe(file):
    with file.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {"name": file.name, "size": file.stat().st_size, "sha256": digest}

assets = {}
abis = {}
for abi in ("arm64-v8a", "armeabi-v7a", "x86_64"):
    files = list(args.release_directory.glob(f"*-{abi}.apk"))
    if len(files) > 1:
        raise SystemExit(f"Duplicate {abi} packages")
    if files:
        abis[abi] = describe(files[0])
for platform, pattern in (("android", "*-android.apk"), ("windows", "*windows*.zip")):
    files = sorted(args.release_directory.glob(pattern))
    if len(files) != 1:
        raise SystemExit(f"Expected exactly one {platform} package, found {len(files)}")
    assets[platform] = describe(files[0])
manifest = {"schemaVersion": 1, "version": version, "buildNumber": int(build), "assets": assets, "androidAbis": abis}
(args.release_directory / "update-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(args.release_directory / "SHA256SUMS.txt").write_text("".join(f"{a['sha256']}  {a['name']}\n" for a in [*assets.values(), *abis.values()]), encoding="utf-8")
print(f"Manifest generated: {version}+{build}")
