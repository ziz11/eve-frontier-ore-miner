# Config Reference

`miner.ahk` now supports a categorized config model with backward-compatible fallback to old keys.

## Category layout
- **Main**: `[main]`
- **Module-specific**: `[module_lock]`, `[module_select]`, `[module_laser]`, `[module_unload]`, `[module_recovery]`
- **Shared/system**: `[layout]`, `[timers]`, `[regions]`, `[colors]`, `[points]`, `[lists]`, `[images]`, `[telegram]`
- **Deprecated compatibility**: `[deprecated]`

## [main]
- `eve_window_title`
- `main_loop_ms`
- `ui_delay_ms`
- `debug_enabled`
- `debug_loop_every_ms`
- `state_start_delay_ms`
- `click_hover_before_click_ms`
- `major_action_prep_delay_ms`
- `dynamic_lock_enabled`

## [module_lock]
- `lock_timeout_ms`
- `lock_retry_delay_ms`
- `asteroid_probe_step_px`
- `asteroid_dedupe_radius_px`
- `asteroid_max_candidates`

## [module_select]
- `target_slot_order` (`rtl`/`ltr`)
- `target_slot_min_spacing_px`
- `target_slot_active_probe_radius_px`
- `target_select_slot_attempts`
- `target_retry_delay_ms`
- `target_settle_delay_ms`
- `target_confirm_timeout_ms`
- `target_active_confirm_hits`
- `target_require_state_transition`
- `target_active_preselected_extra_hits`
- `post_transfer_refocus_attempts`
- `post_transfer_refocus_delay_ms`

## [module_laser]
- `laser_allow_partial`
- `laser_retry_delay_ms`
- `laser_partial_retry_delay_ms`
- `laser_fail_deadline_ms`
- `laser_guard_delay_ms`
- `laser_slot_attempts`
- `laser_slot_retry_delay_ms`
- `laser_activate_confirm_ms`
- `laser_active_confirm_hits`
- `laser_first_hover_before_click_delay_ms`
- `laser_first_click_after_target_select_delay_ms`
- `min_active_lasers_required`
- `laser_probe_radius_px`
- `laser_recovery_unload_attempts`
- `laser_recovery_unload_delay_ms`

## [module_unload]
- `unload_interval_ms` (optional, base for min/max)
- `unload_interval_min_ms`
- `unload_interval_max_ms`
- `unload_after_target_select_delay_ms`
- `unload_block_during_laser`
- `unload_retry_delay_ms`
- `ore_transfer_interval_ms`
- `ore_transfer_no_move_limit`
- `ore_transfer_max_per_cycle`
- `ore_transfer_post_delay_ms`

## [module_recovery]
- `emergency_lock_timeout_ms`

## [timers] (shared)
- `heartbeat_ms`
- `action_poll_interval_ms`
- `action_retry_delay_ms` (optional shared fallback for retry delays in SELECT/LASER)

## [regions], [colors], [points], [lists], [images], [telegram]
These remain unchanged and are consumed as runtime primitives.

## [deprecated]
Use this section only to keep legacy keys while migrating old `config.ini` files. These values are read for compatibility, but are not part of the preferred model.

Common legacy examples:
- `target_slot_y_search_radius_px`, `target_slot_y_search_step_px`, `target_slot_x_jitter_px`
- `target_slot_click_offset_y`, `target_slot_exists_offset_y`, `target_slot_exists_probe_radius_px`
- `lock_retry_pause_ms`, `unload_busy_retry_ms`
- `target_select_*` aliases
- `post_unload_refocus_*` aliases
- `dynamic_lock_ena1`
