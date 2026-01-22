-- Potion Shop Menu Module
-- Buy potions and items to help heroes recover

local Components = require("ui.components")

local PotionMenu = {}

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

-- State
local selectedHero = nil  -- For applying items to specific hero

function PotionMenu.resetState()
    selectedHero = nil
end

function PotionMenu.draw(gameData, Items, Heroes, Economy)
    -- Update menu position for current window size
    updateMenuRect()
    local scale = MENU.scale or 1

    -- Dark background overlay (screen coordinates)
    local windowW, windowH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, windowW, windowH)

    -- Apply transform for scaled menu content
    love.graphics.push()
    love.graphics.translate(MENU.x, MENU.y)
    love.graphics.scale(scale, scale)

    -- Background panel (design coordinates)
    Components.drawPanel(0, 0, MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("MYSTIC POTIONS & REST", 0, 15, MENU_DESIGN_WIDTH, "center")

    -- Close button
    Components.drawCloseButton(MENU_DESIGN_WIDTH - 40, 10)

    -- Gold display
    Components.drawGold(gameData.gold, 20, 15)

    -- Left side: Items for sale (design coordinates)
    local itemsX = 20
    local itemsY = 60
    local itemsWidth = 320

    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Recovery Items", itemsX, itemsY)

    local y = itemsY + 25
    for i, item in ipairs(Items.list) do
        if y + 70 > MENU_DESIGN_HEIGHT - 20 then break end

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

    -- Right side: Resting heroes (design coordinates)
    local heroesX = itemsWidth + 40
    local heroesY = 60
    local heroesWidth = MENU_DESIGN_WIDTH - itemsWidth - 60

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
            if hy + 50 > MENU_DESIGN_HEIGHT - 20 then break end

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
            love.graphics.print("Buy items to speed up rest!", heroesX, MENU_DESIGN_HEIGHT - 60)
        end
    end

    -- Instructions
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Buy potions to instantly restore or speed up resting heroes",
        0, MENU_DESIGN_HEIGHT - 30, MENU_DESIGN_WIDTH, "center")

    -- Restore transform
    love.graphics.pop()
end

function PotionMenu.handleClick(x, y, gameData, Items, Heroes, Economy)
    -- Update menu position for current window size
    updateMenuRect()
    local scale = MENU.scale or 1

    -- Transform screen coordinates to design coordinates
    local designX = (x - MENU.x) / scale
    local designY = (y - MENU.y) / scale

    -- Close button (design coordinates)
    if Components.isPointInRect(designX, designY, MENU_DESIGN_WIDTH - 40, 10, 30, 30) then
        PotionMenu.resetState()
        return "close"
    end

    -- Item buy buttons (design coordinates)
    local itemsX = 20
    local itemsY = 85
    local itemsWidth = 320

    for i, item in ipairs(Items.list) do
        local iy = itemsY + (i - 1) * 70
        local btnX = itemsX + itemsWidth - 55
        local btnY = iy + 18

        if Components.isPointInRect(designX, designY, btnX, btnY, 45, 28) then
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

    -- Hero selection (design coordinates)
    local heroesX = 360
    local heroesY = 85
    local heroesWidth = 320

    local restingIndex = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            local hy = heroesY + restingIndex * 50
            if Components.isPointInRect(designX, designY, heroesX, hy, heroesWidth, 45) then
                selectedHero = hero.id
                return nil
            end
            restingIndex = restingIndex + 1
        end
    end

    return nil
end

return PotionMenu
