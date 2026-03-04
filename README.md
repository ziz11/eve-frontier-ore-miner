# EVE Frontier Ore Miner (AutoHotkey)

## Files
- `script.ahk` - entrypoint (includes `miner.ahk`)
- `miner.ahk` - bot logic and state machine
- `config.ini` - local coordinates/timers/colors (ignored by git)
- `config.ini.example` - tracked template for config
- `secrets.ini` - Telegram secrets (local only, ignored by git)
- `secrets.ini.example` - template for secrets
- `.gitignore` - ignores local machine files and secrets

## Quick Start (short)
1. Install AutoHotkey v2.
2. Create local files:
   - `config.ini` from `config.ini.example`
   - `secrets.ini` from `secrets.ini.example` (optional)
3. Calibrate coordinates/colors in `config.ini` for your 1920x1080 layout.
4. Run `script.ahk`.
5. Use hotkeys:
   - `F6` run one-shot ore transfer test only (no target/laser logic)
   - `F8` start/stop `AUTO` mode (dynamic lock scan + select + lasers + unload)
   - `F7` start/stop `ASSIST` mode (only already locked targets + lasers + unload)
   - `F10` reload script
   - `Esc` exit

## Telegram token/chat_id
Put both in local `secrets.ini` in this project folder.

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

If `bot_token` or `chat_id` is empty, script still works and writes local logs only.

## How bot works (stages)
1. `LOCK`:
   - scans `regions.asteroid_scan_*` for bright asteroid markers when `general.dynamic_lock_enabled=1`
   - de-duplicates nearby hits and uses up to `general.asteroid_max_candidates`
   - if dynamic scan finds nothing, falls back to static `lists.asteroid_points`
   - clicks `Lock Target` menu point (`points.lock_target_menu_x/y`)
   - repeats until target appears in top-right region or timeout (`timers.lock_timeout_ms`)
2. `SELECT`:
   - uses `lists.target_slots` (left->right) as primary target-slot centers
   - skips empty slots by probing around each slot center
   - optional dynamic slot scan can be enabled via `general.dynamic_target_slot_scan_enabled=1`
   - clicks each slot up to `timers.target_select_slot_attempts` times with retry delay
   - waits up to `timers.target_select_confirm_ms` for active orange lock
   - if none of occupied slots can be activated: hard stop with error
3. `LASER`:
   - clicks laser module points from `lists.laser_check_points` (selected by `lists.active_laser_slots`)
   - checks active laser slots from `lists.active_laser_slots` using `lists.laser_check_points` with multi-pixel validation (`colors.laser_active_min_hits`)
   - for each inactive slot: retries activation up to `timers.laser_slot_attempts`, then confirms activation via short polling window (`timers.laser_activate_*`)
   - while lasers are active, scans inventory ore-text area and drags detected ore to `Portable`
   - if no working lasers before deadline: runs recovery (unload + re-lock attempt), then hard stop with error
4. `UNLOAD` (timer-based):
   - clicks ship row (`points.ship_row_x/y`)
   - drags ore slots (`lists.ore_slots`) onto `Portable` row (`points.portable_row_x/y`)
   - unload is postponed while in `LASER` when `timers.unload_block_during_laser=1`

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
  - `colors.target_active_color_variation`
- If false positives happen, increase `colors.target_active_min_hits` (for example `3 -> 4`).
- If false negatives happen, increase variation slightly (for example +5).

4. Laser active detection
- Turn lasers on, set `lists.laser_check_points` to pixels on each module's orange circular refresh indicator.
- Tune `colors.laser_active_orange_color` and `colors.laser_color_variation`.
- If activation is flaky, tune:
  - `colors.laser_active_min_hits`
  - `timers.laser_activate_confirm_ms`
  - `timers.laser_activate_poll_ms`
  - `timers.laser_active_confirm_hits`

5. Lock menu point
- Right-click asteroid and set `points.lock_target_menu_x/y` to the `Lock Target` menu item center.

6. Dynamic asteroid scan (AUTO mode)
- Set `regions.asteroid_scan_x1/y1/x2/y2` to the space area where asteroid markers appear.
- Set `colors.asteroid_marker_color` to marker white/gray pixel.
- Tune `colors.asteroid_marker_variation` (start near `35`).
- Tune:
  - `general.asteroid_scan_step_px` (smaller = more accurate, slower)
  - `general.asteroid_dedupe_radius_px`
  - `general.asteroid_max_candidates`

7. Inventory/Portable points
- Optional: set `points.inventory_window_x/y` to any safe click point inside Inventory window (for focus).
- Set `points.ship_row_x/y` to your ship row in inventory tree.
- Set `points.portable_row_x/y` to `Portable` row in inventory tree.
- Set `lists.ore_slots` to centers of ore icons in the item grid (add several slots you use often).
- Set `regions.ore_scan_x1/y1/x2/y2` to where ore item text appears in inventory list.
- Set `colors.ore_text_color`/`colors.ore_text_variation` for ore text detection.

8. Optional "too far away" banner detection
- Crop and save banner template image locally.
- Set `images.too_far_image` to absolute path.
- Set `regions.too_far_region_*` to top-center banner search area.
- Tune `colors.image_variation` if needed.

9. Timers
- `timers.laser_retry_delay_ms=5000`
- `timers.laser_allow_partial=1`
- `timers.laser_partial_retry_delay_ms=20000`
- `timers.laser_fail_deadline_ms=20000`
- `timers.unload_interval_min_ms` / `timers.unload_interval_max_ms` define unload cadence.
- `timers.unload_interval_min_ms=10000`
- `timers.unload_interval_max_ms=10000`
- `timers.unload_after_target_select_delay_ms=15000`
- `timers.unload_block_during_laser=1`
- `timers.unload_busy_retry_ms=1500`
- `timers.unload_allow_slot_fallback=0`
- `timers.ore_scan_interval_ms=10000`
- `timers.ore_scan_no_text_limit=2`
- `timers.ore_transfer_max_per_scan=3`
- `timers.laser_after_target_select_delay_ms=1000`
- `timers.laser_first_click_after_target_select_delay_ms=150`
- `timers.laser_after_activate_grace_ms=1000`
- `timers.laser_slot_attempts=5`
- `timers.laser_slot_retry_delay_ms=1000`
- `timers.laser_activate_confirm_ms=2200`
- `timers.laser_activate_poll_ms=120`
- `timers.laser_active_confirm_hits=2`
- `timers.laser_recovery_unload_attempts=3`
- `timers.laser_recovery_unload_delay_ms=2000`
- `timers.emergency_lock_timeout_ms=12000`
- `timers.target_select_settle_ms=120`
- `timers.target_select_slot_attempts=3`
- `timers.target_select_retry_delay_ms=1200`
- `timers.target_select_confirm_ms=3000`
- `timers.target_active_confirm_hits=2`
- `timers.target_require_state_transition=1`

## 10-minute practical calibration flow
1. Start game in final 1920x1080 layout.
2. Calibrate target region + target slots.
3. Calibrate laser points/colors while lasers are active.
4. Calibrate lock menu click point.
5. Calibrate ship row / portable row / ore slots.
6. Fill `secrets.ini`.
7. Start script (`F8`) and run a short 2-3 minute test.
8. Adjust only one group at a time (targets, lasers, inventory), then retest.

## Debug logging
- Local log file: `logs/miner.log`
- Enable detailed debug:
  - `general.debug_enabled=1`
  - `general.debug_loop_every_ms=5000` (or lower for more frequent snapshots)
- Disable detailed debug after calibration (`debug_enabled=0`) to reduce log noise.

## Troubleshooting (Known Pitfalls)
- Config changes not applied:
  - If logs still show old thresholds (example: `hits=0/2` after you set `laser_active_min_hits=1`), reload script with `F10` or restart `script.ahk`.
- Laser keeps clicking while already active:
  - Usually `lists.laser_check_points` is not on the bright active ring segment.
  - In logs, this looks like `sample=0x000000 at=0,0` and repeated `laser activate slot#...`.
  - Move each laser check point onto a stable bright pixel of the active indicator.
- Laser detected only sometimes (`hits=1/2` pattern):
  - Lower `colors.laser_active_min_hits` (e.g. `2 -> 1`) or increase `timers.laser_probe_radius_px` (e.g. `3 -> 4`).
  - Optionally increase `colors.laser_color_variation` a little (e.g. `12 -> 14`).
- Second laser slot unstable:
  - Temporarily set `lists.active_laser_slots=1` until slot #2 point is recalibrated.
- Unload interrupts mining flow:
  - Keep `timers.unload_block_during_laser=1`.
  - Use a non-zero `timers.unload_after_target_select_delay_ms` so `SELECT -> LASER` can settle.

## Config Variables
All values are read from local `config.ini`.

### `[general]`
- `eve_window_title` - window title required for bot actions (`WinActive` check).
- `main_loop_ms` - main loop period in ms.
- `ui_delay_ms` - delay between UI actions in ms.
- `debug_enabled` - `1` to enable detailed debug log, `0` to disable.
- `debug_loop_every_ms` - debug snapshot interval in ms.
- `dynamic_lock_enabled` - `1` uses dynamic asteroid marker scan in `AUTO`, `0` uses only static points.
  - compatibility alias: `dynamic_lock_ena1` is also accepted (legacy typo).
- `asteroid_scan_step_px` - dynamic scan grid step in pixels.
- `asteroid_dedupe_radius_px` - minimum distance between two found candidates.
- `asteroid_max_candidates` - max dynamic lock candidates per scan cycle.
- `target_slot_scan_step_px` - scan grid step for dynamic target-slot detection in top-right panel.
- `target_slot_dedupe_radius_px` - dedupe radius for dynamic target-slot candidates.
- `target_slot_max_candidates` - max dynamic target-slot candidates per select cycle.
- `dynamic_target_slot_scan_enabled` - `1` enables dynamic target-slot scan in `SELECT`, `0` uses only `lists.target_slots`.
- `target_slot_y_search_radius_px` - vertical range for per-slot Y auto-correction around configured `target_slots`.
- `target_slot_y_search_step_px` - step (px) used while scanning up/down for slot Y correction.
- `target_slot_x_jitter_px` - small horizontal jitter used during slot Y correction.
- `target_slot_active_probe_radius_px` - local radius for validating active orange state near the clicked slot.
- `target_slot_click_offset_y` - click offset upward from slot anchor (bottom marker) to hit the asteroid body.
- `ore_drag_offset_y` - Y-offset applied to detected ore-text pixel before drag starts.
- `target_slot_exists_offset_y` - offset downward from slot anchor for white-slot-exists probe.
- `target_slot_exists_probe_radius_px` - probe radius for white-slot-exists check.
- `debug_click_marker_ms` - when `>0`, shows short tooltip marker on every click for visual calibration.

### `[timers]`
- `heartbeat_ms` - periodic status message interval.
- `lock_timeout_ms` - max time for lock stage before fail.
- `lock_retry_pause_ms` - pause between lock attempts.
- `laser_retry_delay_ms` - delay between laser retry cycles.
- `laser_allow_partial` - if `1`, bot can continue mining with partially active lasers and keep retrying dead slots in background.
- `laser_partial_retry_delay_ms` - retry interval for dead slots while partial mode is active.
- `laser_fail_deadline_ms` - max no-laser-active duration before hard error stop (after recovery attempts).
- `unload_interval_min_ms` - minimum randomized unload interval (ms).
- `unload_interval_max_ms` - maximum randomized unload interval (ms).
- `unload_after_target_select_delay_ms` - minimum delay before unload after a successful target select.
- `unload_block_during_laser` - if `1`, unload is postponed while bot is in `LASER`.
- `unload_busy_retry_ms` - delay before next unload check after postpone.
- `unload_allow_slot_fallback` - if `0`, static `ore_slots` dragging is disabled when text-based ore transfer fails.
- `ore_scan_interval_ms` - interval between ore-text scans while lasers are active.
- `ore_scan_no_text_limit` - number of consecutive no-ore scans before fallback checks.
- `ore_transfer_max_per_scan` - max drag operations per ore scan cycle.
- `min_active_lasers_required` - minimum active laser indicators required to treat LASER stage as healthy.
- `laser_probe_radius_px` - local radius for checking each laser activity pixel (for rotating orange indicator).
- `laser_after_target_select_delay_ms` - minimum delay before first laser activation attempt after target selection.
- `laser_first_click_after_target_select_delay_ms` - extra one-time pause right before the very first laser click after target selection (helps UI settle after cursor move).
- `laser_after_activate_grace_ms` - grace period after laser-click activation before rechecking/failure handling.
- `laser_slot_attempts` - per-laser-slot activation attempts before moving to the next slot.
- `laser_slot_retry_delay_ms` - delay after each per-slot activation press.
- `laser_activate_confirm_ms` - max wait after laser click to confirm activation.
- `laser_activate_poll_ms` - polling interval while waiting for laser activation.
- `laser_active_confirm_hits` - required consecutive active checks to confirm laser activation.
- `laser_recovery_unload_attempts` - unload attempts before final laser failure stop.
- `laser_recovery_unload_delay_ms` - delay between recovery unload attempts.
- `emergency_lock_timeout_ms` - max duration of emergency re-lock attempt during laser-failure recovery.
- `target_select_settle_ms` - short delay after target-slot click before orange confirmation check starts.
- `target_select_slot_attempts` - slot activation attempts before moving to the next target slot.
- `target_select_retry_delay_ms` - delay between repeated attempts on the same target slot.
- `target_select_confirm_ms` - max wait after slot click for orange target confirmation.
- `target_select_poll_ms` - polling interval while waiting for orange confirmation.
- `target_active_confirm_hits` - required consecutive active-lock detections before slot selection is accepted.
- `target_require_state_transition` - requires post-click active-state transition (helps prevent false "already active" detections).

### `[regions]`
- `target_region_x1/y1/x2/y2` - top-right locked-targets scan region.
- `too_far_region_x1/y1/x2/y2` - region where "too far" banner is searched.
- `asteroid_scan_x1/y1/x2/y2` - region for dynamic asteroid marker scan.
- `ore_scan_x1/y1/x2/y2` - inventory region where ore text is searched.

### `[colors]`
- `target_present_color` - any target presence marker color.
- `target_active_orange_color` - active selected target color.
- `target_active_color_variation` - tolerance for active-target orange check near the selected slot.
- `target_active_min_hits` - minimum matching orange pixels required for active target confirmation.
- `target_active_debug_log` - enables active-target sample color/coordinate debug logs.
- `target_slot_exists_white_color` - white color used to confirm that slot exists before click.
- `target_slot_exists_white_variation` - tolerance for white-slot-exists check.
- `laser_active_orange_color` - active laser indicator color.
- `laser_active_min_hits` - minimum matching orange pixels required per laser check.
- `laser_debug_log` - enables laser sample color/coordinate debug logs.
- `laser_color_variation` - tolerance for laser activity color checks (separate from generic `color_variation`).
- `ore_text_color` - inventory ore text color used to detect draggable ore rows.
- `ore_text_variation` - tolerance for ore text detection.
- `ore_cluster_enabled` - if `1`, validates detected ore text pixel by a short bright-pixel cluster.
- `ore_cluster_len_px` - cluster check horizontal length in pixels.
- `ore_cluster_min_hits` - minimum bright pixels required in the cluster line.
- `ore_cluster_threshold` - minimum RGB threshold for cluster bright-pixel check.
- `asteroid_marker_color` - asteroid marker color used in dynamic scan.
- `color_variation` - tolerance for PixelSearch checks.
- `asteroid_marker_variation` - tolerance for dynamic asteroid marker color check.
- `image_variation` - tolerance for ImageSearch checks.

### `[points]`
- `lock_target_menu_x/y` - click point for `Lock Target` menu item.
- `ship_row_x/y` - `Ship (...)` row in inventory tree.
- `portable_row_x/y` - destination container row in inventory tree.
- `inventory_window_x/y` - optional safe click inside inventory window to force focus.

### `[lists]`
- `asteroid_points` - asteroid click points for `AUTO` lock attempts (`x,y|x,y|...`).
- `target_slots` - top-right target slot click points (`x,y|x,y|...`).
- `laser_check_points` - pixels on active laser indicators (`x,y|x,y|...`).
- `active_laser_slots` - enabled virtual laser slots (`1|2|3`) to include in checks and activation.
- `ore_slots` - ore icon grid points to drag during unload (`x,y|x,y|...`).

### `[telegram]`
- `bot_token` - fallback token (normally leave empty and use `secrets.ini`).
- `chat_id` - fallback chat id (normally leave empty and use `secrets.ini`).

### `[images]`
- `too_far_image` - absolute path to template image for "too far" detection (optional).

## Git Ignore (local-only files)
Ignored and safe to keep local:
- `config.ini`
- `secrets.ini`
- `config.local.ini`
- `*.local.ini`
- `*.override.ini`
- `logs/`

## Safety
- Rotate old bot token if it was shared.
- Never commit `secrets.ini`.
- Test on short sessions after every coordinate change.
