"""Exercise the release manifest against actual package bytes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('generate_update_manifest.py')

class ManifestTests(unittest.TestCase):
    def generate(self, folder):
        return subprocess.run([sys.executable, str(SCRIPT), str(folder)], capture_output=True, text=True)

    def test_universal_and_variants_have_distinct_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            names = ['orbit-v1.5.6-android.apk', 'orbit-v1.5.6-windows-x64.zip']
            names += [f'orbit-v1.5.6-android-{abi}.apk' for abi in ('arm64-v8a', 'armeabi-v7a', 'x86_64')]
            for name in names:
                (root / name).write_bytes(name.encode())
            result = self.generate(root)
            self.assertEqual(result.returncode, 0, result.stderr)
            manifest = json.loads((root / 'update-manifest.json').read_text())
            self.assertEqual(manifest['schemaVersion'], 1)
            self.assertEqual(len(manifest['androidAbis']), 3)
            self.assertEqual(manifest['assets']['android']['name'], names[0])
            for entry in [*manifest['assets'].values(), *manifest['androidAbis'].values()]:
                payload = (root / entry['name']).read_bytes()
                self.assertEqual(entry['sha256'], hashlib.sha256(payload).hexdigest())
                self.assertEqual(entry['size'], len(payload))
            self.assertEqual(len((root / 'SHA256SUMS.txt').read_text().splitlines()), 5)

    def test_legacy_packages_and_missing_universal(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'orbit-v1.5.6-android.apk').write_bytes(b'apk')
            (root / 'orbit-v1.5.6-windows-x64.zip').write_bytes(b'zip')
            self.assertEqual(self.generate(root).returncode, 0)
            self.assertEqual(json.loads((root / 'update-manifest.json').read_text())['androidAbis'], {})
            (root / 'orbit-v1.5.6-android.apk').unlink()
            self.assertNotEqual(self.generate(root).returncode, 0)

if __name__ == '__main__':
    unittest.main()
