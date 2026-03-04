# Config Reference

Full list of config keys used by `LoadConfig()` in `miner.ahk`.

## Notes
- Source of truth: `miner.ahk` (`LoadConfig()` and `ApplyLayoutOverrides()`).
- Ore transfer path is slots-only (`TryTransferOreBySlots()`).
- Backward compatibility alias exists for typo key: `[general] dynamic_lock_ena1`.
- Telegram values are loaded from `secrets.ini` first, then fallback to `[telegram]` in `config.ini`.
- Python calibrator covers only inventory layout-related values; target/laser/asteroid points and combat colors remain manual runtime tuning in `config.ini`.

## Manual Coordinate Contract (No Python Calibrator)
- Set `[layout] layout_enabled=0`.
- You must manually define:
  - `[points] ship_row_x`
  - `[points] ship_row_y`
  - `[points] portable_row_x`
  - `[points] portable_row_y`
  - `[lists] ore_slots`
  - `[lists] laser_check_points`
  - `[lists] active_laser_slots`
  - `[lists] target_slots`
  - `[lists] asteroid_points`
- Format:
  - single point values in `[points]` are integers.
  - list point values in `[lists]` use `x,y|x,y|x,y` (newline-separated `x,y` is also accepted).
  - laser slot list uses `1|2|3` (integer indices).
- Example:
```ini
[layout]
layout_enabled=0

[points]
ship_row_x=244
ship_row_y=540
portable_row_x=244
portable_row_y=586

[lists]
ore_slots=374,556|449,556|524,556
laser_check_points=710,980|758,980|806,980
active_laser_slots=1|2|3
target_slots=1575,185|1675,185|1775,185
asteroid_points=670,430|760,400|880,340
```

## [general]
- `eve_window_title`
- `main_loop_ms`
- `ui_delay_ms`
- `debug_enabled`
- `debug_loop_every_ms`
- `target_slot_order`
- `dynamic_lock_enabled`
- `dynamic_lock_ena1` (legacy alias)
- `asteroid_scan_step_px`
- `asteroid_dedupe_radius_px`
- `asteroid_max_candidates`
- `target_slot_y_search_radius_px`
- `target_slot_y_search_step_px`
- `target_slot_x_jitter_px`
- `target_slot_min_spacing_px`
- `target_slot_active_probe_radius_px`
- `target_slot_click_offset_y`
- `target_slot_exists_offset_y`
- `target_slot_exists_probe_radius_px`
- Deprecated for direct-click target slots: `target_slot_y_search_radius_px`, `target_slot_y_search_step_px`, `target_slot_x_jitter_px`, `target_slot_click_offset_y`, `target_slot_exists_offset_y`, `target_slot_exists_probe_radius_px`.
- `debug_click_marker_ms`
- `inventory_focus_click_enabled`
  - when enabled, `FocusInventoryWindow()` clicks `ship_row_x/ship_row_y` first, then falls back to `inventory_window_x/y` only if ship row point is unavailable.
  - ore transfer also forces a ship-inventory focus click before each drag cycle.
- `drag_duration_ms`
- `drag_steps`
- `drag_hover_before_pick_ms`
- `drag_hold_before_move_ms`
- `drag_hold_after_move_ms`

## [layout]
- `layout_enabled`
- `layout_ini_path`
- `storage_row_index`
- `ore_slot_indices`

## [timers]
- `heartbeat_ms`
- `lock_timeout_ms`
- `lock_retry_pause_ms`
- `laser_retry_delay_ms`
- `laser_allow_partial`
- `laser_partial_retry_delay_ms`
- `laser_fail_deadline_ms`
- `unload_interval_ms`
- `unload_interval_min_ms`
- `unload_interval_max_ms`
- `unload_after_target_select_delay_ms`
- `unload_block_during_laser`
- `unload_busy_retry_ms`
- `ore_scan_interval_ms`
  - effective minimum in runtime is 15000 ms (faster values are clamped).
- `ore_scan_no_text_limit`
- `ore_transfer_max_per_scan`
- `min_active_lasers_required`
- `laser_probe_radius_px`
- `laser_after_target_select_delay_ms`
- `laser_first_hover_before_click_delay_ms`
- `laser_first_click_after_target_select_delay_ms`
- `laser_after_activate_grace_ms`
- `laser_slot_attempts`
- `laser_slot_retry_delay_ms`
- `laser_activate_confirm_ms`
- `laser_activate_poll_ms`
- `laser_active_confirm_hits`
- `laser_recovery_unload_attempts`
- `laser_recovery_unload_delay_ms`
- `emergency_lock_timeout_ms`
- `target_select_settle_ms`
- `target_select_slot_attempts`
- `target_select_retry_delay_ms`
- `target_select_confirm_ms`
- `target_select_poll_ms`
- `target_active_confirm_hits`
- `target_require_state_transition`
- `target_active_preselected_extra_hits`

## [regions]
- `target_region_x1`
- `target_region_y1`
- `target_region_x2`
- `target_region_y2`
- `too_far_region_x1`
- `too_far_region_y1`
- `too_far_region_x2`
- `too_far_region_y2`
- `asteroid_scan_x1`
- `asteroid_scan_y1`
- `asteroid_scan_x2`
- `asteroid_scan_y2`
- `ore_scan_x1`
- `ore_scan_y1`
- `ore_scan_x2`
- `ore_scan_y2`

## [colors]
- `target_present_color`
- `target_active_orange_color`
- `target_active_color_variation`
- `target_active_min_hits`
- `target_active_debug_log`
- `target_slot_exists_white_color`
- `target_slot_exists_white_variation`
- `laser_active_orange_color`
- `laser_active_min_hits`
- `laser_debug_log`
- `asteroid_marker_color`
- `color_variation`
- `laser_color_variation`
- `asteroid_marker_variation`
- `image_variation`

## [points]
- `lock_target_menu_x`
- `lock_target_menu_y`
- `ship_row_x`
- `ship_row_y`
- `portable_row_x`
- `portable_row_y`
- `inventory_window_x`
- `inventory_window_y`

## [lists]
- `asteroid_points`
- `target_slots` (direct-click points for SELECT; same semantics as `layout_target_slots`)
- `laser_check_points`
- `active_laser_slots`
- `ore_slots`

## [images]
- `too_far_image`

## [telegram]
- `bot_token`
- `chat_id`

## Layout Override File Keys

When `[layout] layout_enabled=1`, extra keys are read from `layout_ini_path`:

### [points]
- `ship_row_x`
- `ship_row_y`

### [regions]
- `ore_scan_x1`
- `ore_scan_y1`
- `ore_scan_x2`
- `ore_scan_y2`
- `target_region_x1`
- `target_region_y1`
- `target_region_x2`
- `target_region_y2`

### [lists]
- `layout_storage_rows`
- `layout_ore_slots`
- `layout_ore_slot_fallback`
- `layout_target_slots` (direct-click points for SELECT; same semantics as manual `target_slots`)
