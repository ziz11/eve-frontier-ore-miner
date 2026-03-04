# EVE Frontier Ore Miner

This repository contains AutoHotkey automation scripts and local configuration for EVE Frontier ore mining workflows.

## Files

- `script.ahk`: main AutoHotkey entry script.
- `miner.ahk`: core mining logic/state workflow.
- `config.ini`: local runtime configuration.
- `secrets.ini.example`: example structure for secrets file.
- `README.md`: setup, calibration, and safety notes.

## Quick Start (team note)

1. Install AutoHotkey v2.
2. Create local files:
   - `config.ini` from `config.ini.example`
   - `secrets.ini` from `secrets.ini.example` (optional)
3. Run `script.ahk`.
4. Hotkeys:
   - `F8` full `AUTO` mode
   - `F7` `ASSIST` mode for pre-locked targets
   - `F10` reload
   - `Esc` exit
5. In `AUTO`, dynamic asteroid lock scan is enabled by default (`dynamic_lock_enabled=1`).

## Recent Operational Notes

- `SELECT` confirmation now uses stronger active-target validation:
  - `colors.target_active_orange_color`
  - `colors.target_active_color_variation`
  - `colors.target_active_min_hits`
- `LASER` activation now uses confirm polling instead of single instant check:
  - `timers.laser_activate_confirm_ms`
  - `timers.laser_activate_poll_ms`
  - `timers.laser_active_confirm_hits`
  - `colors.laser_active_min_hits`
- While lasers are active, ore transfer is driven by inventory text scan:
  - `regions.ore_scan_x1/y1/x2/y2`
  - `colors.ore_text_color`
  - `colors.ore_text_variation`
  - `timers.ore_scan_interval_ms`
  - `timers.ore_transfer_max_per_scan`
- Unload behavior is controlled to avoid interference with laser stage:
  - `timers.unload_block_during_laser=1`
  - `timers.unload_after_target_select_delay_ms=15000`
  - `timers.unload_interval_min_ms=10000`
  - `timers.unload_interval_max_ms=10000`

## Troubleshooting Cues From Logs

- `hits=0/2` or `sample=0x000000 at=0,0` on laser checks:
  - `laser_check_points` are off-target (wrong pixel) or config not reloaded.
- After config edit, always `F10` reload before interpreting logs.
- If slot #2 remains unstable, run temporarily with `active_laser_slots=1` and recalibrate slot #2 later.

## Local-only files (do not commit)

- `config.ini`
- `secrets.ini`
- `config.local.ini`
- `*.local.ini`
- `*.override.ini`
- `logs/`
