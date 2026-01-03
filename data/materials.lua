-- Materials Data Module
-- Material definitions and drop tables for the crafting system

local Materials = {}

-- Material tiers with their drop weights and display colors
Materials.tiers = {
    common = {
        dropWeight = 70,
        color = {0.6, 0.5, 0.4},
        name = "Common"
    },
    uncommon = {
        dropWeight = 25,
        color = {0.5, 0.65, 0.8},
        name = "Uncommon"
    },
    rare = {
        dropWeight = 5,
        color = {0.7, 0.5, 0.85},
        name = "Rare"
    }
}

-- Material definitions
Materials.items = {
    -- COMMON TIER
    copper_ore = {
        id = "copper_ore",
        name = "Copper Ore",
        tier = "common",
        description = "Raw copper from mines",
        icon = "ore"
    },
    leather_scrap = {
        id = "leather_scrap",
        name = "Leather Scrap",
        tier = "common",
        description = "Basic crafting leather",
        icon = "leather"
    },
    rough_stone = {
        id = "rough_stone",
        name = "Rough Stone",
        tier = "common",
        description = "Common stone fragment",
        icon = "stone"
    },

    -- UNCOMMON TIER
    iron_ingot = {
        id = "iron_ingot",
        name = "Iron Ingot",
        tier = "uncommon",
        description = "Refined iron metal",
        icon = "ingot"
    },
    steel_bar = {
        id = "steel_bar",
        name = "Steel Bar",
        tier = "uncommon",
        description = "High-quality steel alloy",
        icon = "ingot"
    },
    quality_leather = {
        id = "quality_leather",
        name = "Quality Leather",
        tier = "uncommon",
        description = "Fine tanned leather",
        icon = "leather"
    },

    -- RARE TIER
    mithril_shard = {
        id = "mithril_shard",
        name = "Mithril Shard",
        tier = "rare",
        description = "Magical silver-blue metal",
        icon = "gem"
    },
    dragon_scale = {
        id = "dragon_scale",
        name = "Dragon Scale",
        tier = "rare",
        description = "Scale from a mighty dragon",
        icon = "scale"
    },
    enchanted_gem = {
        id = "enchanted_gem",
        name = "Enchanted Gem",
        tier = "rare",
        description = "A gem pulsing with magic",
        icon = "gem"
    }
}

-- Drop tables: base number of materials by quest rank
Materials.dropTables = {
    D = {common = 3, uncommon = 0, rare = 0},
    C = {common = 2, uncommon = 1, rare = 0},
    B = {common = 1, uncommon = 2, rare = 0},
    A = {common = 0, uncommon = 2, rare = 1},
    S = {common = 0, uncommon = 1, rare = 2}
}

-- Get all materials of a specific tier
function Materials.getByTier(tier)
    local result = {}
    for id, material in pairs(Materials.items) do
        if material.tier == tier then
            table.insert(result, material)
        end
    end
    return result
end

-- Get material by ID
function Materials.get(id)
    return Materials.items[id]
end

-- Calculate material drops from a quest
-- Returns a table of {material_id = count}
function Materials.calculateDrops(quest, heroes, EquipmentSystem)
    local drops = {}

    -- Get base drop counts for quest rank
    local baseDrop = Materials.dropTables[quest.rank]
    if not baseDrop then return drops end

    -- Calculate total party luck (including equipment bonuses)
    local totalLuck = 0
    for _, hero in ipairs(heroes) do
        local baseLuck = hero.stats.luck
        local equipLuck = 0
        if EquipmentSystem then
            equipLuck = EquipmentSystem.getStatBonus(hero, "luck")
        end
        totalLuck = totalLuck + baseLuck + equipLuck
    end
    local avgLuck = #heroes > 0 and (totalLuck / #heroes) or 8

    -- Luck multiplier: +5% per point above 8, clamped 0.5-2.0
    local luckMultiplier = 1.0 + (avgLuck - 8) * 0.05
    luckMultiplier = math.max(0.5, math.min(2.0, luckMultiplier))

    -- Material bonus multiplier for tagged quests (caves/mines)
    local questMultiplier = quest.material_bonus and 1.5 or 1.0

    -- Calculate drops for each tier
    for tier, baseCount in pairs(baseDrop) do
        if baseCount > 0 then
            -- Apply multipliers
            local finalCount = baseCount * luckMultiplier * questMultiplier

            -- Round and add small variance (+/- 1)
            finalCount = math.floor(finalCount + 0.5)
            finalCount = finalCount + math.random(-1, 1)
            finalCount = math.max(0, finalCount)

            if finalCount > 0 then
                -- Pick random materials from this tier
                local tieredMaterials = Materials.getByTier(tier)
                if #tieredMaterials > 0 then
                    for i = 1, finalCount do
                        local mat = tieredMaterials[math.random(#tieredMaterials)]
                        drops[mat.id] = (drops[mat.id] or 0) + 1
                    end
                end
            end
        end
    end

    return drops
end

-- Format materials for display
function Materials.formatDrops(drops)
    local parts = {}
    for id, count in pairs(drops) do
        local mat = Materials.items[id]
        if mat then
            table.insert(parts, mat.name .. " x" .. count)
        end
    end
    return table.concat(parts, ", ")
end

-- Get total count of drops
function Materials.getTotalDropCount(drops)
    local total = 0
    for _, count in pairs(drops) do
        total = total + count
    end
    return total
end

return Materials
