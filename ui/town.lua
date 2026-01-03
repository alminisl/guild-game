-- Town View Module
-- Renders the town with clickable buildings

local Components = require("ui.components")

local Town = {}

-- Building definitions (scaled for 1280x720)
Town.buildings = {
    {
        id = "tavern",
        name = "Tavern",
        x = 120,
        y = 320,
        width = 120,
        height = 130,
        color = {0.7, 0.5, 0.3},
        roofColor = {0.5, 0.3, 0.2},
        description = "Hire adventurers"
    },
    {
        id = "guild",
        name = "Guild Hall",
        x = 400,
        y = 270,
        width = 160,
        height = 180,
        color = {0.6, 0.5, 0.35},
        roofColor = {0.4, 0.3, 0.2},
        description = "Manage quests"
    },
    {
        id = "armory",
        name = "Armory",
        x = 720,
        y = 320,
        width = 120,
        height = 130,
        color = {0.45, 0.45, 0.5},
        roofColor = {0.35, 0.35, 0.4},
        description = "Buy equipment"
    },
    {
        id = "potion",
        name = "Potion Shop",
        x = 1000,
        y = 340,
        width = 110,
        height = 110,
        color = {0.4, 0.3, 0.5},
        roofColor = {0.3, 0.2, 0.4},
        description = "Rest & potions"
    },
    {
        id = "save",
        name = "Archives",
        x = 580,
        y = 380,
        width = 90,
        height = 70,
        color = {0.45, 0.4, 0.35},
        roofColor = {0.35, 0.3, 0.25},
        description = "Save & Load (F5/F9)"
    }
}

-- Draw a single building
local function drawBuilding(building, isHovered)
    local b = building

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", b.x + 5, b.y + 5, b.width, b.height)

    -- Building body
    local color = b.color
    if isHovered then
        color = {color[1] + 0.1, color[2] + 0.1, color[3] + 0.1}
    end
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", b.x, b.y, b.width, b.height)

    -- Roof
    love.graphics.setColor(b.roofColor)
    love.graphics.polygon("fill",
        b.x - 10, b.y,
        b.x + b.width / 2, b.y - 40,
        b.x + b.width + 10, b.y
    )

    -- Door
    love.graphics.setColor(0.25, 0.15, 0.1)
    local doorWidth = b.width * 0.25
    local doorHeight = b.height * 0.4
    love.graphics.rectangle("fill",
        b.x + (b.width - doorWidth) / 2,
        b.y + b.height - doorHeight,
        doorWidth, doorHeight
    )

    -- Windows (lit based on time of day)
    love.graphics.setColor(0.9, 0.8, 0.5)
    local windowSize = 15
    love.graphics.rectangle("fill", b.x + 10, b.y + 20, windowSize, windowSize)
    love.graphics.rectangle("fill", b.x + b.width - 10 - windowSize, b.y + 20, windowSize, windowSize)

    -- Building name
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(b.name, b.x - 20, b.y - 60, b.width + 40, "center")

    -- Hover description
    if isHovered then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf(b.description, b.x - 20, b.y + b.height + 10, b.width + 40, "center")
    end
end

-- Draw decorative tree
local function drawTree(x, y, scale)
    scale = scale or 1
    -- Trunk
    love.graphics.setColor(0.4, 0.25, 0.1)
    love.graphics.rectangle("fill", x - 5 * scale, y, 10 * scale, 40 * scale)

    -- Leaves
    love.graphics.setColor(0.2, 0.45, 0.2)
    love.graphics.circle("fill", x, y - 10 * scale, 25 * scale)
end

-- Draw the town scene
function Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
    -- Get time of day for visual effects
    local dayProgress = gameData.dayProgress or 0

    -- Sky gradient based on time
    local skyR, skyG, skyB = 0.4, 0.6, 0.8
    if dayProgress > 0.75 then  -- Night
        local nightFactor = (dayProgress - 0.75) * 4
        skyR = 0.4 - nightFactor * 0.25
        skyG = 0.6 - nightFactor * 0.35
        skyB = 0.8 - nightFactor * 0.3
    elseif dayProgress < 0.1 then  -- Dawn
        local dawnFactor = dayProgress * 10
        skyR = 0.3 + dawnFactor * 0.1
        skyG = 0.4 + dawnFactor * 0.2
        skyB = 0.5 + dawnFactor * 0.3
    end

    love.graphics.setColor(skyR, skyG, skyB)
    love.graphics.rectangle("fill", 0, 0, 1280, 480)

    -- Sun/Moon position based on time
    local celestialX = 100 + dayProgress * 1080
    local celestialY = 180 - math.sin(dayProgress * math.pi) * 120
    if dayProgress > 0.75 or dayProgress < 0.25 then
        -- Moon
        love.graphics.setColor(0.9, 0.9, 0.95)
    else
        -- Sun
        love.graphics.setColor(1, 0.9, 0.6)
    end
    love.graphics.circle("fill", celestialX, celestialY, 30)

    -- Distant mountains
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.polygon("fill", 0, 480, 240, 280, 480, 480)
    love.graphics.polygon("fill", 320, 480, 640, 220, 960, 480)
    love.graphics.polygon("fill", 800, 480, 1120, 320, 1280, 480)

    -- Ground
    love.graphics.setColor(0.35, 0.5, 0.3)
    love.graphics.rectangle("fill", 0, 450, 1280, 270)

    -- Path
    love.graphics.setColor(0.5, 0.4, 0.3)
    love.graphics.rectangle("fill", 0, 540, 1280, 80)

    -- Path details
    love.graphics.setColor(0.45, 0.35, 0.25)
    for i = 0, 22 do
        love.graphics.rectangle("fill", i * 58 + 10, 560, 35, 12)
    end

    -- Trees (background)
    drawTree(50, 400, 1.0)
    drawTree(1200, 390, 1.1)
    drawTree(280, 420, 0.9)
    drawTree(950, 410, 1.0)

    -- Draw buildings
    for _, building in ipairs(Town.buildings) do
        local isHovered = Town.getBuildingAt(mouseX, mouseY) == building.id
        drawBuilding(building, isHovered)
    end

    -- Trees (foreground)
    drawTree(80, 630, 1.3)
    drawTree(1150, 620, 1.2)

    -- UI Header
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 1280, 50)

    -- Gold display
    Components.drawGold(gameData.gold, 15, 16)

    -- Guild level display
    if GuildSystem and gameData.guild then
        local guildLevel = gameData.guild.level or 1
        love.graphics.setColor(0.4, 0.6, 0.8)
        love.graphics.print("Guild Lv." .. guildLevel, 100, 16)
    end

    -- Day and Time display
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Day " .. gameData.day, 200, 16)

    if TimeSystem then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(TimeSystem.getTimeString(gameData) .. " - " .. TimeSystem.getDayPeriod(gameData), 280, 16)

        -- Time speed indicator (if not 1x)
        if TimeSystem.config.timeScale ~= 1 then
            love.graphics.setColor(Components.colors.warning)
            love.graphics.print(TimeSystem.config.timeScale .. "x", 480, 16)
        end
    end

    -- Active quests indicator with slot info
    local activeCount = #gameData.activeQuests
    local questSlots = GuildSystem and GuildSystem.getQuestSlots(gameData) or 2
    love.graphics.setColor(activeCount >= questSlots and Components.colors.warning or Components.colors.textDim)
    love.graphics.print("Quests: " .. activeCount .. "/" .. questSlots, 560, 16)

    -- Resting heroes count
    local restingCount = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            restingCount = restingCount + 1
        end
    end
    if restingCount > 0 then
        love.graphics.setColor(0.6, 0.4, 0.7)
        love.graphics.print("Resting: " .. restingCount, 700, 16)
    end

    -- Heroes count with slot info
    local heroSlots = GuildSystem and GuildSystem.getHeroSlots(gameData) or 4
    love.graphics.setColor(#gameData.heroes >= heroSlots and Components.colors.warning or Components.colors.text)
    love.graphics.print("Heroes: " .. #gameData.heroes .. "/" .. heroSlots, 820, 16)

    -- Time controls hint
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("+/- Speed", 920, 16)

    -- Graveyard count
    if gameData.graveyard and #gameData.graveyard > 0 then
        love.graphics.setColor(0.6, 0.3, 0.3)
        love.graphics.print("Fallen: " .. #gameData.graveyard, 1000, 16)
    end

    -- Day/Night toggle button (top right)
    -- Only clickable at the end of the current period
    local isNight = TimeSystem and TimeSystem.isNight(gameData) or false
    local progress = gameData.dayProgress or 0

    -- Calculate if button should be enabled
    -- During day (0-0.75): enabled when progress > 0.70 (last 5% of day)
    -- During night (0.75-1): enabled when progress > 0.95 (last 5% of night)
    local canToggle = false
    local timeRemaining = ""
    if isNight then
        canToggle = progress >= 0.95
        local remaining = (1.0 - progress) * TimeSystem.config.dayDuration
        timeRemaining = TimeSystem.formatDuration(remaining)
    else
        canToggle = progress >= 0.70
        local remaining = (0.75 - progress) * TimeSystem.config.dayDuration
        timeRemaining = TimeSystem.formatDuration(math.max(0, remaining))
    end

    local btnText = isNight and "Move to Day" or "Move to Night"
    local btnColor
    if canToggle then
        btnColor = isNight and {0.7, 0.6, 0.3} or {0.3, 0.3, 0.6}
    else
        btnColor = {0.3, 0.3, 0.3}  -- Disabled gray
    end

    love.graphics.setColor(btnColor)
    love.graphics.rectangle("fill", 1100, 8, 170, 34, 5, 5)
    love.graphics.setColor(canToggle and {0.9, 0.9, 0.9} or {0.5, 0.5, 0.5})
    love.graphics.rectangle("line", 1100, 8, 170, 34, 5, 5)

    -- Button icon (sun or moon)
    if isNight then
        love.graphics.setColor(canToggle and {1, 0.9, 0.5} or {0.6, 0.5, 0.3})  -- Sun color
        love.graphics.circle("fill", 1120, 25, 8)
    else
        love.graphics.setColor(canToggle and {0.9, 0.9, 1} or {0.5, 0.5, 0.6})  -- Moon color
        love.graphics.circle("fill", 1120, 25, 8)
        -- Moon shadow
        love.graphics.setColor(btnColor)
        love.graphics.circle("fill", 1116, 23, 6)
    end

    -- Button text
    if canToggle then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(btnText, 1135, 15)
    else
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("Wait " .. timeRemaining, 1135, 15)
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf("Click a building to enter", 0, 680, 1280, "center")
end

-- Check if day/night button was clicked (and is enabled)
function Town.getDayNightButtonAt(x, y, gameData, TimeSystem)
    if not Components.isPointInRect(x, y, 1100, 8, 170, 34) then
        return false
    end

    -- Check if toggle is currently allowed
    local isNight = TimeSystem and TimeSystem.isNight(gameData) or false
    local progress = gameData.dayProgress or 0

    if isNight then
        return progress >= 0.95  -- Can toggle at end of night
    else
        return progress >= 0.70  -- Can toggle at end of day
    end
end

-- Get building ID at mouse position
function Town.getBuildingAt(x, y)
    for _, building in ipairs(Town.buildings) do
        -- Include roof area in click detection
        local clickY = building.y - 40
        local clickHeight = building.height + 40

        if Components.isPointInRect(x, y, building.x - 10, clickY,
                                    building.width + 20, clickHeight) then
            return building.id
        end
    end
    return nil
end

return Town
