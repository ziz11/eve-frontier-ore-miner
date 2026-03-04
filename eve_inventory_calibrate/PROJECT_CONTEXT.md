# Project Context: EVE Frontier Ore Miner — Inventory Calibration + Transfer (AHK v2)

## Goal

We want an **AutoHotkey v2** bot that can reliably interact with the game's **Inventory UI** using:
- pixel-based detection (no OCR)
- drag-and-drop moves from ore slots to a target storage row

The UI can shift between runs; therefore, we introduce a **Python calibration step** that analyzes a screenshot and outputs a machine-readable layout file.

## Calibration Output

Python produces `layout.json` and `config.layout.ini` with coordinates and derived offsets. AHK uses INI overrides for runtime:
- locating Ship row (anchor)
- locating storage rows (Portable Storage, etc.)
- locating ore slots (icons) in the ore area

### Key Requirements
- **Ore may be absent** in inventory. In that case:
  - `ore.slots_count == 0`
  - `ore.slot_fallback` is always provided so AHK still has a stable “slot 1” coordinate to attempt operations / keep logic simple.

## Files

- `eve_inventory_calibrate.py`  
  A single-file tool that:
  1) detects Ship green marker (heuristic)
  2) computes inventory anchor from stable offsets
  3) estimates storage row centers
  4) detects ore icon centers inside `ore_roi` (contour-based; no OCR)
  5) writes `layout.json`
  6) writes `config.layout.ini` for AHK runtime overrides
  7) optionally writes `layout_preview.png` with overlays

## How to Run (Local / CLI)

Install deps:
- `pip install opencv-python numpy`

Run calibration:
- `python eve_inventory_calibrate.py --image "screenshot.jpg" --out-json layout.json --out-ini config.layout.ini --out-preview layout_preview.png`

## How AHK v2 Uses calibration output

AHK v2 reads generated `config.layout.ini` and combines it with explicit user choices from `config.ini`:
- `layout.storage_row_index`: which storage row to use (1-based)
- `layout.ore_slot_indices`: which detected ore slots to drag (1-based list)

Runtime selection:
- storage row target: `layout_storage_rows[storage_row_index]`
- ore source slots:
  - from detected `layout_ore_slots` by indices from `layout.ore_slot_indices`
  - if no detected slots: `layout_ore_slot_fallback`

### JSON Schema (subset)

```json
{
  "screen": { "w": 2048, "h": 1152, "base_w": 1920, "base_h": 1080, "scale_x": 1.066, "scale_y": 1.066 },
  "inventory": { "anchor": { "x": 1550, "y": 785 }, "ship_marker": { "x": 1582, "y": 850 } },
  "storage": {
    "rows": [ { "x": 1582, "y": 910 }, ... ],
    "rows_offset": [ { "dx": 32, "dy": 125 }, ... ],
    "row_count": 5
  },
  "ore": {
    "roi": { "x1": 1710, "y1": 810, "x2": 2015, "y2": 950 },
    "slots": [ { "x": 1760, "y": 860 }, ... ],
    "slots_count": 6,
    "slot_fallback": { "x": 1765, "y": 860 }
  }
}
```

## AHK v2 Integration Notes

### Drag & Drop
Use a robust drag routine with small pauses + multi-step movement.

### Why INI bridge
AHK v2 already uses `IniRead` heavily, so using generated `config.layout.ini` avoids bundling/parsing JSON in bot runtime.

## Current Heuristic Assumptions

- Inventory UI is located in the **bottom-right** area of the screen.
- A small green marker exists near the Ship row.
- Inventory anchor can be derived by stable offsets from ship marker:
  - `inv_x = ship_x - 32`
  - `inv_y = ship_y - 65`
- Storage rows support 3 modes:
  - `auto` (default): parse row Y positions from screenshot, fallback to estimated.
  - `parsed`: parse from screenshot only.
  - `estimated`: constant row height (`row_h = 25`).
- Ore ROI is derived from inventory anchor:
  - `ore_roi = (inv_x + 160, inv_y + 25, inv_x + 465, inv_y + 165)`
- Ore slots are detected by contouring square-ish icons inside `ore_roi`.
- If no ore icons are detected, tool synthesizes several virtual first-row slots from `ore_roi`
  and still writes `layout_ore_slot_fallback` for single-point fallback.

## Future Improvements

- Replace Ship-marker detection with **header-based** detection (template match for "INVENTORY") for higher robustness.
- Auto-estimate row height by detecting multiple list rows instead of fixed `row_h`.
- Detect full ore grid (row1+row2) if needed, not only row1 ROI.

## Workflow

1) Start game, place inventory UI in standard position.
2) Take screenshot (or have your bot take it).
3) Run `eve_inventory_calibrate.py` -> get `layout.json` + `config.layout.ini`.
4) Set `layout.storage_row_index` and `layout.ore_slot_indices` in `config.ini`.
5) Start AHK bot -> it reads `config.ini` + `config.layout.ini`, then performs transfer logic.
