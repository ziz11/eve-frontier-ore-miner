# Quick Start Guide

## 1) Install prerequisites
1. Install **AutoHotkey v2**.
2. Install Python dependencies:

```bash
pip install -r requirements.txt
```

## 2) Prepare local config files
Create local runtime files (do not commit secrets):
- `config.ini` from `config.ini.example`
- `secrets.ini` from `secrets.ini.example` (optional)

## 3) Calibrate layout (recommended)
Take a screenshot with inventory + top-right targets visible, then run:

```bash
python eve_inventory_calibrate/eve_inventory_calibrate.py \
  --image "screenshot.jpg" \
  --out-json eve_inventory_calibrate/layout.json \
  --out-ini eve_inventory_calibrate/config.layout.ini \
  --out-preview eve_inventory_calibrate/layout_preview.png
```

Optional:
- `--storage-row-mode auto|parsed|estimated`
- `--ship-search-mode auto|roi|full`

## 4) Minimal config values to verify
In `config.ini`, check these first:
- `[layout] layout_enabled=1`
- `[layout] storage_row_index`
- `[layout] ore_slot_indices`
- `[module_select] target_slot_order=rtl`
- `[lists] laser_check_points`
- `[lists] active_laser_slots`

If calibrator did not find target slots, set manual fallback:
- `[lists] target_slots=x,y|x,y|x,y`

## 5) Start miner
Run `script.ahk` and use hotkeys:
- `F7` for ASSIST mode
- `F8` for AUTO mode

## 6) Optional no-calibrator mode
Set:
- `[layout] layout_enabled=0`

Then configure manually:
- `[points] ship_row_x`, `ship_row_y`, `portable_row_x`, `portable_row_y`
- `[lists] ore_slots`, `target_slots`, `laser_check_points`, `active_laser_slots`
