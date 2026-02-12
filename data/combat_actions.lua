-- Hero Combat Actions
-- Defines all class-specific combat abilities
-- Structure is JSON-ready for future externalization

local CombatActions = {}

-- Class icon mappings (text-based for font compatibility)
CombatActions.classEmojis = {
    Knight = "[KNT]",
    Paladin = "[PAL]",
    Archer = "[ARC]",
    Hawkeye = "[HWK]",
    Mage = "[MAG]",
    Archmage = "[ARC]",
    Rogue = "[ROG]",
    Shadow = "[SHD]",
    Priest = "[PRI]",
    Saint = "[SNT]",
    Ranger = "[RNG]",
    Warden = "[WRD]"
}

-- Hero action definitions
-- Each class has 3 actions with different tactical purposes
CombatActions.actions = {
    -- ═══════════════════════════════════════════════
    -- KNIGHT - Tank/Defender
    -- ═══════════════════════════════════════════════
    knight_strike = {
        id = "knight_strike",
        name = "Strike",
        emoji = "[ATK]",
        class = "Knight",
        type = "damage",
        target = "single_enemy",
        basePower = 15,
        statScale = "str",
        critChance = 0.10,
        messages = {
            normal = "{actor} STRIKES {target} for {value} damage!",
            crit = "{actor} lands a CRITICAL strike on {target} for {value} damage!"
        }
    },
    knight_taunt = {
        id = "knight_taunt",
        name = "Taunt",
        emoji = "[TNT]",
        class = "Knight",
        type = "special",
        target = "self",
        special = {effect = "taunt", duration = 2},
        messages = {
            normal = "{actor} TAUNTS! All enemies now target them!"
        }
    },
    knight_block = {
        id = "knight_block",
        name = "Block",
        emoji = "[DEF]",
        class = "Knight",
        type = "buff",
        target = "self",
        special = {effect = "block", damageReduction = 0.5, duration = 1},
        messages = {
            normal = "{actor} raises their SHIELD! Damage reduced by 50%!"
        }
    },

    -- ═══════════════════════════════════════════════
    -- ARCHER - Ranged DPS
    -- ═══════════════════════════════════════════════
    archer_shoot = {
        id = "archer_shoot",
        name = "Shoot",
        emoji = "[BOW]",
        class = "Archer",
        type = "damage",
        target = "single_enemy",
        basePower = 18,
        statScale = "dex",
        critChance = 0.15,
        messages = {
            normal = "{actor} shoots {target} for {value} damage!",
            crit = "{actor}'s arrow finds its mark! CRITICAL for {value} damage!"
        }
    },
    archer_aim = {
        id = "archer_aim",
        name = "Aim",
        emoji = "[AIM]",
        class = "Archer",
        type = "buff",
        target = "self",
        special = {effect = "aim", guaranteedCrit = true, duration = 1},
        messages = {
            normal = "{actor} takes careful aim... Next shot will CRIT!"
        }
    },
    archer_volley = {
        id = "archer_volley",
        name = "Volley",
        emoji = "[VOL]",
        class = "Archer",
        type = "damage",
        target = "all_enemies",
        basePower = 10,
        statScale = "dex",
        critChance = 0.08,
        messages = {
            normal = "{actor} fires a volley! All enemies hit for {value} damage!",
            crit = "{actor}'s volley includes a CRITICAL hit for {value} total damage!"
        }
    },

    -- ═══════════════════════════════════════════════
    -- MAGE - AoE/Magic DPS
    -- ═══════════════════════════════════════════════
    mage_fireball = {
        id = "mage_fireball",
        name = "Fireball",
        emoji = "[FIR]",
        class = "Mage",
        type = "damage",
        target = "all_enemies",
        basePower = 12,
        statScale = "int",
        critChance = 0.12,
        damageType = "fire",
        messages = {
            normal = "{actor} casts FIREBALL! All enemies take {value} fire damage!",
            crit = "{actor}'s FIREBALL explodes! CRITICAL for {value} damage!"
        }
    },
    mage_barrier = {
        id = "mage_barrier",
        name = "Barrier",
        emoji = "[BAR]",
        class = "Mage",
        type = "buff",
        target = "all_allies",
        special = {effect = "barrier", shieldAmount = 20, duration = 2},
        messages = {
            normal = "{actor} conjures a magical BARRIER! Party gains 20 shield!"
        }
    },
    mage_arcane_blast = {
        id = "mage_arcane_blast",
        name = "Arcane Blast",
        emoji = "[ARC]",
        class = "Mage",
        type = "damage",
        target = "single_enemy",
        basePower = 25,
        statScale = "int",
        critChance = 0.18,
        damageType = "arcane",
        messages = {
            normal = "{actor} unleashes ARCANE BLAST on {target} for {value} damage!",
            crit = "{actor}'s ARCANE BLAST tears through {target}! CRITICAL for {value}!"
        }
    },

    -- ═══════════════════════════════════════════════
    -- ROGUE - Burst/Utility DPS
    -- ═══════════════════════════════════════════════
    rogue_backstab = {
        id = "rogue_backstab",
        name = "Backstab",
        emoji = "[STB]",
        class = "Rogue",
        type = "damage",
        target = "single_enemy",
        basePower = 20,
        statScale = "dex",
        critChance = 0.20,
        special = {bonusIfDistracted = 1.5}, -- 50% more damage if enemy is taunted
        messages = {
            normal = "{actor} BACKSTABS {target} for {value} damage!",
            crit = "{actor} finds a vital spot! CRITICAL backstab for {value}!",
            bonus = "{actor} exploits the distraction! BACKSTAB for {value} damage!"
        }
    },
    rogue_evade = {
        id = "rogue_evade",
        name = "Evade",
        emoji = "[EVD]",
        class = "Rogue",
        type = "buff",
        target = "self",
        special = {effect = "evade", dodgeChance = 1.0, duration = 1},
        messages = {
            normal = "{actor} prepares to EVADE! Will dodge the next attack!"
        }
    },
    rogue_poison = {
        id = "rogue_poison",
        name = "Poison",
        emoji = "[PSN]",
        class = "Rogue",
        type = "damage",
        target = "single_enemy",
        basePower = 8,
        statScale = "dex",
        critChance = 0.10,
        special = {effect = "poison", duration = 3, tickDamage = 5},
        messages = {
            normal = "{actor} applies POISON to {target}! {value} damage + 5/round!",
            crit = "{actor}'s POISON is potent! CRITICAL for {value} + extra DoT!"
        }
    },

    -- ═══════════════════════════════════════════════
    -- PRIEST - Healer/Support
    -- ═══════════════════════════════════════════════
    priest_heal = {
        id = "priest_heal",
        name = "Heal",
        emoji = "[HEL]",
        class = "Priest",
        type = "heal",
        target = "single_ally",
        basePower = 30,
        statScale = "int",
        messages = {
            normal = "{actor} casts HEAL on {target}! Restored {value} HP!",
            crit = "{actor}'s divine healing surges! {target} restored {value} HP!"
        }
    },
    priest_smite = {
        id = "priest_smite",
        name = "Smite",
        emoji = "[SMT]",
        class = "Priest",
        type = "damage",
        target = "single_enemy",
        basePower = 14,
        statScale = "int",
        critChance = 0.12,
        damageType = "holy",
        messages = {
            normal = "{actor} calls down SMITE on {target} for {value} holy damage!",
            crit = "{actor}'s SMITE is blessed! CRITICAL for {value} damage!"
        }
    },
    priest_bless = {
        id = "priest_bless",
        name = "Bless",
        emoji = "[BLS]",
        class = "Priest",
        type = "buff",
        target = "single_ally",
        special = {effect = "bless", damageBoost = 0.25, duration = 3},
        messages = {
            normal = "{actor} BLESSES {target}! Damage increased by 25%!"
        }
    },

    -- ═══════════════════════════════════════════════
    -- RANGER - Utility/Control
    -- ═══════════════════════════════════════════════
    ranger_trap = {
        id = "ranger_trap",
        name = "Trap",
        emoji = "[TRP]",
        class = "Ranger",
        type = "special",
        target = "single_enemy",
        basePower = 5,
        statScale = "dex",
        special = {effect = "stun", duration = 1},
        messages = {
            normal = "{actor} sets a TRAP! {target} is stunned for 1 round!"
        }
    },
    ranger_called_shot = {
        id = "ranger_called_shot",
        name = "Called Shot",
        emoji = "[SHT]",
        class = "Ranger",
        type = "damage",
        target = "single_enemy",
        basePower = 16,
        statScale = "dex",
        critChance = 0.25,
        messages = {
            normal = "{actor}'s CALLED SHOT hits {target} for {value} damage!",
            crit = "{actor}'s CALLED SHOT is perfect! CRITICAL for {value}!"
        }
    },
    ranger_track = {
        id = "ranger_track",
        name = "Track",
        emoji = "[TRK]",
        class = "Ranger",
        type = "debuff",
        target = "all_enemies",
        special = {effect = "tracked", defenseReduction = 0.3, duration = 3},
        messages = {
            normal = "{actor} TRACKS the enemies! All enemies' defense reduced by 30%!"
        }
    }
}

-- Map classes to their action IDs
CombatActions.classMappings = {
    Knight = {"knight_strike", "knight_taunt", "knight_block"},
    Paladin = {"knight_strike", "knight_taunt", "knight_block"}, -- Awakened Knight
    Archer = {"archer_shoot", "archer_aim", "archer_volley"},
    Hawkeye = {"archer_shoot", "archer_aim", "archer_volley"}, -- Awakened Archer
    Mage = {"mage_fireball", "mage_barrier", "mage_arcane_blast"},
    Archmage = {"mage_fireball", "mage_barrier", "mage_arcane_blast"}, -- Awakened Mage
    Rogue = {"rogue_backstab", "rogue_evade", "rogue_poison"},
    Shadow = {"rogue_backstab", "rogue_evade", "rogue_poison"}, -- Awakened Rogue
    Priest = {"priest_heal", "priest_smite", "priest_bless"},
    Saint = {"priest_heal", "priest_smite", "priest_bless"}, -- Awakened Priest
    Ranger = {"ranger_trap", "ranger_called_shot", "ranger_track"},
    Warden = {"ranger_trap", "ranger_called_shot", "ranger_track"} -- Awakened Ranger
}

-- Get action by ID
function CombatActions.getAction(actionId)
    return CombatActions.actions[actionId]
end

-- Get actions for a class
function CombatActions.getClassActions(class)
    local actionIds = CombatActions.classMappings[class] or {}
    local actions = {}
    for _, id in ipairs(actionIds) do
        if CombatActions.actions[id] then
            table.insert(actions, CombatActions.actions[id])
        end
    end
    return actions
end

-- Get class emoji
function CombatActions.getClassEmoji(class)
    return CombatActions.classEmojis[class] or "👤"
end

-- Select action for hero (AI based on combat situation)
function CombatActions.selectAction(hero, combatState)
    local class = hero.class
    local actionIds = CombatActions.classMappings[class]

    if not actionIds or #actionIds == 0 then
        return nil
    end

    local actions = {}
    for _, id in ipairs(actionIds) do
        actions[id] = CombatActions.actions[id]
    end

    -- Class-specific AI logic
    if class == "Knight" or class == "Paladin" then
        -- Tank: Taunt if no one is taunting, Block if low HP, else Strike
        local anyoneTaunting = false
        for _, h in ipairs(combatState.heroes) do
            if h.isAlive and h.isTaunting then
                anyoneTaunting = true
                break
            end
        end

        if not anyoneTaunting then
            return actions["knight_taunt"]
        elseif hero.currentHp < hero.maxHp * 0.4 then
            return actions["knight_block"]
        else
            return actions["knight_strike"]
        end

    elseif class == "Archer" or class == "Hawkeye" then
        -- Archer: Aim if not aiming, Volley if 3+ enemies, else Shoot
        if not hero.isAiming then
            return actions["archer_aim"]
        end

        local enemyCount = 0
        for _, e in ipairs(combatState.enemies) do
            if e.isAlive then enemyCount = enemyCount + 1 end
        end

        if enemyCount >= 3 then
            return actions["archer_volley"]
        else
            return actions["archer_shoot"]
        end

    elseif class == "Mage" or class == "Archmage" then
        -- Mage: Barrier if party hurt, Fireball if 2+ enemies, else Arcane Blast
        local partyHurt = false
        for _, h in ipairs(combatState.heroes) do
            if h.isAlive and h.currentHp < h.maxHp * 0.5 then
                partyHurt = true
                break
            end
        end

        if partyHurt and not hero.hasBarrier then
            return actions["mage_barrier"]
        end

        local enemyCount = 0
        for _, e in ipairs(combatState.enemies) do
            if e.isAlive then enemyCount = enemyCount + 1 end
        end

        if enemyCount >= 2 then
            return actions["mage_fireball"]
        else
            return actions["mage_arcane_blast"]
        end

    elseif class == "Rogue" or class == "Shadow" then
        -- Rogue: Backstab if enemy distracted, Poison if target not poisoned, else Evade
        local distracted = false
        for _, h in ipairs(combatState.heroes) do
            if h.isAlive and h.isTaunting then
                distracted = true
                break
            end
        end

        if distracted then
            return actions["rogue_backstab"]
        end

        -- Check if any enemy has poison
        local unpoisoned = false
        for _, e in ipairs(combatState.enemies) do
            if e.isAlive and (e.poisonStacks or 0) == 0 then
                unpoisoned = true
                break
            end
        end

        if unpoisoned then
            return actions["rogue_poison"]
        else
            return actions["rogue_backstab"]
        end

    elseif class == "Priest" or class == "Saint" then
        -- Priest: Heal if any ally below 50%, Bless if no one blessed, else Smite
        local needsHealing = nil
        local lowestHpPercent = 1.0
        for _, h in ipairs(combatState.heroes) do
            if h.isAlive then
                local hpPercent = h.currentHp / h.maxHp
                if hpPercent < 0.5 and hpPercent < lowestHpPercent then
                    needsHealing = h
                    lowestHpPercent = hpPercent
                end
            end
        end

        if needsHealing then
            return actions["priest_heal"]
        end

        -- Check if someone needs blessing
        local needsBless = false
        for _, h in ipairs(combatState.heroes) do
            if h.isAlive and not h.isBlessed then
                needsBless = true
                break
            end
        end

        if needsBless then
            return actions["priest_bless"]
        else
            return actions["priest_smite"]
        end

    elseif class == "Ranger" or class == "Warden" then
        -- Ranger: Trap if enemy not trapped, Track if not tracked, else Called Shot
        local unstunned = false
        for _, e in ipairs(combatState.enemies) do
            if e.isAlive and not e.isStunned then
                unstunned = true
                break
            end
        end

        if unstunned then
            return actions["ranger_trap"]
        end

        local untracked = false
        for _, e in ipairs(combatState.enemies) do
            if e.isAlive and not e.isTracked then
                untracked = true
                break
            end
        end

        if untracked then
            return actions["ranger_track"]
        else
            return actions["ranger_called_shot"]
        end
    end

    -- Fallback: first action
    return actions[actionIds[1]]
end

return CombatActions
