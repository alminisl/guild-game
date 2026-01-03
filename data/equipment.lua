-- Equipment Data Module
-- Equipment definitions for weapons, armor, and accessories

local Equipment = {}

-- Equipment slots
Equipment.slots = {"weapon", "armor", "accessory"}

-- Slot display names
Equipment.slotNames = {
    weapon = "Weapon",
    armor = "Armor",
    accessory = "Accessory"
}

-- Equipment tiers
Equipment.tierOrder = {"basic", "crafted"}

-- Rank values for comparison
Equipment.rankValues = {
    D = 1,
    C = 2,
    B = 3,
    A = 4,
    S = 5
}

-- All equipment definitions
Equipment.items = {
    -- ═══════════════════════════════════════════
    -- WEAPONS - Basic (Shop)
    -- ═══════════════════════════════════════════
    rusty_sword = {
        id = "rusty_sword",
        name = "Rusty Sword",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        cost = 50,
        stats = {str = 2, dex = 0, int = 0, vit = 0, luck = 0},
        description = "A worn but functional blade"
    },
    wooden_bow = {
        id = "wooden_bow",
        name = "Wooden Bow",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        cost = 45,
        stats = {str = 0, dex = 2, int = 0, vit = 0, luck = 1},
        description = "A simple hunting bow"
    },
    apprentice_staff = {
        id = "apprentice_staff",
        name = "Apprentice Staff",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        cost = 55,
        stats = {str = 0, dex = 0, int = 3, vit = 0, luck = 0},
        description = "A basic magical focus"
    },
    worn_dagger = {
        id = "worn_dagger",
        name = "Worn Dagger",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        cost = 40,
        stats = {str = 1, dex = 1, int = 0, vit = 0, luck = 1},
        description = "Quick and versatile"
    },

    -- ═══════════════════════════════════════════
    -- WEAPONS - Crafted
    -- ═══════════════════════════════════════════
    iron_sword = {
        id = "iron_sword",
        name = "Iron Sword",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        stats = {str = 4, dex = 1, int = 0, vit = 0, luck = 0},
        description = "A solid iron blade"
    },
    hunters_bow = {
        id = "hunters_bow",
        name = "Hunter's Bow",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        stats = {str = 0, dex = 4, int = 0, vit = 0, luck = 1},
        description = "Accurate and reliable"
    },
    mage_staff = {
        id = "mage_staff",
        name = "Mage Staff",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        stats = {str = 0, dex = 0, int = 5, vit = 0, luck = 1},
        description = "Channels arcane energy"
    },
    steel_blade = {
        id = "steel_blade",
        name = "Steel Blade",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        stats = {str = 6, dex = 2, int = 0, vit = 0, luck = 0},
        description = "A masterwork steel sword"
    },
    composite_bow = {
        id = "composite_bow",
        name = "Composite Bow",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        stats = {str = 1, dex = 6, int = 0, vit = 0, luck = 2},
        description = "Powerful and precise"
    },
    arcane_staff = {
        id = "arcane_staff",
        name = "Arcane Staff",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        stats = {str = 0, dex = 1, int = 7, vit = 0, luck = 1},
        description = "Hums with magical power"
    },
    mithril_sword = {
        id = "mithril_sword",
        name = "Mithril Sword",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        stats = {str = 8, dex = 3, int = 0, vit = 0, luck = 2},
        description = "Light yet incredibly strong"
    },
    dragonbone_bow = {
        id = "dragonbone_bow",
        name = "Dragonbone Bow",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        stats = {str = 2, dex = 8, int = 0, vit = 0, luck = 3},
        description = "Made from dragon remains"
    },
    staff_of_power = {
        id = "staff_of_power",
        name = "Staff of Power",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        stats = {str = 0, dex = 2, int = 10, vit = 0, luck = 2},
        description = "Radiates immense power"
    },

    -- ═══════════════════════════════════════════
    -- ARMOR - Basic (Shop)
    -- ═══════════════════════════════════════════
    leather_vest = {
        id = "leather_vest",
        name = "Leather Vest",
        slot = "armor",
        tier = "basic",
        rank = "D",
        cost = 40,
        stats = {str = 0, dex = 1, int = 0, vit = 2, luck = 0},
        description = "Basic leather protection"
    },
    cloth_robe = {
        id = "cloth_robe",
        name = "Cloth Robe",
        slot = "armor",
        tier = "basic",
        rank = "D",
        cost = 35,
        stats = {str = 0, dex = 0, int = 2, vit = 1, luck = 0},
        description = "Comfortable mage attire"
    },
    padded_armor = {
        id = "padded_armor",
        name = "Padded Armor",
        slot = "armor",
        tier = "basic",
        rank = "D",
        cost = 45,
        stats = {str = 1, dex = 0, int = 0, vit = 2, luck = 0},
        description = "Quilted protection"
    },

    -- ═══════════════════════════════════════════
    -- ARMOR - Crafted
    -- ═══════════════════════════════════════════
    iron_chainmail = {
        id = "iron_chainmail",
        name = "Iron Chainmail",
        slot = "armor",
        tier = "crafted",
        rank = "C",
        stats = {str = 1, dex = 0, int = 0, vit = 4, luck = 0},
        description = "Interlocked iron rings"
    },
    ranger_leather = {
        id = "ranger_leather",
        name = "Ranger Leather",
        slot = "armor",
        tier = "crafted",
        rank = "C",
        stats = {str = 0, dex = 3, int = 0, vit = 3, luck = 0},
        description = "Supple and protective"
    },
    enchanted_robe = {
        id = "enchanted_robe",
        name = "Enchanted Robe",
        slot = "armor",
        tier = "crafted",
        rank = "C",
        stats = {str = 0, dex = 0, int = 4, vit = 2, luck = 0},
        description = "Magically reinforced"
    },
    steel_plate = {
        id = "steel_plate",
        name = "Steel Plate",
        slot = "armor",
        tier = "crafted",
        rank = "B",
        stats = {str = 2, dex = 0, int = 0, vit = 6, luck = 0},
        description = "Heavy steel armor"
    },
    shadow_leather = {
        id = "shadow_leather",
        name = "Shadow Leather",
        slot = "armor",
        tier = "crafted",
        rank = "B",
        stats = {str = 0, dex = 5, int = 0, vit = 4, luck = 1},
        description = "Darkened for stealth"
    },
    mithril_armor = {
        id = "mithril_armor",
        name = "Mithril Armor",
        slot = "armor",
        tier = "crafted",
        rank = "A",
        stats = {str = 3, dex = 2, int = 0, vit = 8, luck = 0},
        description = "Light as cloth, strong as steel"
    },
    dragon_scale_armor = {
        id = "dragon_scale_armor",
        name = "Dragon Scale Armor",
        slot = "armor",
        tier = "crafted",
        rank = "A",
        stats = {str = 4, dex = 0, int = 0, vit = 10, luck = 3},
        description = "Nearly impenetrable"
    },
    archmage_robe = {
        id = "archmage_robe",
        name = "Archmage Robe",
        slot = "armor",
        tier = "crafted",
        rank = "A",
        stats = {str = 0, dex = 2, int = 8, vit = 4, luck = 2},
        description = "Worn by master wizards"
    },

    -- ═══════════════════════════════════════════
    -- ACCESSORIES - Basic (Shop)
    -- ═══════════════════════════════════════════
    lucky_charm = {
        id = "lucky_charm",
        name = "Lucky Charm",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        cost = 35,
        stats = {str = 0, dex = 0, int = 0, vit = 0, luck = 3},
        description = "A simple good luck trinket"
    },
    strength_ring = {
        id = "strength_ring",
        name = "Strength Ring",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        cost = 40,
        stats = {str = 2, dex = 0, int = 0, vit = 0, luck = 0},
        description = "Enhances physical power"
    },
    agility_boots = {
        id = "agility_boots",
        name = "Agility Boots",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        cost = 40,
        stats = {str = 0, dex = 2, int = 0, vit = 0, luck = 0},
        description = "Light and nimble footwear"
    },
    scholars_pendant = {
        id = "scholars_pendant",
        name = "Scholar's Pendant",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        cost = 45,
        stats = {str = 0, dex = 0, int = 2, vit = 0, luck = 0},
        description = "Sharpens the mind"
    },

    -- ═══════════════════════════════════════════
    -- ACCESSORIES - Crafted
    -- ═══════════════════════════════════════════
    iron_bracers = {
        id = "iron_bracers",
        name = "Iron Bracers",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        stats = {str = 2, dex = 0, int = 0, vit = 2, luck = 0},
        description = "Sturdy arm protection"
    },
    swift_boots = {
        id = "swift_boots",
        name = "Swift Boots",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        stats = {str = 0, dex = 3, int = 0, vit = 0, luck = 2},
        description = "Move like the wind"
    },
    mana_crystal = {
        id = "mana_crystal",
        name = "Mana Crystal",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        stats = {str = 0, dex = 0, int = 4, vit = 0, luck = 1},
        description = "Stores magical energy"
    },
    ring_of_fortune = {
        id = "ring_of_fortune",
        name = "Ring of Fortune",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        stats = {str = 0, dex = 0, int = 2, vit = 0, luck = 5},
        description = "Fortune favors the wearer"
    },
    warriors_medallion = {
        id = "warriors_medallion",
        name = "Warrior's Medallion",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        stats = {str = 4, dex = 0, int = 0, vit = 3, luck = 0},
        description = "Symbol of martial prowess"
    },
    champions_amulet = {
        id = "champions_amulet",
        name = "Champion's Amulet",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        stats = {str = 3, dex = 3, int = 0, vit = 3, luck = 3},
        description = "For legendary heroes"
    },
    dragon_heart = {
        id = "dragon_heart",
        name = "Dragon Heart",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        stats = {str = 5, dex = 0, int = 0, vit = 5, luck = 4},
        description = "Pulses with draconic power"
    },
    arcane_focus = {
        id = "arcane_focus",
        name = "Arcane Focus",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        stats = {str = 0, dex = 2, int = 8, vit = 0, luck = 3},
        description = "Amplifies magical ability"
    },

    -- Special: Revival item (consumed on death)
    phoenix_feather = {
        id = "phoenix_feather",
        name = "Phoenix Feather",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        stats = {str = 0, dex = 0, int = 0, vit = 2, luck = 5},
        description = "Revives hero on death (consumed)",
        special = "revive" -- Special flag for revival effect
    }
}

-- Get equipment by ID
function Equipment.get(id)
    return Equipment.items[id]
end

-- Get all shop items (basic tier)
function Equipment.getShopItems()
    local items = {}
    for id, item in pairs(Equipment.items) do
        if item.tier == "basic" then
            table.insert(items, item)
        end
    end
    -- Sort by slot then by cost
    table.sort(items, function(a, b)
        if a.slot ~= b.slot then
            local slotOrder = {weapon = 1, armor = 2, accessory = 3}
            return slotOrder[a.slot] < slotOrder[b.slot]
        end
        return a.cost < b.cost
    end)
    return items
end

-- Get items by slot
function Equipment.getBySlot(slot)
    local items = {}
    for id, item in pairs(Equipment.items) do
        if item.slot == slot then
            table.insert(items, item)
        end
    end
    return items
end

-- Check if hero can equip item (rank check)
function Equipment.canEquip(hero, equipmentId)
    local item = Equipment.items[equipmentId]
    if not item then return false, "Item not found" end

    local heroRank = Equipment.rankValues[hero.rank] or 1
    local itemRank = Equipment.rankValues[item.rank] or 1

    if heroRank < itemRank then
        return false, "Requires " .. item.rank .. "-rank hero"
    end

    return true
end

-- Format stat bonuses for display
function Equipment.formatStats(item)
    local parts = {}
    local statNames = {str = "STR", dex = "DEX", int = "INT", vit = "VIT", luck = "LCK"}
    local statOrder = {"str", "dex", "int", "vit", "luck"}

    for _, stat in ipairs(statOrder) do
        local value = item.stats[stat]
        if value and value > 0 then
            table.insert(parts, statNames[stat] .. "+" .. value)
        end
    end

    return table.concat(parts, " ")
end

-- Get total stat bonus from equipped item
function Equipment.getStatBonus(item, statName)
    if not item or not item.stats then return 0 end
    return item.stats[statName] or 0
end

return Equipment
