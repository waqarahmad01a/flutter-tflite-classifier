"""Run Flutter tests with tflite_flutter's macOS native test library.

The package expects the dylib beside the Flutter engine, rather than inside its
own pub-cache folder. A temporary symlink is removed even if a test fails.
"""
import json
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import unquote, urlparse

root = Path(__file__).resolve().parent.parent
flutter = shutil.which('flutter')
if not flutter or sys.platform != 'darwin':
    sys.exit('Run on macOS with Flutter on PATH.')
config = root / '.dart_tool/package_config.json'
packages = json.loads(config.read_text())['packages']
package = next(p for p in packages if p['name'] == 'tflite_flutter')
uri = urlparse(package['rootUri'])
package_root = (Path(unquote(uri.path)) if uri.scheme == 'file'
                else (config.parent / unquote(package['rootUri'])).resolve())
source = package_root / 'macos/libtensorflowlite_c-mac.dylib'
resources = Path(flutter).resolve().parents[1] / 'bin/cache/artifacts/engine/resources'
link = resources / source.name
created_dir = not resources.exists()
created_link = not link.exists() and not link.is_symlink()
resources.mkdir(exist_ok=True)
if created_link:
    link.symlink_to(source)
try:
    result = subprocess.run([flutter, 'test', '--no-pub', '--reporter', 'expanded', *sys.argv[1:]], cwd=root)
finally:
    if created_link:
        link.unlink()
    if created_dir:
        resources.rmdir()
sys.exit(result.returncode)
