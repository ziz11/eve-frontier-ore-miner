#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetWorkingDir A_ScriptDir

global cfg := Map()
global running := false
global state := "LOCK"
global runMode := "AUTO"
global lastUnloadTick := 0
global nextUnloadTick := 0
global laserLostTick := 0
global lastLaserRetryTick := 0
global lastHeartbeatTick := 0
global lastDebugLoopTick := 0
global lastError := ""
global lastSelectedSlotX := 0
global lastSelectedSlotY := 0
global lastTargetSelectedTick := 0
global lastLaserActionTick := 0
global lastOreScanTick := 0
global oreNoTextStreak := 0

global STATE_LOCK := "LOCK"
global STATE_SELECT := "SELECT"
global STATE_LASER := "LASER"

LoadConfig()

F7::ToggleBot("ASSIST")
F8::ToggleBot("AUTO")
F6::ManualOreTransferTest()
F10::Reload
Esc::ExitApp

ToggleBot(mode) {
    global running, runMode, state, lastUnloadTick, nextUnloadTick, laserLostTick, lastLaserRetryTick, lastHeartbeatTick, lastDebugLoopTick, lastError, lastSelectedSlotX, lastSelectedSlotY, lastTargetSelectedTick, lastLaserActionTick, lastOreScanTick, oreNoTextStreak
    if running && runMode = mode {
        running := false
    } else {
        runMode := mode
        running := true
    }

    if running {
        state := (runMode = "AUTO") ? STATE_LOCK : STATE_SELECT
        lastUnloadTick := A_TickCount
        nextUnloadTick := 0
        ScheduleNextUnload()
        laserLostTick := 0
        lastLaserRetryTick := 0
        lastHeartbeatTick := 0
        lastDebugLoopTick := 0
        lastError := ""
        lastSelectedSlotX := 0
        lastSelectedSlotY := 0
        lastTargetSelectedTick := 0
        lastLaserActionTick := 0
        lastOreScanTick := 0
        oreNoTextStreak := 0
        SendTelegram("STARTED mode=" runMode)
        SetTimer MainLoop, cfg["main_loop_ms"]
        TrayTip "Miner", "Started " runMode, 800
    } else {
        SetTimer MainLoop, 0
        SendTelegram("STOPPED mode=" runMode)
        TrayTip "Miner", "Stopped", 800
    }
}

MainLoop() {
    global running, state, lastUnloadTick, nextUnloadTick, lastHeartbeatTick, lastDebugLoopTick, lastTargetSelectedTick
    if !running {
        return
    }

    if !IsEveActive() {
        return
    }

    now := A_TickCount

    if cfg["debug_enabled"] && (now - lastDebugLoopTick >= cfg["debug_loop_every_ms"]) {
        Debug("loop state=" state " mode=" runMode " targets=" HasAnyTopRightTarget() " active=" HasActiveTargetOrange() " lasers=" CountActiveLasers())
        lastDebugLoopTick := now
    }

    if now - lastHeartbeatTick >= cfg["heartbeat_ms"] {
        SendTelegram("HEARTBEAT: state=" state)
        lastHeartbeatTick := now
    }

    if now >= nextUnloadTick {
        if cfg["unload_block_during_laser"] && state = STATE_LASER {
            nextUnloadTick := now + cfg["unload_busy_retry_ms"]
            if cfg["debug_enabled"] {
                Debug("unload postponed state=LASER next_in_ms=" cfg["unload_busy_retry_ms"])
            }
        } else if lastTargetSelectedTick > 0 && (now - lastTargetSelectedTick) < cfg["unload_after_target_select_delay_ms"] {
            ; Keep mining flow stable right after target selection.
            nextUnloadTick := now + cfg["unload_busy_retry_ms"]
        } else {
            DoUnload()
            lastUnloadTick := now
            ScheduleNextUnload()
        }
    }

    if state = STATE_LOCK {
        if runMode != "AUTO" {
            SetState(STATE_SELECT, "assist mode skips lock stage")
            return
        }
        if DoLockStage() {
            SetState(STATE_SELECT, "lock acquired")
        }
        return
    }

    if state = STATE_SELECT {
        if SelectTopRightTarget() {
            SetState(STATE_LASER, "target selected")
        } else if !HasAnyTopRightTarget() && runMode = "AUTO" {
            SetState(STATE_LOCK, "no targets left")
        }
        return
    }

    if state = STATE_LASER {
        DoLaserStage()
        return
    }
}

DoLockStage() {
    Debug("lock stage start")
    startTick := A_TickCount
    timeout := cfg["lock_timeout_ms"]
    loop {
        if HasAnyTopRightTarget() {
            return true
        }

        for p in GetLockCandidates() {
            Debug("lock try asteroid x=" p[1] " y=" p[2])
            RightClick p[1], p[2]
            Sleep cfg["ui_delay_ms"]
            LeftClick cfg["lock_target_menu_x"], cfg["lock_target_menu_y"]
            Sleep cfg["lock_retry_pause_ms"]
            if HasAnyTopRightTarget() {
                return true
            }
        }

        if A_TickCount - startTick > timeout {
            Fail("LOCK timeout")
            return false
        }
    }
}

GetLockCandidates() {
    ; AUTO lock strategy:
    ; 1) dynamic scan for white asteroid markers
    ; 2) fallback to static points from config list
    if cfg["dynamic_lock_enabled"] {
        points := FindDynamicAsteroidPoints()
        if points.Length > 0 {
            SortPointsLeftToRight(points)
            Debug("lock candidates dynamic=" points.Length)
            return points
        }
        Debug("lock candidates dynamic=0 fallback=static")
    }

    points := []
    for p in cfg["asteroid_points"] {
        points.Push([p[1], p[2]])
    }
    SortPointsLeftToRight(points)
    return points
}

FindDynamicAsteroidPoints() {
    points := []
    step := cfg["asteroid_scan_step_px"]
    dedupeRadius := cfg["asteroid_dedupe_radius_px"]
    maxCandidates := cfg["asteroid_max_candidates"]
    targetColor := cfg["asteroid_marker_color"]
    variation := cfg["asteroid_marker_variation"]

    x1 := cfg["asteroid_scan_x1"]
    y1 := cfg["asteroid_scan_y1"]
    x2 := cfg["asteroid_scan_x2"]
    y2 := cfg["asteroid_scan_y2"]

    y := y1
    while y <= y2 {
        x := x1
        while x <= x2 {
            if PixelNearColor(x, y, targetColor, variation) && !HasNearbyPoint(points, x, y, dedupeRadius) {
                points.Push([x, y])
                if points.Length >= maxCandidates {
                    return points
                }
            }
            x += step
        }
        y += step
    }

    return points
}

HasNearbyPoint(points, x, y, radius) {
    r2 := radius * radius
    for p in points {
        dx := p[1] - x
        dy := p[2] - y
        if (dx * dx + dy * dy) <= r2 {
            return true
        }
    }
    return false
}

PixelNearColor(x, y, targetColor, variation) {
    try {
        c := PixelGetColor(x, y, "RGB")
        return ColorNear(c, targetColor, variation)
    } catch {
        return false
    }
}

ColorNear(c1, c2, variation) {
    r1 := (c1 >> 16) & 0xFF
    g1 := (c1 >> 8) & 0xFF
    b1 := c1 & 0xFF

    r2 := (c2 >> 16) & 0xFF
    g2 := (c2 >> 8) & 0xFF
    b2 := c2 & 0xFF

    return Abs(r1 - r2) <= variation
        && Abs(g1 - g2) <= variation
        && Abs(b1 - b2) <= variation
}

SelectTopRightTarget() {
    global lastSelectedSlotX, lastSelectedSlotY, lastTargetSelectedTick
    candidates := GetTargetCandidates()
    triedAnySlot := false
    for p in candidates {
        anchor := GetSlotAnchor(p[1], p[2])
        if anchor.Length < 2 {
            Debug("select skip empty slot x=" p[1] " y=" p[2])
            continue
        }
        clickPoint := GetSlotClickPoint(anchor[1], anchor[2])
        if clickPoint.Length < 2 {
            Debug("select skip slot no click point x=" anchor[1] " y=" anchor[2])
            continue
        }
        triedAnySlot := true

        attempt := 1
        maxAttempts := cfg["target_select_slot_attempts"]
        while attempt <= maxAttempts {
            Debug("select try slot anchor=" anchor[1] "," anchor[2] " click=" clickPoint[1] "," clickPoint[2] " (base " p[1] "," p[2] ") attempt=" attempt "/" maxAttempts)
            preActive := SlotHasActiveTarget(anchor[1], anchor[2])
            LeftClick clickPoint[1], clickPoint[2]
            Sleep cfg["target_select_settle_ms"]
            if WaitForActiveTarget(anchor[1], anchor[2], preActive) {
                Debug("select success anchor=" anchor[1] "," anchor[2] " attempt=" attempt)
                lastSelectedSlotX := anchor[1]
                lastSelectedSlotY := anchor[2]
                lastTargetSelectedTick := A_TickCount
                return true
            }
            if attempt < maxAttempts {
                Sleep cfg["target_select_retry_delay_ms"]
            }
            attempt += 1
        }

        Debug("select slot failed anchor=" anchor[1] "," anchor[2] " attempts=" maxAttempts)
    }

    if triedAnySlot {
        StopWithError("TARGET LOCK failed: cannot activate any slot")
        return false
    }

    Debug("select failed no active slot")
    return false
}

GetTargetCandidates() {
    if cfg["dynamic_target_slot_scan_enabled"] {
        points := FindDynamicTargetSlots()
        if points.Length > 0 {
            SortPointsLeftToRight(points)
            Debug("select candidates dynamic=" points.Length)
            return points
        }

        Debug("select candidates dynamic=0 fallback=static")
    }

    staticPoints := []
    for p in cfg["target_slots"] {
        staticPoints.Push([p[1], p[2]])
    }
    SortPointsLeftToRight(staticPoints)
    Debug("select candidates static=" staticPoints.Length)
    return staticPoints
}

SlotHasTarget(x, y) {
    p := GetSlotAnchor(x, y)
    return p.Length >= 2
}

GetSlotAnchor(x, y) {
    if HasSlotWhiteBelow(x, y) {
        return [x, y]
    }

    yRadius := cfg["target_slot_y_search_radius_px"]
    yStep := cfg["target_slot_y_search_step_px"]
    xJitter := cfg["target_slot_x_jitter_px"]
    dxList := [0, -xJitter, xJitter]
    offset := 1
    while offset <= yRadius {
        yUp := y - offset
        yDown := y + offset
        for dx in dxList {
            if HasSlotWhiteBelow(x + dx, yUp) {
                return [x + dx, yUp]
            }
            if HasSlotWhiteBelow(x + dx, yDown) {
                return [x + dx, yDown]
            }
        }
        offset += yStep
    }

    return []
}

GetSlotClickPoint(anchorX, anchorY) {
    clickY := anchorY - cfg["target_slot_click_offset_y"]
    return [anchorX, clickY]
}

HasSlotWhiteBelow(anchorX, anchorY) {
    y := anchorY + cfg["target_slot_exists_offset_y"]
    r := cfg["target_slot_exists_probe_radius_px"]
    return PixelInRect(
        anchorX - r, y - r,
        anchorX + r, y + r,
        cfg["target_slot_exists_white_color"], cfg["target_slot_exists_white_variation"]
    )
}

IsColorNear(x, y, targetColor, variation) {
    return PixelInRect(x - 1, y - 1, x + 1, y + 1, targetColor, variation)
}

FindDynamicTargetSlots() {
    points := []
    x1 := cfg["target_region_x1"]
    y1 := cfg["target_region_y1"]
    x2 := cfg["target_region_x2"]
    y2 := cfg["target_region_y2"]
    step := cfg["target_slot_scan_step_px"]
    dedupeRadius := cfg["target_slot_dedupe_radius_px"]
    maxCandidates := cfg["target_slot_max_candidates"]
    targetColor := Integer(cfg["target_present_color"])
    variation := cfg["color_variation"]

    y := y1
    while y <= y2 {
        x := x1
        while x <= x2 {
            if PixelNearColor(x, y, targetColor, variation) && !HasNearbyPoint(points, x, y, dedupeRadius) {
                points.Push([x, y])
                if points.Length >= maxCandidates {
                    return points
                }
            }
            x += step
        }
        y += step
    }

    return points
}

WaitForActiveTarget(slotX := 0, slotY := 0, preActive := false) {
    timeoutMs := cfg["target_select_confirm_ms"]
    pollMs := cfg["target_select_poll_ms"]
    requiredHits := cfg["target_active_confirm_hits"]
    hitStreak := 0
    sawFalseAfterClick := !preActive || !cfg["target_require_state_transition"]
    startTick := A_TickCount
    loop {
        found := false
        if (slotX > 0 && slotY > 0) {
            if SlotHasActiveTarget(slotX, slotY) {
                found := true
            }
        } else if HasActiveTargetOrange() {
            found := true
        }

        if found {
            hitStreak += 1
            if (sawFalseAfterClick && hitStreak >= requiredHits) || (!sawFalseAfterClick && hitStreak >= (requiredHits + cfg["target_active_preselected_extra_hits"])) {
                return true
            }
        } else {
            sawFalseAfterClick := true
            hitStreak := 0
        }
        if (A_TickCount - startTick) >= timeoutMs {
            return false
        }
        Sleep pollMs
    }
}

SlotHasActiveTarget(x, y) {
    if !HasSlotWhiteBelow(x, y) {
        return false
    }

    p := GetSlotClickPoint(x, y)
    if p.Length < 2 {
        return false
    }

    r := cfg["target_slot_active_probe_radius_px"]
    sampleColor := 0
    sampleX := 0
    sampleY := 0
    hitCount := CountColorMatchesInRect(
        p[1] - r, p[2] - r,
        p[1] + r, p[2] + r,
        cfg["target_active_orange_color"], cfg["target_active_color_variation"],
        cfg["target_active_min_hits"],
        &sampleColor, &sampleX, &sampleY
    )
    found := hitCount >= cfg["target_active_min_hits"]

    if cfg["debug_enabled"] && cfg["target_active_debug_log"] {
        Debug(
            "active-check slot=" x "," y
            " click=" p[1] "," p[2]
            " hits=" hitCount "/" cfg["target_active_min_hits"]
            " sample=" Format("0x{:06X}", sampleColor)
            " at=" sampleX "," sampleY
        )
    }

    return found
}

ManualOreTransferTest() {
    if !IsEveActive() {
        Debug("manual ore test skipped: EVE window not active")
        return
    }

    moved := TryTransferOreByText()
    if moved > 0 {
        Debug("manual ore test success moved=" moved)
    } else {
        Debug("manual ore test no ore found")
    }
}

SortPointsLeftToRight(points) {
    if points.Length <= 1 {
        return points
    }

    i := 2
    while i <= points.Length {
        key := points[i]
        j := i - 1
        while j >= 1 && (points[j][1] > key[1] || (points[j][1] = key[1] && points[j][2] > key[2])) {
            points[j + 1] := points[j]
            j -= 1
        }
        points[j + 1] := key
        i += 1
    }
    return points
}

DoLaserStage() {
    global state, runMode, laserLostTick, lastLaserRetryTick, lastTargetSelectedTick, lastLaserActionTick, lastOreScanTick, oreNoTextStreak

    if !HasAnyTopRightTarget() {
        SetState((runMode = "AUTO") ? STATE_LOCK : STATE_SELECT, "no targets in laser stage")
        return
    }

    if !HasSelectedTargetActive() {
        oreNoTextStreak := 0
        SetState(STATE_SELECT, "selected target lost")
        return
    }

    if DetectTooFarBanner() {
        oreNoTextStreak := 0
        SetState(STATE_SELECT, "too far banner")
        return
    }

    now := A_TickCount
    activeCount := CountActiveLasers()

    if activeCount >= cfg["min_active_lasers_required"] {
        laserLostTick := 0

        ; LASER stage does ore transfer checks by scanning inventory text region.
        if lastOreScanTick = 0 || (now - lastOreScanTick) >= cfg["ore_scan_interval_ms"] {
            lastOreScanTick := now
            moved := TryTransferOreByText()
            if moved > 0 {
                oreNoTextStreak := 0
                return
            }

            oreNoTextStreak += 1
            if cfg["debug_enabled"] {
                Debug("ore scan no text streak=" oreNoTextStreak "/" cfg["ore_scan_no_text_limit"])
            }

            if oreNoTextStreak >= cfg["ore_scan_no_text_limit"] {
                oreNoTextStreak := 0
                if !HasAnyTopRightTarget() {
                    SetState((runMode = "AUTO") ? STATE_LOCK : STATE_SELECT, "ore not found and no targets")
                    return
                }
                if CountActiveLasers() < cfg["min_active_lasers_required"] {
                    lastLaserRetryTick := 0
                }
            }
        }
        return
    }

    ; Workaround mode: keep mining with partially active lasers (e.g. one module out of ammo),
    ; and retry dead slots less aggressively without tripping hard fail deadline.
    if cfg["laser_allow_partial"] && activeCount > 0 {
        laserLostTick := 0
        ; Keep ore flow alive even in partial mode.
        if lastOreScanTick = 0 || (now - lastOreScanTick) >= cfg["ore_scan_interval_ms"] {
            lastOreScanTick := now
            moved := TryTransferOreByText()
            if moved > 0 {
                oreNoTextStreak := 0
            } else {
                oreNoTextStreak += 1
                if cfg["debug_enabled"] {
                    Debug("ore scan no text streak=" oreNoTextStreak "/" cfg["ore_scan_no_text_limit"] " (partial)")
                }
                if oreNoTextStreak >= cfg["ore_scan_no_text_limit"] {
                    oreNoTextStreak := 0
                }
            }
        }
        if (now - lastLaserRetryTick) >= cfg["laser_partial_retry_delay_ms"] {
            TryActivateLasersBySlots()
            lastLaserRetryTick := now
        }
        return
    }

    if laserLostTick = 0 {
        laserLostTick := A_TickCount
    }

    if lastTargetSelectedTick > 0 && (now - lastTargetSelectedTick) < cfg["laser_after_target_select_delay_ms"] {
        return
    }
    if lastLaserActionTick > 0 && (now - lastLaserActionTick) < cfg["laser_after_activate_grace_ms"] {
        return
    }

    if (now - lastLaserRetryTick) >= cfg["laser_retry_delay_ms"] {
        TryActivateLasersBySlots()
        activeCount := CountActiveLasers()
        if activeCount >= cfg["min_active_lasers_required"] {
            laserLostTick := 0
            lastLaserRetryTick := now
            return
        }
        lastLaserRetryTick := now
    }

    if (now - laserLostTick) >= cfg["laser_fail_deadline_ms"] {
        AttemptLaserFailureRecovery()
        StopWithError("LASER failed: unable to activate configured slots")
    }
}

HasSelectedTargetActive() {
    global lastSelectedSlotX, lastSelectedSlotY
    if lastSelectedSlotX > 0 && lastSelectedSlotY > 0 {
        return SlotHasActiveTarget(lastSelectedSlotX, lastSelectedSlotY)
    }
    return HasActiveTargetOrange()
}

TryActivateLasersBySlots() {
    global lastLaserActionTick
    slots := GetConfiguredLaserSlots()
    if slots.Length = 0 {
        Debug("laser no configured slots")
        return false
    }

    anyActive := false
    for slot in slots {
        if IsLaserSlotActive(slot) {
            anyActive := true
            continue
        }

        attempt := 1
        maxAttempts := cfg["laser_slot_attempts"]
        while attempt <= maxAttempts {
            Debug("laser activate slot#" slot["index"] " click=" slot["x"] "," slot["y"] " attempt=" attempt "/" maxAttempts)
            LeftClick slot["x"], slot["y"]
            lastLaserActionTick := A_TickCount
            Sleep cfg["laser_slot_retry_delay_ms"]
            if WaitForLaserSlotActive(slot) {
                Debug("laser activated slot#" slot["index"] " attempt=" attempt)
                anyActive := true
                break
            }
            attempt += 1
        }
    }

    for slot in slots {
        Debug("laser slot#" slot["index"] " x=" slot["x"] " y=" slot["y"] " active=" (IsLaserSlotActive(slot) ? 1 : 0))
    }
    Debug("laser retry slots=" cfg["active_laser_slots_raw"] " active_any=" (anyActive ? 1 : 0))
    return anyActive
}

GetConfiguredLaserSlots() {
    slots := []
    for _, slotIndex in cfg["active_laser_slots"] {
        if slotIndex < 1 {
            continue
        }
        if slotIndex > cfg["laser_check_points"].Length {
            Debug("laser slot#" slotIndex " missing check point")
            continue
        }
        p := cfg["laser_check_points"][slotIndex]
        if p.Length < 2 || p[1] <= 0 || p[2] <= 0 {
            Debug("laser slot#" slotIndex " invalid point")
            continue
        }

        slot := Map()
        slot["index"] := slotIndex
        slot["x"] := p[1]
        slot["y"] := p[2]
        slots.Push(slot)
    }
    return slots
}

IsLaserSlotActive(slot) {
    r := cfg["laser_probe_radius_px"]
    sampleColor := 0
    sampleX := 0
    sampleY := 0
    hitCount := CountColorMatchesInRect(
        slot["x"] - r, slot["y"] - r,
        slot["x"] + r, slot["y"] + r,
        cfg["laser_active_orange_color"], cfg["laser_color_variation"],
        cfg["laser_active_min_hits"],
        &sampleColor, &sampleX, &sampleY
    )
    active := hitCount >= cfg["laser_active_min_hits"]
    if cfg["debug_enabled"] && cfg["laser_debug_log"] {
        Debug(
            "laser-check slot#" slot["index"]
            " point=" slot["x"] "," slot["y"]
            " hits=" hitCount "/" cfg["laser_active_min_hits"]
            " sample=" Format("0x{:06X}", sampleColor)
            " at=" sampleX "," sampleY
        )
    }
    return active
}

WaitForLaserSlotActive(slot) {
    timeoutMs := cfg["laser_activate_confirm_ms"]
    pollMs := cfg["laser_activate_poll_ms"]
    requiredHits := cfg["laser_active_confirm_hits"]
    streak := 0
    startTick := A_TickCount
    loop {
        if IsLaserSlotActive(slot) {
            streak += 1
            if streak >= requiredHits {
                return true
            }
        } else {
            streak := 0
        }
        if (A_TickCount - startTick) >= timeoutMs {
            return false
        }
        Sleep pollMs
    }
}

AttemptLaserFailureRecovery() {
    Debug("laser recovery start")
    i := 1
    while i <= cfg["laser_recovery_unload_attempts"] {
        Debug("laser recovery unload attempt=" i "/" cfg["laser_recovery_unload_attempts"])
        DoUnload()
        if i < cfg["laser_recovery_unload_attempts"] {
            Sleep cfg["laser_recovery_unload_delay_ms"]
        }
        i += 1
    }

    if !HasAnyTopRightTarget() {
        Debug("laser recovery lock missing -> emergency lock attempt")
        if TryEmergencyLock() {
            Debug("laser recovery emergency lock acquired")
        } else {
            Debug("laser recovery emergency lock failed")
        }
    }
    Debug("laser recovery end")
}

TryEmergencyLock() {
    startTick := A_TickCount
    timeout := cfg["emergency_lock_timeout_ms"]
    loop {
        if HasAnyTopRightTarget() {
            return true
        }

        for p in GetLockCandidates() {
            RightClick p[1], p[2]
            Sleep cfg["ui_delay_ms"]
            LeftClick cfg["lock_target_menu_x"], cfg["lock_target_menu_y"]
            Sleep cfg["lock_retry_pause_ms"]
            if HasAnyTopRightTarget() {
                return true
            }
        }

        if A_TickCount - startTick > timeout {
            return false
        }
    }
}

DoUnload() {
    Debug("unload start slots=" cfg["ore_slots"].Length)
    ; Prefer robust text-based transfer first; static slots stay as fallback.
    movedByText := 0
    if cfg["ore_transfer_max_per_scan"] > 0 {
        movedByText := TryTransferOreByText()
        if movedByText > 0 {
            Debug("unload end moved_by_text=" movedByText)
            return
        }
        if !cfg["unload_allow_slot_fallback"] {
            Debug("unload text transfer found none -> skip (slot fallback disabled)")
            return
        }
        Debug("unload text transfer found none -> fallback slots")
    }
    ; Re-anchor inventory context every unload to avoid dragging from wrong pane.
    FocusInventoryWindow()
    SelectShipInventory()

    for p in cfg["ore_slots"] {
        ; Some UI interactions can switch pane; force SHIP selection before each drag.
        SelectShipInventory()
        Debug("unload drag x=" p[1] " y=" p[2] " -> portable")
        DragMouse p[1], p[2], cfg["portable_row_x"], cfg["portable_row_y"]
        Sleep cfg["ui_delay_ms"]
    }
    Debug("unload end")
}

TryTransferOreByText() {
    maxTransfers := cfg["ore_transfer_max_per_scan"]
    if maxTransfers < 1 {
        return 0
    }

    FocusInventoryWindow()
    SelectShipInventory()

    moved := 0
    i := 1
    while i <= maxTransfers {
        p := FindOreTextPixel()
        if p.Length < 2 {
            break
        }
        if !IsNumericCoord(p[1]) || !IsNumericCoord(p[2]) {
            Debug("ore text invalid coords x=" p[1] " y=" p[2] " skip transfer")
            break
        }
        if !IsNumericCoord(cfg["portable_row_x"]) || !IsNumericCoord(cfg["portable_row_y"]) {
            Debug("portable row invalid coords x=" cfg["portable_row_x"] " y=" cfg["portable_row_y"] " skip transfer")
            break
        }

        dragX := p[1]
        dragY := p[2] + cfg["ore_drag_offset_y"]
        if !IsNumericCoord(dragX) || !IsNumericCoord(dragY) {
            Debug("ore drag invalid source coords x=" dragX " y=" dragY " skip transfer")
            break
        }

        Debug("ore text found x=" p[1] " y=" p[2] " drag_from=" dragX "," dragY " transfer#" i "/" maxTransfers)
        DragMouse dragX, dragY, cfg["portable_row_x"], cfg["portable_row_y"]
        Sleep cfg["ui_delay_ms"]
        moved += 1

        ; Some UI interactions can deselect ship pane; keep it anchored.
        SelectShipInventory()

        ; Keep lasers alive while unloading ore stacks.
        if CountActiveLasers() < cfg["min_active_lasers_required"] {
            Debug("ore transfer detected inactive lasers -> re-activate")
            TryActivateLasersBySlots()
        }

        i += 1
    }

    return moved
}

FindOreTextPixel() {
    x1 := cfg["ore_scan_x1"]
    y1 := cfg["ore_scan_y1"]
    x2 := cfg["ore_scan_x2"]
    y2 := cfg["ore_scan_y2"]
    color := cfg["ore_text_color"]
    variation := cfg["ore_text_variation"]
    useCluster := cfg["ore_cluster_enabled"]

    curX := x1
    curY := y1
    loop {
    x := ""
    y := ""
    try {
        found := PixelSearch(&x, &y
            , curX, curY
            , x2, y2
            , color, variation)
        if !found {
            return []
        }
        if !IsNumericCoord(x) || !IsNumericCoord(y) {
            if cfg["debug_enabled"] {
                Debug("ore text search returned non-numeric coords x=" x " y=" y)
            }
            return []
        }
        px := Integer(x)
        py := Integer(y)
        if !useCluster || HasOreDigitCluster(px, py) {
            return [px, py]
        }

        ; Keep searching from the next pixel when cluster check fails.
        nextX := px + 1
        nextY := py
        if nextX > x2 {
            nextX := x1
            nextY := py + 1
        }
        if nextY > y2 {
            return []
        }
        curX := nextX
        curY := nextY
    } catch {
        return []
    }
    }
}

HasOreDigitCluster(px, py) {
    lineLen := cfg["ore_cluster_len_px"]
    minHits := cfg["ore_cluster_min_hits"]
    threshold := cfg["ore_cluster_threshold"]
    if lineLen < 1 || minHits < 1 {
        return true
    }

    hits := 0
    i := 0
    while i < lineLen {
        try {
            c := PixelGetColor(px + i, py, "RGB")
            if IsColorBrightEnough(c, threshold) {
                hits += 1
                if hits >= minHits {
                    return true
                }
            }
        } catch {
        }
        i += 1
    }
    return false
}

IsColorBrightEnough(color, threshold) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF

    tr := (threshold >> 16) & 0xFF
    tg := (threshold >> 8) & 0xFF
    tb := threshold & 0xFF

    return r >= tr && g >= tg && b >= tb
}

FocusInventoryWindow() {
    if cfg["inventory_window_x"] > 0 && cfg["inventory_window_y"] > 0 {
        LeftClick cfg["inventory_window_x"], cfg["inventory_window_y"]
        Sleep cfg["ui_delay_ms"]
    }
}

SelectShipInventory() {
    LeftClick cfg["ship_row_x"], cfg["ship_row_y"]
    Sleep cfg["ui_delay_ms"]
}

HasAnyTopRightTarget() {
    return PixelInRect(
        cfg["target_region_x1"], cfg["target_region_y1"],
        cfg["target_region_x2"], cfg["target_region_y2"],
        cfg["target_present_color"], cfg["color_variation"]
    )
}

HasActiveTargetOrange() {
    return PixelInRect(
        cfg["target_region_x1"], cfg["target_region_y1"],
        cfg["target_region_x2"], cfg["target_region_y2"],
        cfg["target_active_orange_color"], cfg["target_active_color_variation"]
    )
}

CountActiveLasers() {
    count := 0
    for slot in GetConfiguredLaserSlots() {
        if IsLaserSlotActive(slot) {
            count += 1
        }
    }
    return count
}

ScheduleNextUnload() {
    global nextUnloadTick
    minMs := cfg["unload_interval_min_ms"]
    maxMs := cfg["unload_interval_max_ms"]
    if maxMs < minMs {
        tmp := minMs
        minMs := maxMs
        maxMs := tmp
    }
    if maxMs = minMs {
        nextUnloadTick := A_TickCount + minMs
        return
    }
    nextUnloadTick := A_TickCount + Random(minMs, maxMs)
}

DetectTooFarBanner() {
    if cfg["too_far_image"] = "" {
        return false
    }
    if !FileExist(cfg["too_far_image"]) {
        return false
    }
    x := 0
    y := 0
    try {
        ImageSearch &x, &y
            , cfg["too_far_region_x1"], cfg["too_far_region_y1"]
            , cfg["too_far_region_x2"], cfg["too_far_region_y2"]
            , "*" cfg["image_variation"] " " cfg["too_far_image"]
        return true
    } catch {
        return false
    }
}

Fail(msg) {
    global lastError
    if lastError != msg {
        SendTelegram("FAILED: " msg)
        lastError := msg
    }
}

StopWithError(msg) {
    global running
    Fail(msg)
    running := false
    SetTimer MainLoop, 0
    TrayTip "Miner", "ERROR: " msg, 2000
}

SetState(nextState, reason := "") {
    global state
    if state != nextState {
        Debug("state " state " -> " nextState ((reason != "") ? " | " reason : ""))
        state := nextState
    }
}

Debug(msg) {
    if cfg.Has("debug_enabled") && cfg["debug_enabled"] {
        LogEvent("[DEBUG] " msg)
    }
}

IsEveActive() {
    return WinActive(cfg["eve_window_title"])
}

PixelInRect(x1, y1, x2, y2, color, variation) {
    try {
        PixelSearch &fx, &fy, x1, y1, x2, y2, color, variation
        return true
    } catch {
        return false
    }
}

PixelNear(x, y, color, variation) {
    return PixelNearWithRadius(x, y, color, variation, 4)
}

PixelNearWithRadius(x, y, color, variation, radius) {
    x1 := x - radius
    y1 := y - radius
    x2 := x + radius
    y2 := y + radius
    return PixelInRect(x1, y1, x2, y2, color, variation)
}

CountColorMatchesInRect(x1, y1, x2, y2, targetColor, variation, stopAt := 0, &sampleColor := 0, &sampleX := 0, &sampleY := 0) {
    count := 0
    y := y1
    while y <= y2 {
        x := x1
        while x <= x2 {
            try {
                c := PixelGetColor(x, y, "RGB")
                if ColorNear(c, targetColor, variation) {
                    count += 1
                    if sampleColor = 0 {
                        sampleColor := c
                        sampleX := x
                        sampleY := y
                    }
                    if stopAt > 0 && count >= stopAt {
                        return count
                    }
                }
            } catch {
            }
            x += 1
        }
        y += 1
    }
    return count
}

LeftClick(x, y) {
    Debug("left click x=" x " y=" y)
    MouseMove x, y, 0
    ShowClickMarker("L", x, y)
    Click "Left"
}

RightClick(x, y) {
    Debug("right click x=" x " y=" y)
    MouseMove x, y, 0
    ShowClickMarker("R", x, y)
    Click "Right"
}

DragMouse(x1, y1, x2, y2) {
    if !IsNumericCoord(x1) || !IsNumericCoord(y1) || !IsNumericCoord(x2) || !IsNumericCoord(y2) {
        Debug("drag skipped invalid coords x1=" x1 " y1=" y1 " x2=" x2 " y2=" y2)
        return
    }
    Debug("drag x1=" x1 " y1=" y1 " x2=" x2 " y2=" y2)
    MouseMove x1, y1, 0
    ShowClickMarker("D", x1, y1)
    MouseClickDrag "Left", x1, y1, x2, y2, 12
}

IsNumericCoord(value) {
    return IsNumber(value) && value != ""
}

ShowClickMarker(kind, x, y) {
    if !(cfg.Has("debug_click_marker_ms") && cfg["debug_click_marker_ms"] > 0) {
        return
    }
    ToolTip kind " " x "," y, x + 18, y + 18
    SetTimer () => ToolTip(), -cfg["debug_click_marker_ms"]
}

SendTelegram(text) {
    LogEvent(text)

    token := cfg["telegram_bot_token"]
    chatId := cfg["telegram_chat_id"]
    if token = "" || chatId = "" {
        return
    }

    text := StrReplace(text, " ", "%20")
    text := StrReplace(text, "`n", "%0A")
    url := "https://api.telegram.org/bot" token "/sendMessage?chat_id=" chatId "&text=[EVE]%20" text
    cmd := "curl -sS --max-time 4 " . Chr(34) . url . Chr(34) . " >NUL 2>&1"
    RunWait A_ComSpec " /c " cmd,, "Hide"
}

LogEvent(text) {
    logDir := A_ScriptDir "\logs"
    if !DirExist(logDir) {
        DirCreate logDir
    }

    ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    line := ts " | " text "`n"
    FileAppend line, logDir "\miner.log", "UTF-8"
}

LoadConfig() {
    global cfg
    cfg["eve_window_title"] := IniRead("config.ini", "general", "eve_window_title", "EVE Frontier")
    cfg["main_loop_ms"] := Integer(IniRead("config.ini", "general", "main_loop_ms", 2000))
    cfg["ui_delay_ms"] := Integer(IniRead("config.ini", "general", "ui_delay_ms", 250))
    cfg["debug_enabled"] := Integer(IniRead("config.ini", "general", "debug_enabled", 0)) = 1
    cfg["debug_loop_every_ms"] := Integer(IniRead("config.ini", "general", "debug_loop_every_ms", 5000))
    ; Keep backward compatibility for a common typo key: dynamic_lock_ena1.
    dynRaw := IniRead("config.ini", "general", "dynamic_lock_enabled", "")
    if dynRaw = "" {
        dynRaw := IniRead("config.ini", "general", "dynamic_lock_ena1", "1")
    }
    cfg["dynamic_lock_enabled"] := Integer(dynRaw) = 1
    cfg["asteroid_scan_step_px"] := Integer(IniRead("config.ini", "general", "asteroid_scan_step_px", 10))
    cfg["asteroid_dedupe_radius_px"] := Integer(IniRead("config.ini", "general", "asteroid_dedupe_radius_px", 26))
    cfg["asteroid_max_candidates"] := Integer(IniRead("config.ini", "general", "asteroid_max_candidates", 12))
    cfg["target_slot_scan_step_px"] := Integer(IniRead("config.ini", "general", "target_slot_scan_step_px", 8))
    cfg["target_slot_dedupe_radius_px"] := Integer(IniRead("config.ini", "general", "target_slot_dedupe_radius_px", 32))
    cfg["target_slot_max_candidates"] := Integer(IniRead("config.ini", "general", "target_slot_max_candidates", 8))
    cfg["dynamic_target_slot_scan_enabled"] := Integer(IniRead("config.ini", "general", "dynamic_target_slot_scan_enabled", 0)) = 1
    cfg["target_slot_probe_radius_px"] := Integer(IniRead("config.ini", "general", "target_slot_probe_radius_px", 24))
    cfg["target_slot_y_search_radius_px"] := Integer(IniRead("config.ini", "general", "target_slot_y_search_radius_px", 40))
    cfg["target_slot_y_search_step_px"] := Integer(IniRead("config.ini", "general", "target_slot_y_search_step_px", 4))
    cfg["target_slot_x_jitter_px"] := Integer(IniRead("config.ini", "general", "target_slot_x_jitter_px", 10))
    cfg["target_slot_active_probe_radius_px"] := Integer(IniRead("config.ini", "general", "target_slot_active_probe_radius_px", 5))
    cfg["target_slot_click_offset_y"] := Integer(IniRead("config.ini", "general", "target_slot_click_offset_y", 30))
    cfg["ore_drag_offset_y"] := Integer(IniRead("config.ini", "general", "ore_drag_offset_y", 30))
    cfg["target_slot_exists_offset_y"] := Integer(IniRead("config.ini", "general", "target_slot_exists_offset_y", 22))
    cfg["target_slot_exists_probe_radius_px"] := Integer(IniRead("config.ini", "general", "target_slot_exists_probe_radius_px", 5))
    cfg["debug_click_marker_ms"] := Integer(IniRead("config.ini", "general", "debug_click_marker_ms", 0))

    cfg["heartbeat_ms"] := Integer(IniRead("config.ini", "timers", "heartbeat_ms", 600000))
    cfg["lock_timeout_ms"] := Integer(IniRead("config.ini", "timers", "lock_timeout_ms", 30000))
    cfg["lock_retry_pause_ms"] := Integer(IniRead("config.ini", "timers", "lock_retry_pause_ms", 500))
    cfg["laser_retry_delay_ms"] := Integer(IniRead("config.ini", "timers", "laser_retry_delay_ms", 5000))
    cfg["laser_allow_partial"] := Integer(IniRead("config.ini", "timers", "laser_allow_partial", 1)) = 1
    cfg["laser_partial_retry_delay_ms"] := Integer(IniRead("config.ini", "timers", "laser_partial_retry_delay_ms", 20000))
    cfg["laser_fail_deadline_ms"] := Integer(IniRead("config.ini", "timers", "laser_fail_deadline_ms", 20000))
    cfg["unload_interval_ms"] := Integer(IniRead("config.ini", "timers", "unload_interval_ms", 90000))
    cfg["unload_interval_min_ms"] := Integer(IniRead("config.ini", "timers", "unload_interval_min_ms", cfg["unload_interval_ms"]))
    cfg["unload_interval_max_ms"] := Integer(IniRead("config.ini", "timers", "unload_interval_max_ms", cfg["unload_interval_ms"]))
    cfg["unload_after_target_select_delay_ms"] := Integer(IniRead("config.ini", "timers", "unload_after_target_select_delay_ms", 1000))
    cfg["unload_block_during_laser"] := Integer(IniRead("config.ini", "timers", "unload_block_during_laser", 1)) = 1
    cfg["unload_busy_retry_ms"] := Integer(IniRead("config.ini", "timers", "unload_busy_retry_ms", 1500))
    cfg["unload_allow_slot_fallback"] := Integer(IniRead("config.ini", "timers", "unload_allow_slot_fallback", 0)) = 1
    cfg["ore_scan_interval_ms"] := Integer(IniRead("config.ini", "timers", "ore_scan_interval_ms", 10000))
    cfg["ore_scan_no_text_limit"] := Integer(IniRead("config.ini", "timers", "ore_scan_no_text_limit", 2))
    cfg["ore_transfer_max_per_scan"] := Integer(IniRead("config.ini", "timers", "ore_transfer_max_per_scan", 3))
    cfg["min_active_lasers_required"] := Integer(IniRead("config.ini", "timers", "min_active_lasers_required", 1))
    cfg["laser_probe_radius_px"] := Integer(IniRead("config.ini", "timers", "laser_probe_radius_px", 3))
    cfg["laser_after_target_select_delay_ms"] := Integer(IniRead("config.ini", "timers", "laser_after_target_select_delay_ms", 1000))
    cfg["laser_after_activate_grace_ms"] := Integer(IniRead("config.ini", "timers", "laser_after_activate_grace_ms", 1000))
    cfg["laser_slot_attempts"] := Integer(IniRead("config.ini", "timers", "laser_slot_attempts", 5))
    cfg["laser_slot_retry_delay_ms"] := Integer(IniRead("config.ini", "timers", "laser_slot_retry_delay_ms", 1000))
    cfg["laser_activate_confirm_ms"] := Integer(IniRead("config.ini", "timers", "laser_activate_confirm_ms", 2200))
    cfg["laser_activate_poll_ms"] := Integer(IniRead("config.ini", "timers", "laser_activate_poll_ms", 120))
    cfg["laser_active_confirm_hits"] := Integer(IniRead("config.ini", "timers", "laser_active_confirm_hits", 2))
    cfg["laser_recovery_unload_attempts"] := Integer(IniRead("config.ini", "timers", "laser_recovery_unload_attempts", 3))
    cfg["laser_recovery_unload_delay_ms"] := Integer(IniRead("config.ini", "timers", "laser_recovery_unload_delay_ms", 2000))
    cfg["emergency_lock_timeout_ms"] := Integer(IniRead("config.ini", "timers", "emergency_lock_timeout_ms", 12000))
    cfg["target_select_settle_ms"] := Integer(IniRead("config.ini", "timers", "target_select_settle_ms", 120))
    cfg["target_select_slot_attempts"] := Integer(IniRead("config.ini", "timers", "target_select_slot_attempts", 3))
    cfg["target_select_retry_delay_ms"] := Integer(IniRead("config.ini", "timers", "target_select_retry_delay_ms", 1200))
    cfg["target_select_confirm_ms"] := Integer(IniRead("config.ini", "timers", "target_select_confirm_ms", 3000))
    cfg["target_select_poll_ms"] := Integer(IniRead("config.ini", "timers", "target_select_poll_ms", 120))
    cfg["target_active_confirm_hits"] := Integer(IniRead("config.ini", "timers", "target_active_confirm_hits", 2))
    cfg["target_require_state_transition"] := Integer(IniRead("config.ini", "timers", "target_require_state_transition", 1)) = 1
    cfg["target_active_preselected_extra_hits"] := Integer(IniRead("config.ini", "timers", "target_active_preselected_extra_hits", 2))

    cfg["target_region_x1"] := Integer(IniRead("config.ini", "regions", "target_region_x1", 1360))
    cfg["target_region_y1"] := Integer(IniRead("config.ini", "regions", "target_region_y1", 180))
    cfg["target_region_x2"] := Integer(IniRead("config.ini", "regions", "target_region_x2", 1880))
    cfg["target_region_y2"] := Integer(IniRead("config.ini", "regions", "target_region_y2", 470))

    cfg["too_far_region_x1"] := Integer(IniRead("config.ini", "regions", "too_far_region_x1", 480))
    cfg["too_far_region_y1"] := Integer(IniRead("config.ini", "regions", "too_far_region_y1", 70))
    cfg["too_far_region_x2"] := Integer(IniRead("config.ini", "regions", "too_far_region_x2", 1450))
    cfg["too_far_region_y2"] := Integer(IniRead("config.ini", "regions", "too_far_region_y2", 300))
    cfg["asteroid_scan_x1"] := Integer(IniRead("config.ini", "regions", "asteroid_scan_x1", 420))
    cfg["asteroid_scan_y1"] := Integer(IniRead("config.ini", "regions", "asteroid_scan_y1", 180))
    cfg["asteroid_scan_x2"] := Integer(IniRead("config.ini", "regions", "asteroid_scan_x2", 1540))
    cfg["asteroid_scan_y2"] := Integer(IniRead("config.ini", "regions", "asteroid_scan_y2", 980))
    cfg["ore_scan_x1"] := Integer(IniRead("config.ini", "regions", "ore_scan_x1", 310))
    cfg["ore_scan_y1"] := Integer(IniRead("config.ini", "regions", "ore_scan_y1", 575))
    cfg["ore_scan_x2"] := Integer(IniRead("config.ini", "regions", "ore_scan_x2", 360))
    cfg["ore_scan_y2"] := Integer(IniRead("config.ini", "regions", "ore_scan_y2", 610))

    cfg["target_present_color"] := IniRead("config.ini", "colors", "target_present_color", "0x4A4D51")
    cfg["target_active_orange_color"] := IniRead("config.ini", "colors", "target_active_orange_color", "0xFF4700")
    cfg["target_active_color_variation"] := Integer(IniRead("config.ini", "colors", "target_active_color_variation", 24))
    cfg["target_active_min_hits"] := Integer(IniRead("config.ini", "colors", "target_active_min_hits", 3))
    cfg["target_active_debug_log"] := Integer(IniRead("config.ini", "colors", "target_active_debug_log", 0)) = 1
    cfg["target_slot_exists_white_color"] := Integer(IniRead("config.ini", "colors", "target_slot_exists_white_color", "0xFFFFFF"))
    cfg["target_slot_exists_white_variation"] := Integer(IniRead("config.ini", "colors", "target_slot_exists_white_variation", 22))
    cfg["laser_active_orange_color"] := IniRead("config.ini", "colors", "laser_active_orange_color", "0xFFB600")
    cfg["laser_active_min_hits"] := Integer(IniRead("config.ini", "colors", "laser_active_min_hits", 2))
    cfg["laser_debug_log"] := Integer(IniRead("config.ini", "colors", "laser_debug_log", 0)) = 1
    cfg["ore_text_color"] := Integer(IniRead("config.ini", "colors", "ore_text_color", "0xFFFFFF"))
    cfg["ore_text_variation"] := Integer(IniRead("config.ini", "colors", "ore_text_variation", 40))
    cfg["ore_cluster_enabled"] := Integer(IniRead("config.ini", "colors", "ore_cluster_enabled", 1)) = 1
    cfg["ore_cluster_len_px"] := Integer(IniRead("config.ini", "colors", "ore_cluster_len_px", 6))
    cfg["ore_cluster_min_hits"] := Integer(IniRead("config.ini", "colors", "ore_cluster_min_hits", 2))
    cfg["ore_cluster_threshold"] := Integer(IniRead("config.ini", "colors", "ore_cluster_threshold", "0xE0E0E0"))
    cfg["asteroid_marker_color"] := Integer(IniRead("config.ini", "colors", "asteroid_marker_color", "0xF0F0F0"))
    cfg["color_variation"] := Integer(IniRead("config.ini", "colors", "color_variation", 28))
    cfg["laser_color_variation"] := Integer(IniRead("config.ini", "colors", "laser_color_variation", 12))
    cfg["asteroid_marker_variation"] := Integer(IniRead("config.ini", "colors", "asteroid_marker_variation", 35))
    cfg["image_variation"] := Integer(IniRead("config.ini", "colors", "image_variation", 35))

    cfg["lock_target_menu_x"] := Integer(IniRead("config.ini", "points", "lock_target_menu_x", 706))
    cfg["lock_target_menu_y"] := Integer(IniRead("config.ini", "points", "lock_target_menu_y", 522))
    cfg["ship_row_x"] := Integer(IniRead("config.ini", "points", "ship_row_x", 244))
    cfg["ship_row_y"] := Integer(IniRead("config.ini", "points", "ship_row_y", 540))
    cfg["portable_row_x"] := Integer(IniRead("config.ini", "points", "portable_row_x", 244))
    cfg["portable_row_y"] := Integer(IniRead("config.ini", "points", "portable_row_y", 586))
    cfg["inventory_window_x"] := Integer(IniRead("config.ini", "points", "inventory_window_x", 220))
    cfg["inventory_window_y"] := Integer(IniRead("config.ini", "points", "inventory_window_y", 520))

    secretsFile := "secrets.ini"
    if FileExist(secretsFile) {
        cfg["telegram_bot_token"] := IniRead(secretsFile, "telegram", "bot_token", "")
        cfg["telegram_chat_id"] := IniRead(secretsFile, "telegram", "chat_id", "")
    } else {
        cfg["telegram_bot_token"] := IniRead("config.ini", "telegram", "bot_token", "")
        cfg["telegram_chat_id"] := IniRead("config.ini", "telegram", "chat_id", "")
    }
    cfg["too_far_image"] := IniRead("config.ini", "images", "too_far_image", "")

    cfg["asteroid_points"] := ParsePoints(IniRead("config.ini", "lists", "asteroid_points", "670,430|760,400|880,340"))
    cfg["target_slots"] := ParsePoints(IniRead("config.ini", "lists", "target_slots", "1575,185|1675,185|1775,185"))
    cfg["laser_check_points"] := ParsePoints(IniRead("config.ini", "lists", "laser_check_points", "710,980|758,980|0,0"))
    cfg["active_laser_slots_raw"] := IniRead("config.ini", "lists", "active_laser_slots", "1|2")
    cfg["active_laser_slots"] := ParseIntList(cfg["active_laser_slots_raw"], 1, 9)
    cfg["ore_slots"] := ParsePoints(IniRead("config.ini", "lists", "ore_slots", "374,556|449,556|524,556|374,631|449,631|524,631"))

    if cfg["active_laser_slots"].Length = 0 {
        cfg["active_laser_slots"] := [1, 2]
        cfg["active_laser_slots_raw"] := "1|2"
    }
    if cfg["min_active_lasers_required"] < 1 {
        cfg["min_active_lasers_required"] := 1
    }
    validLaserSlots := GetConfiguredLaserSlots().Length
    if validLaserSlots > 0 && cfg["min_active_lasers_required"] > validLaserSlots {
        cfg["min_active_lasers_required"] := validLaserSlots
    }
}

ParsePoints(raw) {
    out := []
    parts := StrSplit(raw, "|")
    for _, p in parts {
        xy := StrSplit(p, ",")
        if xy.Length >= 2 {
            out.Push([Integer(xy[1]), Integer(xy[2])])
        }
    }
    return out
}

ParseIntList(raw, minValue, maxValue) {
    out := []
    parts := StrSplit(raw, "|")
    for _, item in parts {
        t := Trim(item)
        if RegExMatch(t, "^\d+$") {
            n := Integer(t)
            if n >= minValue && n <= maxValue {
                out.Push(n)
            }
        }
    }
    return out
}

