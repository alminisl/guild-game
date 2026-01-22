-- Tavern Menu Module
-- UI for hiring heroes

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")

local TavernMenu = {}

-- Menu design dimensions (base size before scaling)
local MENU_DESIGN_WIDTH = 1100
local MENU_DESIGN_HEIGHT = 600

-- Legacy MENU table for backward compatibility (updated dynamically)
local MENU = {
    x = 90,
    y = 60,
    width = 1100,
    height = 600
}

-- Update MENU table with current centered values
local function updateMenuRect()
    local rect = Components.getCenteredMenu(MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)
    MENU.x = rect.x
    MENU.y = rect.y
    MENU.width = rect.width
    MENU.height = rect.height
    MENU.scale = rect.scale
    return MENU
end

-- Draw the tavern menu
function TavernMenu.draw(gameData, Economy, GuildSystem)
    -- Update menu position for current window size
    updateMenuRect()
    local scale = MENU.scale or 1

    -- Dark background overlay (drawn at screen coordinates)
    local windowW, windowH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, windowW, windowH)

    -- Apply transform for scaled menu content
    love.graphics.push()
    love.graphics.translate(MENU.x, MENU.y)
    love.graphics.scale(scale, scale)

    -- Background panel (at origin, using design dimensions)
    Components.drawPanel(0, 0, MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("THE RUSTY TANKARD TAVERN", 0, 15, MENU_DESIGN_WIDTH, "center")

    -- Close button
    Components.drawCloseButton(MENU_DESIGN_WIDTH - 40, 10)

    -- Gold display
    Components.drawGold(gameData.gold, 20, 15)

    -- Subtitle
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Heroes looking for work", 0, 45, MENU_DESIGN_WIDTH, "center")

    -- Roster info (dynamic slots from guild level)
    local rosterLimit = GuildSystem and GuildSystem.getHeroSlots(gameData) or 4
    local rosterColor = #gameData.heroes >= rosterLimit and Components.colors.danger or Components.colors.text
    love.graphics.setColor(rosterColor)
    love.graphics.print("Roster: " .. #gameData.heroes .. "/" .. rosterLimit .. " heroes", 20, 45)

    -- Heroes for hire (20% smaller cards)
    local startY = 80
    local cardHeight = 88
    local cardSpacing = 8
    local cardWidth = MENU_DESIGN_WIDTH - 40

    if #gameData.tavernPool == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No heroes available. Come back tomorrow!", 0, startY + 50, MENU_DESIGN_WIDTH, "center")
    else
        for i, hero in ipairs(gameData.tavernPool) do
            local y = startY + (i - 1) * (cardHeight + cardSpacing)

            -- Card background
            Components.drawPanel(20, y, cardWidth, cardHeight, {
                color = Components.colors.panelLight,
                cornerRadius = 5
            })

            -- Hero sprite portrait (smaller)
            local spriteX = 65
            local spriteY = y + cardHeight / 2
            SpriteSystem.drawCentered(hero, spriteX, spriteY, 200, 200, "Idle")

            -- Hero info
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(hero.name, 130, y + 6)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print((hero.race or "Human") .. " " .. hero.class .. " Lv." .. hero.level, 130, y + 22)

            -- Rank display
            love.graphics.setColor(Components.colors.warning)
            love.graphics.print("Rank: " .. hero.rank, 130, y + 38)

            -- Stats preview
            local statsX = 300
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(string.format("STR:%d DEX:%d INT:%d VIT:%d LCK:%d",
                hero.stats.str, hero.stats.dex, hero.stats.int, hero.stats.vit, hero.stats.luck), statsX, y + 22)

            -- Passive ability display (more compact)
            if hero.passive then
                local catColors = {
                    OFFENSE = {0.9, 0.4, 0.3},
                    DEFENSE = {0.3, 0.6, 0.9},
                    WEALTH = {1, 0.85, 0.2},
                    SPEED = {0.4, 0.9, 0.5}
                }
                local catColor = catColors[hero.passive.category] or Components.colors.text
                love.graphics.setColor(catColor)
                love.graphics.print(hero.passive.name .. " [" .. hero.passive.category .. "]", statsX, y + 38)
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print(hero.passive.description, statsX, y + 54)
            end

            -- Hire cost
            love.graphics.setColor(Components.colors.gold)
            love.graphics.print(hero.hireCost .. "g", cardWidth - 100, y + 10)

            -- Hire button
            local canAfford = Economy.canAfford(gameData, hero.hireCost)
            local canHire = GuildSystem and GuildSystem.canHireHero(gameData) or (#gameData.heroes < 4)

            local btnX = cardWidth - 70
            local btnY = y + 35
            local btnW = 60
            local btnH = 26

            local btnColor = Components.colors.buttonActive
            local btnText = "Hire"

            if not canHire then
                btnColor = Components.colors.buttonDisabled
                btnText = "Full"
            elseif not canAfford then
                btnColor = Components.colors.buttonDisabled
                btnText = "Hire"
            end

            Components.drawButton(btnText, btnX, btnY, btnW, btnH, {
                color = btnColor,
                disabled = not canAfford or not canHire
            })
        end
    end

    -- Refresh button at bottom
    local refreshCost = Economy.costs.tavernRefresh
    local refreshY = MENU_DESIGN_HEIGHT - 50
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Want different heroes?", 20, refreshY + 8)

    Components.drawButton("Refresh (" .. refreshCost .. "g)", 200, refreshY, 120, 30, {
        disabled = not Economy.canAfford(gameData, refreshCost)
    })

    -- Restore transform
    love.graphics.pop()
end

-- Handle click in tavern menu
function TavernMenu.handleClick(x, y, gameData, Heroes, Economy, GuildSystem)
    -- Update menu position for current window size
    updateMenuRect()
    local scale = MENU.scale or 1

    -- Transform screen coordinates to design coordinates
    local designX = (x - MENU.x) / scale
    local designY = (y - MENU.y) / scale

    -- Close button (in design coordinates)
    if Components.isPointInRect(designX, designY, MENU_DESIGN_WIDTH - 40, 10, 30, 30) then
        return "close"
    end

    -- Hire buttons (in design coordinates) - matches draw function
    local startY = 80
    local cardHeight = 88
    local cardSpacing = 8
    local cardWidth = MENU_DESIGN_WIDTH - 40

    for i, hero in ipairs(gameData.tavernPool) do
        local heroY = startY + (i - 1) * (cardHeight + cardSpacing)
        local btnX = cardWidth - 70
        local btnY = heroY + 35
        local btnW = 60
        local btnH = 26

        if Components.isPointInRect(designX, designY, btnX, btnY, btnW, btnH) then
            -- Try to hire this hero (check slot limit)
            if GuildSystem and not GuildSystem.canHireHero(gameData) then
                return "error", "Roster is full! Level up your guild for more slots."
            end

            local success, message = Economy.spend(gameData, hero.hireCost, "hiring " .. hero.name)
            if success then
                -- Add hero to roster
                hero.status = "idle"
                table.insert(gameData.heroes, hero)
                table.remove(gameData.tavernPool, i)
                return "hired", hero.name .. " joined your guild!"
            else
                return "error", message
            end
        end
    end

    -- Refresh button (in design coordinates)
    local refreshY = MENU_DESIGN_HEIGHT - 50
    if Components.isPointInRect(designX, designY, 200, refreshY, 120, 30) then
        local refreshCost = Economy.costs.tavernRefresh
        local success, message = Economy.spend(gameData, refreshCost, "tavern refresh")
        if success then
            local maxRank = GuildSystem and GuildSystem.getMaxTavernRank(gameData) or "C"
            gameData.tavernPool = Heroes.generateTavernPool(4, maxRank)
            return "refreshed", "New heroes have arrived!"
        else
            return "error", message
        end
    end

    return nil
end

return TavernMenu
