-- Items Data Module
-- Potions, food, and consumables

local Items = {}

-- Item definitions
Items.list = {
    -- Rest recovery items
    {
        id = "stamina_potion",
        name = "Stamina Potion",
        description = "Instantly restores a hero",
        category = "potion",
        cost = 30,
        effect = "instant_rest",
        effectValue = 1,  -- Fully restore
        icon = "potion_red"
    },
    {
        id = "energy_drink",
        name = "Energy Tonic",
        description = "Speeds up rest by 2x",
        category = "potion",
        cost = 15,
        effect = "rest_speed",
        effectValue = 2,  -- 2x speed
        icon = "potion_green"
    },
    {
        id = "tavern_meal",
        name = "Hearty Meal",
        description = "Good food speeds rest by 1.5x",
        category = "food",
        cost = 10,
        effect = "rest_speed",
        effectValue = 1.5,
        icon = "food"
    },
    {
        id = "inn_room",
        name = "Inn Room",
        description = "Comfortable rest, 3x speed",
        category = "lodging",
        cost = 25,
        effect = "rest_speed",
        effectValue = 3,
        icon = "bed"
    },
    {
        id = "vigor_elixir",
        name = "Vigor Elixir",
        description = "Fully restores entire party",
        category = "potion",
        cost = 100,
        effect = "instant_rest_all",
        effectValue = 1,
        icon = "potion_gold"
    }
}

-- Get item by ID
function Items.getById(itemId)
    for _, item in ipairs(Items.list) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

-- Get items by category
function Items.getByCategory(category)
    local result = {}
    for _, item in ipairs(Items.list) do
        if item.category == category then
            table.insert(result, item)
        end
    end
    return result
end

-- Apply item effect to a hero
function Items.applyToHero(item, hero, Heroes)
    if item.effect == "instant_rest" then
        Heroes.finishResting(hero)
        return true, hero.name .. " is fully restored!"
    elseif item.effect == "rest_speed" then
        if hero.status == "resting" then
            Heroes.applyRestBonus(hero, item.effectValue)
            return true, hero.name .. "'s rest speed increased!"
        else
            return false, hero.name .. " is not resting"
        end
    end
    return false, "Cannot use this item"
end

-- Apply item effect to all resting heroes
function Items.applyToAllResting(item, gameData, Heroes)
    local count = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            if item.effect == "instant_rest_all" then
                Heroes.finishResting(hero)
                count = count + 1
            elseif item.effect == "rest_speed" then
                Heroes.applyRestBonus(hero, item.effectValue)
                count = count + 1
            end
        end
    end
    if count > 0 then
        return true, count .. " heroes affected!"
    else
        return false, "No resting heroes"
    end
end

return Items
