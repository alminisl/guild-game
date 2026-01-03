-- Recipes Data Module
-- Crafting recipes for equipment and material upgrades

local Recipes = {}

-- Recipe categories
Recipes.categories = {
    weapon = "Weapons",
    armor = "Armor",
    accessory = "Accessories",
    material = "Materials"
}

-- All crafting recipes
Recipes.list = {
    -- ═══════════════════════════════════════════
    -- MATERIAL UPGRADES (3 common -> 1 uncommon)
    -- ═══════════════════════════════════════════
    {
        id = "refine_iron",
        name = "Refine Iron",
        category = "material",
        result = "iron_ingot",
        resultType = "material",
        resultCount = 1,
        requiredRank = "D",
        materials = {
            {id = "copper_ore", amount = 3}
        },
        description = "Smelt copper into iron"
    },
    {
        id = "tan_leather",
        name = "Tan Leather",
        category = "material",
        result = "quality_leather",
        resultType = "material",
        resultCount = 1,
        requiredRank = "D",
        materials = {
            {id = "leather_scrap", amount = 3}
        },
        description = "Process leather scraps"
    },
    {
        id = "forge_steel",
        name = "Forge Steel",
        category = "material",
        result = "steel_bar",
        resultType = "material",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "iron_ingot", amount = 2},
            {id = "rough_stone", amount = 2}
        },
        description = "Alloy iron into steel"
    },

    -- ═══════════════════════════════════════════
    -- WEAPONS - C Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_iron_sword",
        name = "Iron Sword",
        category = "weapon",
        result = "iron_sword",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "iron_ingot", amount = 2},
            {id = "quality_leather", amount = 1}
        },
        description = "A solid iron blade"
    },
    {
        id = "craft_hunters_bow",
        name = "Hunter's Bow",
        category = "weapon",
        result = "hunters_bow",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "quality_leather", amount = 2},
            {id = "iron_ingot", amount = 1}
        },
        description = "Accurate and reliable"
    },
    {
        id = "craft_mage_staff",
        name = "Mage Staff",
        category = "weapon",
        result = "mage_staff",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "iron_ingot", amount = 1},
            {id = "rough_stone", amount = 3}
        },
        description = "Channels arcane energy"
    },

    -- ═══════════════════════════════════════════
    -- WEAPONS - B Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_steel_blade",
        name = "Steel Blade",
        category = "weapon",
        result = "steel_blade",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "steel_bar", amount = 2},
            {id = "iron_ingot", amount = 1},
            {id = "quality_leather", amount = 1}
        },
        description = "A masterwork steel sword"
    },
    {
        id = "craft_composite_bow",
        name = "Composite Bow",
        category = "weapon",
        result = "composite_bow",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "steel_bar", amount = 1},
            {id = "quality_leather", amount = 3}
        },
        description = "Powerful and precise"
    },
    {
        id = "craft_arcane_staff",
        name = "Arcane Staff",
        category = "weapon",
        result = "arcane_staff",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "steel_bar", amount = 1},
            {id = "iron_ingot", amount = 2},
            {id = "enchanted_gem", amount = 1}
        },
        description = "Hums with magical power"
    },

    -- ═══════════════════════════════════════════
    -- WEAPONS - A Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_mithril_sword",
        name = "Mithril Sword",
        category = "weapon",
        result = "mithril_sword",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "mithril_shard", amount = 2},
            {id = "steel_bar", amount = 1},
            {id = "enchanted_gem", amount = 1}
        },
        description = "Light yet incredibly strong"
    },
    {
        id = "craft_dragonbone_bow",
        name = "Dragonbone Bow",
        category = "weapon",
        result = "dragonbone_bow",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "dragon_scale", amount = 2},
            {id = "quality_leather", amount = 2},
            {id = "mithril_shard", amount = 1}
        },
        description = "Made from dragon remains"
    },
    {
        id = "craft_staff_of_power",
        name = "Staff of Power",
        category = "weapon",
        result = "staff_of_power",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "mithril_shard", amount = 2},
            {id = "enchanted_gem", amount = 2}
        },
        description = "Radiates immense power"
    },

    -- ═══════════════════════════════════════════
    -- ARMOR - C Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_iron_chainmail",
        name = "Iron Chainmail",
        category = "armor",
        result = "iron_chainmail",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "iron_ingot", amount = 3},
            {id = "quality_leather", amount = 1}
        },
        description = "Interlocked iron rings"
    },
    {
        id = "craft_ranger_leather",
        name = "Ranger Leather",
        category = "armor",
        result = "ranger_leather",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "quality_leather", amount = 3},
            {id = "iron_ingot", amount = 1}
        },
        description = "Supple and protective"
    },
    {
        id = "craft_enchanted_robe",
        name = "Enchanted Robe",
        category = "armor",
        result = "enchanted_robe",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "quality_leather", amount = 2},
            {id = "rough_stone", amount = 2}
        },
        description = "Magically reinforced"
    },

    -- ═══════════════════════════════════════════
    -- ARMOR - B Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_steel_plate",
        name = "Steel Plate",
        category = "armor",
        result = "steel_plate",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "steel_bar", amount = 3},
            {id = "iron_ingot", amount = 2}
        },
        description = "Heavy steel armor"
    },
    {
        id = "craft_shadow_leather",
        name = "Shadow Leather",
        category = "armor",
        result = "shadow_leather",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "quality_leather", amount = 4},
            {id = "steel_bar", amount = 1}
        },
        description = "Darkened for stealth"
    },

    -- ═══════════════════════════════════════════
    -- ARMOR - A Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_mithril_armor",
        name = "Mithril Armor",
        category = "armor",
        result = "mithril_armor",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "mithril_shard", amount = 3},
            {id = "steel_bar", amount = 2}
        },
        description = "Light as cloth, strong as steel"
    },
    {
        id = "craft_dragon_scale_armor",
        name = "Dragon Scale Armor",
        category = "armor",
        result = "dragon_scale_armor",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "dragon_scale", amount = 4},
            {id = "mithril_shard", amount = 2}
        },
        description = "Nearly impenetrable"
    },
    {
        id = "craft_archmage_robe",
        name = "Archmage Robe",
        category = "armor",
        result = "archmage_robe",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "quality_leather", amount = 2},
            {id = "enchanted_gem", amount = 2},
            {id = "mithril_shard", amount = 1}
        },
        description = "Worn by master wizards"
    },

    -- ═══════════════════════════════════════════
    -- ACCESSORIES - C Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_iron_bracers",
        name = "Iron Bracers",
        category = "accessory",
        result = "iron_bracers",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "iron_ingot", amount = 2},
            {id = "quality_leather", amount = 1}
        },
        description = "Sturdy arm protection"
    },
    {
        id = "craft_swift_boots",
        name = "Swift Boots",
        category = "accessory",
        result = "swift_boots",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "quality_leather", amount = 2},
            {id = "iron_ingot", amount = 1}
        },
        description = "Move like the wind"
    },
    {
        id = "craft_mana_crystal",
        name = "Mana Crystal",
        category = "accessory",
        result = "mana_crystal",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "C",
        materials = {
            {id = "rough_stone", amount = 3},
            {id = "iron_ingot", amount = 1}
        },
        description = "Stores magical energy"
    },

    -- ═══════════════════════════════════════════
    -- ACCESSORIES - B Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_ring_of_fortune",
        name = "Ring of Fortune",
        category = "accessory",
        result = "ring_of_fortune",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "enchanted_gem", amount = 1},
            {id = "mithril_shard", amount = 1}
        },
        description = "Fortune favors the wearer"
    },
    {
        id = "craft_warriors_medallion",
        name = "Warrior's Medallion",
        category = "accessory",
        result = "warriors_medallion",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "steel_bar", amount = 2},
            {id = "quality_leather", amount = 1}
        },
        description = "Symbol of martial prowess"
    },

    -- ═══════════════════════════════════════════
    -- ACCESSORIES - A Rank
    -- ═══════════════════════════════════════════
    {
        id = "craft_champions_amulet",
        name = "Champion's Amulet",
        category = "accessory",
        result = "champions_amulet",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "dragon_scale", amount = 1},
            {id = "enchanted_gem", amount = 2}
        },
        description = "For legendary heroes"
    },
    {
        id = "craft_dragon_heart",
        name = "Dragon Heart",
        category = "accessory",
        result = "dragon_heart",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "dragon_scale", amount = 3},
            {id = "mithril_shard", amount = 1}
        },
        description = "Pulses with draconic power"
    },
    {
        id = "craft_arcane_focus",
        name = "Arcane Focus",
        category = "accessory",
        result = "arcane_focus",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "A",
        materials = {
            {id = "enchanted_gem", amount = 3},
            {id = "mithril_shard", amount = 1}
        },
        description = "Amplifies magical ability"
    },

    -- ═══════════════════════════════════════════
    -- SPECIAL ITEMS
    -- ═══════════════════════════════════════════
    {
        id = "craft_phoenix_feather",
        name = "Phoenix Feather",
        category = "accessory",
        result = "phoenix_feather",
        resultType = "equipment",
        resultCount = 1,
        requiredRank = "B",
        materials = {
            {id = "dragon_scale", amount = 1},
            {id = "enchanted_gem", amount = 1},
            {id = "mithril_shard", amount = 1}
        },
        description = "Revives hero on death (consumed)"
    }
}

-- Rank values for comparison
local rankValues = {D = 1, C = 2, B = 3, A = 4, S = 5}

-- Get recipe by ID
function Recipes.get(id)
    for _, recipe in ipairs(Recipes.list) do
        if recipe.id == id then
            return recipe
        end
    end
    return nil
end

-- Get all recipes by category
function Recipes.getByCategory(category)
    local result = {}
    for _, recipe in ipairs(Recipes.list) do
        if recipe.category == category then
            table.insert(result, recipe)
        end
    end
    return result
end

-- Check if player has materials for a recipe
function Recipes.canCraft(recipe, inventory)
    for _, req in ipairs(recipe.materials) do
        local have = inventory.materials[req.id] or 0
        if have < req.amount then
            return false
        end
    end
    return true
end

-- Check if guild rank allows crafting
function Recipes.meetsRankRequirement(recipe, guildLevel)
    -- Guild levels unlock rank tiers
    local guildMaxRank = {
        [1] = "D", [2] = "D",
        [3] = "C", [4] = "C",
        [5] = "B", [6] = "B",
        [7] = "A", [8] = "A",
        [9] = "S", [10] = "S"
    }

    local maxRank = guildMaxRank[guildLevel] or "D"
    local recipeRankValue = rankValues[recipe.requiredRank] or 1
    local maxRankValue = rankValues[maxRank] or 1

    return recipeRankValue <= maxRankValue
end

-- Get missing materials for a recipe
function Recipes.getMissing(recipe, inventory)
    local missing = {}
    for _, req in ipairs(recipe.materials) do
        local have = inventory.materials[req.id] or 0
        if have < req.amount then
            table.insert(missing, {
                id = req.id,
                need = req.amount,
                have = have,
                short = req.amount - have
            })
        end
    end
    return missing
end

return Recipes
