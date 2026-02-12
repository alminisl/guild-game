-- Quests Data Module
-- Quest templates loaded from JSON for easy customization

local json = require("utils.json")
local Heroes = require("data.heroes")

local Quests = {}

-- Lazy-load party-related modules to avoid circular dependencies
local PartySystem = nil
local PartyTraits = nil

local function getPartySystem()
    if not PartySystem then
        PartySystem = require("systems.party_system")
    end
    return PartySystem
end

local function getPartyTraits()
    if not PartyTraits then
        PartyTraits = require("data.party_traits")
    end
    return PartyTraits
end

-- Load quest data from JSON
local questData = nil
local synergyData = nil

local function loadSynergyData()
    if synergyData then return synergyData end

    local data, err = json.loadFile("data/synergies.json")
    if not data then
        print("ERROR loading synergies.json: " .. (err or "unknown error"))
        data = { synergies = {}, config = {} }
    end
    synergyData = data
    return synergyData
end

local function loadQuestData()
    if questData then return questData end

    local data, err = json.loadFile("data/quests.json")
    if not data then
        print("ERROR loading quests.json: " .. (err or "unknown error"))
        -- Fallback minimal data
        data = {
            config = {
                rankPower = {D = 1, C = 2, B = 3, A = 4, S = 5},
                timers = {
                    D = {travel = 3, execute = 8, ["return"] = 3},
                    C = {travel = 5, execute = 12, ["return"] = 5},
                    B = {travel = 7, execute = 18, ["return"] = 7},
                    A = {travel = 10, execute = 25, ["return"] = 10},
                    S = {travel = 15, execute = 35, ["return"] = 15}
                },
                deathRisk = {
                    D = {canKill = false, injuryOnly = true, deathChance = 0},
                    C = {canKill = false, injuryOnly = true, deathChance = 0},
                    B = {canKill = true, injuryOnly = false, deathChance = 0.10, clericProtection = true},
                    A = {canKill = true, injuryOnly = false, deathChance = 0.25, clericProtection = true},
                    S = {canKill = true, injuryOnly = false, deathChance = 0.45, clericProtection = true}
                }
            },
            templates = {D = {}, C = {}, B = {}, A = {}, S = {}}
        }
    end
    questData = data
    return questData
end

-- Get quest templates (loads from JSON)
function Quests.getTemplates()
    local data = loadQuestData()
    return data.templates
end

-- Get config value
function Quests.getConfig(key)
    local data = loadQuestData()
    return data.config[key]
end

-- Power requirements by rank (from JSON)
function Quests.getRankPower(rank)
    local data = loadQuestData()
    return data.config.rankPower[rank] or 1
end

-- Expose rank power table for compatibility
Quests.rankPower = setmetatable({}, {
    __index = function(_, rank)
        return Quests.getRankPower(rank)
    end
})

-- Timer settings by rank (from JSON)
function Quests.getTimers(rank)
    local data = loadQuestData()
    local timers = data.config.timers[rank]
    if timers then
        return {
            travel = timers.travel,
            execute = timers.execute,
            returnTime = timers["return"]
        }
    end
    return {travel = 5, execute = 10, returnTime = 5}
end

-- Get death risk config for a rank
function Quests.getDeathRisk(rank)
    local data = loadQuestData()
    if data.config.deathRisk then
        return data.config.deathRisk[rank]
    end
    return {canKill = false, injuryOnly = true, deathChance = 0}
end

-- Get warning message for a rank
function Quests.getWarning(rank)
    local data = loadQuestData()
    if data.config.warnings then
        return data.config.warnings[rank]
    end
    return nil
end

-- Get dungeon configuration
function Quests.getDungeonConfig()
    local data = loadQuestData()
    if data.config.dungeons then
        return data.config.dungeons
    end
    return {
        floorCountByRank = {D = 3, C = 3, B = 4, A = 4, S = 5},
        fatiguePerFloor = 0.05,
        deathRiskStartFloor = 3,
        deathChancePerFloor = {["3"] = 0.10, ["4"] = 0.20, ["5"] = 0.30},
        rewards = {
            xpMultiplier = 1.5,
            dropChanceMultiplier = 1.25,
            completionBonusMultiplier = 0.5
        }
    }
end

-- Calculate success chance for a specific dungeon floor (with fatigue penalty)
function Quests.calculateFloorSuccessChance(quest, heroes, floorNumber, EquipmentSystem, gameData)
    local config = Quests.getDungeonConfig()
    local fatigueMultiplier = 1 - ((floorNumber - 1) * config.fatiguePerFloor)

    -- Create adjusted hero stats with fatigue penalty
    local adjustedHeroes = {}
    for _, hero in ipairs(heroes) do
        local adjusted = {
            stats = {},
            rank = hero.rank,
            class = hero.class,
            injuryState = hero.injuryState,
            equipment = hero.equipment,
            id = hero.id  -- Preserve ID for party lookup
        }
        for stat, value in pairs(hero.stats) do
            adjusted.stats[stat] = math.floor(value * fatigueMultiplier)
        end
        table.insert(adjustedHeroes, adjusted)
    end

    return Quests.calculateSuccessChance(quest, adjustedHeroes, EquipmentSystem, gameData)
end

-- Get death risk for a specific dungeon floor
function Quests.getFloorDeathRisk(quest, floorNumber)
    local config = Quests.getDungeonConfig()
    if floorNumber < config.deathRiskStartFloor then
        return {canKill = false, deathChance = 0, clericProtection = false}
    end

    local floorKey = tostring(floorNumber)
    local deathChance = config.deathChancePerFloor[floorKey] or 0.10

    return {
        canKill = true,
        deathChance = deathChance,
        clericProtection = true
    }
end

-- Roll rewards for a single dungeon floor
function Quests.rollFloorRewards(quest, luckMultiplier, floorNumber)
    local config = Quests.getDungeonConfig()
    local dropMultiplier = config.rewards.dropChanceMultiplier

    return Quests.rollRewards({
        possibleRewards = quest.possibleRewards
    }, luckMultiplier * dropMultiplier)
end

-- Internal ID counter
local nextQuestId = 1

-- Stat combinations for secondary requirements based on quest type
local statSynergies = {
    -- Combat tends to pair with VIT (endurance) or DEX (dodging)
    str = {"vit", "dex"},
    -- Agility pairs with LUCK (finding paths) or INT (planning)
    dex = {"luck", "int"},
    -- Magic pairs with VIT (channeling) or LUCK (spell success)
    int = {"vit", "luck"}
}

-- Generate secondary stats for higher rank quests
local function generateSecondaryStats(primaryStat, rank, combat)
    local secondaryStats = {}

    -- D rank: No secondary stats
    if rank == "D" then
        return secondaryStats
    end

    -- Chance of secondary stat based on rank
    local secondaryChance = {
        C = 0.4,   -- 40% chance of 1 secondary
        B = 0.7,   -- 70% chance of 1 secondary
        A = 1.0,   -- Always 1 secondary, 30% chance of 2nd
        S = 1.0    -- Always 1 secondary, 60% chance of 2nd
    }

    local chance = secondaryChance[rank] or 0
    if math.random() > chance then
        return secondaryStats
    end

    -- Pick secondary stat based on primary
    local possibleSecondary = statSynergies[primaryStat] or {"vit", "luck"}

    -- For combat quests, VIT is more likely
    local secondary1
    if combat and math.random() < 0.6 then
        secondary1 = "vit"
    else
        secondary1 = possibleSecondary[math.random(#possibleSecondary)]
    end

    -- Weight: Secondary stat contributes less than primary
    local weight1 = rank == "S" and 0.5 or (rank == "A" and 0.4 or 0.3)
    table.insert(secondaryStats, {stat = secondary1, weight = weight1})

    -- A/S rank might have a third stat
    local thirdChance = rank == "S" and 0.6 or (rank == "A" and 0.3 or 0)
    if thirdChance > 0 and math.random() < thirdChance then
        -- Pick a third stat (VIT or LUCK for survivability)
        local tertiary = secondary1 ~= "vit" and "vit" or "luck"
        table.insert(secondaryStats, {stat = tertiary, weight = 0.2})
    end

    return secondaryStats
end

-- Generate a quest from template
function Quests.generate(rank, template)
    local templates = Quests.getTemplates()
    local rankTemplates = templates[rank]
    if not rankTemplates or #rankTemplates == 0 then
        return nil
    end

    template = template or rankTemplates[math.random(#rankTemplates)]
    local timers = Quests.getTimers(rank)
    local deathRisk = Quests.getDeathRisk(rank)

    -- Generate secondary stat requirements for C+ rank quests
    local secondaryStats = generateSecondaryStats(template.requiredStat, rank, template.combat)

    -- Determine max heroes based on rank
    -- All quests allow at least 4 heroes, higher ranks allow more
    local baseMaxHeroes = {D = 4, C = 4, B = 4, A = 6, S = 6}
    local maxHeroes = baseMaxHeroes[rank] or 4

    -- Higher reward quests can have +2 hero slots
    local rewardThresholds = {D = 45, C = 80, B = 150, A = 350, S = 800}
    if template.reward >= (rewardThresholds[rank] or 999) then
        maxHeroes = maxHeroes + 2
    end

    -- Get dungeon config if this is a dungeon
    local isDungeon = template.isDungeon or false
    local dungeonConfig = Quests.getDungeonConfig()
    local floorCount = 0
    if isDungeon and dungeonConfig.floorCountByRank then
        floorCount = dungeonConfig.floorCountByRank[rank] or 3
    end

    local quest = {
        id = nextQuestId,
        name = template.name,
        description = template.description,
        rank = rank,
        faction = template.faction or "humans",
        reward = template.reward + math.random(-10, 10),
        xpReward = template.xpReward,
        requiredStat = template.requiredStat,
        secondaryStats = secondaryStats,  -- NEW: Secondary stat requirements
        materialBonus = template.materialBonus or false,
        combat = template.combat or false,
        timeOfDay = template.timeOfDay or "any",
        possibleRewards = template.possibleRewards or {},
        -- Hero limits
        maxHeroes = maxHeroes,
        -- Death risk from config
        canKill = deathRisk.canKill,
        injuryOnly = deathRisk.injuryOnly,
        deathChance = deathRisk.deathChance,
        clericProtection = deathRisk.clericProtection,
        -- Timer values
        travelTime = timers.travel,
        executeTime = timers.execute,
        returnTime = timers.returnTime,
        -- State tracking
        assignedHeroes = {},
        status = "available",
        currentPhase = nil,
        phaseProgress = 0,
        -- Dungeon-specific fields
        isDungeon = isDungeon,
        floorCount = floorCount,
        currentFloor = 0,
        floorsCleared = {},      -- Track each floor's result {success, rewards, deaths, injuries}
        partyFatigue = 0,        -- Cumulative stat reduction (0.05 per floor)
        hasRetreated = false     -- True if party chose to retreat early
    }

    nextQuestId = nextQuestId + 1
    return quest
end

-- Get total quest time
function Quests.getTotalTime(quest)
    return quest.travelTime + quest.executeTime + quest.returnTime
end

-- Get time remaining for current phase
function Quests.getPhaseTimeRemaining(quest)
    local phaseMax = 0
    if quest.currentPhase == "travel" then
        phaseMax = quest.travelTime
    elseif quest.currentPhase == "execute" then
        phaseMax = quest.executeTime
    elseif quest.currentPhase == "awaiting_claim" then
        return 0  -- No time remaining - waiting for player
    elseif quest.currentPhase == "return" then
        phaseMax = quest.returnTime
    end
    return math.max(0, phaseMax - quest.phaseProgress)
end

-- Get phase progress as percentage
function Quests.getPhasePercent(quest)
    local phaseMax = 0
    if quest.currentPhase == "travel" then
        phaseMax = quest.travelTime
    elseif quest.currentPhase == "execute" then
        phaseMax = quest.executeTime
    elseif quest.currentPhase == "awaiting_claim" then
        return 1  -- 100% complete - waiting for player
    elseif quest.currentPhase == "return" then
        phaseMax = quest.returnTime
    end
    if phaseMax <= 0 then return 0 end
    return quest.phaseProgress / phaseMax
end

-- Generate a pool of available quests
-- gameData is optional, used for S-rank daily limit tracking
function Quests.generatePool(count, maxRank, gameData)
    count = count or 5
    maxRank = maxRank or "B"

    local rankOrder = {"D", "C", "B", "A", "S"}
    local maxRankIndex = 1
    for i, r in ipairs(rankOrder) do
        if r == maxRank then maxRankIndex = i break end
    end

    -- S-rank daily limit (max 2 per day)
    local S_RANK_DAILY_LIMIT = 2
    local sRankQuestsToday = gameData and gameData.sRankQuestsToday or 0

    local templates = Quests.getTemplates()
    local pool = {}
    local usedTemplates = {}

    for i = 1, count do
        -- Weighted rank selection
        local roll = math.random(100)
        local rankIndex
        if roll <= 40 then rankIndex = 1
        elseif roll <= 70 then rankIndex = 2
        elseif roll <= 90 then rankIndex = 3
        else rankIndex = 4
        end
        rankIndex = math.min(rankIndex, maxRankIndex)
        local rank = rankOrder[rankIndex]

        -- Enforce S-rank daily limit: if at limit, downgrade to A-rank
        if rank == "S" and sRankQuestsToday >= S_RANK_DAILY_LIMIT then
            rank = "A"
            rankIndex = 4
        end

        -- Get all templates for this rank
        local rankTemplates = templates[rank] or {}

        -- Pick unused template if possible
        local template = nil
        for _, t in ipairs(rankTemplates) do
            if not usedTemplates[t.name] then
                template = t
                usedTemplates[t.name] = true
                break
            end
        end

        -- Fall back to random if all used
        if not template and #rankTemplates > 0 then
            template = rankTemplates[math.random(#rankTemplates)]
        end

        if template then
            local quest = Quests.generate(rank, template)
            table.insert(pool, quest)

            -- Track S-rank generation for daily limit
            if rank == "S" and gameData then
                gameData.sRankQuestsToday = (gameData.sRankQuestsToday or 0) + 1
                sRankQuestsToday = gameData.sRankQuestsToday
            end
        end
    end

    return pool
end

-- Check if a party can be assigned to a quest (always true now - no power gate)
function Quests.canAssign(quest, heroes)
    return #heroes > 0
end

-- Roll for possible rewards from quest completion
function Quests.rollRewards(quest, luckMultiplier)
    luckMultiplier = luckMultiplier or 1.0
    local rewards = {}

    if not quest.possibleRewards then return rewards end

    for _, reward in ipairs(quest.possibleRewards) do
        -- Apply luck to drop chance (max 95% to always have some uncertainty)
        local adjustedChance = math.min(0.95, reward.dropChance * luckMultiplier)

        if math.random() <= adjustedChance then
            table.insert(rewards, {
                type = reward.type,
                id = reward.id,
                amount = reward.amount
            })
        end
    end

    return rewards
end

-- Calculate success chance
-- Injury stat penalty multipliers (avoid circular dependency with Heroes module)
local injuryPenalties = {
    fatigued = 0.90,
    injured = 0.75,
    wounded = 0.50
}

-- Class-specific bonuses based on quest type and requirements
-- Makes class choice meaningful beyond just stats
local classQuestBonuses = {
    -- Combat quest bonuses
    combat = {
        Knight = 0.10,    -- Tanks excel in combat
        Paladin = 0.12,   -- Awakened tank
        Archer = 0.05,    -- Ranged DPS
        Hawkeye = 0.07,   -- Awakened archer
        Mage = 0.05,      -- Magical damage
        Archmage = 0.07,  -- Awakened mage
        Rogue = 0.03,     -- Backstabs
        Shadow = 0.05,    -- Awakened rogue
        Priest = 0.04,    -- Combat healing
        Saint = 0.06,     -- Awakened priest
        Ranger = 0.06,    -- Beast companion
        Warden = 0.08     -- Awakened ranger
    },
    -- Non-combat (exploration/fetch) bonuses
    exploration = {
        Knight = 0.02,    -- Heavy armor slows exploration
        Paladin = 0.03,
        Archer = 0.04,    -- Good scouts
        Hawkeye = 0.06,
        Mage = 0.05,      -- Magic aids exploration
        Archmage = 0.07,
        Rogue = 0.10,     -- Stealth and agility excel
        Shadow = 0.12,
        Priest = 0.03,    -- Limited mobility
        Saint = 0.04,
        Ranger = 0.12,    -- Born explorers
        Warden = 0.15
    },
    -- Primary stat affinity bonuses (stacks with quest type)
    statAffinity = {
        str = { Knight = 0.05, Paladin = 0.06 },
        dex = { Archer = 0.05, Hawkeye = 0.06, Rogue = 0.05, Shadow = 0.06, Ranger = 0.04, Warden = 0.05 },
        int = { Mage = 0.08, Archmage = 0.10, Priest = 0.05, Saint = 0.06 },
        vit = { Knight = 0.03, Paladin = 0.04, Ranger = 0.03, Warden = 0.04, Priest = 0.03, Saint = 0.04 },
        luck = { Rogue = 0.06, Shadow = 0.08 }
    }
}

-- Calculate total class bonus for a party on a specific quest
local function calculateClassBonus(quest, heroes)
    local totalBonus = 0
    local questType = quest.combat and "combat" or "exploration"
    local requiredStat = quest.requiredStat or "str"

    for _, hero in ipairs(heroes) do
        local heroClass = hero.class

        -- Quest type bonus (combat vs exploration)
        local typeBonus = classQuestBonuses[questType][heroClass] or 0

        -- Stat affinity bonus (class matches required stat)
        local statBonus = 0
        if classQuestBonuses.statAffinity[requiredStat] then
            statBonus = classQuestBonuses.statAffinity[requiredStat][heroClass] or 0
        end

        totalBonus = totalBonus + typeBonus + statBonus
    end

    -- Average across party (so 4 knights don't get 4x bonus)
    return totalBonus / math.max(1, #heroes)
end

function Quests.calculateSuccessChance(quest, heroes, EquipmentSystem, gameData)
    if #heroes == 0 then return 0 end

    local data = loadQuestData()
    local config = data.config

    local totalPrimaryStat = 0
    local totalSecondaryStats = {}  -- Track each secondary stat total
    local totalLuck = 0

    -- Initialize secondary stat tracking
    for _, secStat in ipairs(quest.secondaryStats or {}) do
        totalSecondaryStats[secStat.stat] = 0
    end

    -- Rank values for comparison
    local rankValues = {D = 1, C = 2, B = 3, A = 4, S = 5}
    local questRankValue = rankValues[quest.rank] or 1
    local totalRankValue = 0

    for _, hero in ipairs(heroes) do
        totalRankValue = totalRankValue + (rankValues[hero.rank] or 1)

        -- Get injury penalty multiplier
        local injuryPenalty = hero.injuryState and injuryPenalties[hero.injuryState] or 1.0

        -- Apply injury penalty to primary stat
        local baseStat = math.floor((hero.stats[quest.requiredStat] or 10) * injuryPenalty)
        local equipStatBonus = 0
        if EquipmentSystem then
            equipStatBonus = EquipmentSystem.getStatBonus(hero, quest.requiredStat)
        end
        totalPrimaryStat = totalPrimaryStat + baseStat + equipStatBonus

        -- Calculate secondary stats
        for _, secStat in ipairs(quest.secondaryStats or {}) do
            local secBase = math.floor((hero.stats[secStat.stat] or 5) * injuryPenalty)
            local secEquip = EquipmentSystem and EquipmentSystem.getStatBonus(hero, secStat.stat) or 0
            totalSecondaryStats[secStat.stat] = (totalSecondaryStats[secStat.stat] or 0) + secBase + secEquip
        end

        local baseLuck = math.floor((hero.stats.luck or 5) * injuryPenalty)
        local equipLuckBonus = 0
        if EquipmentSystem then
            equipLuckBonus = EquipmentSystem.getStatBonus(hero, "luck")
        end
        totalLuck = totalLuck + baseLuck + equipLuckBonus
    end

    -- Base chance from rank comparison (average party rank vs quest rank)
    local avgRankValue = totalRankValue / #heroes
    local rankRatio = avgRankValue / questRankValue
    local baseChance
    if rankRatio >= 1 then
        -- Adequately ranked or over-ranked: 60% to 98%
        baseChance = math.min(0.60 + (rankRatio - 1) * 0.35, 0.98)
    else
        -- Under-ranked: scales from 15% (at ratio 0) to 60% (at ratio 1)
        -- This allows risky plays with lower rank heroes
        baseChance = 0.15 + (rankRatio * 0.45)
    end

    -- Rank bonus from config
    local rankBonus = 0
    if config.rankBonus then
        rankBonus = config.rankBonus[quest.rank] or 0
    end

    -- Primary stat bonus (weighted at 1.0) - scaled for 1-100 stat system
    -- Increased from 0.6% to 2% per point to make stats matter more
    local expectedStats = config.expectedStats or {D = 18, C = 32, B = 50, A = 72, S = 92}
    local expected = expectedStats[quest.rank] or 35
    local avgPrimaryStat = totalPrimaryStat / #heroes
    local primaryStatBonus = (avgPrimaryStat - expected) * 0.02

    -- Secondary stat bonuses (weighted by their importance)
    -- Increased from 0.3% to 1% per point
    local secondaryStatBonus = 0
    for _, secStat in ipairs(quest.secondaryStats or {}) do
        local avgSecStat = (totalSecondaryStats[secStat.stat] or 0) / #heroes
        -- Secondary stats compared against a lower expectation
        local secExpected = math.floor(expected * 0.7)
        local secBonus = (avgSecStat - secExpected) * 0.01 * secStat.weight
        secondaryStatBonus = secondaryStatBonus + secBonus
    end

    -- Luck bonus (scaled for 1-100 system, baseline ~25)
    local avgLuck = totalLuck / #heroes
    local luckBonus = (avgLuck - 25) * 0.002

    -- Synergy bonuses (from party system)
    local synergyBonuses = Quests.getSynergyBonuses(heroes, quest)
    local synergySuccessBonus = synergyBonuses.successBonus or 0

    -- Add stat-specific synergy bonuses
    if synergyBonuses.statBonuses and synergyBonuses.statBonuses[quest.requiredStat] then
        synergySuccessBonus = synergySuccessBonus + synergyBonuses.statBonuses[quest.requiredStat]
    end

    -- Passive ability bonuses (individual + party synergy archetype)
    local passiveEffects = Heroes.getPartyPassiveEffects(heroes)
    local passiveSuccessBonus = passiveEffects.successBonus or 0

    -- Class-specific bonuses (combat/exploration + stat affinity)
    local classBonus = calculateClassBonus(quest, heroes)

    -- Party trait bonuses (if heroes form a party and gameData is available)
    local partyTraitBonus = 0
    if gameData then
        local PS = getPartySystem()
        local PT = getPartyTraits()
        if PS and PT then
            -- Check if these heroes form a party
            local party = PS.findPartyByMembers(heroes, gameData)
            if party then
                -- Get trait bonuses applicable to this quest
                local traitBonuses = PT.getQuestBonuses(party, quest)
                partyTraitBonus = traitBonuses.successBonus or 0
            end
        end
    end

    local finalChance = baseChance + rankBonus + primaryStatBonus + secondaryStatBonus + luckBonus + synergySuccessBonus + passiveSuccessBonus + classBonus + partyTraitBonus
    return math.max(0.15, math.min(0.98, finalChance))
end

-- Check if party has a priest (for death protection)
function Quests.partyHasCleric(heroes)
    for _, hero in ipairs(heroes) do
        if hero.class == "Priest" or hero.class == "Saint" then
            return true
        end
    end
    return false
end

-- Get party roles for display (Tank, Healer, DPS, Support)
-- Returns a table of active roles with their heroes
function Quests.getPartyRoles(heroes)
    local roles = {
        tank = {active = false, heroes = {}, description = "Absorbs damage, protects party from death"},
        healer = {active = false, heroes = {}, description = "Reduces injury severity, prevents death on A/S quests"},
        dps = {active = false, heroes = {}, description = "Bonus success chance on combat quests"},
        support = {active = false, heroes = {}, description = "Party-wide buffs and exploration bonuses"}
    }

    local roleMapping = {
        -- Tanks
        Knight = "tank", Paladin = "tank",
        -- Healers
        Priest = "healer", Saint = "healer",
        -- DPS
        Archer = "dps", Hawkeye = "dps",
        Mage = "dps", Archmage = "dps",
        Rogue = "dps", Shadow = "dps",
        -- Support
        Ranger = "support", Warden = "support"
    }

    for _, hero in ipairs(heroes) do
        local role = roleMapping[hero.class]
        if role and roles[role] then
            roles[role].active = true
            table.insert(roles[role].heroes, hero)
        end
    end

    return roles
end

-- Get class bonus info for display
function Quests.getClassBonusInfo(quest, heroes)
    local bonuses = {}
    local questType = quest.combat and "combat" or "exploration"

    for _, hero in ipairs(heroes) do
        local typeBonus = classQuestBonuses[questType][hero.class] or 0
        local statBonus = 0
        if classQuestBonuses.statAffinity[quest.requiredStat] then
            statBonus = classQuestBonuses.statAffinity[quest.requiredStat][hero.class] or 0
        end
        local totalBonus = typeBonus + statBonus

        if totalBonus > 0 then
            table.insert(bonuses, {
                hero = hero,
                bonus = totalBonus,
                reason = questType == "combat" and "Combat specialist" or "Exploration expert"
            })
        end
    end

    return bonuses
end

-- Get all synergy definitions
function Quests.getSynergies()
    local data = loadSynergyData()
    return data.synergies or {}
end

-- Check if a hero's class matches any in a class list (handles "Class1|Class2" format)
local function classMatches(heroClass, classPattern)
    if classPattern:find("|") then
        for match in classPattern:gmatch("[^|]+") do
            if heroClass == match then return true end
        end
        return false
    end
    return heroClass == classPattern
end

-- Calculate active synergies for a party
function Quests.calculateSynergies(heroes, quest)
    if #heroes == 0 then return {} end

    local data = loadSynergyData()
    local synergies = data.synergies or {}
    local activeSynergies = {}

    -- Count classes in party
    local classCounts = {}
    local uniqueClasses = {}
    for _, hero in ipairs(heroes) do
        classCounts[hero.class] = (classCounts[hero.class] or 0) + 1
        uniqueClasses[hero.class] = true
    end

    local uniqueClassCount = 0
    for _ in pairs(uniqueClasses) do uniqueClassCount = uniqueClassCount + 1 end

    -- Check each synergy
    for _, synergy in ipairs(synergies) do
        local req = synergy.requirements
        local isActive = false

        -- Check minCount requirement (at least N heroes of specific classes)
        if req.classes and req.minCount then
            local matchCount = 0
            for _, hero in ipairs(heroes) do
                for _, reqClass in ipairs(req.classes) do
                    if classMatches(hero.class, reqClass) then
                        matchCount = matchCount + 1
                        break
                    end
                end
            end
            isActive = matchCount >= req.minCount
        end

        -- Check combination requirement (must have one from each group)
        if req.combination then
            local allGroupsMatch = true
            for _, group in ipairs(req.combination) do
                local groupMatches = false
                for _, hero in ipairs(heroes) do
                    if classMatches(hero.class, group) then
                        groupMatches = true
                        break
                    end
                end
                if not groupMatches then
                    allGroupsMatch = false
                    break
                end
            end
            isActive = allGroupsMatch
        end

        -- Check unique classes requirement
        if req.uniqueClasses then
            isActive = uniqueClassCount >= req.uniqueClasses
        end

        -- Check quest type requirement
        if isActive and req.questType and quest then
            if req.questType == "combat" and not quest.combat then
                isActive = false
            end
        end

        if isActive then
            table.insert(activeSynergies, synergy)
        end
    end

    -- Sort by priority (higher = more important)
    table.sort(activeSynergies, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)

    return activeSynergies
end

-- Get total synergy bonuses for a party
function Quests.getSynergyBonuses(heroes, quest)
    local activeSynergies = Quests.calculateSynergies(heroes, quest)
    local bonuses = {
        successBonus = 0,
        survivalBonus = 0,
        dropBonus = 0,
        travelTimeReduction = 0,
        deathProtection = false,
        statBonuses = {},
        allBonus = 0,
        activeSynergies = activeSynergies
    }

    for _, synergy in ipairs(activeSynergies) do
        local b = synergy.bonus
        if b.successBonus then
            bonuses.successBonus = bonuses.successBonus + b.successBonus
        end
        if b.survivalBonus then
            bonuses.survivalBonus = bonuses.survivalBonus + b.survivalBonus
        end
        if b.dropBonus then
            bonuses.dropBonus = bonuses.dropBonus + b.dropBonus
        end
        if b.travelTimeReduction then
            bonuses.travelTimeReduction = bonuses.travelTimeReduction + b.travelTimeReduction
        end
        if b.deathProtection then
            bonuses.deathProtection = true
        end
        if b.allBonus then
            bonuses.allBonus = bonuses.allBonus + b.allBonus
        end
        if b.statBonus then
            for stat, value in pairs(b.statBonus) do
                bonuses.statBonuses[stat] = (bonuses.statBonuses[stat] or 0) + value
            end
        end
    end

    -- Apply all bonus to relevant bonuses
    if bonuses.allBonus > 0 then
        bonuses.successBonus = bonuses.successBonus + bonuses.allBonus
        bonuses.survivalBonus = bonuses.survivalBonus + bonuses.allBonus
        bonuses.dropBonus = bonuses.dropBonus + bonuses.allBonus
    end

    return bonuses
end

-- Resolve a quest (called when quest completes)
-- partyLuckBonus: optional flat luck bonus from formed party
-- gameData: optional gameData for party trait bonus lookups
-- Check if party has a tank role (Knight, Paladin)
local function partyHasTank(heroes)
    for _, hero in ipairs(heroes) do
        if hero.class == "Knight" or hero.class == "Paladin" then
            return true, hero
        end
    end
    return false, nil
end

-- Check if party has a healer role (Priest, Saint)
local function partyHasHealer(heroes)
    for _, hero in ipairs(heroes) do
        if hero.class == "Priest" or hero.class == "Saint" then
            return true, hero
        end
    end
    return false, nil
end

-- Get injury severity based on roles
-- Returns: severity ("wounded", "injured", "fatigued") and any protected heroes
local function getInjurySeverityWithRoles(heroes, baseInjurySeverity)
    local hasTank, tankHero = partyHasTank(heroes)
    local hasHealer, _ = partyHasHealer(heroes)

    local results = {}
    local tankAbsorbedInjury = false

    for _, hero in ipairs(heroes) do
        local severity = baseInjurySeverity

        -- Tank absorbs first severe injury for party
        if hasTank and not tankAbsorbedInjury and hero ~= tankHero then
            if severity == "wounded" then
                severity = "injured"  -- Tank absorbs the worst of it
                tankAbsorbedInjury = true
            end
        end

        -- Healer reduces injury severity by one level
        if hasHealer then
            if severity == "wounded" then
                severity = "injured"
            elseif severity == "injured" then
                severity = "fatigued"
            end
        end

        results[hero.id] = severity
    end

    -- Tank takes extra injury for protecting party
    if tankAbsorbedInjury and tankHero then
        results[tankHero.id] = "wounded"  -- Tank takes the hit
    end

    return results
end

-- Generate narrative text for non-combat quests
-- Creates a simple story of what happened during the quest
function Quests.generateNarrative(quest, heroes, success)
    local narrative = {}

    -- Get hero names for the narrative
    local heroNames = {}
    for _, hero in ipairs(heroes) do
        table.insert(heroNames, hero.name)
    end

    local partyDesc = #heroNames == 1 and heroNames[1] or
                      (#heroNames == 2 and (heroNames[1] .. " and " .. heroNames[2])) or
                      "the party"

    -- Quest-specific narratives based on keywords
    local questLower = quest.name:lower()

    if success then
        -- Success narratives
        if questLower:find("cat") or questLower:find("pet") then
            table.insert(narrative, {
                emoji = "🐱",
                text = partyDesc .. " searched high and low through the village."
            })
            table.insert(narrative, {
                emoji = "🌳",
                text = "They found the missing cat hiding in an old oak tree."
            })
            table.insert(narrative, {
                emoji = "😊",
                text = "The grateful owner rewarded them handsomely!"
            })
        elseif questLower:find("herb") or questLower:find("gather") or questLower:find("collect") then
            table.insert(narrative, {
                emoji = "🌿",
                text = partyDesc .. " ventured into the wilderness."
            })
            table.insert(narrative, {
                emoji = "🔍",
                text = "After careful searching, they found everything needed."
            })
            table.insert(narrative, {
                emoji = "✅",
                text = "They returned with baskets full of valuable materials!"
            })
        elseif questLower:find("deliver") or questLower:find("escort") or questLower:find("guard") then
            table.insert(narrative, {
                emoji = "📦",
                text = partyDesc .. " set out on the journey."
            })
            table.insert(narrative, {
                emoji = "🛣️",
                text = "The roads were clear and the weather held."
            })
            table.insert(narrative, {
                emoji = "🎉",
                text = "The delivery was completed without incident!"
            })
        elseif questLower:find("investigate") or questLower:find("mystery") or questLower:find("find") then
            table.insert(narrative, {
                emoji = "🔎",
                text = partyDesc .. " began their investigation."
            })
            table.insert(narrative, {
                emoji = "💡",
                text = "Careful questioning and observation paid off."
            })
            table.insert(narrative, {
                emoji = "📜",
                text = "The truth was uncovered!"
            })
        else
            -- Generic success
            table.insert(narrative, {
                emoji = "⭐",
                text = partyDesc .. " accepted the quest with determination."
            })
            table.insert(narrative, {
                emoji = "💪",
                text = "Through skill and perseverance, they succeeded."
            })
            table.insert(narrative, {
                emoji = "🏆",
                text = "Another job well done for the guild!"
            })
        end
    else
        -- Failure narratives
        if questLower:find("cat") or questLower:find("pet") then
            table.insert(narrative, {
                emoji = "🐱",
                text = partyDesc .. " searched throughout the village."
            })
            table.insert(narrative, {
                emoji = "😿",
                text = "But the clever cat evaded them at every turn."
            })
            table.insert(narrative, {
                emoji = "😔",
                text = "They returned empty-handed, but wiser."
            })
        elseif questLower:find("herb") or questLower:find("gather") or questLower:find("collect") then
            table.insert(narrative, {
                emoji = "🌧️",
                text = partyDesc .. " ventured out but the weather turned."
            })
            table.insert(narrative, {
                emoji = "❌",
                text = "A sudden storm forced them to retreat early."
            })
            table.insert(narrative, {
                emoji = "📉",
                text = "Only a fraction of the needed items were gathered."
            })
        elseif questLower:find("deliver") or questLower:find("escort") or questLower:find("guard") then
            table.insert(narrative, {
                emoji = "🚧",
                text = partyDesc .. " encountered unexpected obstacles."
            })
            table.insert(narrative, {
                emoji = "⚠️",
                text = "A bridge was out, forcing a long detour."
            })
            table.insert(narrative, {
                emoji = "⏰",
                text = "They arrived too late to complete the delivery."
            })
        else
            -- Generic failure
            table.insert(narrative, {
                emoji = "😤",
                text = partyDesc .. " gave it their best effort."
            })
            table.insert(narrative, {
                emoji = "🌀",
                text = "But circumstances conspired against them."
            })
            table.insert(narrative, {
                emoji = "📚",
                text = "A valuable lesson was learned nonetheless."
            })
        end
    end

    return narrative
end

function Quests.resolve(quest, heroes, partyLuckBonus, gameData)
    partyLuckBonus = partyLuckBonus or 0

    -- Load combat system for combat quests
    local CombatSystem = require("systems.combat_system")

    -- Calculate luck multiplier for reward rolls (includes party bonus)
    local totalLuck = 0
    for _, hero in ipairs(heroes) do
        totalLuck = totalLuck + hero.stats.luck + partyLuckBonus
    end
    local avgLuck = #heroes > 0 and (totalLuck / #heroes) or 5
    local luckMultiplier = 1.0 + (avgLuck - 5) * 0.05

    -- Get passive effects for reward/survival modifiers
    local passiveEffects = Heroes.getPartyPassiveEffects(heroes)

    local result = {
        success = false,
        goldReward = 0,
        xpReward = 0,
        message = "",
        bonusRewards = {},
        heroDeaths = {},
        heroInjuries = {},
        passiveSynergy = Heroes.getSynergyInfo(heroes),
        -- Combat log (for combat quests)
        combatLog = nil,
        combatSummary = nil,
        -- Non-combat narrative (for non-combat quests)
        narrative = nil
    }

    -- ═══════════════════════════════════════════════════════════════════
    -- COMBAT QUESTS: Use detailed battle simulation
    -- ═══════════════════════════════════════════════════════════════════
    if quest.combat then
        local combatResult = CombatSystem.runCombat(quest, heroes)

        result.success = combatResult.success
        result.combatLog = combatResult.log
        result.combatSummary = combatResult.summary

        -- Transfer deaths from combat
        for _, heroCombatant in ipairs(combatResult.heroes) do
            if not heroCombatant.isAlive then
                table.insert(result.heroDeaths, heroCombatant.sourceHero)
            end
        end

        -- Build message based on combat result
        if result.success then
            result.message = string.format("Victory in %d rounds!", combatResult.rounds)
            if combatResult.summary.mvp then
                result.message = result.message .. " MVP: " .. combatResult.summary.mvp.name
            end
        else
            result.message = string.format("Defeated after %d rounds of combat.", combatResult.rounds)
        end

    -- ═══════════════════════════════════════════════════════════════════
    -- NON-COMBAT QUESTS: Use narrative resolution with RNG
    -- ═══════════════════════════════════════════════════════════════════
    else
        local successChance = Quests.calculateSuccessChance(quest, heroes, nil, gameData)
        local roll = math.random()
        result.success = roll <= successChance

        -- Generate narrative for non-combat quests
        result.narrative = Quests.generateNarrative(quest, heroes, result.success)
    end

    -- Apply success/failure rewards (common to both types)

    if result.success then
        result.goldReward = quest.reward
        result.xpReward = quest.xpReward

        -- Keep combat message or set default
        if not quest.combat then
            result.message = "Quest completed successfully!"
        end

        -- Roll for bonus rewards (with material bonus from passives)
        local materialLuckMultiplier = luckMultiplier * (1 + (passiveEffects.materialBonus or 0))
        result.bonusRewards = Quests.rollRewards(quest, materialLuckMultiplier)

        -- Add bonus gold from rewards
        for _, reward in ipairs(result.bonusRewards) do
            if reward.type == "gold" then
                result.goldReward = result.goldReward + reward.amount
            end
        end

        -- Apply gold bonus from passives
        local goldMultiplier = 1 + (passiveEffects.goldBonus or 0)
        result.goldReward = math.floor(result.goldReward * goldMultiplier)

        -- Apply XP bonus from passives
        local xpMultiplier = 1 + (passiveEffects.xpBonus or 0)
        result.xpReward = math.floor(result.xpReward * xpMultiplier)
    else
        -- Partial rewards on failure
        result.goldReward = math.floor(quest.reward * 0.2)
        result.xpReward = math.floor(quest.xpReward * 0.3)

        -- Keep combat message or set default
        if not quest.combat then
            result.message = "Quest failed, but heroes gained experience."
        end

        -- Check for role-based protection
        local hasTank, tankHero = partyHasTank(heroes)
        local hasHealer, _ = partyHasHealer(heroes)

        -- Combat quests: deaths already determined by combat system
        -- Only handle injuries for surviving heroes
        if quest.combat then
            -- Survivors from combat get injuries
            for _, hero in ipairs(heroes) do
                local isDead = false
                for _, deadHero in ipairs(result.heroDeaths) do
                    if deadHero.id == hero.id then
                        isDead = true
                        break
                    end
                end
                if not isDead then
                    table.insert(result.heroInjuries, hero)
                end
            end

        -- Non-combat quests with death risk (shouldn't happen, but handle anyway)
        elseif quest.canKill then
            local hasCleric = Quests.partyHasCleric(heroes)

            -- Calculate reduced death chance from passives
            local deathReduction = passiveEffects.deathReduction or 0
            local adjustedDeathChance = quest.deathChance * (1 - deathReduction)

            -- Tank reduces death chance for non-tanks by 20%
            local tankDeathReduction = hasTank and 0.20 or 0

            for _, hero in ipairs(heroes) do
                -- Skip if cleric protection applies
                if hasCleric and quest.clericProtection then
                    table.insert(result.heroInjuries, hero)
                else
                    -- Calculate hero-specific death chance
                    local heroDeathChance = adjustedDeathChance
                    if hasTank and hero ~= tankHero then
                        heroDeathChance = heroDeathChance * (1 - tankDeathReduction)
                    end

                    -- Roll for death (with passive reduction)
                    if math.random() <= heroDeathChance then
                        -- Check for escape artist skill (Rogue level 10)
                        local hasEscapeArtist = hero.class == "Rogue" and hero.level >= 10

                        -- Check for Shadow Step passive (50% death evade)
                        local hasShadowStep = hero.passive and hero.passive.id == "shadow_step"
                        local evadedDeath = hasShadowStep and math.random() <= 0.5

                        if not hasEscapeArtist and not evadedDeath then
                            table.insert(result.heroDeaths, hero)
                        else
                            table.insert(result.heroInjuries, hero)
                        end
                    else
                        table.insert(result.heroInjuries, hero)
                    end
                end
            end

            if hasCleric and quest.clericProtection and #heroes > 0 then
                result.message = result.message .. " Cleric's divine protection saved the party from death!"
            end
            if hasTank and #heroes > 1 then
                result.message = result.message .. " " .. tankHero.name .. " shielded the party!"
            end
        elseif quest.combat and quest.injuryOnly then
            -- D/C/B rank combat: injuries only, but roles reduce severity
            local baseInjury = "injured"  -- Default injury level for failed combat

            -- Determine injury severity with role protection
            local injurySeverities = getInjurySeverityWithRoles(heroes, baseInjury)

            for _, hero in ipairs(heroes) do
                hero.pendingInjury = injurySeverities[hero.id] or "fatigued"
                table.insert(result.heroInjuries, hero)
            end

            -- Add role protection messages
            if hasHealer then
                result.message = result.message .. " Healer reduced injury severity!"
            end
            if hasTank and #heroes > 1 then
                result.message = result.message .. " " .. tankHero.name .. " absorbed damage for the party!"
            end
        end
    end

    return result
end

-- Reload quest data (for hot-reloading during development)
function Quests.reload()
    questData = nil
    synergyData = nil
    loadQuestData()
    loadSynergyData()
    print("Quest and synergy data reloaded from JSON")
end

return Quests
