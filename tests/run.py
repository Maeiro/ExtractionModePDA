import argparse
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--extraction-root', required=True, type=Path)
args = parser.parse_args()
for name in ['garage_preview_safety_spec.lua', 'ui_pages_spec.lua']:
    lua = LuaRuntime()
    lua.globals().clientPath = (root / '42/media/lua/client').as_posix()
    lua.globals().layoutSource = (args.extraction_root / '42/media/lua/client/ExtractionMode/TextLayout.lua').read_text(encoding='utf-8-sig')
    lua.execute('package.path = clientPath .. "/?.lua;" .. package.path')
    lua.execute((root / 'tests' / name).read_text(encoding='utf-8'))
