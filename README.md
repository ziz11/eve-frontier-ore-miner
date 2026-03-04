# EVE Frontier Ore Miner (AutoHotkey)

## Current Status
- Production flow: `ASSIST` (`F7`) with pre-locked targets.
- `LOCK` is not considered production-ready now.
- `AUTO` (`F8`) is kept mostly for recovery/testing.

## Docs Tree
- Runtime modules and function call flow: [`docs/MODULES.md`](docs/MODULES.md)
- Full config key reference (all sections/keys): [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md)

## Main Files
- `script.ahk` - entrypoint (includes `miner.ahk`)
- `miner.ahk` - state machine and bot logic
- `config.ini` - local runtime config (gitignored)
- `config.ini.example` - tracked template
- `secrets.ini` - local Telegram creds (gitignored)
- `eve_inventory_calibrate/config.layout.ini` - generated layout overrides

## Quick Start (ASSIST)
1. Install AutoHotkey v2.
2. Create local files:
   - `config.ini` from `config.ini.example`
   - `secrets.ini` from `secrets.ini.example` (optional)
3. Run inventory calibrator:
```bash
python eve_inventory_calibrate/eve_inventory_calibrate.py --image "screenshot.jpg" --out-json eve_inventory_calibrate/layout.json --out-ini eve_inventory_calibrate/config.layout.ini --out-preview eve_inventory_calibrate/layout_preview.png
```
4. In `config.ini`, set at minimum:
   - `[layout] storage_row_index`
   - `[layout] ore_slot_indices`
   - `[general] target_slot_order=rtl`
   - `[lists] target_slots`
   - `[lists] laser_check_points`
   - `[lists] active_laser_slots`
5. Run `script.ahk`.
6. Hotkeys:
   - `F7` start/stop `ASSIST`
   - `F6` one-shot ore transfer test
   - `F10` reload script
   - `Esc` exit

## Minimal Config Notes
- `ore_transfer_mode` is currently forced to `slots` in code.
- Drag behavior for unload is tuned by:
  - `[general] drag_duration_ms`
  - `[general] drag_steps`
  - `[general] drag_hold_before_move_ms`
  - `[general] drag_hold_after_move_ms`
- Most timing stability is controlled by:
  - `[timers] target_select_*`
  - `[timers] laser_*`
  - `[timers] unload_*`

## Notes
- Reload script (`F10`) after config updates.
- Full per-key config list is intentionally moved to [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md).

