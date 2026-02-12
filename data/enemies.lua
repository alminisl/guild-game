-- Enemy Definitions
-- Enemies with their stats, actions, and scaling
-- Structure is JSON-ready for future externalization

local Enemies = {}

-- Enemy action definitions (extensible - can be moved to JSON later)
-- Each action has: id, name, emoji, type, power, description, special effects
Enemies.actions = {
    -- Basic attacks
    slash = {
        id = "slash",
        name = "Slash",
        emoji = "[SLH]",
        type = "damage",
        target = "single",
        basePower = 12,
        description = "A basic melee attack"
    },
    bite = {
        id = "bite",
        name = "Bite",
        emoji = "[BIT]",
        type = "damage",
        target = "single",
        basePower = 10,
        description = "A vicious bite attack"
    },
    claw = {
        id = "claw",
        name = "Claw",
        emoji = "[CLW]",
        type = "damage",
        target = "single",
        basePower = 11,
        description = "Raking claw attack"
    },

    -- Ranged attacks
    throw_rock = {
        id = "throw_rock",
        name = "Throw Rock",
        emoji = "[ROK]",
        type = "damage",
        target = "single",
        basePower = 8,
        description = "Hurls a rock at the target"
    },
    arrow_shot = {
        id = "arrow_shot",
        name = "Arrow Shot",
        emoji = "[ARW]",
        type = "damage",
        target = "single",
        basePower = 14,
        description = "Fires an arrow"
    },

    -- Special attacks
    poison_spit = {
        id = "poison_spit",
        name = "Poison Spit",
        emoji = "[PSN]",
        type = "damage",
        target = "single",
        basePower = 6,
        special = {effect = "poison", duration = 2, tickDamage = 4},
        description = "Spits venom that poisons the target"
    },
    war_cry = {
        id = "war_cry",
        name = "War Cry",
        emoji = "[CRY]",
        type = "buff",
        target = "all_allies",
        special = {effect = "damage_boost", amount = 0.25, duration = 2},
        description = "Boosts all allies' damage"
    },
    shield_bash = {
        id = "shield_bash",
        name = "Shield Bash",
        emoji = "[BSH]",
        type = "damage",
        target = "single",
        basePower = 8,
        special = {effect = "stun", duration = 1},
        description = "Bashes with shield, may stun"
    },

    -- Magic attacks
    dark_bolt = {
        id = "dark_bolt",
        name = "Dark Bolt",
        emoji = "[DRK]",
        type = "damage",
        target = "single",
        basePower = 16,
        description = "Fires a bolt of dark energy"
    },
    flame_breath = {
        id = "flame_breath",
        name = "Flame Breath",
        emoji = "[FLM]",
        type = "damage",
        target = "all_enemies",
        basePower = 10,
        description = "Breathes fire on all heroes"
    },
    heal_ally = {
        id = "heal_ally",
        name = "Heal Ally",
        emoji = "[HEL]",
        type = "heal",
        target = "single_ally",
        basePower = 20,
        description = "Heals an injured ally"
    },

    -- Defensive
    defend = {
        id = "defend",
        name = "Defend",
        emoji = "[DEF]",
        type = "buff",
        target = "self",
        special = {effect = "defense_boost", amount = 0.5, duration = 1},
        description = "Raises defenses for one round"
    },

    -- Boss abilities
    summon_minion = {
        id = "summon_minion",
        name = "Summon Minion",
        emoji = "[SUM]",
        type = "summon",
        target = "none",
        special = {summonType = "minion", count = 1},
        description = "Summons a weaker ally"
    },
    crushing_blow = {
        id = "crushing_blow",
        name = "Crushing Blow",
        emoji = "[CRS]",
        type = "damage",
        target = "single",
        basePower = 25,
        special = {effect = "armor_break", duration = 2},
        description = "A devastating attack that reduces armor"
    },
    enrage = {
        id = "enrage",
        name = "Enrage",
        emoji = "[RGE]",
        type = "buff",
        target = "self",
        special = {effect = "enrage", damageBoost = 0.5, defensePenalty = 0.25, duration = 3},
        description = "Enters a rage, dealing more damage but taking more"
    }
}

-- Enemy type definitions
-- Maps quest themes to appropriate enemies
Enemies.types = {
    -- Vermin (D-rank)
    rat = {
        id = "rat",
        name = "Giant Rat",
        emoji = "[RAT]",
        baseHp = 25,
        baseDamage = 8,
        baseDefense = 2,
        speed = 12,
        actions = {"bite", "claw"},
        rank = "D"
    },
    spider = {
        id = "spider",
        name = "Cave Spider",
        emoji = "[SPD]",
        baseHp = 20,
        baseDamage = 6,
        baseDefense = 1,
        speed = 14,
        actions = {"bite", "poison_spit"},
        rank = "D"
    },

    -- Goblins (D-C rank)
    goblin = {
        id = "goblin",
        name = "Goblin",
        emoji = "[GBL]",
        baseHp = 35,
        baseDamage = 10,
        baseDefense = 3,
        speed = 10,
        actions = {"slash", "throw_rock"},
        rank = "D"
    },
    goblin_archer = {
        id = "goblin_archer",
        name = "Goblin Archer",
        emoji = "[GBA]",
        baseHp = 28,
        baseDamage = 12,
        baseDefense = 2,
        speed = 11,
        actions = {"arrow_shot", "throw_rock"},
        rank = "C"
    },
    goblin_chief = {
        id = "goblin_chief",
        name = "Goblin Chief",
        emoji = "[GBC]",
        baseHp = 60,
        baseDamage = 14,
        baseDefense = 5,
        speed = 8,
        actions = {"slash", "war_cry", "shield_bash"},
        isBoss = true,
        rank = "C"
    },

    -- Bandits (C-B rank)
    bandit = {
        id = "bandit",
        name = "Bandit",
        emoji = "[BND]",
        baseHp = 45,
        baseDamage = 12,
        baseDefense = 4,
        speed = 9,
        actions = {"slash", "defend"},
        rank = "C"
    },
    bandit_archer = {
        id = "bandit_archer",
        name = "Bandit Archer",
        emoji = "[BDA]",
        baseHp = 35,
        baseDamage = 14,
        baseDefense = 3,
        speed = 10,
        actions = {"arrow_shot", "slash"},
        rank = "C"
    },
    bandit_leader = {
        id = "bandit_leader",
        name = "Bandit Leader",
        emoji = "[BDL]",
        baseHp = 80,
        baseDamage = 16,
        baseDefense = 6,
        speed = 9,
        actions = {"slash", "crushing_blow", "war_cry"},
        isBoss = true,
        rank = "B"
    },

    -- Undead (B-A rank)
    skeleton = {
        id = "skeleton",
        name = "Skeleton",
        emoji = "[SKL]",
        baseHp = 40,
        baseDamage = 11,
        baseDefense = 2,
        speed = 7,
        actions = {"slash", "defend"},
        weaknesses = {"holy"},
        rank = "B"
    },
    zombie = {
        id = "zombie",
        name = "Zombie",
        emoji = "[ZMB]",
        baseHp = 55,
        baseDamage = 13,
        baseDefense = 1,
        speed = 4,
        actions = {"claw", "bite"},
        weaknesses = {"holy", "fire"},
        rank = "B"
    },
    necromancer = {
        id = "necromancer",
        name = "Necromancer",
        emoji = "[NCR]",
        baseHp = 50,
        baseDamage = 8,
        baseDefense = 3,
        speed = 8,
        actions = {"dark_bolt", "summon_minion", "heal_ally"},
        isBoss = true,
        rank = "A"
    },

    -- Beasts (B-A rank)
    wolf = {
        id = "wolf",
        name = "Dire Wolf",
        emoji = "[WLF]",
        baseHp = 50,
        baseDamage = 14,
        baseDefense = 3,
        speed = 13,
        actions = {"bite", "claw"},
        rank = "B"
    },
    bear = {
        id = "bear",
        name = "Cave Bear",
        emoji = "[BER]",
        baseHp = 90,
        baseDamage = 18,
        baseDefense = 6,
        speed = 6,
        actions = {"claw", "crushing_blow", "enrage"},
        isBoss = true,
        rank = "A"
    },

    -- Dragons (S rank)
    wyvern = {
        id = "wyvern",
        name = "Wyvern",
        emoji = "[WYV]",
        baseHp = 100,
        baseDamage = 20,
        baseDefense = 8,
        speed = 11,
        actions = {"claw", "flame_breath", "bite"},
        rank = "S"
    },
    dragon = {
        id = "dragon",
        name = "Dragon",
        emoji = "[DRG]",
        baseHp = 200,
        baseDamage = 28,
        baseDefense = 12,
        speed = 10,
        actions = {"claw", "flame_breath", "crushing_blow", "enrage"},
        isBoss = true,
        rank = "S"
    }
}

-- Quest name to enemy mapping
-- Maps keywords in quest names to enemy types
Enemies.questMapping = {
    -- Keywords -> enemy types
    rat = {"rat"},
    cellar = {"rat", "spider"},
    spider = {"spider"},
    cave = {"spider", "goblin"},
    goblin = {"goblin", "goblin_archer"},
    bandit = {"bandit", "bandit_archer"},
    camp = {"bandit", "goblin"},
    undead = {"skeleton", "zombie"},
    crypt = {"skeleton", "zombie"},
    tomb = {"skeleton", "zombie", "necromancer"},
    forest = {"wolf", "spider"},
    wolf = {"wolf"},
    bear = {"bear"},
    dragon = {"wyvern", "dragon"},

    -- Default by rank
    default_D = {"rat", "spider", "goblin"},
    default_C = {"goblin", "goblin_archer", "bandit"},
    default_B = {"bandit", "skeleton", "wolf"},
    default_A = {"zombie", "wolf", "bear"},
    default_S = {"wyvern", "dragon"}
}

-- Rank multipliers for scaling
Enemies.rankMultipliers = {
    D = {hp = 1.0, damage = 1.0, defense = 1.0, count = {min = 2, max = 3}},
    C = {hp = 1.3, damage = 1.2, defense = 1.2, count = {min = 2, max = 4}},
    B = {hp = 1.6, damage = 1.4, defense = 1.4, count = {min = 3, max = 4}},
    A = {hp = 2.0, damage = 1.7, defense = 1.6, count = {min = 3, max = 5}},
    S = {hp = 2.5, damage = 2.0, defense = 2.0, count = {min = 4, max = 6}}
}

-- Generate enemies for a quest
function Enemies.generateForQuest(quest)
    local enemies = {}
    local questName = quest.name:lower()
    local rank = quest.rank or "D"
    local multipliers = Enemies.rankMultipliers[rank]

    -- Find matching enemy types based on quest name
    local matchedTypes = {}
    for keyword, types in pairs(Enemies.questMapping) do
        if not keyword:match("^default") and questName:find(keyword) then
            for _, t in ipairs(types) do
                matchedTypes[t] = true
            end
        end
    end

    -- Use defaults if no matches
    if not next(matchedTypes) then
        local defaultKey = "default_" .. rank
        if Enemies.questMapping[defaultKey] then
            for _, t in ipairs(Enemies.questMapping[defaultKey]) do
                matchedTypes[t] = true
            end
        end
    end

    -- Convert to array
    local availableTypes = {}
    for t, _ in pairs(matchedTypes) do
        if Enemies.types[t] then
            table.insert(availableTypes, t)
        end
    end

    -- Fallback
    if #availableTypes == 0 then
        availableTypes = {"goblin"}
    end

    -- Determine enemy count
    local minCount = multipliers.count.min
    local maxCount = multipliers.count.max
    local enemyCount = math.random(minCount, maxCount)

    -- Check for boss - high rank quests get a boss
    local includeBoss = (rank == "A" or rank == "S") or (rank == "B" and math.random() < 0.3)
    local bossAdded = false

    -- Generate enemies
    for i = 1, enemyCount do
        local typeId = availableTypes[math.random(#availableTypes)]
        local template = Enemies.types[typeId]

        -- Try to add boss as last enemy
        if includeBoss and not bossAdded and i == enemyCount then
            -- Find a boss type from available
            for _, t in ipairs(availableTypes) do
                if Enemies.types[t].isBoss then
                    template = Enemies.types[t]
                    bossAdded = true
                    break
                end
            end
        end

        local enemy = {
            id = i,
            typeId = template.id,
            name = template.name,
            emoji = template.emoji,

            maxHp = math.floor(template.baseHp * multipliers.hp),
            currentHp = math.floor(template.baseHp * multipliers.hp),
            damage = math.floor(template.baseDamage * multipliers.damage),
            defense = math.floor(template.baseDefense * multipliers.defense),
            speed = template.speed,

            actions = {},
            weaknesses = template.weaknesses or {},
            isBoss = template.isBoss or false,
            isAlive = true,

            -- Combat state
            buffs = {},
            debuffs = {},
            poisonStacks = 0,
            isStunned = false,
            isDefending = false,
            damageBoost = 0,
            defenseBoost = 0
        }

        -- Copy actions
        for _, actionId in ipairs(template.actions) do
            if Enemies.actions[actionId] then
                table.insert(enemy.actions, actionId)
            end
        end

        table.insert(enemies, enemy)
    end

    return enemies
end

-- Get action by ID
function Enemies.getAction(actionId)
    return Enemies.actions[actionId]
end

-- Select an action for an enemy (AI)
function Enemies.selectAction(enemy, combatState)
    if not enemy.isAlive or enemy.isStunned then
        return nil
    end

    local availableActions = enemy.actions
    if #availableActions == 0 then
        return Enemies.actions["slash"] -- Fallback
    end

    -- Simple AI: weighted random based on situation
    local weights = {}
    local totalWeight = 0

    for _, actionId in ipairs(availableActions) do
        local action = Enemies.actions[actionId]
        local weight = 10 -- Base weight

        if action then
            -- Prefer heals when allies are hurt
            if action.type == "heal" then
                local hasHurtAlly = false
                for _, e in ipairs(combatState.enemies) do
                    if e.isAlive and e.currentHp < e.maxHp * 0.5 then
                        hasHurtAlly = true
                        break
                    end
                end
                weight = hasHurtAlly and 25 or 2
            end

            -- Prefer buffs if not already buffed
            if action.type == "buff" then
                weight = (enemy.damageBoost == 0) and 15 or 3
            end

            -- Bosses prefer their special attacks
            if enemy.isBoss and action.basePower and action.basePower >= 20 then
                weight = weight + 10
            end
        end

        weights[actionId] = weight
        totalWeight = totalWeight + weight
    end

    -- Weighted random selection
    local roll = math.random() * totalWeight
    local cumulative = 0
    for actionId, weight in pairs(weights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return Enemies.actions[actionId]
        end
    end

    -- Fallback
    return Enemies.actions[availableActions[1]]
end

return Enemies
