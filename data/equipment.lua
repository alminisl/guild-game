-- Equipment Data Module
-- Equipment definitions for weapons, armor, and accessories
-- Balanced using stat budget system to prevent power creep

local Equipment = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- STAT BUDGET SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
-- Items are balanced using a budget system:
-- Base Budget = rankValue × 3
-- Slot Multipliers: weapon=1.0, armor=0.9, accessory=0.7, mount=0.5
-- Luck costs 1.5× (meta-stat that affects economy/survival)
-- ═══════════════════════════════════════════════════════════════════════════

-- Budget configuration (scaled to 1-100 stat system)
Equipment.budgetConfig = {
    rankBudget = {
        D = 8,
        C = 15,
        B = 22,
        A = 28,
        S = 35
    },
    slotMultiplier = {
        weapon = 1.0,
        armor = 0.85,
        accessory = 0.55,
        mount = 0.35
    },
    statWeight = {
        str = 1.0,
        dex = 1.0,
        int = 1.0,
        vit = 1.0,
        luck = 1.5  -- Luck is weighted higher (affects gold, drops, survival)
    }
}

-- Rarity configuration (affects drop rates and budget usage)
Equipment.rarityConfig = {
    common = {
        budgetUsage = 0.65,  -- Uses 65% of max budget
        dropWeight = 70,
        color = {0.7, 0.7, 0.7}  -- Gray
    },
    uncommon = {
        budgetUsage = 0.80,  -- Uses 80% of max budget
        dropWeight = 25,
        color = {0.2, 0.8, 0.2}  -- Green
    },
    rare = {
        budgetUsage = 0.95,  -- Uses 95% of max budget
        dropWeight = 5,
        color = {0.2, 0.4, 1.0}  -- Blue
    },
    epic = {
        budgetUsage = 1.0,   -- Full budget + special effect
        dropWeight = 0,      -- Boss/raid only
        color = {0.6, 0.2, 0.8}  -- Purple
    }
}

-- Equipment slots
Equipment.slots = {"weapon", "armor", "accessory", "mount"}

-- Slot display names
Equipment.slotNames = {
    weapon = "Weapon",
    armor = "Armor",
    accessory = "Accessory",
    mount = "Mount"
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

-- ═══════════════════════════════════════════════════════════════════════════
-- STAT BUDGET VALIDATOR
-- ═══════════════════════════════════════════════════════════════════════════

-- Calculate the weighted stat total for an item
function Equipment.calculateStatBudget(item)
    local total = 0
    if not item.stats then return 0 end

    for stat, value in pairs(item.stats) do
        local weight = Equipment.budgetConfig.statWeight[stat] or 1.0
        total = total + (value * weight)
    end
    return total
end

-- Get maximum allowed budget for an item
function Equipment.getMaxBudget(rank, slot)
    local baseBudget = Equipment.budgetConfig.rankBudget[rank] or 3
    local multiplier = Equipment.budgetConfig.slotMultiplier[slot] or 1.0
    return baseBudget * multiplier
end

-- Validate an item's stat budget
function Equipment.validateItem(item)
    local maxBudget = Equipment.getMaxBudget(item.rank, item.slot)
    local usedBudget = Equipment.calculateStatBudget(item)

    return {
        valid = usedBudget <= maxBudget,
        usedBudget = usedBudget,
        maxBudget = maxBudget,
        overage = usedBudget - maxBudget,
        itemId = item.id
    }
end

-- Validate all items and return report
function Equipment.validateAllItems()
    local report = {
        valid = {},
        invalid = {},
        totalChecked = 0
    }

    for id, item in pairs(Equipment.items) do
        local result = Equipment.validateItem(item)
        result.itemId = id
        result.itemName = item.name

        if result.valid then
            table.insert(report.valid, result)
        else
            table.insert(report.invalid, result)
        end
        report.totalChecked = report.totalChecked + 1
    end

    return report
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EQUIPMENT DEFINITIONS (Scaled to 1-100 stat system)
-- ═══════════════════════════════════════════════════════════════════════════
-- Budget Reference:
-- D: weapon=8, armor=6.8, accessory=4.4, mount=2.8
-- C: weapon=15, armor=12.75, accessory=8.25, mount=5.25
-- B: weapon=22, armor=18.7, accessory=12.1, mount=7.7
-- A: weapon=28, armor=23.8, accessory=15.4, mount=9.8
-- S: weapon=35, armor=29.75, accessory=19.25, mount=12.25
-- ═══════════════════════════════════════════════════════════════════════════

Equipment.items = {
    -- ═══════════════════════════════════════════
    -- D-RANK WEAPONS (Budget: 8)
    -- Shop items - single stat focus, +5 to +7 max
    -- ═══════════════════════════════════════════
    rusty_sword = {
        id = "rusty_sword",
        name = "Rusty Sword",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 50,
        stats = {str = 6},  -- Budget: 6/8
        description = "A worn but functional blade",
        powerWeight = 1.0
    },
    wooden_bow = {
        id = "wooden_bow",
        name = "Wooden Bow",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 45,
        stats = {dex = 6},  -- Budget: 6/8
        description = "A simple hunting bow",
        powerWeight = 1.0
    },
    apprentice_staff = {
        id = "apprentice_staff",
        name = "Apprentice Staff",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 55,
        stats = {int = 6},  -- Budget: 6/8
        description = "A basic magical focus",
        powerWeight = 1.0
    },
    worn_dagger = {
        id = "worn_dagger",
        name = "Worn Dagger",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 40,
        stats = {str = 3, dex = 3},  -- Budget: 6/8
        description = "Quick and versatile",
        powerWeight = 1.0
    },
    training_spear = {
        id = "training_spear",
        name = "Training Spear",
        slot = "weapon",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 48,
        stats = {str = 3, vit = 3},  -- Budget: 6/8
        description = "Reach and defense",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- D-RANK ARMOR (Budget: 6.8 ≈ 5-6)
    -- Defensive focus, no offense creep
    -- ═══════════════════════════════════════════
    leather_vest = {
        id = "leather_vest",
        name = "Leather Vest",
        slot = "armor",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 40,
        stats = {vit = 5},  -- Budget: 5/6.8
        description = "Basic leather protection",
        powerWeight = 1.0
    },
    cloth_robe = {
        id = "cloth_robe",
        name = "Cloth Robe",
        slot = "armor",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 35,
        stats = {int = 2, vit = 3},  -- Budget: 5/6.8
        description = "Comfortable mage attire",
        powerWeight = 1.0
    },
    padded_armor = {
        id = "padded_armor",
        name = "Padded Armor",
        slot = "armor",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 45,
        stats = {str = 2, vit = 3},  -- Budget: 5/6.8
        description = "Quilted protection",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- D-RANK ACCESSORIES (Budget: 4.4 ≈ 3-4)
    -- Helpers, not power items. Luck max 2.
    -- ═══════════════════════════════════════════
    lucky_charm = {
        id = "lucky_charm",
        name = "Lucky Charm",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 35,
        stats = {luck = 2},  -- Budget: 3/4.4
        description = "A simple good luck trinket",
        powerWeight = 1.0
    },
    strength_ring = {
        id = "strength_ring",
        name = "Strength Ring",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 40,
        stats = {str = 3},  -- Budget: 3/4.4
        description = "Slightly enhances physical power",
        powerWeight = 1.0
    },
    agility_boots = {
        id = "agility_boots",
        name = "Agility Boots",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 40,
        stats = {dex = 3},  -- Budget: 3/4.4
        description = "Light and nimble footwear",
        powerWeight = 1.0
    },
    scholars_pendant = {
        id = "scholars_pendant",
        name = "Scholar's Pendant",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 45,
        stats = {int = 3},  -- Budget: 3/4.4
        description = "Sharpens the mind slightly",
        powerWeight = 1.0
    },
    iron_band = {
        id = "iron_band",
        name = "Iron Band",
        slot = "accessory",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 38,
        stats = {vit = 3},  -- Budget: 3/4.4
        description = "Simple protective ring",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- C-RANK WEAPONS (Budget: 15)
    -- Multi-stat allowed, still focused
    -- ═══════════════════════════════════════════
    iron_sword = {
        id = "iron_sword",
        name = "Iron Sword",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {str = 10, dex = 3},  -- Budget: 13/15
        description = "A solid iron blade",
        powerWeight = 1.0
    },
    hunters_bow = {
        id = "hunters_bow",
        name = "Hunter's Bow",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {dex = 10, luck = 2},  -- Budget: 13/15
        description = "Accurate and reliable",
        powerWeight = 1.0
    },
    mage_staff = {
        id = "mage_staff",
        name = "Mage Staff",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {int = 12},  -- Budget: 12/15
        description = "Channels arcane energy",
        powerWeight = 1.0
    },
    steel_spear = {
        id = "steel_spear",
        name = "Steel Spear",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {str = 8, dex = 5},  -- Budget: 13/15
        description = "Balanced reach weapon",
        powerWeight = 1.0
    },
    silver_dagger = {
        id = "silver_dagger",
        name = "Silver Dagger",
        slot = "weapon",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {dex = 8, luck = 2},  -- Budget: 11/15
        description = "Quick silver blade",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- C-RANK ARMOR (Budget: 12.75 ≈ 11-12)
    -- ═══════════════════════════════════════════
    iron_chainmail = {
        id = "iron_chainmail",
        name = "Iron Chainmail",
        slot = "armor",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {str = 3, vit = 8},  -- Budget: 11/12.75
        description = "Interlocked iron rings",
        powerWeight = 1.0
    },
    ranger_leather = {
        id = "ranger_leather",
        name = "Ranger Leather",
        slot = "armor",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {dex = 5, vit = 5},  -- Budget: 10/12.75
        description = "Supple and protective",
        powerWeight = 1.0
    },
    enchanted_robe = {
        id = "enchanted_robe",
        name = "Enchanted Robe",
        slot = "armor",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {int = 7, vit = 4},  -- Budget: 11/12.75
        description = "Magically reinforced",
        powerWeight = 1.0
    },
    scout_garb = {
        id = "scout_garb",
        name = "Scout Garb",
        slot = "armor",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {dex = 7, vit = 3},  -- Budget: 10/12.75
        description = "Light and mobile",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- C-RANK ACCESSORIES (Budget: 8.25 ≈ 7-8)
    -- Luck paired, never stacked
    -- ═══════════════════════════════════════════
    iron_bracers = {
        id = "iron_bracers",
        name = "Iron Bracers",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {str = 4, vit = 3},  -- Budget: 7/8.25
        description = "Sturdy arm protection",
        powerWeight = 1.0
    },
    swift_boots = {
        id = "swift_boots",
        name = "Swift Boots",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {dex = 5, luck = 2},  -- Budget: 8/8.25
        description = "Move with agility",
        powerWeight = 1.0
    },
    mana_crystal = {
        id = "mana_crystal",
        name = "Mana Crystal",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {int = 7},  -- Budget: 7/8.25
        description = "Stores magical energy",
        powerWeight = 1.0
    },
    scouts_talisman = {
        id = "scouts_talisman",
        name = "Scout's Talisman",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {dex = 5, luck = 2},  -- Budget: 8/8.25
        description = "Enhances awareness",
        powerWeight = 1.0
    },
    vitality_pendant = {
        id = "vitality_pendant",
        name = "Vitality Pendant",
        slot = "accessory",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {vit = 7},  -- Budget: 7/8.25
        description = "Strengthens constitution",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- B-RANK WEAPONS (Budget: 22)
    -- ═══════════════════════════════════════════
    steel_blade = {
        id = "steel_blade",
        name = "Steel Blade",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {str = 15, dex = 5},  -- Budget: 20/22
        description = "A masterwork steel sword",
        powerWeight = 1.0
    },
    composite_bow = {
        id = "composite_bow",
        name = "Composite Bow",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {str = 3, dex = 14, luck = 2},  -- Budget: 20/22
        description = "Powerful and precise",
        powerWeight = 1.0
    },
    arcane_staff = {
        id = "arcane_staff",
        name = "Arcane Staff",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {dex = 3, int = 17},  -- Budget: 20/22
        description = "Hums with magical power",
        powerWeight = 1.0
    },
    battle_axe = {
        id = "battle_axe",
        name = "Battle Axe",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {str = 17, vit = 3},  -- Budget: 20/22
        description = "Heavy cleaving weapon",
        powerWeight = 1.0
    },
    assassin_blade = {
        id = "assassin_blade",
        name = "Assassin's Blade",
        slot = "weapon",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {dex = 12, luck = 4},  -- Budget: 18/22
        description = "Silent and deadly",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- B-RANK ARMOR (Budget: 18.7 ≈ 17-18)
    -- ═══════════════════════════════════════════
    steel_plate = {
        id = "steel_plate",
        name = "Steel Plate",
        slot = "armor",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {str = 4, vit = 13},  -- Budget: 17/18.7
        description = "Heavy steel armor",
        powerWeight = 1.0
    },
    shadow_leather = {
        id = "shadow_leather",
        name = "Shadow Leather",
        slot = "armor",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {dex = 9, vit = 6, luck = 2},  -- Budget: 18/18.7
        description = "Darkened for stealth",
        powerWeight = 1.0
    },
    battlemage_vestments = {
        id = "battlemage_vestments",
        name = "Battlemage Vestments",
        slot = "armor",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {int = 11, vit = 6},  -- Budget: 17/18.7
        description = "Combat-ready wizard robes",
        powerWeight = 1.0
    },
    knight_armor = {
        id = "knight_armor",
        name = "Knight's Armor",
        slot = "armor",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {str = 3, vit = 14},  -- Budget: 17/18.7
        description = "Full plate protection",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- B-RANK ACCESSORIES (Budget: 12.1 ≈ 10-11)
    -- ═══════════════════════════════════════════
    ring_of_fortune = {
        id = "ring_of_fortune",
        name = "Ring of Fortune",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {vit = 3, luck = 5},  -- Budget: 10.5/12.1
        description = "Fortune favors the wearer",
        powerWeight = 1.0
    },
    warriors_medallion = {
        id = "warriors_medallion",
        name = "Warrior's Medallion",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {str = 6, vit = 4},  -- Budget: 10/12.1
        description = "Symbol of martial prowess",
        powerWeight = 1.0
    },
    phoenix_feather = {
        id = "phoenix_feather",
        name = "Phoenix Feather",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        rarity = "epic",
        stats = {vit = 4, luck = 4},  -- Budget: 10/12.1
        description = "Revives hero on death (consumed)",
        special = "revive",
        powerWeight = 1.0
    },
    precision_lens = {
        id = "precision_lens",
        name = "Precision Lens",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {dex = 8, luck = 2},  -- Budget: 11/12.1
        description = "Enhances aim and focus",
        powerWeight = 1.0
    },
    mages_focus = {
        id = "mages_focus",
        name = "Mage's Focus",
        slot = "accessory",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {int = 10},  -- Budget: 10/12.1
        description = "Concentrates magical power",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- A-RANK WEAPONS (Budget: 28)
    -- ═══════════════════════════════════════════
    mithril_sword = {
        id = "mithril_sword",
        name = "Mithril Sword",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {str = 18, dex = 5, luck = 2},  -- Budget: 26/28
        description = "Light yet incredibly strong",
        powerWeight = 1.0
    },
    dragonbone_bow = {
        id = "dragonbone_bow",
        name = "Dragonbone Bow",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {str = 5, dex = 16, luck = 3},  -- Budget: 25.5/28
        description = "Made from dragon remains",
        powerWeight = 1.0
    },
    staff_of_power = {
        id = "staff_of_power",
        name = "Staff of Power",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {dex = 3, int = 20, luck = 2},  -- Budget: 26/28
        description = "Radiates immense power",
        powerWeight = 1.0
    },
    legendary_blade = {
        id = "legendary_blade",
        name = "Legendary Blade",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        rarity = "epic",
        stats = {str = 20, dex = 5},  -- Budget: 25/28
        description = "A blade of heroes past",
        powerWeight = 1.0
    },
    void_dagger = {
        id = "void_dagger",
        name = "Void Dagger",
        slot = "weapon",
        tier = "crafted",
        rank = "A",
        rarity = "epic",
        stats = {dex = 14, int = 5, luck = 4},  -- Budget: 25/28
        description = "Cuts through reality",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- A-RANK ARMOR (Budget: 23.8 ≈ 22-23)
    -- ═══════════════════════════════════════════
    mithril_armor = {
        id = "mithril_armor",
        name = "Mithril Armor",
        slot = "armor",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {str = 5, dex = 3, vit = 14},  -- Budget: 22/23.8
        description = "Light as cloth, strong as steel",
        powerWeight = 1.0
    },
    dragon_scale_armor = {
        id = "dragon_scale_armor",
        name = "Dragon Scale Armor",
        slot = "armor",
        tier = "crafted",
        rank = "A",
        rarity = "epic",
        stats = {str = 5, vit = 16, luck = 2},  -- Budget: 24/23.8 (epic can exceed slightly)
        description = "Nearly impenetrable",
        powerWeight = 1.0
    },
    archmage_robe = {
        id = "archmage_robe",
        name = "Archmage Robe",
        slot = "armor",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {int = 14, vit = 6, luck = 2},  -- Budget: 23/23.8
        description = "Worn by master wizards",
        powerWeight = 1.0
    },
    shadow_cloak = {
        id = "shadow_cloak",
        name = "Shadow Cloak",
        slot = "armor",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {dex = 12, vit = 6, luck = 2},  -- Budget: 21/23.8
        description = "Wraps the wearer in darkness",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- A-RANK ACCESSORIES (Budget: 15.4 ≈ 14-15)
    -- ═══════════════════════════════════════════
    champions_amulet = {
        id = "champions_amulet",
        name = "Champion's Amulet",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {str = 6, dex = 4, vit = 4},  -- Budget: 14/15.4
        description = "For legendary heroes",
        powerWeight = 1.0
    },
    dragon_heart = {
        id = "dragon_heart",
        name = "Dragon Heart",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        rarity = "epic",
        stats = {str = 6, vit = 6, luck = 2},  -- Budget: 15/15.4
        description = "Pulses with draconic power",
        powerWeight = 1.0
    },
    arcane_focus = {
        id = "arcane_focus",
        name = "Arcane Focus",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {int = 10, luck = 3},  -- Budget: 14.5/15.4
        description = "Amplifies magical ability",
        powerWeight = 1.0
    },
    hunters_eye = {
        id = "hunters_eye",
        name = "Hunter's Eye",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {dex = 9, luck = 3},  -- Budget: 13.5/15.4
        description = "Never miss your mark",
        powerWeight = 1.0
    },
    guardian_sigil = {
        id = "guardian_sigil",
        name = "Guardian Sigil",
        slot = "accessory",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {vit = 10, luck = 3},  -- Budget: 14.5/15.4
        description = "Protective ward",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- S-RANK WEAPONS (Budget: 35)
    -- Legendary items, very rare
    -- ═══════════════════════════════════════════
    excalibur = {
        id = "excalibur",
        name = "Excalibur",
        slot = "weapon",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {str = 24, dex = 5, vit = 4},  -- Budget: 33/35
        description = "The sword of kings",
        powerWeight = 1.0
    },
    celestial_bow = {
        id = "celestial_bow",
        name = "Celestial Bow",
        slot = "weapon",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {dex = 24, luck = 5},  -- Budget: 31.5/35
        description = "Arrows of starlight",
        powerWeight = 1.0
    },
    staff_of_the_cosmos = {
        id = "staff_of_the_cosmos",
        name = "Staff of the Cosmos",
        slot = "weapon",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {int = 26, vit = 5},  -- Budget: 31/35
        description = "Commands the universe",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- S-RANK ARMOR (Budget: 29.75 ≈ 28-29)
    -- ═══════════════════════════════════════════
    divine_plate = {
        id = "divine_plate",
        name = "Divine Plate",
        slot = "armor",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {str = 7, vit = 21},  -- Budget: 28/29.75
        description = "Blessed by the gods",
        powerWeight = 1.0
    },
    void_weave = {
        id = "void_weave",
        name = "Void Weave",
        slot = "armor",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {dex = 9, int = 9, vit = 9},  -- Budget: 27/29.75
        description = "Woven from nothingness",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- S-RANK ACCESSORIES (Budget: 19.25 ≈ 18-19)
    -- ═══════════════════════════════════════════
    crown_of_ages = {
        id = "crown_of_ages",
        name = "Crown of Ages",
        slot = "accessory",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {int = 12, vit = 4, luck = 2},  -- Budget: 19/19.25
        description = "Wisdom of millennia",
        powerWeight = 1.0
    },
    heart_of_the_world = {
        id = "heart_of_the_world",
        name = "Heart of the World",
        slot = "accessory",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {str = 6, vit = 8, luck = 3},  -- Budget: 18.5/19.25
        description = "Life force incarnate",
        powerWeight = 1.0
    },

    -- ═══════════════════════════════════════════
    -- D-RANK MOUNTS (Budget: 2.8)
    -- Stats do NOT affect quest success
    -- ═══════════════════════════════════════════
    donkey = {
        id = "donkey",
        name = "Donkey",
        slot = "mount",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 500,
        stats = {vit = 2},  -- Budget: 2/2.8 (utility only)
        travelSpeed = 0.10,
        description = "Slow but reliable pack animal",
        powerWeight = 1.0,
        affectsQuestSuccess = false  -- Mount stats don't affect quests
    },
    riding_horse = {
        id = "riding_horse",
        name = "Riding Horse",
        slot = "mount",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 1000,
        stats = {dex = 2},  -- Budget: 2/2.8 (utility only)
        travelSpeed = 0.20,
        description = "A standard riding horse",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },
    pony = {
        id = "pony",
        name = "Pony",
        slot = "mount",
        tier = "basic",
        rank = "D",
        rarity = "common",
        cost = 750,
        stats = {},  -- No stats, just travel
        travelSpeed = 0.15,
        description = "Small but spirited mount",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },

    -- ═══════════════════════════════════════════
    -- C-RANK MOUNTS (Budget: 5.25)
    -- ═══════════════════════════════════════════
    war_horse = {
        id = "war_horse",
        name = "War Horse",
        slot = "mount",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {str = 2, vit = 2},  -- Budget: 4/5.25
        travelSpeed = 0.25,
        description = "Trained for battle and speed",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },
    swift_mare = {
        id = "swift_mare",
        name = "Swift Mare",
        slot = "mount",
        tier = "crafted",
        rank = "C",
        rarity = "uncommon",
        stats = {dex = 4},  -- Budget: 4/5.25
        travelSpeed = 0.30,
        description = "Bred for exceptional speed",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },

    -- ═══════════════════════════════════════════
    -- B-RANK MOUNTS (Budget: 7.7)
    -- ═══════════════════════════════════════════
    armored_destrier = {
        id = "armored_destrier",
        name = "Armored Destrier",
        slot = "mount",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {str = 3, vit = 4},  -- Budget: 7/7.7
        travelSpeed = 0.25,
        description = "Heavy cavalry mount with barding",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },
    elven_steed = {
        id = "elven_steed",
        name = "Elven Steed",
        slot = "mount",
        tier = "crafted",
        rank = "B",
        rarity = "rare",
        stats = {dex = 6},  -- Budget: 6/7.7
        travelSpeed = 0.35,
        description = "Graceful and impossibly fast",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },

    -- ═══════════════════════════════════════════
    -- A-RANK MOUNTS (Budget: 9.8)
    -- ═══════════════════════════════════════════
    nightmare = {
        id = "nightmare",
        name = "Nightmare",
        slot = "mount",
        tier = "crafted",
        rank = "A",
        rarity = "rare",
        stats = {str = 4, int = 4},  -- Budget: 8/9.8
        travelSpeed = 0.40,
        description = "A demonic horse wreathed in flame",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },
    griffon = {
        id = "griffon",
        name = "Griffon",
        slot = "mount",
        tier = "crafted",
        rank = "A",
        rarity = "epic",
        stats = {dex = 6, vit = 2},  -- Budget: 8/9.8
        travelSpeed = 0.50,
        description = "Majestic flying mount",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    },

    -- ═══════════════════════════════════════════
    -- S-RANK MOUNTS (Budget: 12.25)
    -- ═══════════════════════════════════════════
    dragon_mount = {
        id = "dragon_mount",
        name = "Young Dragon",
        slot = "mount",
        tier = "crafted",
        rank = "S",
        rarity = "epic",
        stats = {str = 4, dex = 4, vit = 4},  -- Budget: 12/12.25
        travelSpeed = 0.60,
        description = "A trained young dragon - legendary!",
        powerWeight = 1.0,
        affectsQuestSuccess = false
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

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
            local slotOrder = {weapon = 1, armor = 2, accessory = 3, mount = 4}
            return (slotOrder[a.slot] or 5) < (slotOrder[b.slot] or 5)
        end
        return (a.cost or 0) < (b.cost or 0)
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

-- Get items by rank
function Equipment.getByRank(rank)
    local items = {}
    for id, item in pairs(Equipment.items) do
        if item.rank == rank then
            table.insert(items, item)
        end
    end
    return items
end

-- Get items by rarity
function Equipment.getByRarity(rarity)
    local items = {}
    for id, item in pairs(Equipment.items) do
        if item.rarity == rarity then
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
        local value = item.stats and item.stats[stat]
        if value and value > 0 then
            table.insert(parts, statNames[stat] .. "+" .. value)
        end
    end

    return table.concat(parts, " ")
end

-- Get total stat bonus from equipped item
-- For mounts, check affectsQuestSuccess flag
function Equipment.getStatBonus(item, statName, forQuest)
    if not item or not item.stats then return 0 end

    -- If checking for quest success and item is a mount that doesn't affect quests
    if forQuest and item.slot == "mount" and item.affectsQuestSuccess == false then
        return 0
    end

    return item.stats[statName] or 0
end

-- Get rarity color for display
function Equipment.getRarityColor(item)
    local rarity = item.rarity or "common"
    local config = Equipment.rarityConfig[rarity]
    return config and config.color or {1, 1, 1}
end

-- Get rarity display name
function Equipment.getRarityName(rarity)
    local names = {
        common = "Common",
        uncommon = "Uncommon",
        rare = "Rare",
        epic = "Epic"
    }
    return names[rarity] or "Common"
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DROP TABLE GENERATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Generate drop weights for a dungeon rank
function Equipment.getDropTable(dungeonRank, includeMounts)
    local drops = {}
    local rankValue = Equipment.rankValues[dungeonRank] or 1

    -- Items can drop from current rank and one below
    local validRanks = {dungeonRank}
    if rankValue > 1 then
        for r, v in pairs(Equipment.rankValues) do
            if v == rankValue - 1 then
                table.insert(validRanks, r)
            end
        end
    end

    for id, item in pairs(Equipment.items) do
        -- Check if item rank is valid for this dungeon
        local validRank = false
        for _, r in ipairs(validRanks) do
            if item.rank == r then
                validRank = true
                break
            end
        end

        -- Skip shop items and invalid ranks
        if validRank and item.tier ~= "basic" then
            -- Skip mounts unless specified
            if item.slot ~= "mount" or includeMounts then
                local rarityConfig = Equipment.rarityConfig[item.rarity or "common"]
                local weight = rarityConfig and rarityConfig.dropWeight or 0

                if weight > 0 then
                    table.insert(drops, {
                        item = item,
                        weight = weight
                    })
                end
            end
        end
    end

    return drops
end

-- Roll for a random drop from the drop table
function Equipment.rollDrop(dropTable)
    if #dropTable == 0 then return nil end

    local totalWeight = 0
    for _, entry in ipairs(dropTable) do
        totalWeight = totalWeight + entry.weight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0

    for _, entry in ipairs(dropTable) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.item
        end
    end

    return dropTable[#dropTable].item
end

return Equipment
