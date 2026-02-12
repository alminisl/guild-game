-- Combat System
-- Handles turn-based combat resolution with battle log generation
-- Combat is pre-calculated when quest is assigned, displayed when claimed

local CombatSystem = {}

local Enemies = require("data.enemies")
local CombatActions = require("data.combat_actions")

-- Configuration
local CONFIG = {
    -- Round counts by quest rank
    roundsByRank = {D = 3, C = 4, B = 4, A = 5, S = 6},

    -- HP calculation from VIT
    baseHp = 50,
    hpPerVit = 2,

    -- Damage calculation
    baseDamageMultiplier = 1.0,
    statDamageScaling = 0.5,

    -- Crit settings
    baseCritChance = 0.10,
    critDamageMultiplier = 2.0,
    luckCritBonus = 0.005,

    -- Initiative bonus from DEX
    initiativeDexBonus = 0.1
}

-- ═══════════════════════════════════════════════════════════════════
-- COMBAT INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════

-- Create a combatant state from a hero
local function createHeroCombatant(hero, index)
    local maxHp = CONFIG.baseHp + (hero.stats.vit * CONFIG.hpPerVit)

    return {
        id = index,
        heroId = hero.id,
        name = hero.name,
        class = hero.class,
        emoji = CombatActions.getClassEmoji(hero.class),
        isHero = true,

        maxHp = maxHp,
        currentHp = maxHp,
        stats = {
            str = hero.stats.str,
            dex = hero.stats.dex,
            int = hero.stats.int,
            vit = hero.stats.vit,
            luck = hero.stats.luck
        },
        speed = 10 + math.floor(hero.stats.dex * 0.2),

        isAlive = true,
        sourceHero = hero,

        -- Combat state
        isTaunting = false,
        isAiming = false,
        isEvading = false,
        hasBarrier = false,
        isBlessed = false,
        isBlocking = false,
        shieldAmount = 0,
        damageBoost = 0,
        poisonStacks = 0,

        -- Buff/debuff tracking
        buffs = {},
        debuffs = {}
    }
end

-- Initialize combat state from quest and heroes
function CombatSystem.initCombat(quest, heroes)
    local state = {
        round = 0,
        maxRounds = CONFIG.roundsByRank[quest.rank] or 4,
        phase = "init",

        questName = quest.name,
        questRank = quest.rank,

        heroes = {},
        enemies = {},

        log = {},
        result = nil,

        -- Initiative
        heroInitiative = 0,
        enemyInitiative = 0,
        heroesGoFirst = true,

        -- Stats tracking
        totalHeroDamage = 0,
        totalEnemyDamage = 0,
        totalHealing = 0,
        critCount = 0
    }

    -- Create hero combatants
    for i, hero in ipairs(heroes) do
        table.insert(state.heroes, createHeroCombatant(hero, i))
    end

    -- Generate enemies
    state.enemies = Enemies.generateForQuest(quest)

    -- Roll initiative (d20 for each side)
    state.heroInitiative = math.random(1, 20)
    state.enemyInitiative = math.random(1, 20)

    -- Add DEX bonus for heroes
    local avgDex = 0
    for _, h in ipairs(state.heroes) do
        avgDex = avgDex + h.stats.dex
    end
    avgDex = avgDex / #state.heroes
    state.heroInitiative = state.heroInitiative + math.floor(avgDex * CONFIG.initiativeDexBonus)

    state.heroesGoFirst = state.heroInitiative >= state.enemyInitiative

    -- Log initiative
    table.insert(state.log, {
        round = 0,
        type = "initiative",
        message = string.format("[INIT] Heroes roll %d vs Enemies roll %d - %s go first!",
            state.heroInitiative, state.enemyInitiative,
            state.heroesGoFirst and "Heroes" or "Enemies")
    })

    return state
end

-- ═══════════════════════════════════════════════════════════════════
-- COMBAT RESOLUTION
-- ═══════════════════════════════════════════════════════════════════

-- Check if combat should end
local function checkBattleEnd(state)
    local heroesAlive = 0
    local enemiesAlive = 0

    for _, h in ipairs(state.heroes) do
        if h.isAlive then heroesAlive = heroesAlive + 1 end
    end

    for _, e in ipairs(state.enemies) do
        if e.isAlive then enemiesAlive = enemiesAlive + 1 end
    end

    if enemiesAlive == 0 then
        state.result = "victory"
        table.insert(state.log, {
            round = state.round,
            type = "result",
            message = "*** VICTORY! All enemies defeated! ***"
        })
        return true
    end

    if heroesAlive == 0 then
        state.result = "defeat"
        table.insert(state.log, {
            round = state.round,
            type = "result",
            message = "*** DEFEAT! All heroes have fallen! ***"
        })
        return true
    end

    return false
end

-- Get a random alive target
local function getRandomTarget(combatants)
    local alive = {}
    for _, c in ipairs(combatants) do
        if c.isAlive then table.insert(alive, c) end
    end
    if #alive == 0 then return nil end
    return alive[math.random(#alive)]
end

-- Get target with lowest HP
local function getLowestHpTarget(combatants)
    local lowest = nil
    local lowestHp = math.huge
    for _, c in ipairs(combatants) do
        if c.isAlive and c.currentHp < lowestHp then
            lowest = c
            lowestHp = c.currentHp
        end
    end
    return lowest
end

-- Get taunting target
local function getTauntingTarget(combatants)
    for _, c in ipairs(combatants) do
        if c.isAlive and c.isTaunting then
            return c
        end
    end
    return nil
end

-- Calculate damage
local function calculateDamage(attacker, action, target, state)
    local basePower = action.basePower or 10
    local statScale = action.statScale or "str"
    local statValue = attacker.stats and attacker.stats[statScale] or (attacker.damage or 10)

    -- Base damage
    local damage = basePower + math.floor(statValue * CONFIG.statDamageScaling)

    -- Damage boost from buffs
    if attacker.damageBoost and attacker.damageBoost > 0 then
        damage = math.floor(damage * (1 + attacker.damageBoost))
    end

    -- Blessed bonus
    if attacker.isBlessed then
        damage = math.floor(damage * 1.25)
    end

    -- Backstab bonus (if target is distracted by taunt)
    if action.special and action.special.bonusIfDistracted then
        local taunter = getTauntingTarget(state.heroes)
        if taunter and taunter ~= attacker then
            damage = math.floor(damage * action.special.bonusIfDistracted)
        end
    end

    -- Critical hit
    local critChance = action.critChance or CONFIG.baseCritChance
    if attacker.stats and attacker.stats.luck then
        critChance = critChance + (attacker.stats.luck * CONFIG.luckCritBonus)
    end
    if attacker.isAiming then
        critChance = 1.0
        attacker.isAiming = false
    end

    local isCrit = math.random() < critChance
    if isCrit then
        damage = math.floor(damage * CONFIG.critDamageMultiplier)
        state.critCount = state.critCount + 1
    end

    -- Target defense
    local defense = target.defense or 0
    if target.isTracked then
        defense = math.floor(defense * 0.7)
    end
    if target.isBlocking then
        damage = math.floor(damage * 0.5)
    end

    -- Shield absorption
    if target.shieldAmount and target.shieldAmount > 0 then
        local absorbed = math.min(target.shieldAmount, damage)
        target.shieldAmount = target.shieldAmount - absorbed
        damage = damage - absorbed
    end

    damage = math.max(1, damage - defense)

    return damage, isCrit
end

-- Apply damage to target
local function applyDamage(target, damage, state, attacker)
    -- Check evade
    if target.isEvading then
        target.isEvading = false
        return 0, true -- Evaded
    end

    target.currentHp = target.currentHp - damage

    if target.currentHp <= 0 then
        target.currentHp = 0
        target.isAlive = false
    end

    -- Track stats
    if attacker and attacker.isHero then
        state.totalHeroDamage = state.totalHeroDamage + damage
    else
        state.totalEnemyDamage = state.totalEnemyDamage + damage
    end

    return damage, false
end

-- Format action message
local function formatMessage(template, data)
    local msg = template
    for key, value in pairs(data) do
        msg = msg:gsub("{" .. key .. "}", tostring(value))
    end
    return msg
end

-- Execute a hero action
local function executeHeroAction(hero, action, state)
    if not hero.isAlive then return end

    local logEntry = {
        round = state.round,
        actor = hero.name,
        actorEmoji = hero.emoji,
        action = action.name,
        actionEmoji = action.emoji,
        isHero = true,
        damage = 0,
        healing = 0,
        isCrit = false
    }

    if action.type == "damage" then
        -- Damage action
        local targets = {}

        if action.target == "single_enemy" then
            -- Prefer taunting enemy, then random
            local target = getTauntingTarget(state.enemies) or getRandomTarget(state.enemies)
            if target then table.insert(targets, target) end
        elseif action.target == "all_enemies" then
            for _, e in ipairs(state.enemies) do
                if e.isAlive then table.insert(targets, e) end
            end
        end

        local totalDamage = 0
        local anyCrit = false
        for _, target in ipairs(targets) do
            local damage, isCrit = calculateDamage(hero, action, target, state)
            local actualDamage, evaded = applyDamage(target, damage, state, hero)

            if evaded then
                logEntry.message = string.format("%s %s used %s but %s EVADED!",
                    hero.emoji, hero.name, action.name, target.name)
            else
                totalDamage = totalDamage + actualDamage
                if isCrit then anyCrit = true end

                if not target.isAlive then
                    table.insert(state.log, {
                        round = state.round,
                        type = "death",
                        message = string.format("[SLAIN] %s %s has been slain!", target.emoji, target.name)
                    })
                end
            end
        end

        logEntry.damage = totalDamage
        logEntry.isCrit = anyCrit

        local msgKey = anyCrit and "crit" or "normal"
        if action.special and action.special.bonusIfDistracted and getTauntingTarget(state.heroes) then
            msgKey = "bonus"
        end
        local template = action.messages and action.messages[msgKey] or "{actor} attacks for {value} damage!"
        logEntry.message = formatMessage(template, {
            actor = hero.emoji .. " " .. hero.name,
            target = targets[1] and targets[1].name or "enemy",
            value = totalDamage
        })

    elseif action.type == "heal" then
        -- Healing action
        local target = getLowestHpTarget(state.heroes)
        if target then
            local healAmount = action.basePower or 20
            if hero.stats.int then
                healAmount = healAmount + math.floor(hero.stats.int * 0.3)
            end

            local actualHeal = math.min(healAmount, target.maxHp - target.currentHp)
            target.currentHp = target.currentHp + actualHeal
            state.totalHealing = state.totalHealing + actualHeal

            logEntry.healing = actualHeal
            logEntry.target = target.name
            logEntry.message = formatMessage(action.messages and action.messages.normal or "{actor} heals {target} for {value} HP!", {
                actor = hero.emoji .. " " .. hero.name,
                target = target.name,
                value = actualHeal
            })
        end

    elseif action.type == "buff" then
        -- Buff action
        if action.special then
            if action.special.effect == "taunt" then
                hero.isTaunting = true
                hero.tauntDuration = action.special.duration or 2
            elseif action.special.effect == "block" then
                hero.isBlocking = true
                hero.blockDuration = 1
            elseif action.special.effect == "aim" then
                hero.isAiming = true
            elseif action.special.effect == "evade" then
                hero.isEvading = true
            elseif action.special.effect == "barrier" then
                for _, h in ipairs(state.heroes) do
                    if h.isAlive then
                        h.shieldAmount = (h.shieldAmount or 0) + (action.special.shieldAmount or 20)
                        h.hasBarrier = true
                    end
                end
            elseif action.special.effect == "bless" then
                -- Find unbuffed ally
                for _, h in ipairs(state.heroes) do
                    if h.isAlive and not h.isBlessed then
                        h.isBlessed = true
                        h.blessDuration = action.special.duration or 3
                        logEntry.target = h.name
                        break
                    end
                end
            end
        end

        logEntry.message = formatMessage(action.messages and action.messages.normal or "{actor} uses {action}!", {
            actor = hero.emoji .. " " .. hero.name,
            action = action.name,
            target = logEntry.target or ""
        })

    elseif action.type == "special" then
        -- Special actions (like Taunt, Trap)
        if action.special and action.special.effect == "taunt" then
            hero.isTaunting = true
            hero.tauntDuration = action.special.duration or 2
        elseif action.special and action.special.effect == "stun" then
            local target = getRandomTarget(state.enemies)
            if target and not target.isStunned then
                target.isStunned = true
                target.stunDuration = action.special.duration or 1
                logEntry.target = target.name
            end
        end

        logEntry.message = formatMessage(action.messages and action.messages.normal or "{actor} uses {action}!", {
            actor = hero.emoji .. " " .. hero.name,
            action = action.name,
            target = logEntry.target or ""
        })

    elseif action.type == "debuff" then
        -- Debuff actions (like Track)
        if action.special and action.special.effect == "tracked" then
            for _, e in ipairs(state.enemies) do
                if e.isAlive then
                    e.isTracked = true
                    e.trackedDuration = action.special.duration or 3
                end
            end
        end

        logEntry.message = formatMessage(action.messages and action.messages.normal or "{actor} uses {action}!", {
            actor = hero.emoji .. " " .. hero.name,
            action = action.name
        })
    end

    -- Handle poison application
    if action.special and action.special.effect == "poison" then
        local target = getRandomTarget(state.enemies)
        if target then
            target.poisonStacks = (target.poisonStacks or 0) + 1
            target.poisonDuration = action.special.duration or 3
            target.poisonDamage = action.special.tickDamage or 5
        end
    end

    table.insert(state.log, logEntry)
end

-- Execute an enemy action
local function executeEnemyAction(enemy, action, state)
    if not enemy.isAlive or enemy.isStunned then
        if enemy.isStunned then
            table.insert(state.log, {
                round = state.round,
                actor = enemy.name,
                actorEmoji = enemy.emoji,
                message = string.format("%s %s is STUNNED and cannot act!", enemy.emoji, enemy.name)
            })
        end
        return
    end

    local logEntry = {
        round = state.round,
        actor = enemy.name,
        actorEmoji = enemy.emoji,
        action = action.name,
        actionEmoji = action.emoji,
        isHero = false,
        damage = 0,
        healing = 0,
        isCrit = false
    }

    if action.type == "damage" then
        local targets = {}

        if action.target == "single" or action.target == "single_enemy" then
            -- Target taunting hero first, else lowest HP, else random
            local target = getTauntingTarget(state.heroes)
            if not target then
                target = getLowestHpTarget(state.heroes)
            end
            if not target then
                target = getRandomTarget(state.heroes)
            end
            if target then table.insert(targets, target) end
        elseif action.target == "all_enemies" then
            for _, h in ipairs(state.heroes) do
                if h.isAlive then table.insert(targets, h) end
            end
        end

        local totalDamage = 0
        for _, target in ipairs(targets) do
            local baseDamage = (action.basePower or 10) + (enemy.damage or 0)
            local damage = math.floor(baseDamage * (1 + (enemy.damageBoost or 0)))

            -- Crit check
            local isCrit = math.random() < 0.1
            if isCrit then
                damage = math.floor(damage * 1.5)
                logEntry.isCrit = true
            end

            local actualDamage, evaded = applyDamage(target, damage, state, enemy)

            if evaded then
                logEntry.message = string.format("%s %s attacks but %s EVADED!",
                    enemy.emoji, enemy.name, target.name)
            else
                totalDamage = totalDamage + actualDamage
                logEntry.target = target.name

                if not target.isAlive then
                    table.insert(state.log, {
                        round = state.round,
                        type = "death",
                        message = string.format("[FALLEN] %s %s has fallen!", target.emoji, target.name)
                    })
                end
            end
        end

        logEntry.damage = totalDamage
        if not logEntry.message then
            logEntry.message = string.format("%s %s %s %s for %d damage!%s",
                enemy.emoji, enemy.name, action.emoji, action.name,
                totalDamage, logEntry.isCrit and " CRITICAL!" or "")
        end

    elseif action.type == "heal" then
        local target = getLowestHpTarget(state.enemies)
        if target then
            local healAmount = action.basePower or 20
            local actualHeal = math.min(healAmount, target.maxHp - target.currentHp)
            target.currentHp = target.currentHp + actualHeal
            logEntry.healing = actualHeal
            logEntry.message = string.format("%s %s heals %s for %d HP!",
                enemy.emoji, enemy.name, target.name, actualHeal)
        end

    elseif action.type == "buff" then
        if action.special and action.special.effect == "damage_boost" then
            for _, e in ipairs(state.enemies) do
                if e.isAlive then
                    e.damageBoost = (e.damageBoost or 0) + (action.special.amount or 0.25)
                end
            end
        elseif action.special and action.special.effect == "enrage" then
            enemy.damageBoost = (enemy.damageBoost or 0) + (action.special.damageBoost or 0.5)
            enemy.isEnraged = true
        elseif action.special and action.special.effect == "defense_boost" then
            enemy.isDefending = true
        end

        logEntry.message = string.format("%s %s %s %s!",
            enemy.emoji, enemy.name, action.emoji, action.name)
    end

    table.insert(state.log, logEntry)
end

-- Process end of round effects (poison, buff expiration, etc.)
local function processRoundEnd(state)
    -- Process heroes
    for _, hero in ipairs(state.heroes) do
        if hero.isAlive then
            -- Poison damage
            if hero.poisonStacks and hero.poisonStacks > 0 then
                local poisonDmg = hero.poisonDamage or 5
                hero.currentHp = hero.currentHp - poisonDmg
                table.insert(state.log, {
                    round = state.round,
                    type = "poison",
                    message = string.format("[PSN] %s takes %d poison damage!", hero.name, poisonDmg)
                })
                if hero.currentHp <= 0 then
                    hero.currentHp = 0
                    hero.isAlive = false
                    table.insert(state.log, {
                        round = state.round,
                        type = "death",
                        message = string.format("[FALLEN] %s %s succumbed to poison!", hero.emoji, hero.name)
                    })
                end
            end

            -- Expire buffs
            if hero.tauntDuration then
                hero.tauntDuration = hero.tauntDuration - 1
                if hero.tauntDuration <= 0 then
                    hero.isTaunting = false
                    hero.tauntDuration = nil
                end
            end
            if hero.blockDuration then
                hero.blockDuration = hero.blockDuration - 1
                if hero.blockDuration <= 0 then
                    hero.isBlocking = false
                    hero.blockDuration = nil
                end
            end
            if hero.blessDuration then
                hero.blessDuration = hero.blessDuration - 1
                if hero.blessDuration <= 0 then
                    hero.isBlessed = false
                    hero.blessDuration = nil
                end
            end
        end
    end

    -- Process enemies
    for _, enemy in ipairs(state.enemies) do
        if enemy.isAlive then
            -- Poison damage
            if enemy.poisonStacks and enemy.poisonStacks > 0 then
                local poisonDmg = enemy.poisonDamage or 5
                enemy.currentHp = enemy.currentHp - poisonDmg
                state.totalHeroDamage = state.totalHeroDamage + poisonDmg
                table.insert(state.log, {
                    round = state.round,
                    type = "poison",
                    message = string.format("[PSN] %s takes %d poison damage!", enemy.name, poisonDmg)
                })
                if enemy.currentHp <= 0 then
                    enemy.currentHp = 0
                    enemy.isAlive = false
                    table.insert(state.log, {
                        round = state.round,
                        type = "death",
                        message = string.format("[SLAIN] %s %s succumbed to poison!", enemy.emoji, enemy.name)
                    })
                end

                enemy.poisonDuration = (enemy.poisonDuration or 1) - 1
                if enemy.poisonDuration <= 0 then
                    enemy.poisonStacks = 0
                end
            end

            -- Expire stun
            if enemy.stunDuration then
                enemy.stunDuration = enemy.stunDuration - 1
                if enemy.stunDuration <= 0 then
                    enemy.isStunned = false
                    enemy.stunDuration = nil
                end
            end

            -- Expire tracked
            if enemy.trackedDuration then
                enemy.trackedDuration = enemy.trackedDuration - 1
                if enemy.trackedDuration <= 0 then
                    enemy.isTracked = false
                    enemy.trackedDuration = nil
                end
            end
        end
    end
end

-- Main combat resolution loop
function CombatSystem.resolveCombat(state)
    while state.round < state.maxRounds and state.result == nil do
        state.round = state.round + 1

        -- Round header
        table.insert(state.log, {
            round = state.round,
            type = "round_start",
            message = string.format("═══ Round %d ═══", state.round)
        })

        -- Determine turn order based on initiative
        local firstGroup, secondGroup
        if state.heroesGoFirst then
            firstGroup = {list = state.heroes, isHeroes = true}
            secondGroup = {list = state.enemies, isHeroes = false}
        else
            firstGroup = {list = state.enemies, isHeroes = false}
            secondGroup = {list = state.heroes, isHeroes = true}
        end

        -- First group acts
        for _, combatant in ipairs(firstGroup.list) do
            if combatant.isAlive then
                local action
                if firstGroup.isHeroes then
                    action = CombatActions.selectAction(combatant, state)
                    if action then
                        executeHeroAction(combatant, action, state)
                    end
                else
                    action = Enemies.selectAction(combatant, state)
                    if action then
                        executeEnemyAction(combatant, action, state)
                    end
                end

                if checkBattleEnd(state) then break end
            end
        end

        if state.result then break end

        -- Second group acts
        for _, combatant in ipairs(secondGroup.list) do
            if combatant.isAlive then
                local action
                if secondGroup.isHeroes then
                    action = CombatActions.selectAction(combatant, state)
                    if action then
                        executeHeroAction(combatant, action, state)
                    end
                else
                    action = Enemies.selectAction(combatant, state)
                    if action then
                        executeEnemyAction(combatant, action, state)
                    end
                end

                if checkBattleEnd(state) then break end
            end
        end

        if state.result then break end

        -- End of round processing
        processRoundEnd(state)
        if checkBattleEnd(state) then break end
    end

    -- If max rounds reached, determine winner by remaining HP
    if state.result == nil then
        local heroHp = 0
        local enemyHp = 0
        for _, h in ipairs(state.heroes) do
            if h.isAlive then heroHp = heroHp + h.currentHp end
        end
        for _, e in ipairs(state.enemies) do
            if e.isAlive then enemyHp = enemyHp + e.currentHp end
        end

        if heroHp >= enemyHp then
            state.result = "victory"
            table.insert(state.log, {
                round = state.round,
                type = "result",
                message = "[TIME] Time's up! Heroes win by remaining HP!"
            })
        else
            state.result = "defeat"
            table.insert(state.log, {
                round = state.round,
                type = "result",
                message = "[TIME] Time's up! Heroes couldn't overcome the enemies!"
            })
        end
    end

    return state
end

-- ═══════════════════════════════════════════════════════════════════
-- SUMMARY GENERATION
-- ═══════════════════════════════════════════════════════════════════

function CombatSystem.generateSummary(state)
    local summary = {
        rounds = state.round,
        result = state.result,
        totalHeroDamage = state.totalHeroDamage,
        totalEnemyDamage = state.totalEnemyDamage,
        totalHealing = state.totalHealing,
        critCount = state.critCount,

        heroesAlive = 0,
        heroesDead = 0,
        enemiesDefeated = 0,

        heroDamageByName = {},
        mvp = nil,

        initiative = {
            heroRoll = state.heroInitiative,
            enemyRoll = state.enemyInitiative,
            heroesFirst = state.heroesGoFirst
        }
    }

    -- Count survivors
    for _, h in ipairs(state.heroes) do
        if h.isAlive then
            summary.heroesAlive = summary.heroesAlive + 1
        else
            summary.heroesDead = summary.heroesDead + 1
        end
    end

    for _, e in ipairs(state.enemies) do
        if not e.isAlive then
            summary.enemiesDefeated = summary.enemiesDefeated + 1
        end
    end

    -- Calculate damage per hero from log
    for _, entry in ipairs(state.log) do
        if entry.isHero and entry.damage and entry.damage > 0 then
            summary.heroDamageByName[entry.actor] = (summary.heroDamageByName[entry.actor] or 0) + entry.damage
        end
    end

    -- Determine MVP
    local maxDamage = 0
    for name, damage in pairs(summary.heroDamageByName) do
        if damage > maxDamage then
            maxDamage = damage
            summary.mvp = {name = name, damage = damage}
        end
    end

    return summary
end

-- ═══════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════════

-- Full combat resolution (init + resolve + summary)
function CombatSystem.runCombat(quest, heroes)
    local state = CombatSystem.initCombat(quest, heroes)
    state = CombatSystem.resolveCombat(state)
    local summary = CombatSystem.generateSummary(state)

    return {
        success = state.result == "victory",
        log = state.log,
        summary = summary,
        heroes = state.heroes,
        enemies = state.enemies,
        rounds = state.round
    }
end

return CombatSystem
