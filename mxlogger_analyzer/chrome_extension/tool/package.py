"""Package the configured Chromium CanvasKit renderer and runtime resources."""
from pathlib import Path
import argparse
import json
import re
import shutil
import zipfile


def chrome_version(value):
    """Chrome accepts 1–4 integer components in 0..65535, not all zero."""
    if not re.fullmatch(r'(0|[1-9][0-9]{0,4})(\.(0|[1-9][0-9]{0,4})){0,3}', value):
        raise argparse.ArgumentTypeError(
            '版本号必须由 1–4 段数字组成，以点分隔且不能有前导零，例如 1.0.0。')
    parts = [int(part) for part in value.split('.')]
    if any(part > 65535 for part in parts) or not any(parts):
        raise argparse.ArgumentTypeError(
            '版本号每段必须在 0–65535 之间，且不能全部为 0。')
    return value


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--version', required=True, type=chrome_version,
                    help='Required Chrome extension version, e.g. 1.0.0.')
parser.add_argument('--validate-only', action='store_true',
                    help='Validate the version before starting the build.')
arguments = parser.parse_args()
if arguments.validate_only:
    print(f'Extension version: {arguments.version}')
    raise SystemExit(0)

source = Path('build/web')
destination = Path('dist/mxlogger-chrome-prototype')
destination.mkdir(parents=True, exist_ok=True)
font_manifest = json.loads((source / 'assets/FontManifest.json').read_text())
declared_fonts = {
    f'assets/{font["asset"]}'
    for family in font_manifest for font in family['fonts']
}

def include(path):
    relative = path.relative_to(source)
    if path.suffix in {'.map', '.deps', '.symbols'}:
        return False
    if path.name in {'version.json', '.last_build_id', 'flutter_service_worker.js'}:
        return False
    # Flutter's incremental build can leave the previous TTF beside its WOFF2
    # replacement. Include exactly the fonts used by the current manifest.
    if relative.parts[0] == 'assets' and path.suffix in {'.ttf', '.otf', '.ttc', '.woff', '.woff2'}:
        return relative.as_posix() in declared_fonts
    if relative.parts[0] == 'fonts':
        return path.name == 'OFL.txt' and (Path('web') / relative).is_file()
    # flutter_bootstrap.js fixes renderer=canvaskit, variant=chromium.
    if relative.parts[0] == 'canvaskit':
        return relative.as_posix() in {
            'canvaskit/chromium/canvaskit.js',
            'canvaskit/chromium/canvaskit.wasm',
        }
    return True

runtime = {path.relative_to(source) for path in source.rglob('*')
           if path.is_file() and include(path)}
required = {'manifest.json', 'main.dart.js', 'worker.js', 'sqlite3.wasm',
            'font-manifest.json', 'font_bridge.js',
            'canvaskit/chromium/canvaskit.js', 'canvaskit/chromium/canvaskit.wasm'}
if not required.issubset({path.as_posix() for path in runtime}):
    raise RuntimeError('Missing runtime assets; run the complete build first.')

manifest = json.loads((source / 'manifest.json').read_text())
manifest['version'] = arguments.version

# Remove obsolete files from this generated output so unpacked installs shrink
# too. Source assets and other files in dist/ are not touched.
for path in destination.rglob('*'):
    if path.is_file() and path.relative_to(destination) not in runtime:
        path.unlink()
for relative in sorted(runtime):
    path = source / relative
    target = destination / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if relative.as_posix() == 'manifest.json':
        target.write_text(json.dumps(manifest, indent=2) + '\n')
    else:
        shutil.copy2(path, target)
archive_path = Path('dist/mxlogger-chrome-prototype.zip')
with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in destination.rglob('*'):
        if path.is_file():
            archive.write(path, path.relative_to(destination))
with zipfile.ZipFile(archive_path) as archive:
    contents = sorted(archive.infolist(), key=lambda entry: entry.compress_size,
                      reverse=True)
    report = {
        'version': arguments.version,
        'zipBytes': archive_path.stat().st_size,
        'installedBytes': sum(entry.file_size for entry in contents),
        'files': [{'path': entry.filename, 'zipBytes': entry.compress_size,
                   'installedBytes': entry.file_size} for entry in contents],
    }
Path('dist/package-size.json').write_text(json.dumps(report, indent=2))
packs = Path('dist/font-packs')
packs.mkdir(parents=True, exist_ok=True)
shutil.copy2('assets/fonts/NotoSansSC.woff2', packs / 'mxlogger-cjk.woff2')
shutil.copy2('assets/fonts/OFL.txt', packs / 'OFL.txt')
for family in ['NotoSansSymbols2', 'NotoSansMath']:
    shutil.copy2(f'assets/fonts/{family}.woff2', packs / f'{family}.woff2')
    shutil.copy2(f'web/fonts/{family.lower()}/OFL.txt', packs / f'{family}-OFL.txt')
(packs / 'README.txt').write_text(
    'MXLogger Analyzer optional Chinese / common Japanese log font.\n'
    'Open Font settings, choose Import a local font, and select mxlogger-cjk.woff2.\n'
    'The font is cached in this browser for offline use.\n'
    'Full NotoSansSymbols2 / NotoSansMath packs restore uncommon supplementary symbols.\n'
    'This directory is separate from the Chrome extension installation package.\n')
print(f'Extension version: {arguments.version}')
print(f'Unpacked extension: {destination.resolve()}')
print(f'ZIP: {Path("dist/mxlogger-chrome-prototype.zip").resolve()}')
print(f'Size: {report["zipBytes"] / 1048576:.2f} MiB ZIP, '
      f'{report["installedBytes"] / 1048576:.2f} MiB installed')
