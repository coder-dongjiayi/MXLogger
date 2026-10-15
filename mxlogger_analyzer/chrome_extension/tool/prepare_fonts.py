"""Generate a small UI font, coverage manifest and an optional full font pack.

Regeneration requires fonttools[woff]. Normal builds use the checked-in assets.
"""
from pathlib import Path
import hashlib
import json
import re
import shutil
from urllib.parse import urlparse, unquote

from fontTools import subset
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable

root = Path(__file__).resolve().parent.parent
library = root.parent / 'mxlogger_analyzer_lib'
source = root / 'assets/fonts/NotoSansSC.ttf'
target = root / 'assets/fonts/MXInterface.woff2'
full = TTFont(source, recalcTimestamp=False)
original = full.getBestCmap()
characters = set(range(32, 127)) | set(range(160, 592))
characters.update(map(ord, '星期周年月日一二三四五六七八九十〇零上午下午'))

def collect(value):
    if isinstance(value, str):
        characters.update(map(ord, value))
    elif isinstance(value, dict):
        for child in value.values():
            collect(child)
    elif isinstance(value, list):
        for child in value:
            collect(child)

for path in (library / 'lib/src/app/l10n').glob('app_*.arb'):
    collect(json.loads(path.read_text()))
for directory in [library / 'lib', root / 'lib']:
    for path in directory.rglob('*.dart'):
        for match in re.finditer(r'''(['"])((?:\\.|(?!\1).)*?)\1''', path.read_text(), re.S):
            collect(match.group(2))
# Date pickers and text-selection menus also use Flutter's own Chinese labels.
config = json.loads((root / '.dart_tool/package_config.json').read_text())
localizations = next(package for package in config['packages'] if package['name'] == 'flutter_localizations')
sdk_labels = Path(unquote(urlparse(localizations['rootUri']).path)) / 'lib/src/l10n'
for path in sdk_labels.glob('generated_*_localizations.dart'):
    for match in re.finditer(r'(?ms)^class \w+LocalizationZh(?:Hans)? extends .*?(?=^class |\Z)', path.read_text()):
        collect(match.group())
requested_characters = characters.copy()
characters &= set(original)
options = subset.Options()
options.layout_features = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=characters)
subsetter.subset(full)
full.flavor = 'woff2'
full.save(target)
ui_cmap = TTFont(target).getBestCmap()
assert set(ui_cmap) == characters, 'UI characters lost during subsetting'

# An explicit placeholder prevents Flutter from attempting to fetch fallback
# fonts before the user chooses to install a pack. Detection excludes this font.
builder = FontBuilder(1000, isTTF=True)
builder.setupGlyphOrder(['.notdef', 'box'])
empty = TTGlyphPen(None).glyph()
pen = TTGlyphPen(None)
pen.moveTo((100, 0)); pen.lineTo((100, 700)); pen.lineTo((600, 700)); pen.lineTo((600, 0)); pen.closePath()
pen.moveTo((150, 50)); pen.lineTo((550, 50)); pen.lineTo((550, 650)); pen.lineTo((150, 650)); pen.closePath()
builder.setupGlyf({'.notdef': empty, 'box': pen.glyph()})
builder.setupHorizontalMetrics({'.notdef': (700, 0), 'box': (700, 100)})
builder.setupHorizontalHeader(ascent=800, descent=-200)
builder.setupCharacterMap({0xFFFD: 'box'})
placeholder = CmapSubtable.newSubtable(13)
placeholder.platformID = 0
placeholder.platEncID = 6
placeholder.language = 0
placeholder.cmap = {cp: 'box' for cp in range(0x110000) if not 0xD800 <= cp <= 0xDFFF}
builder.font['cmap'].tables = [placeholder]
builder.setupNameTable({'familyName': 'MX Missing Glyph', 'styleName': 'Regular',
                       'uniqueFontIdentifier': 'MXMissingGlyph-1', 'fullName': 'MX Missing Glyph',
                       'psName': 'MXMissingGlyph-Regular', 'version': 'Version 1.0'})
builder.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
builder.setupPost()
builder.setupMaxp()
builder.font.flavor = 'woff2'
builder.save(root / 'assets/fonts/MXMissingGlyph.woff2')

def ranges(points):
    result = []
    for cp in sorted(points):
        if result and cp == result[-1][1] + 1:
            result[-1][1] = cp
        else:
            result.append([cp, cp])
    return result

coverage = set(ui_cmap)
symbol_fonts = []
for family, filename in [('NotoSansSymbols2', 'MXSymbols.woff2'), ('NotoSansMath', 'MXMath.woff2')]:
    font = TTFont(root / 'assets/fonts' / f'{family}.woff2', recalcTimestamp=False)
    original_symbols = set(font.getBestCmap())
    # Keep all BMP symbols and every character used by the interface. Uncommon
    # supplementary symbols remain available in the optional original fonts.
    keep = {cp for cp in original_symbols if cp < 0x10000 or cp in requested_characters}
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=keep)
    subsetter.subset(font)
    font.flavor = 'woff2'
    symbol_target = root / 'assets/fonts' / filename
    font.save(symbol_target)
    assert set(TTFont(symbol_target).getBestCmap()) == keep, 'Symbol characters lost'
    coverage.update(keep)
    symbol_fonts.append({'family': family, 'characters': len(keep), 'bytes': symbol_target.stat().st_size})

# Declare this exact SDK fallback as Roboto, so Flutter does not inject a second
# TTF. This is lossless compression with the same complete glyph coverage.
sdk = Path(unquote(urlparse(localizations['rootUri']).path)).parents[1]
roboto = TTFont(sdk / 'engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf', recalcTimestamp=False)
roboto_cmap = roboto.getBestCmap()
roboto_glyphs = roboto['maxp'].numGlyphs
roboto.flavor = 'woff2'
roboto_target = root / 'assets/fonts/MXRoboto.woff2'
roboto.save(roboto_target)
compressed_roboto = TTFont(roboto_target)
assert compressed_roboto.getBestCmap() == roboto_cmap, 'Roboto coverage changed'
assert compressed_roboto['maxp'].numGlyphs == roboto_glyphs, 'Roboto glyphs lost'
coverage.update(roboto_cmap)
font_path = 'google/fonts/2894aab31764f10f29c421bdfd2340d3b382d384/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf'
cdn_url = 'https://cdn.jsdelivr.net/gh/' + font_path.replace('fonts/', 'fonts@', 1)
upstream_url = 'https://raw.githubusercontent.com/' + font_path
manifest = {
    'version': 2,
    'bundledRanges': ranges(coverage),
    'uiCharacters': len(ui_cmap),
    'uiBytes': target.stat().st_size,
    'pack': {
        'id': 'cjk',
        'url': cdn_url,
        'sources': [
            {'name': 'jsDelivr', 'url': cdn_url},
            {'name': 'Google Fonts (GitHub)', 'url': upstream_url},
        ],
        'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'downloadBytes': source.stat().st_size,
        'characters': len(original),
    },
}
(root / 'web/font-manifest.json').write_text(json.dumps(manifest, separators=(',', ':')))
packs = root / 'dist/font-packs'
packs.mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'assets/fonts/NotoSansSC.woff2', packs / 'mxlogger-cjk.woff2')
shutil.copy2(root / 'assets/fonts/OFL.txt', packs / 'OFL.txt')
for family in ['NotoSansSymbols2', 'NotoSansMath']:
    shutil.copy2(root / 'assets/fonts' / f'{family}.woff2', packs / f'{family}.woff2')
    shutil.copy2(root / 'web/fonts' / family.lower() / 'OFL.txt', packs / f'{family}-OFL.txt')
print(json.dumps({'uiBytes': manifest['uiBytes'], 'uiCharacters': manifest['uiCharacters'],
                  'symbolFonts': symbol_fonts, 'robotoBytes': roboto_target.stat().st_size,
                  'optionalFontBytes': (packs / 'mxlogger-cjk.woff2').stat().st_size}, indent=2))
