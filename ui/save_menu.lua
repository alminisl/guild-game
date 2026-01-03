-- Save Menu Module
-- UI for saving and loading game state

local Components = require("ui.components")
local SaveSystem = require("systems.save_system")

local SaveMenu = {}

-- Menu dimensions
local MENU = {
    x = 290,
    y = 110,
    width = 700,
    height = 500
}

-- State
local selectedSlot = nil
local saveInfoCache = nil
local lastRefresh = 0
local REFRESH_INTERVAL = 1  -- Refresh save info every second when menu is open

-- Mode: "save" or "load"
local currentMode = "save"

-- Reset menu state
function SaveMenu.resetState()
    selectedSlot = nil
    saveInfoCache = nil
    currentMode = "save"
end

-- Set mode
function SaveMenu.setMode(mode)
    currentMode = mode or "save"
    selectedSlot = nil
end

-- Refresh save info
local function refreshSaveInfo()
    saveInfoCache = SaveSystem.getAllSaveInfo()
    lastRefresh = love.timer.getTime()
end

-- Draw the save menu
function SaveMenu.draw(gameData)
    -- Refresh cache if needed
    local now = love.timer.getTime()
    if not saveInfoCache or (now - lastRefresh) > REFRESH_INTERVAL then
        refreshSaveInfo()
    end

    -- Background panel
    Components.drawPanel(MENU.x, MENU.y, MENU.width, MENU.height)

    -- Title
    love.graphics.setColor(Components.colors.text)
    local titleText = currentMode == "save" and "SAVE GAME" or "LOAD GAME"
    love.graphics.printf(titleText, MENU.x, MENU.y + 15, MENU.width, "center")

    -- Close button
    Components.drawCloseButton(MENU.x + MENU.width - 40, MENU.y + 10)

    -- Mode tabs
    local tabY = MENU.y + 50
    local tabW = 100
    Components.drawButton("Save", MENU.x + MENU.width/2 - tabW - 10, tabY, tabW, 30, {
        active = currentMode == "save"
    })
    Components.drawButton("Load", MENU.x + MENU.width/2 + 10, tabY, tabW, 30, {
        active = currentMode == "load"
    })

    -- Save slots
    local slotY = tabY + 50
    local slotHeight = 100
    local slotWidth = MENU.width - 40

    for slot = 1, SaveSystem.SAVE_SLOTS do
        local info = saveInfoCache and saveInfoCache[slot]
        local isSelected = selectedSlot == slot

        -- Slot background
        local bgColor = isSelected and {0.3, 0.4, 0.5} or Components.colors.panelLight
        Components.drawPanel(MENU.x + 20, slotY, slotWidth, slotHeight, {
            color = bgColor,
            cornerRadius = 5,
            border = isSelected,
            borderColor = {0.5, 0.7, 0.9}
        })

        -- Slot number
        love.graphics.setColor(Components.colors.text)
        love.graphics.print("Slot " .. slot, MENU.x + 35, slotY + 10)

        if info and info.exists and not info.corrupted then
            -- Save exists - show details
            love.graphics.setColor(Components.colors.text)
            love.graphics.print("Day " .. info.day, MENU.x + 120, slotY + 10)

            love.graphics.setColor(Components.colors.gold)
            love.graphics.print("Gold: " .. info.gold, MENU.x + 35, slotY + 35)

            love.graphics.setColor(Components.colors.text)
            love.graphics.print("Heroes: " .. info.heroCount, MENU.x + 150, slotY + 35)

            love.graphics.setColor({0.4, 0.6, 0.8})
            love.graphics.print("Guild Lv." .. info.guildLevel, MENU.x + 280, slotY + 35)

            -- Timestamp
            love.graphics.setColor(Components.colors.textDim)
            local timestamp = SaveSystem.formatTimestamp(info.timestamp)
            love.graphics.print("Saved: " .. timestamp, MENU.x + 35, slotY + 60)

            -- Play time
            local playTime = SaveSystem.formatPlayTime(info.totalTime)
            love.graphics.print("Play time: " .. playTime, MENU.x + 280, slotY + 60)

            -- Action buttons (on right side)
            local btnX = MENU.x + slotWidth - 100
            if currentMode == "save" then
                -- Overwrite warning
                love.graphics.setColor(Components.colors.warning)
                love.graphics.print("Overwrite?", btnX - 80, slotY + 40)
            end

        elseif info and info.corrupted then
            -- Corrupted save
            love.graphics.setColor(Components.colors.danger)
            love.graphics.print("CORRUPTED", MENU.x + 120, slotY + 10)
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("This save file cannot be loaded.", MENU.x + 35, slotY + 40)

        else
            -- Empty slot
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Empty", MENU.x + 120, slotY + 10)

            if currentMode == "save" then
                love.graphics.print("Click to save here", MENU.x + 35, slotY + 40)
            else
                love.graphics.print("No save data", MENU.x + 35, slotY + 40)
            end
        end

        slotY = slotY + slotHeight + 10
    end

    -- Action button at bottom
    if selectedSlot then
        local btnY = MENU.y + MENU.height - 60
        local btnW = 200
        local btnX = MENU.x + (MENU.width - btnW) / 2

        local info = saveInfoCache and saveInfoCache[selectedSlot]
        local canAction = false

        if currentMode == "save" then
            canAction = true
            local btnText = (info and info.exists) and "Overwrite Save" or "Save Game"
            local btnColor = (info and info.exists) and Components.colors.warning or Components.colors.success
            Components.drawButton(btnText, btnX, btnY, btnW, 40, {color = btnColor})
        else
            canAction = info and info.exists and not info.corrupted
            Components.drawButton("Load Game", btnX, btnY, btnW, 40, {
                disabled = not canAction,
                color = canAction and Components.colors.success or Components.colors.buttonDisabled
            })
        end

        -- Delete button (if save exists)
        if info and info.exists then
            Components.drawButton("Delete", MENU.x + MENU.width - 100, btnY, 80, 40, {
                color = Components.colors.danger
            })
        end
    end

    -- Hint text
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("F5: Quick Save to Slot 1  |  F9: Quick Load from Slot 1  |  ESC: Close",
        MENU.x, MENU.y + MENU.height - 20, MENU.width, "center")
end

-- Handle click
function SaveMenu.handleClick(x, y, gameData, Heroes, Quests, GuildSystem, TimeSystem)
    -- Close button
    if Components.isPointInRect(x, y, MENU.x + MENU.width - 40, MENU.y + 10, 30, 30) then
        SaveMenu.resetState()
        return "close"
    end

    -- Mode tabs
    local tabY = MENU.y + 50
    local tabW = 100
    if Components.isPointInRect(x, y, MENU.x + MENU.width/2 - tabW - 10, tabY, tabW, 30) then
        currentMode = "save"
        selectedSlot = nil
        return nil
    end
    if Components.isPointInRect(x, y, MENU.x + MENU.width/2 + 10, tabY, tabW, 30) then
        currentMode = "load"
        selectedSlot = nil
        return nil
    end

    -- Slot selection
    local slotY = tabY + 50
    local slotHeight = 100
    local slotWidth = MENU.width - 40

    for slot = 1, SaveSystem.SAVE_SLOTS do
        if Components.isPointInRect(x, y, MENU.x + 20, slotY, slotWidth, slotHeight) then
            selectedSlot = slot
            return nil
        end
        slotY = slotY + slotHeight + 10
    end

    -- Action buttons
    if selectedSlot then
        local btnY = MENU.y + MENU.height - 60
        local btnW = 200
        local btnX = MENU.x + (MENU.width - btnW) / 2

        local info = saveInfoCache and saveInfoCache[selectedSlot]

        -- Save/Load button
        if Components.isPointInRect(x, y, btnX, btnY, btnW, 40) then
            if currentMode == "save" then
                local success, msg = SaveSystem.save(gameData, selectedSlot)
                refreshSaveInfo()
                return success and "saved" or "error", msg
            else
                if info and info.exists and not info.corrupted then
                    local loadedData, err = SaveSystem.load(selectedSlot)
                    if loadedData then
                        SaveSystem.applyLoadedData(gameData, loadedData, Heroes, Quests, GuildSystem, TimeSystem)
                        SaveMenu.resetState()
                        return "loaded", "Game loaded from slot " .. selectedSlot
                    else
                        return "error", err
                    end
                end
            end
        end

        -- Delete button
        if info and info.exists then
            if Components.isPointInRect(x, y, MENU.x + MENU.width - 100, btnY, 80, 40) then
                local success, msg = SaveSystem.deleteSave(selectedSlot)
                refreshSaveInfo()
                selectedSlot = nil
                return success and "deleted" or "error", msg
            end
        end
    end

    return nil
end

-- Quick save (slot 1)
function SaveMenu.quickSave(gameData)
    return SaveSystem.save(gameData, 1)
end

-- Quick load (slot 1)
function SaveMenu.quickLoad(gameData, Heroes, Quests, GuildSystem, TimeSystem)
    if not SaveSystem.saveExists(1) then
        return false, "No save in slot 1"
    end

    local loadedData, err = SaveSystem.load(1)
    if not loadedData then
        return false, err
    end

    SaveSystem.applyLoadedData(gameData, loadedData, Heroes, Quests, GuildSystem, TimeSystem)
    return true, "Game loaded from slot 1"
end

return SaveMenu
