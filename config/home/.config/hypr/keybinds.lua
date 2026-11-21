-- Key bindings, loaded from hyprland.lua with require("keybinds").
--
-- They're in their own file for the Super+? cheat sheet (Noctalia's keybind-cheatsheet plugin). It
-- reads each key's description from Hyprland, and scans this file for the "-- 1. Name" headings
-- below, which become its sections. Noctalia stops plugins that run too long, and scanning the whole
-- hyprland.lua was too slow, so the plugin is pointed at this file in noctalia/config.toml.
-- Keep a description on every bind, and add new binds under one of the headings.

-- Programs the binds start
local terminal    = "ghostty"
local fileManager = "nautilus"
local browser     = "google-chrome-stable"
local codeEditor  = "code"
local textEditor  = "gnome-text-editor"
local aiAgent     = "t3code"

-- Noctalia (bar, launcher, notifications, lock screen, wallpaper) takes commands through this
local noctalia    = "noctalia msg "

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- See https://wiki.hypr.land/configuring/core/binds/

-- 1. Applications

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
-- Super+Enter as on Omarchy and most tiling setups
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), { description = "Terminal" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { description = "File manager" })
-- Super+Shift+B as on Omarchy
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(browser), { description = "Browser" })
-- C for code, N for notepad (Super+Shift+N is the editor on Omarchy too), A for AI
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(codeEditor), { description = "VS Code" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(textEditor), { description = "Text Editor" })
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(aiAgent), { description = "T3 Code" })

-- Noctalia's launcher and control center. Super+S is the scratchpad, as on Omarchy, so the control
-- center is on Super+`. Its settings open from the gear in the control center.
hl.bind(mainMod .. " + space",         hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"), { description = "App launcher" })
hl.bind(mainMod .. " + grave",         hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center"), { description = "Control center" })

-- Clipboard history, as on Windows and Omarchy
hl.bind(mainMod .. " + V",             hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard"), { description = "Clipboard history" })

-- Screenshot of a region you select, copied to the clipboard and saved to a file.
-- Super+Shift+S as on Windows and niri, for keyboards without a Print key.
hl.bind("Print",                       hl.dsp.exec_cmd(noctalia .. "screenshot-region"), { description = "Screenshot of a region" })
hl.bind(mainMod .. " + SHIFT + S",     hl.dsp.exec_cmd(noctalia .. "screenshot-region"), { description = "Screenshot of a region" })

-- This cheat sheet, on Super+? as on niri
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd(noctalia .. "panel-toggle kenn/keybind-cheatsheet:cheatsheet"), { description = "Keybind cheat sheet" })

-- 2. System

-- Lock as on Windows, GNOME and KDE. The session menu (lock, suspend, log out, reboot, shut down)
-- replaces Hyprland's Super+M, which quit at once without asking.
hl.bind(mainMod .. " + L",             hl.dsp.exec_cmd(noctalia .. "session lock"), { description = "Lock screen" })
hl.bind(mainMod .. " + Escape",        hl.dsp.exec_cmd(noctalia .. "panel-toggle session"), { description = "Session menu" })
-- The power button opens the same menu. systemd ignores it (config/etc/systemd/logind.conf.d).
hl.bind("XF86PowerOff",                hl.dsp.exec_cmd(noctalia .. "panel-toggle session"), { description = "Session menu" })

-- Super+Space is the launcher, so the keyboard layout switch (us/lt) is here, as on niri
hl.bind(mainMod .. " + SHIFT + space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { description = "Switch keyboard layout (US/LT)" })

-- Notifications on Comma, as on Omarchy. Super+Comma dismisses the ones on screen (Noctalia can't
-- dismiss just the latest), Super+Shift+Comma also clears the history, and Super+Alt+Comma does what
-- clicking the latest one does (opens the chat, the downloaded file, ...). The bell in the bar shows them.
hl.bind(mainMod .. " + comma",         hl.dsp.exec_cmd(noctalia .. "notification-clear-active"), { description = "Dismiss notifications on screen" })
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.exec_cmd(noctalia .. "notification-clear-active; " .. noctalia .. "notification-clear-history"), { description = "Clear all notifications" })
hl.bind(mainMod .. " + ALT + comma",   hl.dsp.exec_cmd(noctalia .. "notification-invoke-latest"), { description = "Open latest notification" })

-- 3. Window management

local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close window" })
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Maximize window" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Fullscreen" })
-- Super+V is clipboard history, so floating is on Super+Shift+V
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Pseudo-tile window" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle split direction" })    -- dwindle only

-- Swap the active window with its neighbour, as on Omarchy
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }), { description = "Swap window left" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }), { description = "Swap window right" })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }), { description = "Swap window up" })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }), { description = "Swap window down" })

-- Switches the current workspace between dwindle and the niri-like scrolling layout, as Super+L
-- does on Omarchy. Other workspaces keep theirs. Back to dwindle on login or config reload.
hl.bind(mainMod .. " + CTRL + L", function()
    local ws = hl.get_active_workspace()
    if not ws or not ws.id then return end
    local layout = ws.tiled_layout == "scrolling" and "dwindle" or "scrolling"
    hl.workspace_rule({ workspace = tostring(ws.id), layout = layout })
    hl.exec_cmd(noctalia .. "notification-show 'Workspace " .. ws.id .. " layout: " .. layout .. "'")
end, { description = "Toggle workspace layout (dwindle/scrolling)" })

-- Resize the active window by 100px, as on Omarchy: Minus/Equal for width, with Shift for height.
-- Held down, they keep resizing. In dwindle the width keys move the window's border left or right;
-- in the scrolling layout they make the column 10% of the screen narrower or wider, as on niri.
local function resizeWidth(px, fraction)
    return function()
        local ws = hl.get_active_workspace()
        if ws and ws.tiled_layout == "scrolling" then
            hl.dispatch(hl.dsp.layout("colresize " .. fraction))
        else
            hl.dispatch(hl.dsp.window.resize({ x = px, y = 0, relative = true }))
        end
    end
end
hl.bind(mainMod .. " + minus",         resizeWidth(-100, "-0.1"), { description = "Resize: border left (scrolling: narrower)", repeating = true })
hl.bind(mainMod .. " + equal",         resizeWidth(100, "+0.1"),  { description = "Resize: border right (scrolling: wider)", repeating = true })
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { description = "Resize: border up", repeating = true })
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100,  relative = true }), { description = "Resize: border down", repeating = true })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { description = "Move window (drag)", mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { description = "Resize window (drag)", mouse = true })

-- 4. Focus

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }), { description = "Focus down" })

hl.bind("ALT + Tab",                   hl.dsp.exec_cmd(noctalia .. "window-switcher hold"), { description = "Window switcher" })
hl.bind("ALT + SHIFT + Tab",           hl.dsp.exec_cmd(noctalia .. "window-switcher hold reverse"), { description = "Window switcher, backwards" })

-- 5. Workspaces

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
-- Two loops, so the cheat sheet shows each as one row (Super + 1-0)
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}), { description = "Workspace " .. i })
end
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }), { description = "Move window to workspace " .. i })
end

-- Next or previous workspace on this monitor (m+1/m-1), as on niri and GNOME. With Shift, the active
-- window moves there. Super + mouse wheel does the same.
hl.bind(mainMod .. " + Page_Down",         hl.dsp.focus({ workspace = "m+1" }), { description = "Next workspace on this monitor" })
hl.bind(mainMod .. " + Page_Up",           hl.dsp.focus({ workspace = "m-1" }), { description = "Previous workspace on this monitor" })
hl.bind(mainMod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "m+1" }), { description = "Move window to next workspace on this monitor" })
hl.bind(mainMod .. " + SHIFT + Page_Up",   hl.dsp.window.move({ workspace = "m-1" }), { description = "Move window to previous workspace on this monitor" })
hl.bind(mainMod .. " + mouse_down",        hl.dsp.focus({ workspace = "m+1" }), { description = "Next workspace on this monitor" })
hl.bind(mainMod .. " + mouse_up",          hl.dsp.focus({ workspace = "m-1" }), { description = "Previous workspace on this monitor" })

-- Scratchpad: a workspace shown over the current one. Super+S shows or hides it, as on Omarchy.
-- Super+Alt+S moves the active window into it (Super+Shift+S is the screenshot).
hl.bind(mainMod .. " + S",             hl.dsp.workspace.toggle_special("scratchpad"), { description = "Toggle scratchpad" })
hl.bind(mainMod .. " + ALT + S",       hl.dsp.window.move({ workspace = "special:scratchpad" }), { description = "Move window to scratchpad" })

-- 6. Media and brightness

-- Volume, brightness and media keys through Noctalia, so its on-screen popups show.
-- locked = true keeps them working on the lock screen.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(noctalia .. "volume-up"),       { description = "Volume up", locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(noctalia .. "volume-down"),     { description = "Volume down", locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(noctalia .. "volume-mute"),     { description = "Mute", locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(noctalia .. "mic-mute"),        { description = "Mute microphone", locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(noctalia .. "brightness-up"),   { description = "Brightness up", locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctalia .. "brightness-down"), { description = "Brightness down", locked = true, repeating = true })
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(noctalia .. "media toggle"),    { description = "Play/pause", locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd(noctalia .. "media toggle"),    { description = "Play/pause", locked = true })
hl.bind("XF86AudioStop",         hl.dsp.exec_cmd(noctalia .. "media stop"),      { description = "Stop", locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd(noctalia .. "media previous"),  { description = "Previous track", locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd(noctalia .. "media next"),      { description = "Next track", locked = true })
