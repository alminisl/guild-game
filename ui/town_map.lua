-- Town Map Module
-- Displays the town with clickable buildings

local Components = require("ui.components")

local TownMap = {}

-- Screen dimensions
local SCREEN = {
    width = 1280,
    height = 720
}

-- Building definitions
local buildings = {
    {
        id = "guild",
        name = "Guild Hall",
        sprite = "assets/Buildings/Blue Buildings/Castle.png",
        x = 640,  -- Center
        y = 200,
        scale = 1.0,
        menu = "guild",
        description = "Manage heroes, quests, and guild operations"
    },
    {
        id = "tavern",
        name = "Tavern",
        sprite = "assets/Buildings/Blue Buildings/Monastery.png",
        x = 300,
        y = 350,
        scale = 0.9,
        menu = "tavern",
        description = "Recruit new heroes"
    },
    {
        id = "armory",
        name = "Armory",
        sprite = "assets/Buildings/Blue Buildings/Barracks.png",
        x = 980,
        y = 350,
        scale = 0.9,
        menu = "armory",
        description = "Buy equipment and craft gear"
    },
    -- Decorative houses
    {
        id = "house1",
        name = "Town House",
        sprite = "assets/Buildings/Blue Buildings/House1.png",
        x = 150,
        y = 500,
        scale = 0.7,
        menu = nil,  -- Not clickable
        description = nil
    },
    {
        id = "house2",
        name = "Town House",
        sprite = "assets/Buildings/Blue Buildings/House2.png",
        x = 500,
        y = 520,
        scale = 0.7,
        menu = nil,
        description = nil
    },
    {
        id = "house3",
        name = "Town House",
        sprite = "assets/Buildings/Blue Buildings/House3.png",
        x = 780,
        y = 530,
        scale = 0.7,
        menu = nil,
        description = nil
    },
    {
        id = "tower",
        name = "Watch Tower",
        sprite = "assets/Buildings/Blue Buildings/Tower.png",
        x = 1100,
        y = 480,
        scale = 0.8,
        menu = nil,  -- Future feature?
        description = nil
    }
}

-- Loaded sprites
local sprites = {}
local hoveredBuilding = nil

-- Load all building sprites
function TownMap.load()
    for _, building in ipairs(buildings) do
        local success, img = pcall(love.graphics.newImage, building.sprite)
        if success then
            sprites[building.id] = img
        else
            print("Failed to load sprite: " .. building.sprite)
        end
    end
end

-- Draw the town map
function TownMap.draw(gameData)
    -- Draw sky gradient background
    local skyTop = {0.4, 0.6, 0.9}
    local skyBottom = {0.6, 0.75, 0.95}

    for y = 0, SCREEN.height do
        local t = y / SCREEN.height
        love.graphics.setColor(
            skyTop[1] + (skyBottom[1] - skyTop[1]) * t,
            skyTop[2] + (skyBottom[2] - skyTop[2]) * t,
            skyTop[3] + (skyBottom[3] - skyTop[3]) * t
        )
        love.graphics.line(0, y, SCREEN.width, y)
    end

    -- Draw ground (simple grass area)
    love.graphics.setColor(0.35, 0.55, 0.3)
    love.graphics.rectangle("fill", 0, SCREEN.height * 0.6, SCREEN.width, SCREEN.height * 0.4)

    -- Draw a path/road
    love.graphics.setColor(0.55, 0.45, 0.35)
    love.graphics.ellipse("fill", SCREEN.width / 2, SCREEN.height * 0.75, 400, 80)
    love.graphics.setColor(0.5, 0.4, 0.3)
    love.graphics.ellipse("fill", SCREEN.width / 2, SCREEN.height * 0.75, 380, 70)

    -- Sort buildings by Y position for proper layering
    local sortedBuildings = {}
    for _, b in ipairs(buildings) do
        table.insert(sortedBuildings, b)
    end
    table.sort(sortedBuildings, function(a, b) return a.y < b.y end)

    -- Draw buildings
    for _, building in ipairs(sortedBuildings) do
        local sprite = sprites[building.id]
        if sprite then
            local scale = building.scale or 1.0
            local w = sprite:getWidth() * scale
            local h = sprite:getHeight() * scale

            -- Highlight if hovered and clickable
            if hoveredBuilding == building and building.menu then
                love.graphics.setColor(1.2, 1.2, 1.2)  -- Brighten
            else
                love.graphics.setColor(1, 1, 1)
            end

            -- Draw shadow
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.ellipse("fill", building.x, building.y + h/2 - 10, w * 0.4, 15)

            -- Draw building
            if hoveredBuilding == building and building.menu then
                love.graphics.setColor(1.15, 1.15, 1.15)
            else
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.draw(sprite, building.x - w/2, building.y - h/2, 0, scale, scale)

            -- Draw label for interactive buildings
            if building.menu then
                -- Label background
                local labelWidth = love.graphics.getFont():getWidth(building.name) + 20
                local labelX = building.x - labelWidth/2
                local labelY = building.y - h/2 - 30

                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.rectangle("fill", labelX, labelY, labelWidth, 24, 5, 5)

                -- Label text
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(building.name, labelX, labelY + 4, labelWidth, "center")
            end
        end
    end

    -- Draw tooltip for hovered building
    if hoveredBuilding and hoveredBuilding.description then
        local mx, my = love.mouse.getPosition()
        local tooltipWidth = 250
        local tooltipX = math.min(mx + 15, SCREEN.width - tooltipWidth - 10)
        local tooltipY = my + 15

        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, 50, 5, 5)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(hoveredBuilding.name, tooltipX + 10, tooltipY + 5)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.printf(hoveredBuilding.description, tooltipX + 10, tooltipY + 25, tooltipWidth - 20, "left")
    end

    -- Draw title
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", SCREEN.width/2 - 100, 10, 200, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("TOWN OF AVENTHEIM", 0, 18, SCREEN.width, "center")

    -- Draw gold display
    Components.drawGold(gameData.gold, 20, 15)

    -- Draw day counter
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", SCREEN.width - 100, 10, 90, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Day " .. (gameData.day or 1), SCREEN.width - 100, 17, 90, "center")

    -- Instructions
end

-- Update hover state
function TownMap.update(dt)
    local mx, my = love.mouse.getPosition()
    hoveredBuilding = nil

    for _, building in ipairs(buildings) do
        local sprite = sprites[building.id]
        if sprite and building.menu then
            local scale = building.scale or 1.0
            local w = sprite:getWidth() * scale
            local h = sprite:getHeight() * scale
            local bx = building.x - w/2
            local by = building.y - h/2

            if mx >= bx and mx <= bx + w and my >= by and my <= by + h then
                hoveredBuilding = building
                break
            end
        end
    end
end

-- Handle click - returns menu to open or nil
function TownMap.handleClick(x, y)
    for _, building in ipairs(buildings) do
        local sprite = sprites[building.id]
        if sprite and building.menu then
            local scale = building.scale or 1.0
            local w = sprite:getWidth() * scale
            local h = sprite:getHeight() * scale
            local bx = building.x - w/2
            local by = building.y - h/2

            if x >= bx and x <= bx + w and y >= by and y <= by + h then
                return building.menu
            end
        end
    end
    return nil
end

-- Get hovered building (for cursor changes, etc.)
function TownMap.getHoveredBuilding()
    return hoveredBuilding
end

return TownMap
