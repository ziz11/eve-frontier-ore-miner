# EVE Frontier Ore Miner - Module Documentation

This document describes the current `miner.ahk` implementation by modules: logic, entry points, function calls, and cross-module interactions.

## 1) Core / Orchestration

### Purpose
- Runtime initialization, bot start/stop, main loop, and state routing.

### Key Functions
- `LoadConfig()` - loads runtime settings into `cfg`.
- `ToggleBot(mode)` - starts/stops `ASSIST` (`F7`) and `AUTO` (`F8`), resets runtime counters.
- `MainLoop()` - central loop:
  - heartbeat/debug;
  - unload scheduler;
  - state transitions `LOCK -> SELECT -> LASER`.
- `SetState(nextState, reason)` - safe state change with logging.
- `StopWithError(msg)` / `Fail(msg)` - stop with error and notifications.

### Calls To
- `UNLOAD`: `DoUnload()`, `ScheduleNextUnload()`.
- `LOCK`: `DoLockStage()`.
- `SELECT`: `SelectTopRightTarget()`.
- `LASER`: `DoLaserStage()`.
- Service functions: `IsEveActive()`, `HasAnyTopRightTarget()`, `HasActiveTargetOrange()`, `CountActiveLasers()`, `SendTelegram()`, `Debug()`.

---

## 2) LOCK (target lock acquisition)

### Purpose
- Used in `AUTO` mode for initial target lock acquisition.
- Not used in `ASSIST` mode (it starts from `SELECT`).

### Entry Point
- `DoLockStage()` from `MainLoop()` when `state = LOCK`.

### Logic
1. Checks whether a target already exists in the top-right target list (`HasAnyTopRightTarget()`).
2. Gets candidates from `GetLockCandidates()`:
   - dynamic: `FindDynamicAsteroidPoints()`;
   - fallback: static `cfg["asteroid_points"]`.
3. For each candidate: `RightClick` asteroid -> `LeftClick` lock menu point.
4. Retries until `lock_timeout_ms`.

### Internal Call Path
- `GetLockCandidates()` -> `FindDynamicAsteroidPoints()` -> `PixelNearColor()`, `HasNearbyPoint()`.
- Helpers: `SortPointsLeftToRight()`, `ColorNear()`, `HasAnyTopRightTarget()`.

### Output
- `true`: lock acquired, `MainLoop` moves to `SELECT`.
- `false`: timeout, `Fail("LOCK timeout")`.

---

## 3) SELECT (active target selection)

### Purpose
- Select a target slot and confirm active orange state.

### Entry Point
- `SelectTopRightTarget()` from `MainLoop()` when `state = SELECT`.

### Logic
1. Gets candidates from `GetTargetCandidates()`:
   - uses `cfg["target_slots"]` (preferably from `layout_target_slots` via layout override).
   - each point is a final direct-click coordinate.
2. Sorts candidates via `SortTargetPoints()` according to `target_slot_order` (`rtl/ltr`).
3. For each candidate:
   - clicks the point directly;
   - waits for confirmation: `WaitForActiveTarget(...)`.
4. On success stores `lastSelectedSlotX/Y`, `lastTargetSelectedTick`.
5. If slots were tried but none activated -> `StopWithError("TARGET LOCK failed...")`.

### Internal Call Path
- `GetTargetCandidates()` -> `SortTargetPoints()`.
- `WaitForActiveTarget()` -> `SlotHasActiveTarget()` / `HasActiveTargetOrange()`.
- `SlotHasActiveTarget()` -> `CountColorMatchesInRect()` around the same direct-click point.

### Output
- `true`: `MainLoop` moves to `LASER`.
- `false`: stays in `SELECT`, or moves to `LOCK` (`AUTO` + no targets).

---

## 4) LASER (laser keepalive and recovery)

### Purpose
- Validate target/laser activity.
- Reactivate lasers when needed.
- Run ore transfer checks in parallel through `UNLOAD` functions.

### Entry Point
- `DoLaserStage()` from `MainLoop()` when `state = LASER`.

### Logic
1. State guards:
   - no targets -> `SELECT` (or `LOCK` in `AUTO`);
   - selected target inactive -> `SELECT`;
   - "too far" banner -> `SELECT`.
2. Reads active lasers via `CountActiveLasers()`.
3. If active lasers are sufficient:
   - periodic ore transfer tick (`ore_scan_interval_ms`) via `TryTransferOre()`;
   - updates `oreNoTextStreak` as a generic "nothing moved" streak counter.
4. If partial mode is allowed (`laser_allow_partial`) and at least one laser is active:
   - continues ore flow;
   - retries dead slots less aggressively.
5. If lasers are fully lost:
   - retries `TryActivateLasersBySlots()` on timer;
   - at `laser_fail_deadline_ms`, runs `AttemptLaserFailureRecovery()` and stops with error.

### Internal Call Path
- `TryActivateLasersBySlots()` -> `GetConfiguredLaserSlots()`, `IsLaserSlotActive()`, `WaitForLaserSlotActive()`.
- `AttemptLaserFailureRecovery()` -> `DoUnload()` (`UNLOAD`) + `TryEmergencyLock()` (`LOCK` helpers).
- `TryTransferOre()` (`UNLOAD`) for ore-flow support during LASER stage.

---

## 5) UNLOAD (ore transfer)

### Purpose
- Move ore from ship inventory into destination storage (`portable_row`).
- Can be called by timer (`MainLoop`), by `LASER`, manually (`F6`), and in recovery.

### Entry Points
- `DoUnload()` - primary entry.
- `ManualOreTransferTest()` (`F6`) -> `TryTransferOre()`.
- Calls from `DoLaserStage()` and `AttemptLaserFailureRecovery()`.

### Transfer Modes
- `TryTransferOre()` uses slots-only path: `TryTransferOreBySlots()`.

### Slots Mode Logic
- `TryTransferOreBySlots()`:
  - validates destination (`portable_row`) once;
  - `FocusInventoryWindow()`;
  - iterates `cfg["ore_slots"]`;
  - `DragMouse(slot -> portable_row)` up to `ore_transfer_max_per_scan`.

### Scheduling
- `ScheduleNextUnload()` picks next unload tick in range `unload_interval_min_ms..unload_interval_max_ms`.
- In `MainLoop`, unload can be postponed:
  - if `state = LASER` and `unload_block_during_laser=1`;
  - right after target select (`unload_after_target_select_delay_ms`).

---

## 6) Config + Layout Overrides

### Purpose
- Load full runtime config from `config.ini` / `secrets.ini`.
- Apply inventory calibration overrides from `eve_inventory_calibrate/config.layout.ini`.

### Key Functions
- `LoadConfig()` - reads `general/layout/timers/regions/colors/points/lists/images/telegram`.
- `ApplyLayoutOverrides(path)`:
  - overrides `ship_row`, `portable_row`, `ore_scan_region`, `ore_slots`;
  - selects `portable_row` by `storage_row_index`;
  - selects `ore_slots` by `ore_slot_indices`.
- Parsers: `ParsePoints()`, `ParseIntList()`.

### Impact
- All runtime modules (`LOCK/SELECT/LASER/UNLOAD`) read settings only from `cfg`.

---

## 7) Service / Infra Utilities

### Pixel/Color
- `PixelInRect()`, `PixelNearColor()`, `ColorNear()`, `CountColorMatchesInRect()`.

### Mouse/Input
- `LeftClick()`, `RightClick()`, `DragMouse()`, `ShowClickMarker()`.

### Runtime checks
- `IsEveActive()`, `DetectTooFarBanner()`, `IsNumericCoord()`.

### Logging/alerts
- `Debug()`, `LogEvent()`, `SendTelegram()`.

---

## 8) State Transition Map

- `AUTO` start: `LOCK`.
- `ASSIST` start: `SELECT`.
- `LOCK -> SELECT`: `DoLockStage() = true`.
- `SELECT -> LASER`: `SelectTopRightTarget() = true`.
- `SELECT -> LOCK`: no targets in `AUTO`.
- `LASER -> SELECT`: target lost / too far / no targets in `ASSIST`.
- `LASER -> LOCK`: no targets in `AUTO`.
- `ANY -> STOP`: `StopWithError(...)` (critical error).
