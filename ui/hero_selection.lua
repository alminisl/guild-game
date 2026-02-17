-- Hero Selection Module
-- Choose your starter hero from 4 random D-rank options

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")

local HeroSelection = {}

-- Screen dimensions
local SCREEN_W, SCREEN_H = 1920, 1080

-- Selection state
local heroOptions = {}  -- 4 random D-rank heroes to choose from
local selectedIndex = nil
local hoveredIndex = nil

-- Initialize the selection screen with 4 hero options
function HeroSelection.init(Heroes)
    heroOptions = {}
    selectedIndex = nil
    hoveredIndex = nil
    
    -- Generate 4 random D-rank heroes with different classes
    local classes = {"Knight", "Archer", "Mage", "Rogue", "Priest", "Ranger"}
    local usedClasses = {}
    
    for i = 1, 4 do
        -- Pick a random unused class
        local class
        repeat
            class = classes[math.random(#classes)]
        until not usedClasses[class]
        usedClasses[class] = true
        
        -- Generate hero
        local hero = Heroes.generate({
            rank = "D",
            class = class,
            level = 1
        })
        table.insert(heroOptions, hero)
    end
end

-- Draw the hero selection screen
function HeroSelection.draw()
    -- Dark background
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)
    
    -- Title
    love.graphics.setColor(1, 0.9, 0.6)
    love.graphics.setNewFont(32)
    love.graphics.printf("CHOOSE YOUR HERO", 0, 100, SCREEN_W, "center")
    
    -- Subtitle
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setNewFont(18)
    love.graphics.printf("Select one hero to begin your guild's journey", 0, 150, SCREEN_W, "center")
    
    -- Reset font
    love.graphics.setNewFont(16)
    
    -- Calculate card layout (4 cards in a row)
    local cardWidth = 400
    local cardHeight = 550
    local spacing = 40
    local totalWidth = (cardWidth * 4) + (spacing * 3)
    local startX = (SCREEN_W - totalWidth) / 2
    local cardY = 250
    
    -- Draw hero cards
    for i, hero in ipairs(heroOptions) do
        local cardX = startX + (i - 1) * (cardWidth + spacing)
        local isHovered = (hoveredIndex == i)
        local isSelected = (selectedIndex == i)
        
        drawHeroCard(hero, cardX, cardY, cardWidth, cardHeight, isHovered, isSelected)
    end
    
    -- Draw confirm button if hero selected
    if selectedIndex then
        local btnW, btnH = 300, 60
        local btnX = (SCREEN_W - btnW) / 2
        local btnY = cardY + cardHeight + 60
        
        -- Button background
        love.graphics.setColor(0.3, 0.7, 0.3)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 10, 10)
        
        -- Button border
        love.graphics.setColor(0.4, 0.9, 0.4)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 10, 10)
        
        -- Button text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setNewFont(24)
        love.graphics.printf("BEGIN ADVENTURE", btnX, btnY + 18, btnW, "center")
        love.graphics.setNewFont(16)
    end
    
    -- Instructions at bottom
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setNewFont(14)
    love.graphics.printf("Click a hero to select, then click BEGIN ADVENTURE to start", 0, SCREEN_H - 50, SCREEN_W, "center")
    love.graphics.setNewFont(16)
end

-- Draw individual hero card
function drawHeroCard(hero, x, y, w, h, isHovered, isSelected)
    -- Card background
    local bgColor = {0.15, 0.15, 0.2}
    if isSelected then
        bgColor = {0.2, 0.35, 0.25}
    elseif isHovered then
        bgColor = {0.2, 0.2, 0.25}
    end
    
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    
    -- Card border
    local borderColor = {0.3, 0.3, 0.4}
    if isSelected then
        borderColor = {0.4, 0.8, 0.4}
    elseif isHovered then
        borderColor = {0.5, 0.5, 0.6}
    end
    
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(isSelected and 4 or 2)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    
    -- Hero sprite (large, centered)
    local spriteY = y + 180
    SpriteSystem.drawCentered(hero, x + w/2, spriteY, 400, 400, "Idle")
    
    -- Hero name
    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(24)
    love.graphics.printf(hero.name, x, y + 20, w, "center")
    
    -- Hero class and race
    love.graphics.setColor(0.9, 0.8, 0.5)
    love.graphics.setNewFont(18)
    love.graphics.printf(hero.class, x, y + 50, w, "center")
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setNewFont(16)
    love.graphics.printf(hero.race, x, y + 75, w, "center")
    
    -- Stats section
    local statsY = y + 320
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setNewFont(16)
    love.graphics.printf("STATS", x, statsY, w, "center")
    
    statsY = statsY + 30
    local statData = {
        {name = "STR", key = "str", color = {0.9, 0.5, 0.5}},
        {name = "DEX", key = "dex", color = {0.5, 0.9, 0.5}},
        {name = "INT", key = "int", color = {0.5, 0.5, 0.9}},
        {name = "VIT", key = "vit", color = {0.9, 0.7, 0.4}},
        {name = "LCK", key = "luck", color = {0.8, 0.6, 0.9}}
    }
    
    for _, stat in ipairs(statData) do
        love.graphics.setColor(stat.color)
        love.graphics.print(stat.name, x + 40, statsY)
        
        -- Stat value
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(hero.stats[stat.key], x + w - 60, statsY)
        
        -- Small bar
        local barW = 200
        local barH = 12
        local barX = x + 80
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", barX, statsY + 2, barW, barH)
        
        love.graphics.setColor(stat.color)
        love.graphics.rectangle("fill", barX, statsY + 2, barW * math.min(hero.stats[stat.key] / 20, 1), barH)
        
        statsY = statsY + 25
    end
    
    -- Passive ability
    if hero.passive then
        statsY = statsY + 10
        love.graphics.setColor(0.8, 0.7, 0.9)
        love.graphics.setNewFont(14)
        love.graphics.printf("Passive: " .. hero.passive.name, x + 20, statsY, w - 40, "left")
        statsY = statsY + 20
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setNewFont(12)
        love.graphics.printf(hero.passive.description, x + 20, statsY, w - 40, "left")
    end
    
    -- Reset font
    love.graphics.setNewFont(16)
end

-- Handle mouse movement
function HeroSelection.update(dt)
    local mx, my = love.mouse.getPosition()
    
    -- Check which card is hovered
    local cardWidth = 400
    local spacing = 40
    local totalWidth = (cardWidth * 4) + (spacing * 3)
    local startX = (SCREEN_W - totalWidth) / 2
    local cardY = 250
    local cardHeight = 550
    
    hoveredIndex = nil
    for i = 1, 4 do
        local cardX = startX + (i - 1) * (cardWidth + spacing)
        if mx >= cardX and mx <= cardX + cardWidth and my >= cardY and my <= cardY + cardHeight then
            hoveredIndex = i
            break
        end
    end
end

-- Handle mouse click
function HeroSelection.handleClick(x, y)
    -- Check if clicking on a hero card
    local cardWidth = 400
    local cardHeight = 550
    local spacing = 40
    local totalWidth = (cardWidth * 4) + (spacing * 3)
    local startX = (SCREEN_W - totalWidth) / 2
    local cardY = 250
    
    for i = 1, 4 do
        local cardX = startX + (i - 1) * (cardWidth + spacing)
        if x >= cardX and x <= cardX + cardWidth and y >= cardY and y <= cardY + cardHeight then
            selectedIndex = i
            return "selected"
        end
    end
    
    -- Check if clicking confirm button
    if selectedIndex then
        local btnW, btnH = 300, 60
        local btnX = (SCREEN_W - btnW) / 2
        local btnY = cardY + cardHeight + 60
        
        if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
            return "confirm"
        end
    end
    
    return nil
end

-- Get the selected hero
function HeroSelection.getSelectedHero()
    if selectedIndex then
        return heroOptions[selectedIndex]
    end
    return nil
end

return HeroSelection
