-- Potion Shop Menu Module
-- Buy potions and items to help heroes recover

local Components = require("ui.components")

local PotionMenu = {}

-- Menu dimensions (scaled for 1280x720)
local MENU = {
    x = 90,
    y = 60,
    width = 1100,
    height = 600
}

-- State
local selectedHero = nil  -- For applying items to specific hero

function PotionMenu.resetState()
    selectedHero = nil
end

function PotionMenu.draw(gameData, Items, Heroes, Economy)
    -- Background panel
    Components.drawPanel(MENU.x, MENU.y, MENU.width, MENU.height)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("MYSTIC POTIONS & REST", MENU.x, MENU.y + 15, MENU.width, "center")

    -- Close button
    Components.drawCloseButton(MENU.x + MENU.width - 40, MENU.y + 10)

    -- Gold display
    Components.drawGold(gameData.gold, MENU.x + 20, MENU.y + 15)

    -- Left side: Items for sale
    local itemsX = MENU.x + 20
    local itemsY = MENU.y + 60
    local itemsWidth = 320

    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Recovery Items", itemsX, itemsY)

    local y = itemsY + 25
    for i, item in ipairs(Items.list) do
        if y + 70 > MENU.y + MENU.height - 20 then break end

        -- Item card
        local canAfford = Economy.canAfford(gameData, item.cost)
        local bgColor = canAfford and Components.colors.panelLight or {0.2, 0.2, 0.2}
        Components.drawPanel(itemsX, y, itemsWidth, 65, {
            color = bgColor,
            cornerRadius = 5
        })

        -- Item icon placeholder
        local iconColor = {0.5, 0.3, 0.6}
        if item.category == "food" then iconColor = {0.6, 0.4, 0.2}
        elseif item.category == "lodging" then iconColor = {0.4, 0.4, 0.5}
        end
        love.graphics.setColor(iconColor)
        love.graphics.rectangle("fill", itemsX + 10, y + 12, 40, 40, 5, 5)

        -- Item info
        love.graphics.setColor(canAfford and Components.colors.text or Components.colors.textDim)
        love.graphics.print(item.name, itemsX + 60, y + 8)

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(item.description, itemsX + 60, y + 26)

        -- Cost
        love.graphics.setColor(canAfford and Components.colors.gold or Components.colors.danger)
        love.graphics.print(item.cost .. "g", itemsX + 60, y + 44)

        -- Buy button
        local btnX = itemsX + itemsWidth - 55
        local btnY = y + 18
        local btnColor = canAfford and Components.colors.buttonActive or Components.colors.buttonDisabled
        Components.drawButton("Buy", btnX, btnY, 45, 28, {
            color = btnColor,
            disabled = not canAfford
        })

        y = y + 70
    end

    -- Right side: Resting heroes
    local heroesX = MENU.x + itemsWidth + 40
    local heroesY = MENU.y + 60
    local heroesWidth = MENU.width - itemsWidth - 60

    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Resting Heroes", heroesX, heroesY)

    local restingHeroes = {}
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            table.insert(restingHeroes, hero)
        end
    end

    if #restingHeroes == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No heroes resting", heroesX, heroesY + 50, heroesWidth, "center")
    else
        local hy = heroesY + 25
        for i, hero in ipairs(restingHeroes) do
            if hy + 50 > MENU.y + MENU.height - 20 then break end

            local isSelected = selectedHero == hero.id
            local bgColor = isSelected and {0.3, 0.4, 0.5} or Components.colors.panelLight
            Components.drawPanel(heroesX, hy, heroesWidth, 45, {
                color = bgColor,
                cornerRadius = 5
            })

            -- Rank badge
            Components.drawRankBadge(hero.rank, heroesX + 5, hy + 8, 28)

            -- Name
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(hero.name, heroesX + 40, hy + 5)

            -- Rest progress bar
            local restPercent = Heroes.getRestPercent(hero)
            local timeRemaining = (hero.restTimeMax or 0) - (hero.restProgress or 0)
            Components.drawProgressBar(heroesX + 40, hy + 24, heroesWidth - 55, 14, restPercent, {
                fgColor = {0.6, 0.4, 0.7},
                text = string.format("%.0fs", math.max(0, timeRemaining))
            })

            hy = hy + 50
        end

        -- "Apply to All" section
        if #restingHeroes > 1 then
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Buy items to speed up rest!", heroesX, MENU.y + MENU.height - 60)
        end
    end

    -- Instructions
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Buy potions to instantly restore or speed up resting heroes",
        MENU.x, MENU.y + MENU.height - 30, MENU.width, "center")
end

function PotionMenu.handleClick(x, y, gameData, Items, Heroes, Economy)
    -- Close button
    if Components.isPointInRect(x, y, MENU.x + MENU.width - 40, MENU.y + 10, 30, 30) then
        PotionMenu.resetState()
        return "close"
    end

    -- Item buy buttons
    local itemsX = MENU.x + 20
    local itemsY = MENU.y + 85
    local itemsWidth = 320

    for i, item in ipairs(Items.list) do
        local iy = itemsY + (i - 1) * 70
        local btnX = itemsX + itemsWidth - 55
        local btnY = iy + 18

        if Components.isPointInRect(x, y, btnX, btnY, 45, 28) then
            -- Try to buy and apply item
            if Economy.canAfford(gameData, item.cost) then
                -- Find resting heroes to apply to
                local restingHeroes = {}
                for _, hero in ipairs(gameData.heroes) do
                    if hero.status == "resting" then
                        table.insert(restingHeroes, hero)
                    end
                end

                if #restingHeroes == 0 then
                    return "error", "No heroes need rest!"
                end

                -- Apply effect
                local success, message
                if item.effect == "instant_rest_all" then
                    success, message = Items.applyToAllResting(item, gameData, Heroes)
                elseif item.effect == "instant_rest" then
                    -- Apply to first resting hero
                    success, message = Items.applyToHero(item, restingHeroes[1], Heroes)
                else
                    -- Apply speed boost to all resting
                    success, message = Items.applyToAllResting(item, gameData, Heroes)
                end

                if success then
                    Economy.spend(gameData, item.cost)
                    return "purchased", item.name .. " used! " .. message
                else
                    return "error", message
                end
            else
                return "error", "Not enough gold!"
            end
        end
    end

    -- Hero selection (for future targeted items)
    local heroesX = MENU.x + 360
    local heroesY = MENU.y + 85
    local heroesWidth = 320

    local restingIndex = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            local hy = heroesY + restingIndex * 50
            if Components.isPointInRect(x, y, heroesX, hy, heroesWidth, 45) then
                selectedHero = hero.id
                return nil
            end
            restingIndex = restingIndex + 1
        end
    end

    return nil
end

return PotionMenu
