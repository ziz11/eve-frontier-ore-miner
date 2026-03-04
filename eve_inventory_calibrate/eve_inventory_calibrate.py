#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
EVE Frontier Inventory Calibrator (for AutoHotkey v2 bots)

What it does
------------
1) Reads a screenshot (png/jpg).
2) Detects Inventory UI position using a Ship-row green marker (fast heuristic).
3) Computes a stable "inventory anchor" (top-left-ish point) and derives:
   - storage rows (center points)
   - ore ROI (first row area)
4) Detects ore item icons (square-ish) inside ore ROI (no OCR; works even if ore digits absent).
5) Writes layout.json containing ONLY what was found + always provides 1 fallback ore slot
   (for cases when ore is absent).

Dependencies
------------
pip install opencv-python numpy

CLI usage
---------
python eve_inventory_calibrate.py --image "screenshot.jpg" --out-json layout.json --out-ini config.layout.ini --out-preview layout_preview.png

Notes
-----
- This version uses the Ship green marker. If that fails on your setup, implement an alternative:
  header-based inventory detection (e.g., via template match for "INVENTORY" label).
- The ore icon contour detector is tuned to your UI; thresholds can be adjusted if needed.

Authoring hint
--------------
Keep this file as a single source of truth. In Colab you can paste the same code cells:
- Cell 1: imports + functions
- Cell 2: run detect + save json + visualize (see commented snippets at bottom)
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import configparser

import cv2
import numpy as np

Point = Tuple[int, int]
Rect = Tuple[int, int, int, int]


# ---------------------------
# Utilities
# ---------------------------

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def ensure_int_point(p: Tuple[float, float] | Point) -> Point:
    return (int(round(p[0])), int(round(p[1])))


# ---------------------------
# 1) Ship marker detection
# ---------------------------

def find_ship_marker(img_bgr: np.ndarray, roi_rect: Rect) -> Optional[Point]:
    """
    Find small green marker near 'Ship (Reflex)' row.

    Args:
      img_bgr: image in BGR (cv2 default)
      roi_rect: (x1,y1,x2,y2) region to search (usually bottom-right)

    Returns:
      (x,y) in absolute screen coords, or None
    """
    x1, y1, x2, y2 = roi_rect
    roi = img_bgr[y1:y2, x1:x2]
    if roi.size == 0:
        return None

    hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)

    # Two green-ish ranges (UI can shift toward olive)
    ranges = [
        (np.array([35, 35, 35]), np.array([95, 255, 255])),   # green
        (np.array([20, 30, 30]), np.array([45, 255, 255])),   # yellow-green / olive
    ]

    mask = np.zeros((roi.shape[0], roi.shape[1]), dtype=np.uint8)
    for lo, hi in ranges:
        mask |= cv2.inRange(hsv, lo, hi)

    # Clean up noise and merge marker pixels
    kernel = np.ones((3, 3), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)

    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    best = None
    best_score = -1.0

    for c in cnts:
        area = float(cv2.contourArea(c))
        if area < 8 or area > 1200:
            continue

        x, y, w, h = cv2.boundingRect(c)
        aspect = w / max(h, 1)
        if not (0.4 <= aspect <= 2.5):
            continue

        # Prefer compact, near-square blobs
        score = area - abs(w - h) * 2.0
        if score > best_score:
            best_score = score
            best = (x, y, w, h)

    if best is None:
        return None

    bx, by, bw, bh = best
    cx = x1 + bx + bw // 2
    cy = y1 + by + bh // 2
    return (int(cx), int(cy))


def detect_storage_rows_from_profile(
    img_bgr: np.ndarray,
    ship_marker: Point,
    max_rows: int = 8,
) -> List[Point]:
    """
    Detect storage row Y positions below ship marker from the left inventory tree.
    This captures real gaps (row can be immediately below Ship or with spacing).
    """
    ship_x, ship_y = ship_marker
    h, w = img_bgr.shape[:2]

    # Narrow strip where row bullets/icons are expected in inventory tree.
    x1 = max(0, ship_x - 18)
    x2 = min(w, ship_x + 18)
    y1 = max(0, ship_y + 10)
    y2 = min(h, ship_y + 220)
    if x2 <= x1 or y2 <= y1:
        return []

    roi = img_bgr[y1:y2, x1:x2]
    hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)

    sat = hsv[:, :, 1].astype(np.float32) / 255.0
    val = hsv[:, :, 2].astype(np.float32) / 255.0
    # Weighted profile: catches both colored and bright row markers.
    profile = (0.65 * sat + 0.35 * val).mean(axis=1)
    if profile.size == 0:
        return []

    smooth = cv2.GaussianBlur(profile.reshape(-1, 1), (1, 5), 0).reshape(-1)
    threshold = float(np.percentile(smooth, 84))

    raw_peaks: List[Tuple[int, float]] = []
    for i in range(1, len(smooth) - 1):
        if smooth[i] >= smooth[i - 1] and smooth[i] > smooth[i + 1] and smooth[i] >= threshold:
            raw_peaks.append((i, float(smooth[i])))

    # Merge nearby peaks; keep strongest representative.
    merged: List[Tuple[int, float]] = []
    for yi, score in raw_peaks:
        if not merged:
            merged.append((yi, score))
            continue
        prev_y, prev_score = merged[-1]
        if yi - prev_y <= 10:
            if score > prev_score:
                merged[-1] = (yi, score)
        else:
            merged.append((yi, score))

    out: List[Point] = []
    prev_abs_y: Optional[int] = None
    for yi, _ in merged:
        abs_y = int(y1 + yi)
        if prev_abs_y is not None and (abs_y - prev_abs_y) > 70:
            break
        out.append((int(ship_x), abs_y))
        prev_abs_y = abs_y
        if len(out) >= max_rows:
            break
    return out


def estimate_storage_rows(ship_marker: Point, row_count: int = 5, row_h: int = 25, first_row_offset: int = 55) -> List[Point]:
    ship_x, ship_y = ship_marker
    y0 = ship_y + first_row_offset
    return [(int(ship_x), int(y0 + row_h * i)) for i in range(row_count)]


# ---------------------------
# 2) Ore icon detection (no OCR)
# ---------------------------

def detect_ore_slots(img_bgr: np.ndarray, ore_roi: Rect, point_mode: str = "center") -> List[Point]:
    """
    Detect ore icon centers within ore_roi by contouring square-ish icons.
    Works even if ore digits are absent (no OCR).

    Args:
      point_mode:
        - "center": use icon center as slot point
        - "lower": use lower point inside icon tile (more drag-friendly)

    Returns:
      list of absolute (x,y) slot points, sorted top-to-bottom, left-to-right.
      May be empty.
    """
    x1, y1, x2, y2 = ore_roi
    roi = img_bgr[y1:y2, x1:x2]
    if roi.size == 0:
        return []

    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)

    # Edge map for contour proposals.
    edges = cv2.Canny(gray, 40, 120)
    kernel = np.ones((3, 3), np.uint8)
    edges = cv2.dilate(edges, kernel, iterations=1)

    cnts, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    candidates: List[Tuple[int, int, int, int, int]] = []
    roi_h, roi_w = roi.shape[:2]
    for c in cnts:
        x, y, w, h = cv2.boundingRect(c)
        box_area = w * h
        if box_area < 1200 or box_area > 20000:
            continue

        aspect = w / max(h, 1)
        if not (0.65 <= aspect <= 1.45):
            continue

        # Reject tiny/noisy contours and text fragments.
        contour_area = float(cv2.contourArea(c))
        fill_ratio = contour_area / max(box_area, 1)
        if fill_ratio < 0.18:
            continue

        edge_density = float(np.count_nonzero(edges[y:y + h, x:x + w])) / max(box_area, 1)
        if edge_density < 0.05 or edge_density > 0.95:
            continue

        # Ignore very high items in ROI; ore tiles are usually in lower half.
        center_y = y + h // 2
        if center_y < int(roi_h * 0.35):
            continue

        if x < 0 or y < 0 or x + w > roi_w or y + h > roi_h:
            continue

        candidates.append((x, y, w, h, box_area))

    if not candidates:
        return []

    # Keep only boxes near dominant row to avoid accidental lower text picks.
    ys = sorted([y + h // 2 for x, y, w, h, _ in candidates])
    median_y = ys[len(ys) // 2]
    row_filtered = [b for b in candidates if abs((b[1] + b[3] // 2) - median_y) <= 20]
    if row_filtered:
        candidates = row_filtered

    # Simple dedupe by center distance; keep larger box when overlapping.
    candidates.sort(key=lambda b: b[4], reverse=True)
    deduped: List[Tuple[int, int, int, int, int]] = []
    for box in candidates:
        x, y, w, h, area = box
        cx = x + w // 2
        cy = y + h // 2
        keep = True
        for ex, ey, ew, eh, _ in deduped:
            ecx = ex + ew // 2
            ecy = ey + eh // 2
            if abs(cx - ecx) <= 16 and abs(cy - ecy) <= 16:
                keep = False
                break
        if keep:
            deduped.append(box)

    # Keep index order deterministic for AHK config (slot 1..N left->right).
    deduped.sort(key=lambda b: (b[0], b[1]))

    slots: List[Point] = []
    y_ratio = 0.50 if point_mode == "center" else 0.80
    for x, y, w, h, _ in deduped:
        cx = x + w // 2
        cy = y + int(round(h * y_ratio))
        if cy >= roi_h:
            cy = roi_h - 1
        slots.append((int(cx + x1), int(cy + y1)))

    return slots


# ---------------------------
# 3) Fallback slot (when ore absent)
# ---------------------------

def compute_fallback_ore_slot(params: Dict) -> Point:
    """
    Always returns one usable point even if ore_slots == [].

    Strategy:
    - if ore_roi exists: use percentage-based point inside ROI (scales well)
    - else: use offset from inventory anchor
    """
    inv_x, inv_y = params["inventory_anchor"]
    ore_roi = params.get("ore_roi")
    point_mode = str(params.get("ore_point_mode", "center"))

    if ore_roi:
        x1, y1, x2, y2 = ore_roi
        fx = x1 + int((x2 - x1) * 0.18)
        fy_ratio = 0.50 if point_mode == "center" else 0.57
        fy = y1 + int((y2 - y1) * fy_ratio)
        return (int(fx), int(fy))

    return (int(inv_x + 210), int(inv_y + 80))


def synthesize_ore_slots_from_roi(ore_roi: Optional[Rect], point_mode: str = "center", max_slots: int = 4) -> List[Point]:
    """
    Build virtual ore slot candidates when no icon was detected.
    This keeps transfer logic stable even if inventory currently has no ore.
    """
    if ore_roi is None:
        return []

    x1, y1, x2, y2 = ore_roi
    w = max(1, x2 - x1)
    h = max(1, y2 - y1)

    y_ratio = 0.52 if point_mode == "center" else 0.60
    y = int(y1 + h * y_ratio)

    # First row slot anchors: left-to-right spread inside ROI.
    x_ratios = [0.12, 0.30, 0.48, 0.66, 0.84]
    out: List[Point] = []
    for xr in x_ratios:
        out.append((int(x1 + w * xr), int(y)))
        if len(out) >= max_slots:
            break
    return out


# ---------------------------
# 4) Main detector (returns params dict)
# ---------------------------

def detect_inventory_layout(
    image_path: str,
    ore_point_mode: str = "center",
    storage_row_mode: str = "auto",
) -> Dict:
    """
    Detect layout from screenshot:
      - ship_marker
      - inventory_anchor (derived from ship_marker by stable offsets)
      - storage_rows (estimated)
      - ore_roi (first row area)
      - ore_slots (detected by contouring inside ore_roi)

    Returns dict 'params' for downstream steps (visualization / JSON export).
    """
    img = cv2.imread(str(image_path))
    if img is None:
        raise RuntimeError(f"Cannot read image: {image_path}")

    h, w = img.shape[:2]

    # Search ROI: bottom-right area where inventory is expected
    roi_rect: Rect = (int(w * 0.60), int(h * 0.60), int(w * 0.995), int(h * 0.99))

    ship = find_ship_marker(img, roi_rect)
    if ship is None:
        raise RuntimeError(
            "Ship marker not found. "
            "Tip: ensure Inventory is visible in bottom-right and the green marker is present. "
            "If this is unstable, switch to header-based inventory detection."
        )

    ship_x, ship_y = ship

    # Calibrated offsets from your screenshots (tune once if needed)
    inv_x = ship_x - 32
    inv_y = ship_y - 65

    parsed_storage_rows = detect_storage_rows_from_profile(img, ship)
    estimated_storage_rows = estimate_storage_rows(ship)
    storage_rows_mode_used = "estimated"
    storage_rows = estimated_storage_rows

    if storage_row_mode == "parsed":
        if parsed_storage_rows:
            storage_rows = parsed_storage_rows
            storage_rows_mode_used = "parsed"
    elif storage_row_mode == "auto":
        # Auto uses parsed rows only when signal is strong enough.
        if len(parsed_storage_rows) >= 2:
            storage_rows = parsed_storage_rows
            storage_rows_mode_used = "parsed"
    else:
        storage_rows_mode_used = "estimated"

    # Ore ROI: first row area (relative to inv anchor), widened to avoid clipping first tile.
    ore_roi: Rect = (int(inv_x + 140), int(inv_y + 20), int(inv_x + 470), int(inv_y + 170))

    detected_ore_slots = detect_ore_slots(img, ore_roi, point_mode=ore_point_mode)
    synthesized_ore_slots = synthesize_ore_slots_from_roi(ore_roi, point_mode=ore_point_mode, max_slots=4)

    ore_slots_source = "detected"
    ore_slots = detected_ore_slots
    if len(ore_slots) == 0 and len(synthesized_ore_slots) > 0:
        ore_slots = synthesized_ore_slots
        ore_slots_source = "synthetic"

    params = {
        "image_path": str(image_path),
        "image_size": (int(w), int(h)),
        "inventory_anchor": (int(inv_x), int(inv_y)),
        "ship_marker": (int(ship_x), int(ship_y)),
        "storage_rows": storage_rows,
        "storage_rows_mode": storage_rows_mode_used,
        "storage_rows_parsed_count": int(len(parsed_storage_rows)),
        "ore_roi": ore_roi,
        "ore_slots": ore_slots,
        "ore_slots_detected_count": int(len(detected_ore_slots)),
        "ore_slots_synthesized_count": int(len(synthesized_ore_slots)),
        "ore_slots_source": ore_slots_source,
        "ore_point_mode": ore_point_mode,
    }
    return params


# ---------------------------
# 5) JSON export (layout.json for AHK v2)
# ---------------------------

def save_layout_json(params: Dict, out_path: str, base_resolution: Tuple[int, int] = (1920, 1080)) -> Dict:
    """
    Writes layout.json with:
      - screen w/h, base_w/base_h, scale_x/scale_y (hints)
      - inventory anchor + ship marker
      - storage rows (abs + offsets)
      - ore ROI, slots (abs + offsets)
      - ore fallback slot ALWAYS present (for "no ore" case)
    """
    img_w, img_h = params["image_size"]
    base_w, base_h = base_resolution
    scale_x = img_w / base_w
    scale_y = img_h / base_h

    inv_x, inv_y = params["inventory_anchor"]
    ship_x, ship_y = params.get("ship_marker", (None, None))

    storage_rows: List[Point] = params.get("storage_rows", [])
    ore_roi: Optional[Rect] = params.get("ore_roi")
    ore_slots: List[Point] = params.get("ore_slots", [])
    ore_slots_source = str(params.get("ore_slots_source", "detected"))
    ore_slots_detected_count = int(params.get("ore_slots_detected_count", len(ore_slots)))

    def to_offset(pt: Point) -> Dict[str, int]:
        return {"dx": int(pt[0] - inv_x), "dy": int(pt[1] - inv_y)}

    fallback_slot = compute_fallback_ore_slot(params)

    layout = {
        "meta": {
            "generated_at": utc_now_iso(),
            "image_path": params.get("image_path"),
        },
        "screen": {
            "w": int(img_w),
            "h": int(img_h),
            "base_w": int(base_w),
            "base_h": int(base_h),
            "scale_x": float(scale_x),
            "scale_y": float(scale_y),
        },
        "inventory": {
            "anchor": {"x": int(inv_x), "y": int(inv_y)},
            "ship_marker": None if ship_x is None else {"x": int(ship_x), "y": int(ship_y)},
        },
        "storage": {
            "rows": [{"x": int(x), "y": int(y)} for (x, y) in storage_rows],
            "rows_offset": [to_offset((x, y)) for (x, y) in storage_rows],
            "row_count": int(len(storage_rows)),
        },
        "ore": {
            "roi": None if ore_roi is None else {
                "x1": int(ore_roi[0]), "y1": int(ore_roi[1]),
                "x2": int(ore_roi[2]), "y2": int(ore_roi[3]),
            },
            "slots": [{"x": int(x), "y": int(y)} for (x, y) in ore_slots],
            "slots_offset": [to_offset((x, y)) for (x, y) in ore_slots],
            "slots_count": int(len(ore_slots)),
            "slots_source": ore_slots_source,
            "slots_detected_count": int(ore_slots_detected_count),
            "slot_fallback": {"x": int(fallback_slot[0]), "y": int(fallback_slot[1])},
            "slot_fallback_offset": to_offset(fallback_slot),
        },
    }

    out_path = str(out_path)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(layout, f, ensure_ascii=False, indent=2)

    return layout


def points_to_ini(raw_points: List[Dict[str, int]]) -> str:
    parts: List[str] = []
    for p in raw_points:
        parts.append(f"{int(p['x'])},{int(p['y'])}")
    return "|".join(parts)


def save_layout_ini(layout: Dict, out_path: str) -> None:
    """
    Writes config.layout.ini consumed by AHK:
      - points/regions overrides
      - full storage row list
      - full detected ore slot list (+ fallback)
    """
    cfg = configparser.ConfigParser()
    cfg.optionxform = str

    ship = layout["inventory"]["ship_marker"] or {}
    ore_roi = layout["ore"]["roi"] or {}
    storage_rows = layout["storage"]["rows"] or []
    ore_slots = layout["ore"]["slots"] or []
    ore_fallback = layout["ore"]["slot_fallback"]

    cfg["points"] = {
        "ship_row_x": str(int(ship.get("x", 0))),
        "ship_row_y": str(int(ship.get("y", 0))),
    }
    cfg["regions"] = {
        "ore_scan_x1": str(int(ore_roi.get("x1", 0))),
        "ore_scan_y1": str(int(ore_roi.get("y1", 0))),
        "ore_scan_x2": str(int(ore_roi.get("x2", 0))),
        "ore_scan_y2": str(int(ore_roi.get("y2", 0))),
    }
    cfg["lists"] = {
        "layout_storage_rows": points_to_ini(storage_rows),
        "layout_ore_slots": points_to_ini(ore_slots),
        "layout_ore_slot_fallback": f"{int(ore_fallback['x'])},{int(ore_fallback['y'])}",
    }
    cfg["meta"] = {
        "layout_generated_at": layout["meta"]["generated_at"],
        "layout_image_path": str(layout["meta"]["image_path"]),
    }

    with open(out_path, "w", encoding="utf-8") as f:
        cfg.write(f)


# ---------------------------
# 6) Preview overlay image (for verification)
# ---------------------------

def render_preview(image_path: str, params: Dict, out_path: str) -> None:
    """
    Writes a preview PNG with overlays:
      - INV anchor (red)
      - SHIP marker (green)
      - storage rows S1..S5 (yellow)
      - ore ROI rectangle (magenta)
      - ore slots O1..On (cyan)
    """
    img = cv2.imread(str(image_path))
    if img is None:
        raise RuntimeError(f"Cannot read image: {image_path}")

    draw = img.copy()

    inv_x, inv_y = params["inventory_anchor"]
    ship_x, ship_y = params["ship_marker"]
    storage_rows: List[Point] = params.get("storage_rows", [])
    ore_roi: Optional[Rect] = params.get("ore_roi")
    ore_slots: List[Point] = params.get("ore_slots", [])

    # INV anchor (red) - BGR
    cv2.circle(draw, (inv_x, inv_y), 10, (0, 0, 255), -1)
    cv2.putText(draw, "INV", (inv_x + 12, inv_y + 12), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)

    # SHIP marker (green)
    cv2.circle(draw, (ship_x, ship_y), 10, (0, 255, 0), -1)
    cv2.putText(draw, "SHIP", (ship_x + 12, ship_y + 12), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    # Storage rows (yellow)
    for i, (x, y) in enumerate(storage_rows, start=1):
        cv2.circle(draw, (x, y), 8, (0, 255, 255), -1)
        cv2.putText(draw, f"S{i}", (x + 10, y + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)

    # Ore ROI (magenta)
    if ore_roi:
        x1, y1, x2, y2 = ore_roi
        cv2.rectangle(draw, (x1, y1), (x2, y2), (255, 0, 255), 2)
        cv2.putText(draw, "ORE ROI", (x1, max(0, y1 - 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 255), 2)

    # Ore slots (cyan-ish)
    for i, (x, y) in enumerate(ore_slots, start=1):
        cv2.circle(draw, (x, y), 8, (255, 255, 0), -1)
        cv2.putText(draw, f"O{i}", (x + 10, y + 5), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)

    cv2.imwrite(str(out_path), draw)


# ---------------------------
# 7) CLI entrypoint
# ---------------------------

def print_summary(
    params: Dict,
    layout: Dict,
    out_json: str,
    out_preview: Optional[str],
    out_ini: Optional[str],
) -> None:
    inv_x, inv_y = params["inventory_anchor"]
    ship_x, ship_y = params["ship_marker"]
    slots_count = layout["ore"]["slots_count"]
    slots_source = params.get("ore_slots_source", "detected")
    detected_count = int(params.get("ore_slots_detected_count", slots_count))

    print("=== Calibration summary ===")
    print(f"Image: {params.get('image_path')}")
    print(f"Size:  {params['image_size'][0]}x{params['image_size'][1]}")
    print(f"INV:   ({inv_x}, {inv_y})")
    print(f"SHIP:  ({ship_x}, {ship_y})")
    print(f"Storage rows: {layout['storage']['row_count']} ({params.get('storage_rows_mode', 'estimated')})")
    print(f"Ore point mode: {params.get('ore_point_mode', 'center')}")
    print(f"Ore slots: {slots_count} (source={slots_source}, detected={detected_count})")
    if slots_count == 0:
        fb = layout["ore"]["slot_fallback"]
        print(f"Ore fallback slot: ({fb['x']}, {fb['y']})")
    print(f"Wrote JSON: {out_json}")
    if out_ini:
        print(f"Wrote INI: {out_ini}")
    if out_preview:
        print(f"Wrote preview: {out_preview}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True, help="Path to screenshot (png/jpg)")
    ap.add_argument("--out-json", default="layout.json", help="Output JSON path")
    ap.add_argument("--out-ini", default="config.layout.ini", help="Output INI path for AHK overrides")
    ap.add_argument("--out-preview", default="", help="Optional output preview PNG path (if empty, no preview)")
    ap.add_argument("--base-w", type=int, default=1920, help="Base width for scale hints")
    ap.add_argument("--base-h", type=int, default=1080, help="Base height for scale hints")
    ap.add_argument("--ore-point-mode", choices=["center", "lower"], default="center", help="How slot point is placed: icon center or lower drag-friendly point")
    ap.add_argument(
        "--storage-row-mode",
        choices=["auto", "parsed", "estimated"],
        default="auto",
        help="How to build storage rows: parse from image, estimate by fixed step, or auto with fallback",
    )
    args = ap.parse_args()

    params = detect_inventory_layout(
        args.image,
        ore_point_mode=args.ore_point_mode,
        storage_row_mode=args.storage_row_mode,
    )
    layout = save_layout_json(params, args.out_json, base_resolution=(args.base_w, args.base_h))
    if args.out_ini:
        save_layout_ini(layout, args.out_ini)

    if args.out_preview:
        render_preview(args.image, params, args.out_preview)

    print_summary(params, layout, args.out_json, args.out_preview or None, args.out_ini or None)


if __name__ == "__main__":
    main()


# ============================================================
# Colab snippets (copy/paste as needed)
# ============================================================

# --- (A) Detect + save JSON ---
# image_path = "Clipboard Image (4 March 2026).jpg"
# params = detect_inventory_layout(image_path)
# layout = save_layout_json(params, "layout.json", base_resolution=(1920,1080))
# print(layout["ore"]["slots_count"], layout["ore"]["slot_fallback"])

# --- (B) Create preview overlay ---
# render_preview(image_path, params, "layout_preview.png")

# --- (C) If you want matplotlib visualization in Colab ---
# import matplotlib.pyplot as plt
# img = cv2.imread("layout_preview.png")
# img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
# plt.figure(figsize=(12,7))
# plt.imshow(img)
# plt.axis("off")
