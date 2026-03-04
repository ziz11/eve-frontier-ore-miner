# Config Reference

Full list of config keys used by `LoadConfig()` in `miner.ahk`.

## Notes
- Source of truth: `miner.ahk` (`LoadConfig()` and `ApplyLayoutOverrides()`).
- `ore_transfer_mode` is currently hardcoded to `slots` in code.
- Backward compatibility alias exists for typo key: `[general] dynamic_lock_ena1`.
- Telegram values are loaded from `secrets.ini` first, then fallback to `[telegram]` in `config.ini`.

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
- `target_slot_scan_step_px`
- `target_slot_dedupe_radius_px`
- `target_slot_max_candidates`
- `dynamic_target_slot_scan_enabled`
- `target_slot_probe_radius_px`
- `target_slot_y_search_radius_px`
- `target_slot_y_search_step_px`
- `target_slot_x_jitter_px`
- `target_slot_active_probe_radius_px`
- `target_slot_click_offset_y`
- `ore_drag_offset_y`
- `target_slot_exists_offset_y`
- `target_slot_exists_probe_radius_px`
- `debug_click_marker_ms`
- `ship_reanchor_mode`
- `drag_duration_ms`
- `drag_steps`

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
- `unload_allow_slot_fallback`
- `ore_scan_interval_ms`
- `ore_scan_no_text_limit`
- `ore_transfer_max_per_scan`
- `min_active_lasers_required`
- `laser_probe_radius_px`
- `laser_after_target_select_delay_ms`
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
- `ore_text_color`
- `ore_text_variation`
- `ore_cluster_enabled`
- `ore_cluster_len_px`
- `ore_cluster_min_hits`
- `ore_cluster_threshold`
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
- `target_slots`
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

### [lists]
- `layout_storage_rows`
- `layout_ore_slots`
- `layout_ore_slot_fallback`
