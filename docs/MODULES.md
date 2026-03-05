# EVE Frontier Ore Miner - Module Documentation

## Runtime modules

1. **LOCK**
   - Builds lock candidates (dynamic probe + static fallback).
   - Tries right-click -> lock menu action until target appears or timeout.

2. **SELECT**
   - Uses direct-click target slots from `layout_target_slots` or `[lists] target_slots`.
   - Applies retries and active-target confirmation.

3. **LASER**
   - Activates configured laser slots.
   - Supports partial-laser mode and retry windows.
   - Performs periodic ore transfer while mining continues.

4. **UNLOAD**
   - Drag-transfers ore slots to configured storage row.
   - Triggered by timer, manual hotkey (`F6`), and recovery flows.

5. **RECOVERY**
   - Laser-failure recovery unload attempts.
   - Emergency lock attempt when target lock disappears.

## Orchestration
- `MainLoop()` drives state machine: `LOCK -> SELECT -> LASER`.
- `ASSIST` mode starts in `SELECT`.
- `AUTO` mode includes `LOCK` stage.

## Config ownership by module
- Main controls: `[main]`
- LOCK controls: `[module_lock]`
- SELECT controls: `[module_select]`
- LASER controls: `[module_laser]`
- UNLOAD controls: `[module_unload]`
- Recovery controls: `[module_recovery]`
- Shared timing primitives: `[timers]`
- Compatibility-only keys: `[deprecated]`

## Key helper groups
- Pixel/color: `PixelInRect`, `CountColorMatchesInRect`, `ColorNear`
- Input: `LeftClick`, `RightClick`, `DragMouse`
- Runtime/logging: `Debug`, `LogEvent`, `SendTelegram`
- Config/load: `LoadConfig`, `ApplyLayoutOverrides`, `ParsePoints`, `ParseIntList`
