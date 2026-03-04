# Project Context: EVE Frontier Ore Miner - Inventory Calibration + Transfer (AHK v2)

## Goal

Build an **AutoHotkey v2** bot that can reliably interact with the game's **Inventory UI** using:
- pixel-based detection (no OCR),
- drag-and-drop transfer from ore slots to selected storage row.

Because UI position can shift, there is a **Python calibration step** that analyzes a screenshot and writes a machine-readable layout file.

## Calibration Output

Python produces `layout.json` and `config.layout.ini` with coordinates and offsets used by AHK runtime:
- ship row click point,
- storage rows,
- ore ROI,
- ore slot points,
- target-lock slots in top-right HUD,
- target region bounds.

### Key Requirement
- Ore may be absent in inventory.
- In that case, calibrator still writes:
  - synthetic `layout_ore_slots` candidates,
  - `layout_ore_slot_fallback` for a stable single-point fallback.

## Files

- `eve_inventory_calibrate.py`  
  Single-file tool that:
  1) detects ship green marker (heuristic),
  2) computes inventory anchor from stable offsets,
  3) builds storage row centers (`auto`/`parsed`/`estimated`),
  4) detects ore icon centers in `ore_roi` (contour-based),
  5) detects target circles in top-right HUD and outputs lower-arc direct-click points,
  6) writes `layout.json`,
  7) writes `config.layout.ini` for AHK overrides,
  8) optionally writes `layout_preview.png`.

## How to Run

Install deps:
- `pip install -r requirements.txt`

Run calibration:
- `python eve_inventory_calibrate/eve_inventory_calibrate.py --image "screenshot.jpg" --out-json eve_inventory_calibrate/layout.json --out-ini eve_inventory_calibrate/config.layout.ini --out-preview eve_inventory_calibrate/layout_preview.png`

Optional row mode:
- `--storage-row-mode auto|parsed|estimated`

Optional ship-row click offset:
- `--row-text-offset-x 72`

## How AHK Uses Output

AHK reads `config.layout.ini` and combines it with user choices in `config.ini`:
- `layout.storage_row_index` (1-based target row),
- `layout.ore_slot_indices` (1-based ore slots subset).

Runtime selection:
- storage target = `layout_storage_rows[storage_row_index]`,
- ore source slots = selected indices from `layout_ore_slots`,
- fallback = `layout_ore_slot_fallback` when detected list is empty,
- target select candidates = `layout_target_slots` when available.
  These points are final direct-click coordinates (same semantics as manual `target_slots`).

## Current Heuristics

- Inventory expected in bottom-right screen area.
- Ship marker search ROI is bottom-right slice of screenshot.
- Inventory anchor offsets:
  - `inv_x = ship_x - 32`
  - `inv_y = ship_y - 65`
- Row click X:
  - `row_click_x = ship_x + row_text_offset_x` (clamped to screen)
- Ore ROI:
  - `ore_roi = (inv_x + 140, inv_y + 20, inv_x + 470, inv_y + 170)`

## Workflow

1) Place inventory UI in stable position.
2) Take screenshot.
3) Run calibrator -> generate `layout.json` + `config.layout.ini`.
4) Set `layout.storage_row_index` and `layout.ore_slot_indices` in `config.ini`.
5) Run AHK bot.
