"""Lossless font compression. Optional regeneration tool: fonttools[woff]."""
from pathlib import Path
import json

from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parent.parent
source = root / 'assets/fonts/NotoSansSC.ttf'
target = source.with_suffix('.woff2')
temporary = target.with_suffix('.woff2.tmp')

font = TTFont(source, recalcTimestamp=False)
cmap = font.getBestCmap()
glyphs = font['maxp'].numGlyphs
axes = [(axis.axisTag, axis.minValue, axis.defaultValue, axis.maxValue)
        for axis in font['fvar'].axes]
font.flavor = 'woff2'
font.save(temporary)

compressed = TTFont(temporary)
assert compressed.getBestCmap() == cmap, 'Font character coverage changed'
assert compressed['maxp'].numGlyphs == glyphs, 'Font glyphs were lost'
assert [(axis.axisTag, axis.minValue, axis.defaultValue, axis.maxValue)
        for axis in compressed['fvar'].axes] == axes, 'Font weights changed'
compressed.close()
temporary.replace(target)

report = {
    'sourceBytes': source.stat().st_size,
    'compressedBytes': target.stat().st_size,
    'retainedCharacters': len(cmap),
    'retainedGlyphs': glyphs,
    'retainedAxes': axes,
}
(root / 'assets/fonts/compression.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
