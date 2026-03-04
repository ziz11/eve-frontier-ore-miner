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
2. Install Python deps for calibrator:
```bash
pip install -r requirements.txt
```
3. Create local files:
   - `config.ini` from `config.ini.example`
   - `secrets.ini` from `secrets.ini.example` (optional)
4. Run inventory calibrator:
```bash
python eve_inventory_calibrate/eve_inventory_calibrate.py --image "screenshot.jpg" --out-json eve_inventory_calibrate/layout.json --out-ini eve_inventory_calibrate/config.layout.ini --out-preview eve_inventory_calibrate/layout_preview.png
```
Optional storage row detection mode:
```bash
python eve_inventory_calibrate/eve_inventory_calibrate.py --image "screenshot.jpg" --storage-row-mode auto
```
- `auto` (default): parse row positions from screenshot, fallback to estimated rows if signal is weak.
- `parsed`: force parsed row positions only.
- `estimated`: keep old fixed-step rows.
- `--ship-search-mode auto|roi|full` controls ship marker search:
  - `auto` (default): try preferred bottom-right ROI first, then full-screen fallback.
  - `roi`: only preferred ROI (fastest, legacy behavior).
  - `full`: always search whole screen (best when inventory window is moved).
- `--row-text-offset-x` controls how far right row click points are shifted from the ship marker (default `72`, toward text center).
- If ore slots are not detected on screenshot, calibrator now writes synthetic slot candidates in `layout_ore_slots` (plus `layout_ore_slot_fallback`) so AHK can still try multiple indices.
5. In `config.ini`, set at minimum:
   - `[layout] storage_row_index`
   - `[layout] ore_slot_indices`
   - `[general] target_slot_order=rtl`
   - `[lists] target_slots`
   - `[lists] laser_check_points`
   - `[lists] active_laser_slots`
6. Run `script.ahk`.

## Hotkeys (actual from `miner.ahk`)
- `F6` - one-shot ore transfer test (`ManualOreTransferTest`).
- `F7` - start/stop `ASSIST`.
- `F8` - start/stop `AUTO` (mostly recovery/testing, not recommended as main mode).
- `F10` - reload script.
- `Esc` - exit script.

## If You Do Not Use Python Calibrator
Set `layout.layout_enabled=0` in `config.ini`, then fill inventory coordinates manually:
- `[points] ship_row_x`, `ship_row_y` (click point on Ship row text center)
- `[points] portable_row_x`, `portable_row_y` (destination storage row text center)
- `[lists] ore_slots` (source drag points in ore grid)

Also still required manually (Python does not provide these):
- `[lists] target_slots`
- `[lists] laser_check_points`
- `[lists] active_laser_slots`
- `[lists] asteroid_points` (used by `AUTO` lock flow)

## What Is User-Tuned In AHK (Not In Python)
These offsets/tuners are from `config.ini` and affect runtime behavior:
- `[general] target_slot_click_offset_y`
- `[general] target_slot_exists_offset_y`
- `[general] target_slot_x_jitter_px`
- `[general] target_slot_y_search_radius_px`
- `[general] target_slot_y_search_step_px`
- `[timers] target_select_*`
- `[timers] laser_*`
- `[timers] unload_*`

## Python Scope (What It Does Not Mark Up)
Python script calibrates only inventory-related layout (`ship row`, `storage rows`, `ore ROI`, `ore slots`).
It does not auto-mark and does not auto-tune:
- asteroid lock points
- target slot points in top-right panel
- laser check points / active laser slot mapping
- combat/target colors like active orange lock state

## Minimal Config Notes
- Ore transfer path is slots-only (`TryTransferOreBySlots()`).
- Drag behavior for unload is tuned by:
  - `[general] drag_duration_ms`
  - `[general] drag_steps`
  - `[general] drag_hold_before_move_ms`
  - `[general] drag_hold_after_move_ms`
- Inventory refocus click during unload is disabled by default:
  - `[general] inventory_focus_click_enabled=0`
  - set to `1` only if game/client requires explicit click-to-focus inventory before drag.
  - when enabled, bot clicks `[points] ship_row_x/ship_row_y` first (from Python `config.layout.ini`), not `inventory_window_x/y`.
- Most timing stability is controlled by:
  - `[timers] target_select_*`
  - `[timers] laser_*`
  - `[timers] unload_*`

## Notes
- Reload script (`F10`) after config updates.
- This README hotkey list is verified against `miner.ahk` hotkey bindings (`F6/F7/F8/F10`).
- Full per-key config list is intentionally moved to [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md).

