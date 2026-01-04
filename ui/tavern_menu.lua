-- Tavern Menu Module
-- UI for hiring heroes

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")

local TavernMenu = {}

-- Menu dimensions (scaled for 1280x720)
local MENU = {
    x = 90,
    y = 60,
    width = 1100,
    height = 600
}

-- Draw the tavern menu
function TavernMenu.draw(gameData, Economy, GuildSystem)
    -- Background panel
    Components.drawPanel(MENU.x, MENU.y, MENU.width, MENU.height)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("THE RUSTY TANKARD TAVERN", MENU.x, MENU.y + 15, MENU.width, "center")

    -- Close button
    Components.drawCloseButton(MENU.x + MENU.width - 40, MENU.y + 10)

    -- Gold display
    Components.drawGold(gameData.gold, MENU.x + 20, MENU.y + 15)

    -- Subtitle
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Heroes looking for work", MENU.x, MENU.y + 45, MENU.width, "center")

    -- Roster info (dynamic slots from guild level)
    local rosterLimit = GuildSystem and GuildSystem.getHeroSlots(gameData) or 4
    local rosterColor = #gameData.heroes >= rosterLimit and Components.colors.danger or Components.colors.text
    love.graphics.setColor(rosterColor)
    love.graphics.print("Roster: " .. #gameData.heroes .. "/" .. rosterLimit .. " heroes", MENU.x + 20, MENU.y + 45)

    -- Heroes for hire
    local startY = MENU.y + 80
    local cardHeight = 110
    local cardWidth = MENU.width - 40

    if #gameData.tavernPool == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No heroes available. Come back tomorrow!", MENU.x, startY + 50, MENU.width, "center")
    else
        for i, hero in ipairs(gameData.tavernPool) do
            local y = startY + (i - 1) * (cardHeight + 10)

            -- Card background
            Components.drawPanel(MENU.x + 20, y, cardWidth, cardHeight, {
                color = Components.colors.panelLight,
                cornerRadius = 5
            })

            -- Hero sprite portrait (much larger to compensate for sprite padding)
            local spriteX = MENU.x + 80
            local spriteY = y + cardHeight / 2
            SpriteSystem.drawCentered(hero, spriteX, spriteY, 264, 264, "Idle")

            -- Hero info (shifted right for bigger sprite)
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(hero.name, MENU.x + 155, y + 10)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print((hero.race or "Human") .. " " .. hero.class .. " - Lv." .. hero.level, MENU.x + 155, y + 30)

            -- Rank display
            love.graphics.setColor(Components.colors.warning)
            love.graphics.print("Rank: " .. hero.rank, MENU.x + 155, y + 50)

            -- Stats preview (shifted for bigger sprite)
            local statsX = MENU.x + 340
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(string.format("STR:%d DEX:%d INT:%d",
                hero.stats.str, hero.stats.dex, hero.stats.int), statsX, y + 30)
            love.graphics.print(string.format("VIT:%d LCK:%d",
                hero.stats.vit, hero.stats.luck), statsX, y + 50)

            -- Hire cost
            love.graphics.setColor(Components.colors.gold)
            love.graphics.print(hero.hireCost .. " gold", MENU.x + cardWidth - 140, y + 15)

            -- Hire button
            local canAfford = Economy.canAfford(gameData, hero.hireCost)
            local canHire = GuildSystem and GuildSystem.canHireHero(gameData) or (#gameData.heroes < 4)

            local btnX = MENU.x + cardWidth - 80
            local btnY = y + 45
            local btnW = 70
            local btnH = 30

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
    local refreshY = MENU.y + MENU.height - 50
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Want different heroes?", MENU.x + 20, refreshY + 8)

    Components.drawButton("Refresh (" .. refreshCost .. "g)", MENU.x + 200, refreshY, 120, 30, {
        disabled = not Economy.canAfford(gameData, refreshCost)
    })
end

-- Handle click in tavern menu
function TavernMenu.handleClick(x, y, gameData, Heroes, Economy, GuildSystem)
    -- Close button
    if Components.isPointInRect(x, y, MENU.x + MENU.width - 40, MENU.y + 10, 30, 30) then
        return "close"
    end

    -- Hire buttons
    local startY = MENU.y + 80
    local cardHeight = 90
    local cardWidth = MENU.width - 40

    for i, hero in ipairs(gameData.tavernPool) do
        local heroY = startY + (i - 1) * (cardHeight + 10)
        local btnX = MENU.x + cardWidth - 80
        local btnY = heroY + 45
        local btnW = 70
        local btnH = 30

        if Components.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
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

    -- Refresh button
    local refreshY = MENU.y + MENU.height - 50
    if Components.isPointInRect(x, y, MENU.x + 200, refreshY, 120, 30) then
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
