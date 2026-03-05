# EVE Frontier Ore Miner (AutoHotkey)

AHK v2 miner bot with module-oriented runtime (`LOCK` / `SELECT` / `LASER` / `UNLOAD`) and Python-assisted layout calibration.

## Current Status
- Primary mode: `ASSIST` (`F7`) with already locked targets.
- `AUTO` (`F8`) is mostly for lock/recovery experiments.

## Documentation
- Quick start: [`docs/QUICK_START.md`](docs/QUICK_START.md)
- Module architecture: [`docs/MODULES.md`](docs/MODULES.md)
- Config reference: [`docs/CONFIG_REFERENCE.md`](docs/CONFIG_REFERENCE.md)

## Main Files
- `script.ahk` - AHK entrypoint.
- `miner.ahk` - runtime state machine and module logic.
- `config.ini.example` - categorized config template.
- `secrets.ini.example` - optional Telegram credentials template.
- `eve_inventory_calibrate/eve_inventory_calibrate.py` - screenshot calibrator.

## Hotkeys
- `F6` - one-shot ore transfer test.
- `F7` - start/stop ASSIST.
- `F8` - start/stop AUTO.
- `F10` - reload script.
- `Esc` - exit.

## Config Model (new)
Config is now split by runtime responsibility:
- `[main]` - global runtime controls.
- `[module_lock]` / `[module_select]` / `[module_laser]` / `[module_unload]` / `[module_recovery]`.
- `[deprecated]` - compatibility-only keys not used in active flow.

Backward compatibility is preserved: old keys from `[general]` and `[timers]` are still read as fallback.

## Notes
- After editing `config.ini`, reload script with `F10`.
- If using calibrator output, keep `layout.layout_enabled=1` and regenerate `eve_inventory_calibrate/config.layout.ini` when UI layout changes.
