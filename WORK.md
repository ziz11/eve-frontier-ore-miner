# EVE Frontier Ore Miner

## Current Mode
- `LOCK` is currently not usable and is not part of the supported flow.
- Supported runtime is `ASSIST` (`F7`) with pre-locked targets.

## Main Files
- `script.ahk`: entry script
- `miner.ahk`: core logic
- `config.ini`: local runtime config
- `config.ini.example`: current ASSIST-only template
- `eve_inventory_calibrate/config.layout.ini`: generated layout overrides

## Operational Steps
1. Run inventory calibrator to refresh `config.layout.ini`.
2. Set `layout.storage_row_index` and `layout.ore_slot_indices` in `config.ini`.
3. Reload AHK (`F10`).
4. Start `ASSIST` (`F7`).

## Config Scope
Only config keys present in `config.ini.example` are considered current.
Legacy lock/asteroid settings are intentionally excluded from the template.

