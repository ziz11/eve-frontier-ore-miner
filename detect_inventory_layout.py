# python detect_inventory_layout.py screenshot.png

import cv2
import numpy as np
import sys

if len(sys.argv) < 2:
    print("Usage: python detect_inventory_layout.py screenshot.png")
    sys.exit(1)

img = cv2.imread(sys.argv[1])
h, w, _ = img.shape

print(f"Image size: {w}x{h}")

# ------------------------------------------------
# 1. Find Ship green indicator
# ------------------------------------------------

hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

lower_green = np.array([40, 80, 80])
upper_green = np.array([90, 255, 255])

mask = cv2.inRange(hsv, lower_green, upper_green)

cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

ship_center = None
best_area = 0

for c in cnts:
    area = cv2.contourArea(c)
    if 20 < area < 500:
        x, y, cw, ch = cv2.boundingRect(c)
        cx = x + cw // 2
        cy = y + ch // 2

        if area > best_area:
            best_area = area
            ship_center = (cx, cy)

if ship_center is None:
    print("ERROR: Ship indicator not found")
    sys.exit(1)

ship_x, ship_y = ship_center

print("\nDetected Ship marker:")
print(f"ship_marker = ({ship_x}, {ship_y})")

# ------------------------------------------------
# 2. Infer inventory anchor
# ------------------------------------------------

inv_x = ship_x - 32
inv_y = ship_y - 65

print("\nEstimated inventory anchor:")
print(f"inv_x = {inv_x}")
print(f"inv_y = {inv_y}")

# ------------------------------------------------
# 3. Storage rows
# ------------------------------------------------

row_height = 30

storage_rows = []

for i in range(5):
    y = ship_y + 60 + row_height * i
    storage_rows.append((ship_x, y))

print("\nStorage rows (center points):")

for i, (x, y) in enumerate(storage_rows):
    print(f"storage_row{i+1} = ({x}, {y})")

# ------------------------------------------------
# 4. Ore grid detection
# ------------------------------------------------

# search right half of inventory
x1 = inv_x + 160
x2 = inv_x + 470

y1 = inv_y + 20
y2 = inv_y + 200

ore_roi = img[y1:y2, x1:x2]

gray = cv2.cvtColor(ore_roi, cv2.COLOR_BGR2GRAY)

_, thresh = cv2.threshold(gray, 220, 255, cv2.THRESH_BINARY)

cnts, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

digits = []

for c in cnts:
    x, y, cw, ch = cv2.boundingRect(c)

    if 5 < cw < 40 and 10 < ch < 40:
        digits.append((x, y, cw, ch))

digits.sort(key=lambda d: d[1])

if len(digits) == 0:
    print("\nNo ore digits detected")
else:

    ys = [d[1] for d in digits]

    row1 = min(ys)
    row2 = max(ys)

    print("\nOre rows detected:")

    print(f"ore_row1_roi = ({x1}, {y1+row1-20}) -> ({x2}, {y1+row1+60})")
    print(f"ore_row2_roi = ({x1}, {y1+row2-20}) -> ({x2}, {y1+row2+60})")

# ------------------------------------------------
# 5. Offsets (recommended for config)
# ------------------------------------------------

print("\nOffsets relative to inventory anchor:")

print(f"ship_dx = {ship_x - inv_x}")
print(f"ship_dy = {ship_y - inv_y}")

for i,(x,y) in enumerate(storage_rows):
    print(f"storage{i+1}_dx = {x - inv_x}")
    print(f"storage{i+1}_dy = {y - inv_y}")