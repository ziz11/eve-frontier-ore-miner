#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetWorkingDir A_ScriptDir

global cfg := Map()
global running := false
global state := "LOCK"
global lastUnloadTick := 0
global laserLostTick := 0
global lastLaserRetryTick := 0
global lastHeartbeatTick := 0
global lastError := ""

global STATE_LOCK := "LOCK"
global STATE_SELECT := "SELECT"
global STATE_LASER := "LASER"

LoadConfig()

F8::ToggleBot()
F10::Reload
Esc::ExitApp

ToggleBot() {
    global running, state, lastUnloadTick, laserLostTick, lastLaserRetryTick, lastHeartbeatTick, lastError
    running := !running
    if running {
        state := STATE_LOCK
        lastUnloadTick := A_TickCount
        laserLostTick := 0
        lastLaserRetryTick := 0
        lastHeartbeatTick := 0
        lastError := ""
        SendTelegram("STARTED")
        SetTimer MainLoop, cfg["main_loop_ms"]
        TrayTip "Miner", "Started", 800
    } else {
        SetTimer MainLoop, 0
        SendTelegram("STOPPED")
        TrayTip "Miner", "Stopped", 800
    }
}

MainLoop() {
    global running, state, lastUnloadTick, lastHeartbeatTick
    if !running {
        return
    }

    if !IsEveActive() {
        return
    }

    now := A_TickCount

    if now - lastHeartbeatTick >= cfg["heartbeat_ms"] {
        SendTelegram("HEARTBEAT: state=" state)
        lastHeartbeatTick := now
    }

    if now - lastUnloadTick >= cfg["unload_interval_ms"] {
        DoUnload()
        lastUnloadTick := now
    }

    if state = STATE_LOCK {
        if DoLockStage() {
            state := STATE_SELECT
        }
        return
    }

    if state = STATE_SELECT {
        if SelectTopRightTarget() {
            state := STATE_LASER
        } else if !HasAnyTopRightTarget() {
            state := STATE_LOCK
        }
        return
    }

    if state = STATE_LASER {
        DoLaserStage()
        return
    }
}

DoLockStage() {
    startTick := A_TickCount
    timeout := cfg["lock_timeout_ms"]
    loop {
        if HasAnyTopRightTarget() {
            return true
        }

        for p in cfg["asteroid_points"] {
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

SelectTopRightTarget() {
    ; Order slots by preferred nearest-first click order from config.
    for p in cfg["target_slots"] {
        LeftClick p[1], p[2]
        Sleep cfg["ui_delay_ms"]
        if HasActiveTargetOrange() {
            return true
        }
    }
    return false
}

DoLaserStage() {
    global state, laserLostTick, lastLaserRetryTick

    if !HasAnyTopRightTarget() {
        state := STATE_LOCK
        return
    }

    if !HasActiveTargetOrange() {
        state := STATE_SELECT
        return
    }

    activeCount := CountActiveLasers()
    if activeCount > 0 {
        laserLostTick := 0
        return
    }

    if DetectTooFarBanner() {
        state := STATE_SELECT
        return
    }

    if laserLostTick = 0 {
        laserLostTick := A_TickCount
    }

    if (A_TickCount - lastLaserRetryTick) >= cfg["laser_retry_delay_ms"] {
        Send "1"
        Sleep 70
        Send "2"
        lastLaserRetryTick := A_TickCount
    }

    if (A_TickCount - laserLostTick) >= cfg["laser_fail_deadline_ms"] {
        Fail("No active lasers for deadline")
        state := STATE_SELECT
    }
}

DoUnload() {
    ; Keep this simple: click ship row, then drag each ore slot onto Portable row.
    LeftClick cfg["ship_row_x"], cfg["ship_row_y"]
    Sleep cfg["ui_delay_ms"]

    for p in cfg["ore_slots"] {
        DragMouse p[1], p[2], cfg["portable_row_x"], cfg["portable_row_y"]
        Sleep cfg["ui_delay_ms"]
    }
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
        cfg["target_active_orange_color"], cfg["color_variation"]
    )
}

CountActiveLasers() {
    count := 0
    for p in cfg["laser_check_points"] {
        if PixelNear(p[1], p[2], cfg["laser_active_orange_color"], cfg["color_variation"]) {
            count += 1
        }
    }
    return count
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

IsEveActive() {
    return WinActive(cfg["eve_window_title"])
}

PixelInRect(x1, y1, x2, y2, color, variation) {
    try {
        PixelSearch &fx, &fy, x1, y1, x2, y2, color, variation, "RGB Fast"
        return true
    } catch {
        return false
    }
}

PixelNear(x, y, color, variation) {
    x1 := x - 4
    y1 := y - 4
    x2 := x + 4
    y2 := y + 4
    return PixelInRect(x1, y1, x2, y2, color, variation)
}

LeftClick(x, y) {
    MouseMove x, y, 0
    Click "Left"
}

RightClick(x, y) {
    MouseMove x, y, 0
    Click "Right"
}

DragMouse(x1, y1, x2, y2) {
    MouseMove x1, y1, 0
    MouseClickDrag "Left", x1, y1, x2, y2, 12
}

SendTelegram(text) {
    token := cfg["telegram_bot_token"]
    chatId := cfg["telegram_chat_id"]
    if token = "" || chatId = "" {
        return
    }

    text := StrReplace(text, " ", "%20")
    text := StrReplace(text, "`n", "%0A")
    url := "https://api.telegram.org/bot" token "/sendMessage?chat_id=" chatId "&text=[EVE]%20" text
    cmd := "curl -sS --max-time 4 \"" url "\" >NUL 2>&1"
    RunWait A_ComSpec " /c " cmd,, "Hide"
}

LoadConfig() {
    global cfg
    cfg["eve_window_title"] := IniRead("config.ini", "general", "eve_window_title", "EVE Frontier")
    cfg["main_loop_ms"] := Integer(IniRead("config.ini", "general", "main_loop_ms", 2000))
    cfg["ui_delay_ms"] := Integer(IniRead("config.ini", "general", "ui_delay_ms", 250))

    cfg["heartbeat_ms"] := Integer(IniRead("config.ini", "timers", "heartbeat_ms", 600000))
    cfg["lock_timeout_ms"] := Integer(IniRead("config.ini", "timers", "lock_timeout_ms", 30000))
    cfg["lock_retry_pause_ms"] := Integer(IniRead("config.ini", "timers", "lock_retry_pause_ms", 500))
    cfg["laser_retry_delay_ms"] := Integer(IniRead("config.ini", "timers", "laser_retry_delay_ms", 5000))
    cfg["laser_fail_deadline_ms"] := Integer(IniRead("config.ini", "timers", "laser_fail_deadline_ms", 20000))
    cfg["unload_interval_ms"] := Integer(IniRead("config.ini", "timers", "unload_interval_ms", 90000))

    cfg["target_region_x1"] := Integer(IniRead("config.ini", "regions", "target_region_x1", 1360))
    cfg["target_region_y1"] := Integer(IniRead("config.ini", "regions", "target_region_y1", 180))
    cfg["target_region_x2"] := Integer(IniRead("config.ini", "regions", "target_region_x2", 1880))
    cfg["target_region_y2"] := Integer(IniRead("config.ini", "regions", "target_region_y2", 470))

    cfg["too_far_region_x1"] := Integer(IniRead("config.ini", "regions", "too_far_region_x1", 480))
    cfg["too_far_region_y1"] := Integer(IniRead("config.ini", "regions", "too_far_region_y1", 70))
    cfg["too_far_region_x2"] := Integer(IniRead("config.ini", "regions", "too_far_region_x2", 1450))
    cfg["too_far_region_y2"] := Integer(IniRead("config.ini", "regions", "too_far_region_y2", 300))

    cfg["target_present_color"] := IniRead("config.ini", "colors", "target_present_color", "0x4A4D51")
    cfg["target_active_orange_color"] := IniRead("config.ini", "colors", "target_active_orange_color", "0xFF5B1A")
    cfg["laser_active_orange_color"] := IniRead("config.ini", "colors", "laser_active_orange_color", "0xFFB600")
    cfg["color_variation"] := Integer(IniRead("config.ini", "colors", "color_variation", 28))
    cfg["image_variation"] := Integer(IniRead("config.ini", "colors", "image_variation", 35))

    cfg["lock_target_menu_x"] := Integer(IniRead("config.ini", "points", "lock_target_menu_x", 706))
    cfg["lock_target_menu_y"] := Integer(IniRead("config.ini", "points", "lock_target_menu_y", 522))
    cfg["ship_row_x"] := Integer(IniRead("config.ini", "points", "ship_row_x", 250))
    cfg["ship_row_y"] := Integer(IniRead("config.ini", "points", "ship_row_y", 145))
    cfg["portable_row_x"] := Integer(IniRead("config.ini", "points", "portable_row_x", 245))
    cfg["portable_row_y"] := Integer(IniRead("config.ini", "points", "portable_row_y", 228))

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
    cfg["target_slots"] := ParsePoints(IniRead("config.ini", "lists", "target_slots", "1535,300|1660,300|1780,300"))
    cfg["laser_check_points"] := ParsePoints(IniRead("config.ini", "lists", "1056,1530|1132,1530"))
    cfg["ore_slots"] := ParsePoints(IniRead("config.ini", "lists", "500,980|620,980|500,1110|620,1110|500,1240|620,1240"))
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
