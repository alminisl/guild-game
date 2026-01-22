-- Settings Menu Module
-- UI for game settings: Video, Audio, Save/Load, Exit

local Components = require("ui.components")
local SaveSystem = require("systems.save_system")

local SettingsMenu = {}

-- Menu dimensions (centered for 1920x1080)
local MENU = {
    x = 560,
    y = 180,
    width = 800,
    height = 720
}

-- Available resolutions
local RESOLUTIONS = {
    {width = 1280, height = 720, label = "1280 x 720 (HD)"},
    {width = 1366, height = 768, label = "1366 x 768"},
    {width = 1600, height = 900, label = "1600 x 900"},
    {width = 1920, height = 1080, label = "1920 x 1080 (Full HD)"},
    {width = 2560, height = 1440, label = "2560 x 1440 (2K)"}
}

-- Tabs
local TABS = {"VIDEO", "AUDIO", "SAVE/LOAD", "EXIT"}
local currentTab = "VIDEO"

-- State
local selectedResolution = 1
local masterVolume = 1.0
local musicVolume = 0.7
local sfxVolume = 1.0
local fullscreen = false
local editModeEnabled = false

-- Save/Load state
local saveInfoCache = nil
local selectedSlot = nil
local saveMode = "save"  -- "save" or "load"

-- Initialize settings from current window
function SettingsMenu.init()
    local w, h, flags = love.window.getMode()
    fullscreen = flags.fullscreen or false

    -- Find matching resolution
    for i, res in ipairs(RESOLUTIONS) do
        if res.width == w and res.height == h then
            selectedResolution = i
            break
        end
    end
end

-- Reset menu state
function SettingsMenu.resetState()
    currentTab = "VIDEO"
    selectedSlot = nil
    saveMode = "save"
end

-- Refresh save info
local function refreshSaveInfo()
    saveInfoCache = SaveSystem.getAllSaveInfo()
end

-- Apply resolution change
local function applyResolution(index)
    local res = RESOLUTIONS[index]
    if res then
        love.window.setMode(res.width, res.height, {
            resizable = true,
            minwidth = 800,
            minheight = 600,
            fullscreen = fullscreen
        })
        selectedResolution = index
    end
end

-- Toggle fullscreen
local function toggleFullscreen()
    fullscreen = not fullscreen
    local res = RESOLUTIONS[selectedResolution]
    love.window.setMode(res.width, res.height, {
        resizable = true,
        minwidth = 800,
        minheight = 600,
        fullscreen = fullscreen
    })
end

-- Draw the settings menu
function SettingsMenu.draw(gameData)
    -- Semi-transparent overlay (full screen)
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Background panel
    Components.drawPanel(MENU.x, MENU.y, MENU.width, MENU.height)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("SETTINGS", MENU.x, MENU.y + 15, MENU.width, "center")

    -- Close button
    Components.drawCloseButton(MENU.x + MENU.width - 40, MENU.y + 10)

    -- Tabs
    local tabY = MENU.y + 55
    local tabW = 120
    local tabSpacing = 10
    local totalTabW = (#TABS * tabW) + ((#TABS - 1) * tabSpacing)
    local tabStartX = MENU.x + (MENU.width - totalTabW) / 2

    for i, tab in ipairs(TABS) do
        local tabX = tabStartX + (i - 1) * (tabW + tabSpacing)
        local isActive = currentTab == tab
        local color = isActive and {0.3, 0.5, 0.7} or Components.colors.button

        Components.drawButton(tab, tabX, tabY, tabW, 35, {
            active = isActive,
            color = color
        })
    end

    -- Content area
    local contentY = tabY + 55
    local contentH = MENU.height - 140

    if currentTab == "VIDEO" then
        drawVideoSettings(contentY, contentH)
    elseif currentTab == "AUDIO" then
        drawAudioSettings(contentY, contentH)
    elseif currentTab == "SAVE/LOAD" then
        drawSaveLoadSettings(contentY, contentH, gameData)
    elseif currentTab == "EXIT" then
        drawExitSettings(contentY, contentH)
    end
end

-- Draw VIDEO settings
function drawVideoSettings(y, height)
    local centerX = MENU.x + MENU.width / 2

    -- Resolution label
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("Resolution", MENU.x + 40, y, MENU.width - 80, "left")

    -- Resolution options
    local resY = y + 30
    for i, res in ipairs(RESOLUTIONS) do
        local isSelected = selectedResolution == i
        local btnColor = isSelected and {0.3, 0.6, 0.4} or Components.colors.button

        Components.drawButton(res.label, MENU.x + 80, resY, 440, 35, {
            color = btnColor,
            active = isSelected
        })
        resY = resY + 45
    end

    -- Fullscreen toggle
    resY = resY + 20
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Fullscreen:", MENU.x + 80, resY + 8)

    local fsText = fullscreen and "ON" or "OFF"
    local fsColor = fullscreen and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
    Components.drawButton(fsText, MENU.x + 200, resY, 100, 35, {color = fsColor})

    -- Edit Mode toggle
    resY = resY + 50
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Edit Mode:", MENU.x + 80, resY + 8)
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("(Press F2 in town)", MENU.x + 80, resY + 25, MENU.width - 160, "left")

    local emText = editModeEnabled and "ON" or "OFF"
    local emColor = editModeEnabled and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
    Components.drawButton(emText, MENU.x + 200, resY, 100, 35, {color = emColor})
end

-- Draw AUDIO settings
function drawAudioSettings(y, height)
    love.graphics.setColor(Components.colors.text)

    -- Master Volume
    love.graphics.print("Master Volume", MENU.x + 80, y)
    drawVolumeSlider(MENU.x + 80, y + 30, masterVolume, "master")

    -- Music Volume
    love.graphics.print("Music Volume", MENU.x + 80, y + 90)
    drawVolumeSlider(MENU.x + 80, y + 120, musicVolume, "music")

    -- SFX Volume
    love.graphics.print("SFX Volume", MENU.x + 80, y + 180)
    drawVolumeSlider(MENU.x + 80, y + 210, sfxVolume, "sfx")

    -- Note
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Audio system not yet implemented", MENU.x, y + 280, MENU.width, "center")
end

-- Draw volume slider
function drawVolumeSlider(x, y, value, id)
    local sliderW = 400
    local sliderH = 20

    -- Background
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", x, y, sliderW, sliderH, 5, 5)

    -- Filled portion
    love.graphics.setColor(0.3, 0.5, 0.7)
    love.graphics.rectangle("fill", x, y, sliderW * value, sliderH, 5, 5)

    -- Border
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", x, y, sliderW, sliderH, 5, 5)

    -- Value text
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(math.floor(value * 100) .. "%", x + sliderW + 15, y)
end

-- Draw SAVE/LOAD settings
function drawSaveLoadSettings(y, height, gameData)
    -- Mode tabs
    local tabW = 100
    local tabX = MENU.x + (MENU.width - tabW * 2 - 20) / 2

    Components.drawButton("Save", tabX, y, tabW, 30, {
        active = saveMode == "save",
        color = saveMode == "save" and {0.3, 0.5, 0.4} or Components.colors.button
    })
    Components.drawButton("Load", tabX + tabW + 20, y, tabW, 30, {
        active = saveMode == "load",
        color = saveMode == "load" and {0.4, 0.5, 0.3} or Components.colors.button
    })

    -- Refresh save info if needed
    if not saveInfoCache then
        refreshSaveInfo()
    end

    -- Save slots
    local slotY = y + 50
    local slotH = 60
    local slotW = MENU.width - 80

    for slot = 1, SaveSystem.SAVE_SLOTS do
        local info = saveInfoCache and saveInfoCache[slot]
        local isSelected = selectedSlot == slot

        local bgColor = isSelected and {0.3, 0.4, 0.5} or Components.colors.panelLight
        Components.drawPanel(MENU.x + 40, slotY, slotW, slotH, {
            color = bgColor,
            cornerRadius = 5,
            border = isSelected
        })

        love.graphics.setColor(Components.colors.text)
        love.graphics.print("Slot " .. slot, MENU.x + 55, slotY + 8)

        if info and info.exists and not info.corrupted then
            love.graphics.print("Day " .. info.day .. " | Gold: " .. info.gold .. " | Heroes: " .. info.heroCount, MENU.x + 130, slotY + 8)
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(SaveSystem.formatTimestamp(info.timestamp), MENU.x + 55, slotY + 32)
        else
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(info and info.corrupted and "CORRUPTED" or "Empty", MENU.x + 130, slotY + 8)
        end

        slotY = slotY + slotH + 10
    end

    -- Action button
    if selectedSlot then
        local info = saveInfoCache and saveInfoCache[selectedSlot]
        local btnY = y + height - 50
        local btnW = 150
        local btnX = MENU.x + (MENU.width - btnW) / 2

        if saveMode == "save" then
            local txt = (info and info.exists) and "Overwrite" or "Save"
            Components.drawButton(txt, btnX, btnY, btnW, 40, {color = {0.3, 0.5, 0.3}})
        else
            local canLoad = info and info.exists and not info.corrupted
            Components.drawButton("Load", btnX, btnY, btnW, 40, {
                disabled = not canLoad,
                color = canLoad and {0.3, 0.5, 0.6} or Components.colors.buttonDisabled
            })
        end
    end
end

-- Draw EXIT settings
function drawExitSettings(y, height)
    local centerX = MENU.x + MENU.width / 2
    local centerY = y + height / 2 - 60

    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("Are you sure you want to exit?", MENU.x, centerY, MENU.width, "center")

    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Make sure to save your game first!", MENU.x, centerY + 30, MENU.width, "center")

    -- Exit button
    Components.drawButton("Exit Game", centerX - 100, centerY + 80, 200, 50, {
        color = {0.6, 0.2, 0.2}
    })

    -- Cancel button
    Components.drawButton("Cancel", centerX - 75, centerY + 145, 150, 40, {
        color = Components.colors.button
    })
end

-- Handle click
function SettingsMenu.handleClick(x, y, gameData, Heroes, Quests, GuildSystem, TimeSystem)
    -- Close button
    if Components.isPointInRect(x, y, MENU.x + MENU.width - 40, MENU.y + 10, 30, 30) then
        SettingsMenu.resetState()
        return "close"
    end

    -- Tabs
    local tabY = MENU.y + 55
    local tabW = 120
    local tabSpacing = 10
    local totalTabW = (#TABS * tabW) + ((#TABS - 1) * tabSpacing)
    local tabStartX = MENU.x + (MENU.width - totalTabW) / 2

    for i, tab in ipairs(TABS) do
        local tabX = tabStartX + (i - 1) * (tabW + tabSpacing)
        if Components.isPointInRect(x, y, tabX, tabY, tabW, 35) then
            currentTab = tab
            selectedSlot = nil
            if tab == "SAVE/LOAD" then
                refreshSaveInfo()
            end
            return nil
        end
    end

    local contentY = tabY + 55
    local contentH = MENU.height - 140

    -- Handle tab-specific clicks
    if currentTab == "VIDEO" then
        return handleVideoClick(x, y, contentY)
    elseif currentTab == "AUDIO" then
        return handleAudioClick(x, y, contentY)
    elseif currentTab == "SAVE/LOAD" then
        return handleSaveLoadClick(x, y, contentY, contentH, gameData, Heroes, Quests, GuildSystem, TimeSystem)
    elseif currentTab == "EXIT" then
        return handleExitClick(x, y, contentY, contentH)
    end

    return nil
end

-- Handle VIDEO tab clicks
function handleVideoClick(x, y, contentY)
    local resY = contentY + 30

    -- Resolution buttons
    for i, res in ipairs(RESOLUTIONS) do
        if Components.isPointInRect(x, y, MENU.x + 80, resY, 440, 35) then
            applyResolution(i)
            return "resolution_changed", res.label
        end
        resY = resY + 45
    end

    -- Fullscreen toggle
    resY = resY + 20
    if Components.isPointInRect(x, y, MENU.x + 200, resY, 100, 35) then
        toggleFullscreen()
        return "fullscreen_toggled"
    end

    -- Edit Mode toggle
    resY = resY + 50
    if Components.isPointInRect(x, y, MENU.x + 200, resY, 100, 35) then
        editModeEnabled = not editModeEnabled
        return "edit_mode_toggled", editModeEnabled
    end

    return nil
end

-- Handle AUDIO tab clicks
function handleAudioClick(x, y, contentY)
    local sliderX = MENU.x + 80
    local sliderW = 400

    -- Master volume slider
    if Components.isPointInRect(x, y, sliderX, contentY + 30, sliderW, 20) then
        masterVolume = math.max(0, math.min(1, (x - sliderX) / sliderW))
        return nil
    end

    -- Music volume slider
    if Components.isPointInRect(x, y, sliderX, contentY + 120, sliderW, 20) then
        musicVolume = math.max(0, math.min(1, (x - sliderX) / sliderW))
        return nil
    end

    -- SFX volume slider
    if Components.isPointInRect(x, y, sliderX, contentY + 210, sliderW, 20) then
        sfxVolume = math.max(0, math.min(1, (x - sliderX) / sliderW))
        return nil
    end

    return nil
end

-- Handle SAVE/LOAD tab clicks
function handleSaveLoadClick(x, y, contentY, contentH, gameData, Heroes, Quests, GuildSystem, TimeSystem)
    -- Mode tabs
    local tabW = 100
    local tabX = MENU.x + (MENU.width - tabW * 2 - 20) / 2

    if Components.isPointInRect(x, y, tabX, contentY, tabW, 30) then
        saveMode = "save"
        selectedSlot = nil
        return nil
    end
    if Components.isPointInRect(x, y, tabX + tabW + 20, contentY, tabW, 30) then
        saveMode = "load"
        selectedSlot = nil
        return nil
    end

    -- Save slots
    local slotY = contentY + 50
    local slotH = 60
    local slotW = MENU.width - 80

    for slot = 1, SaveSystem.SAVE_SLOTS do
        if Components.isPointInRect(x, y, MENU.x + 40, slotY, slotW, slotH) then
            selectedSlot = slot
            return nil
        end
        slotY = slotY + slotH + 10
    end

    -- Action button
    if selectedSlot then
        local info = saveInfoCache and saveInfoCache[selectedSlot]
        local btnY = contentY + contentH - 50
        local btnW = 150
        local btnX = MENU.x + (MENU.width - btnW) / 2

        if Components.isPointInRect(x, y, btnX, btnY, btnW, 40) then
            if saveMode == "save" then
                local success, msg = SaveSystem.save(gameData, selectedSlot)
                refreshSaveInfo()
                return success and "saved" or "error", msg or "Save failed"
            else
                if info and info.exists and not info.corrupted then
                    local loadedData, err = SaveSystem.load(selectedSlot)
                    if loadedData then
                        SaveSystem.applyLoadedData(gameData, loadedData, Heroes, Quests, GuildSystem, TimeSystem)
                        return "loaded", "Game loaded from slot " .. selectedSlot
                    else
                        return "error", err
                    end
                end
            end
        end
    end

    return nil
end

-- Handle EXIT tab clicks
function handleExitClick(x, y, contentY, contentH)
    local centerX = MENU.x + MENU.width / 2
    local centerY = contentY + contentH / 2 - 60

    -- Exit button
    if Components.isPointInRect(x, y, centerX - 100, centerY + 80, 200, 50) then
        love.event.quit()
        return "exit"
    end

    -- Cancel button
    if Components.isPointInRect(x, y, centerX - 75, centerY + 145, 150, 40) then
        currentTab = "VIDEO"
        return nil
    end

    return nil
end

-- Check if settings button is clicked (gear in top-left)
function SettingsMenu.isSettingsButtonClicked(x, y)
    return Components.isPointInRect(x, y, 10, 8, 34, 34)
end

-- Draw settings button (gear icon)
function SettingsMenu.drawSettingsButton()
    -- Button background
    love.graphics.setColor(0.25, 0.25, 0.3, 0.9)
    love.graphics.rectangle("fill", 10, 8, 34, 34, 5, 5)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", 10, 8, 34, 34, 5, 5)

    -- Gear icon (simple representation)
    love.graphics.setColor(0.8, 0.8, 0.8)
    local cx, cy = 27, 25
    local outerR = 10
    local innerR = 4

    -- Outer gear shape (using circle + rectangles for teeth)
    love.graphics.circle("fill", cx, cy, innerR + 3)

    -- Gear teeth
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        local tx = cx + math.cos(angle) * (innerR + 5)
        local ty = cy + math.sin(angle) * (innerR + 5)
        love.graphics.rectangle("fill", tx - 3, ty - 3, 6, 6)
    end

    -- Inner hole
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.circle("fill", cx, cy, innerR)
end

-- Get Edit Mode enabled state
function SettingsMenu.isEditModeEnabled()
    return editModeEnabled
end

return SettingsMenu
