from pathlib import Path
import hashlib
import json
import zipfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
repo = root.parent
dist = root / 'dist'
version = ET.parse(root / 'app' / 'Package.appxmanifest').getroot().find('{http://schemas.microsoft.com/appx/manifest/foundation/windows10}Identity').get('Version')
release = dist / f'Komet.W10M_{version}_ARM.zip'
source = dist / f'Komet.W10M_{version}_Source.zip'
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as archive:
    for folder in ['app', 'tools', 'tests', 'third_party']:
        for path in sorted((root / folder).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts:
                archive.write(path, 'w10m/' + path.relative_to(root).as_posix())
    archive.write(root / 'README.md', 'w10m/README.md')
    archive.write(root / 'FEATURES.md', 'w10m/FEATURES.md')
    archive.write(root / '.gitignore', 'w10m/.gitignore')
    archive.write(repo / 'LICENSE', 'LICENSE')
    archive.write(repo / 'assets' / 'komet_icon.png', 'assets/komet_icon.png')
with zipfile.ZipFile(release, 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in [f'Komet.W10M_{version}_ARM.appx', 'Komet.W10M.Development.cer']:
        archive.write(dist / name, name)
    archive.write(root / 'README.md', 'README.md')
    archive.write(root / 'FEATURES.md', 'FEATURES.md')
    archive.write(repo / 'LICENSE', 'LICENSE.txt')
hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(dist.iterdir())
          if p.suffix in {'.appx', '.cer', '.zip'}}
(dist / 'SHA256.json').write_text(json.dumps(hashes, indent=2) + '\n', encoding='utf-8')
print('Created install/source archives and SHA256.json; private signing material excluded.')
