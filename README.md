# EVE Frontier Ore Miner (AutoHotkey)

## Files
- `script.ahk` - entrypoint (includes `miner.ahk`)
- `miner.ahk` - bot logic and state machine
- `config.ini` - local coordinates/timers/colors (ignored by git)
- `config.ini.example` - tracked template for config
- `secrets.ini` - Telegram secrets (local only, ignored by git)
- `secrets.ini.example` - template for secrets
- `.gitignore` - ignores local machine files and secrets

## Quick start
1. Copy `config.ini.example` to `config.ini`, then tune for your screen/UI.
2. Create `secrets.ini` from template:
   - copy `secrets.ini.example` -> `secrets.ini`
   - fill `bot_token` and `chat_id`
3. Run `script.ahk`.
4. Hotkeys:
   - `F8` start/stop
   - `F10` reload script
   - `Esc` exit

## Telegram token/chat_id
Put both in:
- `/Users/nacnac/Documents/ef-map.com/eve-frontier-ore-miner/secrets.ini`

Example:
```ini
[telegram]
bot_token=123456:ABCDEF...
chat_id=123456789
```

How to get `chat_id`:
1. Open Telegram and send any message to your bot.
2. Run:
```bash
curl -sS "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates"
```
3. Find `"chat":{"id":...}` and copy that number into `secrets.ini`.

## How bot works (stages)
1. `LOCK`:
   - right-clicks asteroid points (`lists.asteroid_points`)
   - clicks `Lock Target` menu point (`points.lock_target_menu_x/y`)
   - repeats until target appears in top-right region or timeout (`timers.lock_timeout_ms`)
2. `SELECT`:
   - clicks top-right target slots (`lists.target_slots`) in order
   - expects active orange lock in target region
3. `LASER`:
   - sends keys `1` and `2`
   - checks laser active pixels (`lists.laser_check_points`)
   - if lasers drop: retries every `timers.laser_retry_delay_ms` (default 5s)
   - if no active laser for `timers.laser_fail_deadline_ms` (default 20s): fail event
4. `UNLOAD` (timer-based):
   - clicks ship row (`points.ship_row_x/y`)
   - drags ore slots (`lists.ore_slots`) onto `Portable` row (`points.portable_row_x/y`)

## 1920x1080 note (important)
If you calibrated from other screenshots/devices (for example Mac), coordinates can be wrong on 1920x1080.
This script is pixel/coordinate based, so you must recalibrate on the target PC.

## Calibration checklist (1920x1080)
Do this in full-screen or stable window size with fixed UI scale.

1. Window title check
- `general.eve_window_title` should match your game window title (default `EVE Frontier`).

2. Top-right target area
- Set `regions.target_region_x1/y1/x2/y2` to cover locked targets panel in top-right.
- Set `lists.target_slots` to clickable centers of target icons (left->right or nearest-first order you prefer).

3. Active lock color
- With a selected orange target, tune:
  - `colors.target_active_orange_color`
  - `colors.color_variation`
- If false negatives happen, increase variation slightly (for example +5).

4. Laser active detection
- Turn lasers on, set `lists.laser_check_points` to pixels on each module's orange circular refresh indicator.
- Tune `colors.laser_active_orange_color` and `colors.color_variation`.

5. Lock menu point
- Right-click asteroid and set `points.lock_target_menu_x/y` to the `Lock Target` menu item center.

6. Inventory/Portable points
- Set `points.ship_row_x/y` to your ship row in inventory tree.
- Set `points.portable_row_x/y` to `Portable` row in inventory tree.
- Set `lists.ore_slots` to centers of ore icons in the item grid (add several slots you use often).

7. Optional "too far away" banner detection
- Crop and save banner template image locally.
- Set `images.too_far_image` to absolute path.
- Set `regions.too_far_region_*` to top-center banner search area.
- Tune `colors.image_variation` if needed.

8. Timers
- `timers.laser_retry_delay_ms=5000`
- `timers.laser_fail_deadline_ms=20000`
- `timers.unload_interval_ms=60000..120000` based on cargo flow.

## 10-minute practical calibration flow
1. Start game in final 1920x1080 layout.
2. Calibrate target region + target slots.
3. Calibrate laser points/colors while lasers are active.
4. Calibrate lock menu click point.
5. Calibrate ship row / portable row / ore slots.
6. Fill `secrets.ini`.
7. Start script (`F8`) and run a short 2-3 minute test.
8. Adjust only one group at a time (targets, lasers, inventory), then retest.

## Safety
- Rotate old bot token if it was shared.
- Never commit `secrets.ini`.
- Test on short sessions after every coordinate change.
