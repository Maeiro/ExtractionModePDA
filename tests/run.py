import argparse
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--extraction-root', required=True, type=Path)
parser.add_argument('--pda-root', required=True, type=Path)
args = parser.parse_args()
for name in ['garage_preview_safety_spec.lua', 'ui_pages_spec.lua', 'barter_layout_spec.lua', 'service_payments_spec.lua', 'sandbox_settings_spec.lua', 'page_transition_spec.lua']:
    lua = LuaRuntime()
    lua.globals().clientPath = (root / '42/media/lua/client').as_posix()
    lua.globals().sharedPath = (root / '42/media/lua/shared').as_posix()
    lua.globals().layoutSource = (args.extraction_root / '42/media/lua/client/ExtractionMode/TextLayout.lua').read_text(encoding='utf-8-sig')
    lua.globals().serviceSource = (args.extraction_root / '42/media/lua/shared/ExtractionMode/BarterServices.lua').read_text(encoding='utf-8-sig')
    lua.globals().currencySource = (args.pda_root / '42/media/lua/shared/PRPGE_Currency.lua').read_text(encoding='utf-8-sig')
    bank_source = (args.pda_root / '42/media/lua/server/PRPGE_BankServer.lua').read_text(encoding='utf-8-sig')
    lua.globals().bankChargeSource = bank_source.split('function S.Spendable', 1)[1].split('PRPGE_SP_Bank=', 1)[0]
    lua.globals().paymentSource = (root / '42/media/lua/server/EMPD_ServicePayments.lua').read_text(encoding='utf-8')
    upgrades = (args.extraction_root / '42/media/lua/shared/ExtractionMode/Upgrades.lua').read_text(encoding='utf-8-sig')
    lua.globals().consumeSource = 'function Upgrades.requirementsMet' + upgrades.split('function Upgrades.requirementsMet', 1)[1].split('ExtractionMode.Upgrades', 1)[0]
    integration = (root / '42/media/lua/client/ExtractionModePDA/Integration.lua').read_text(encoding='utf-8')
    lua.globals().pageHookSource = 'local function installPageHooks' + integration.split('local function installPageHooks', 1)[1].split('local function installDockSkin', 1)[0] + '\nreturn installPageHooks'
    pda_source = (args.pda_root / '42/media/lua/client/PRPGE_PDA.lua').read_text(encoding='utf-8-sig')
    lua.globals().contentReadySource = 'function D.ContentReady(ui)' + pda_source.split('function D.ContentReady(ui)', 1)[1].split('\nend', 1)[0] + '\nend'
    lua.globals().transitionActiveSource = 'function D.TransitionActive(ui)' + pda_source.split('function D.TransitionActive(ui)', 1)[1].split('\nend', 1)[0] + '\nend'
    lua.execute('package.path = clientPath .. "/?.lua;" .. sharedPath .. "/?.lua;" .. package.path')
    lua.execute((root / 'tests' / name).read_text(encoding='utf-8'))
