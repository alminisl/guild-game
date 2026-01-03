-- Heroes Data Module
-- Hero generation, classes, names, and stats - loaded from JSON

local json = require("utils.json")

local Heroes = {}

-- Load hero data from JSON
local heroData = nil
local function loadHeroData()
    if heroData then return heroData end

    local data, err = json.loadFile("data/heroes.json")
    if not data then
        print("ERROR loading heroes.json: " .. (err or "unknown error"))
        -- Minimal fallback data
        data = {
            config = {
                rankPower = {D = 1, C = 2, B = 3, A = 4, S = 5},
                rankCost = {D = 50, C = 100, B = 200, A = 500, S = 1000},
                baseRestTime = {D = 20, C = 15, B = 12, A = 8, S = 5},
                baseStats = {
                    D = {min = 2, max = 5, cap = 10},
                    C = {min = 3, max = 6, cap = 10},
                    B = {min = 5, max = 8, cap = 10},
                    A = {min = 10, max = 13, cap = 17},
                    S = {min = 14, max = 17, cap = 20}
                },
                maxLevel = 10
            },
            classes = {},
            races = {},
            names = {firstNames = {"Hero"}, lastNames = {"Unknown"}, titles = {}}
        }
    end
    heroData = data
    return heroData
end

-- Get config value
function Heroes.getConfig(key)
    local data = loadHeroData()
    return data.config[key]
end

-- Rank power values (compatible with old code)
Heroes.rankPower = setmetatable({}, {
    __index = function(_, rank)
        local data = loadHeroData()
        return data.config.rankPower[rank] or 1
    end
})

-- Rank hire costs
Heroes.rankCost = setmetatable({}, {
    __index = function(_, rank)
        local data = loadHeroData()
        return data.config.rankCost[rank] or 100
    end
})

-- Base rest times by rank
Heroes.baseRestTime = setmetatable({}, {
    __index = function(_, rank)
        local data = loadHeroData()
        return data.config.baseRestTime[rank] or 15
    end
})

-- Class definitions
Heroes.classes = setmetatable({}, {
    __index = function(_, className)
        local data = loadHeroData()
        return data.classes[className]
    end,
    __pairs = function(_)
        local data = loadHeroData()
        return pairs(data.classes)
    end
})

-- Get list of normal (non-awakened) classes
function Heroes.getNormalClasses()
    local data = loadHeroData()
    local classes = {}
    for name, classData in pairs(data.classes) do
        if not classData.isAwakened then
            table.insert(classes, name)
        end
    end
    return classes
end

-- Get list of awakened classes
function Heroes.getAwakenedClasses()
    local data = loadHeroData()
    local classes = {}
    for name, classData in pairs(data.classes) do
        if classData.isAwakened then
            table.insert(classes, name)
        end
    end
    return classes
end

-- Compatibility properties
Heroes.normalClasses = nil  -- Will be lazy-loaded
Heroes.awakenedClasses = nil

-- Race definitions
Heroes.races = setmetatable({}, {
    __index = function(_, raceName)
        local data = loadHeroData()
        return data.races[raceName]
    end,
    __pairs = function(_)
        local data = loadHeroData()
        return pairs(data.races)
    end
})

-- Get list of races
function Heroes.getRaceList()
    local data = loadHeroData()
    local races = {}
    for name, _ in pairs(data.races) do
        table.insert(races, name)
    end
    return races
end

Heroes.raceList = nil  -- Will be lazy-loaded

-- Guild level to hero level range mapping
function Heroes.getGuildLevelRange(guildLevel)
    local data = loadHeroData()
    local mapping = data.config.guildLevelToHeroLevel
    if mapping then
        local range = mapping[tostring(guildLevel)]
        if range then
            return range.min, range.max
        end
    end
    return 1, 2
end

-- Name pools
function Heroes.getFirstNames()
    local data = loadHeroData()
    return data.names.firstNames or {"Hero"}
end

function Heroes.getLastNames()
    local data = loadHeroData()
    return data.names.lastNames or {"Unknown"}
end

function Heroes.getTitles(rank)
    local data = loadHeroData()
    if data.names.titles then
        return data.names.titles[rank]
    end
    return nil
end

-- Max level cap
Heroes.MAX_LEVEL = 10

-- Injury system configuration
Heroes.injuryConfig = {
    -- Injury states and their effects
    states = {
        fatigued = {
            name = "Fatigued",
            statPenalty = 0.90,       -- 10% stat reduction
            restMultiplier = 1.0,     -- Normal rest time
            canQuest = true,          -- Can still go on quests
            color = {0.7, 0.7, 0.3},
            description = "Tired from recent quest. -10% stats."
        },
        injured = {
            name = "Injured",
            statPenalty = 0.75,       -- 25% stat reduction
            restMultiplier = 2.0,     -- 2x rest time
            canQuest = true,          -- Can quest but risky
            color = {0.8, 0.5, 0.2},
            description = "Wounded in battle. -25% stats, 2x rest time."
        },
        wounded = {
            name = "Wounded",
            statPenalty = 0.50,       -- 50% stat reduction
            restMultiplier = 3.0,     -- 3x rest time
            canQuest = false,         -- Cannot quest until healed
            color = {0.7, 0.2, 0.2},
            description = "Severely wounded. Cannot quest. -50% stats, 3x rest time."
        }
    },
    -- Which injury state results from quest outcomes by rank
    questOutcomes = {
        success = "fatigued",         -- All successes cause fatigue
        failureLow = "injured",       -- D/C/B rank failures
        failureHigh = "wounded"       -- A/S rank failures (with protection)
    }
}

-- Internal ID counter
local nextHeroId = 1

-- Generate random stats based on rank, class, and race
local function generateStats(rank, class, race)
    local data = loadHeroData()
    local baseStats = data.config.baseStats

    local range = baseStats[rank] or {min = 3, max = 6, cap = 10}
    local classData = data.classes[class]
    local raceData = data.races[race]

    local classBonus = classData and classData.statBonus or {str = 0, dex = 0, int = 0, vit = 0, luck = 0}
    local raceBonus = raceData and raceData.statBonus or {str = 0, dex = 0, int = 0, vit = 0, luck = 0}

    -- Get rank-specific stat cap (D/C/B max 10, A max 17, S max 20)
    local statCap = range.cap or 10

    local stats = {
        str = math.random(range.min, range.max) + (classBonus.str or 0) + (raceBonus.str or 0),
        dex = math.random(range.min, range.max) + (classBonus.dex or 0) + (raceBonus.dex or 0),
        int = math.random(range.min, range.max) + (classBonus.int or 0) + (raceBonus.int or 0),
        vit = math.random(range.min, range.max) + (classBonus.vit or 0) + (raceBonus.vit or 0),
        luck = math.random(range.min, range.max) + (classBonus.luck or 0) + (raceBonus.luck or 0)
    }

    -- Clamp stats to rank-specific cap
    for stat, value in pairs(stats) do
        stats[stat] = math.max(1, math.min(statCap, value))
    end

    return stats
end

-- Select a random race, weighted by rarity
local function selectRace()
    local data = loadHeroData()
    local totalRarity = 0
    for _, race in pairs(data.races) do
        totalRarity = totalRarity + (race.rarity or 10)
    end

    local roll = math.random(totalRarity)
    local cumulative = 0
    for raceName, race in pairs(data.races) do
        cumulative = cumulative + (race.rarity or 10)
        if roll <= cumulative then
            return raceName
        end
    end
    return "Human"
end

-- Select a class based on race preference
local function selectClassForRace(race, isAwakened)
    local data = loadHeroData()
    local raceData = data.races[race]

    if not raceData then
        local classes = isAwakened and Heroes.getAwakenedClasses() or Heroes.getNormalClasses()
        return classes[math.random(#classes)]
    end

    -- 70% chance to pick a preferred class, 30% any class
    if math.random(100) <= 70 and raceData.preferredClasses and #raceData.preferredClasses > 0 then
        local preferredClass = raceData.preferredClasses[math.random(#raceData.preferredClasses)]
        if isAwakened then
            -- Find the awakened version
            local classData = data.classes[preferredClass]
            if classData and classData.awakened then
                return classData.awakened
            end
        end
        return preferredClass
    else
        local classes = isAwakened and Heroes.getAwakenedClasses() or Heroes.getNormalClasses()
        return classes[math.random(#classes)]
    end
end

-- Generate a random name
local function generateName(rank)
    local firstNames = Heroes.getFirstNames()
    local lastNames = Heroes.getLastNames()

    local firstName = firstNames[math.random(#firstNames)]
    local lastName = lastNames[math.random(#lastNames)]

    -- Add title for high ranks
    local titles = Heroes.getTitles(rank)
    if titles and #titles > 0 then
        local title = titles[math.random(#titles)]
        return title .. " " .. firstName .. " " .. lastName
    end

    return firstName .. " " .. lastName
end

-- Calculate hero power based on rank and level
function Heroes.calculatePower(rank, level)
    local data = loadHeroData()
    local basePower = data.config.rankPower[rank] or 1
    local levelBonus = math.floor((level - 1) / 5)
    return basePower + levelBonus
end

-- Generate a new hero
function Heroes.generate(options)
    options = options or {}
    local data = loadHeroData()

    -- Determine rank
    local rank = options.rank
    if not rank then
        local weights = data.rankWeights or {D = 50, C = 30, B = 13, A = 6, S = 1}
        local total = 0
        for _, w in pairs(weights) do total = total + w end
        local roll = math.random(total)
        local cumulative = 0
        for r, w in pairs(weights) do
            cumulative = cumulative + w
            if roll <= cumulative then
                rank = r
                break
            end
        end
        rank = rank or "D"
    end

    -- Determine race first
    local race = options.race or selectRace()

    -- Determine class
    local class = options.class
    if not class then
        class = selectClassForRace(race, rank == "S")
    end

    -- Determine level
    local level = options.level or 1
    if options.guildLevel and not options.level then
        local minL, maxL = Heroes.getGuildLevelRange(options.guildLevel)
        level = math.random(minL, maxL)
    end

    -- S-rank heroes start at level 5 minimum
    if rank == "S" and level < 5 then
        level = 5
    end

    local classData = data.classes[class]

    local hero = {
        id = nextHeroId,
        name = options.name or generateName(rank),
        race = race,
        class = class,
        rank = rank,
        level = level,
        xp = 0,
        xpToLevel = level < Heroes.MAX_LEVEL and (100 * level) or 0,
        stats = generateStats(rank, class, race),
        status = "idle",
        power = Heroes.calculatePower(rank, level),
        hireCost = data.config.rankCost[rank] or 100,
        isAwakened = classData and classData.isAwakened or false,
        currentQuestId = nil,
        questPhase = nil,
        questProgress = 0,
        questPhaseMax = 0,
        restProgress = 0,
        restTimeMax = 0,
        restSpeedBonus = 1,
        failureCount = 0,
        injuryState = nil,  -- nil = healthy, or "fatigued", "injured", "wounded"
        equipment = {
            weapon = nil,
            armor = nil,
            accessory = nil
        }
    }

    nextHeroId = nextHeroId + 1
    return hero
end

-- Generate a pool of heroes for the tavern
function Heroes.generateTavernPool(count, maxRank, guildLevel)
    count = count or 4
    maxRank = maxRank or "B"
    guildLevel = guildLevel or 1

    local rankOrder = {"D", "C", "B", "A", "S"}
    local maxRankIndex = 1
    for i, r in ipairs(rankOrder) do
        if r == maxRank then maxRankIndex = i break end
    end

    -- S-rank only available at guild level 5+
    if guildLevel < 5 then
        maxRankIndex = math.min(maxRankIndex, 4)
    end

    local pool = {}
    for i = 1, count do
        local roll = math.random(100)
        local rank
        if roll <= 50 then rank = "D"
        elseif roll <= 80 then rank = "C"
        elseif roll <= 95 and maxRankIndex >= 3 then rank = "B"
        elseif roll <= 99 and maxRankIndex >= 4 then rank = "A"
        elseif maxRankIndex >= 5 then rank = "S"
        else rank = rankOrder[math.min(maxRankIndex, 2)]
        end

        table.insert(pool, Heroes.generate({rank = rank, guildLevel = guildLevel}))
    end

    return pool
end

-- Class skills (from JSON)
function Heroes.getClassSkills(className)
    local data = loadHeroData()
    local classData = data.classes[className]
    if classData and classData.skills then
        return classData.skills
    end
    return {}
end

-- Check if hero has a specific skill
function Heroes.hasSkill(hero, skillId)
    local skills = Heroes.getClassSkills(hero.class)
    for levelStr, skill in pairs(skills) do
        local level = tonumber(levelStr)
        if skill.id == skillId and hero.level >= level then
            return true
        end
    end
    return false
end

-- Get all unlocked skills for a hero
function Heroes.getUnlockedSkills(hero)
    local skills = {}
    local classSkills = Heroes.getClassSkills(hero.class)
    for levelStr, skill in pairs(classSkills) do
        local level = tonumber(levelStr)
        if hero.level >= level then
            table.insert(skills, skill)
        end
    end
    return skills
end

-- Add XP to a hero and handle level up
function Heroes.addXP(hero, amount)
    hero.xp = hero.xp + amount

    local leveledUp = false
    while hero.xp >= hero.xpToLevel and hero.level < Heroes.MAX_LEVEL do
        hero.xp = hero.xp - hero.xpToLevel
        hero.level = hero.level + 1
        hero.xpToLevel = 100 * hero.level
        hero.power = Heroes.calculatePower(hero.rank, hero.level)
        leveledUp = true

        local statKeys = {"str", "dex", "int", "vit", "luck"}
        local randomStat = statKeys[math.random(#statKeys)]
        hero.stats[randomStat] = math.min(20, hero.stats[randomStat] + 1)
    end

    if hero.level >= Heroes.MAX_LEVEL then
        hero.xp = 0
        hero.xpToLevel = 0
    end

    return leveledUp
end

-- Get total party power
function Heroes.getPartyPower(heroList)
    local totalPower = 0
    for _, hero in ipairs(heroList) do
        totalPower = totalPower + hero.power
    end
    return totalPower
end

-- Get hero's primary stat based on class
function Heroes.getPrimaryStat(hero)
    local data = loadHeroData()
    local classData = data.classes[hero.class]
    if classData and classData.primaryStat then
        return classData.primaryStat
    end
    return "str"
end

-- Start hero resting after quest
function Heroes.startResting(hero, questRank, failed)
    local data = loadHeroData()
    local baseRest = data.config.baseRestTime[hero.rank] or 15
    local questMultiplier = (data.config.rankPower[questRank] or 1) * 0.5 + 0.5
    local vitBonus = 1 - (hero.stats.vit - 10) * 0.02

    -- Get injury rest multiplier
    local injuryInfo = Heroes.getInjuryInfo(hero)
    local injuryMultiplier = injuryInfo.restMultiplier or 1.0

    hero.restTimeMax = baseRest * questMultiplier * math.max(0.5, vitBonus) * injuryMultiplier
    hero.restProgress = 0
    hero.status = "resting"
end

-- Record a quest failure
function Heroes.recordFailure(hero)
    hero.failureCount = (hero.failureCount or 0) + 1
    return hero.failureCount >= 3
end

-- Check if hero is dead
function Heroes.isDead(hero)
    return (hero.failureCount or 0) >= 3
end

-- Update hero rest progress
function Heroes.updateRest(hero, dt)
    if hero.status ~= "resting" then return false end

    hero.restProgress = hero.restProgress + (dt * hero.restSpeedBonus)

    if hero.restProgress >= hero.restTimeMax then
        hero.status = "idle"
        hero.restProgress = 0
        hero.restTimeMax = 0
        hero.restSpeedBonus = 1

        -- Heal one level of injury when rest completes
        Heroes.healInjury(hero)

        return true
    end
    return false
end

-- Get rest progress as percentage
function Heroes.getRestPercent(hero)
    if hero.restTimeMax <= 0 then return 1 end
    return hero.restProgress / hero.restTimeMax
end

-- Apply rest speed bonus
function Heroes.applyRestBonus(hero, bonusMultiplier)
    hero.restSpeedBonus = hero.restSpeedBonus * bonusMultiplier
end

-- Instantly finish resting
function Heroes.finishResting(hero)
    if hero.status == "resting" then
        hero.status = "idle"
        hero.restProgress = 0
        hero.restTimeMax = 0
        hero.restSpeedBonus = 1
    end
end

-- Check if hero is available
function Heroes.isAvailable(hero)
    return hero.status == "idle"
end

-- ============================================
-- INJURY SYSTEM FUNCTIONS
-- ============================================

-- Apply an injury state to a hero
function Heroes.applyInjury(hero, injuryState)
    if not injuryState then return end

    local config = Heroes.injuryConfig.states[injuryState]
    if not config then return end

    -- Don't downgrade injuries (wounded > injured > fatigued)
    local severity = {fatigued = 1, injured = 2, wounded = 3}
    local currentSeverity = hero.injuryState and severity[hero.injuryState] or 0
    local newSeverity = severity[injuryState] or 0

    if newSeverity > currentSeverity then
        hero.injuryState = injuryState
    end
end

-- Get injury state info
function Heroes.getInjuryInfo(hero)
    if not hero.injuryState then
        return {
            name = "Healthy",
            statPenalty = 1.0,
            restMultiplier = 1.0,
            canQuest = true,
            color = {0.3, 0.7, 0.3},
            description = "In good condition."
        }
    end
    return Heroes.injuryConfig.states[hero.injuryState] or Heroes.injuryConfig.states.fatigued
end

-- Check if hero can go on quests (not wounded)
function Heroes.canQuest(hero)
    if hero.status ~= "idle" then return false end
    local info = Heroes.getInjuryInfo(hero)
    return info.canQuest
end

-- Get effective stats (base stats with injury penalty applied)
function Heroes.getEffectiveStats(hero)
    local info = Heroes.getInjuryInfo(hero)
    local penalty = info.statPenalty

    return {
        str = math.floor(hero.stats.str * penalty),
        dex = math.floor(hero.stats.dex * penalty),
        int = math.floor(hero.stats.int * penalty),
        vit = math.floor(hero.stats.vit * penalty),
        luck = math.floor(hero.stats.luck * penalty)
    }
end

-- Get a single effective stat value
function Heroes.getEffectiveStat(hero, stat)
    local info = Heroes.getInjuryInfo(hero)
    local baseValue = hero.stats[stat] or 0
    return math.floor(baseValue * info.statPenalty)
end

-- Clear injury state (hero is healed)
function Heroes.clearInjury(hero)
    hero.injuryState = nil
end

-- Heal one level of injury (wounded -> injured -> fatigued -> healthy)
function Heroes.healInjury(hero)
    if hero.injuryState == "wounded" then
        hero.injuryState = "injured"
    elseif hero.injuryState == "injured" then
        hero.injuryState = "fatigued"
    elseif hero.injuryState == "fatigued" then
        hero.injuryState = nil
    end
end

-- Check if hero has any injury
function Heroes.hasInjury(hero)
    return hero.injuryState ~= nil
end

-- Get injury severity (0 = healthy, 1 = fatigued, 2 = injured, 3 = wounded)
function Heroes.getInjurySeverity(hero)
    local severity = {fatigued = 1, injured = 2, wounded = 3}
    return hero.injuryState and severity[hero.injuryState] or 0
end

-- Determine injury from quest outcome
function Heroes.determineInjury(questRank, success, hasClericProtection)
    if success then
        -- Successful quests cause fatigue
        return "fatigued"
    else
        -- Failed quests cause injuries based on rank
        local highRanks = {A = true, S = true}
        if highRanks[questRank] then
            -- High rank failures cause wounds (or death without protection)
            if hasClericProtection then
                return "wounded"
            else
                return nil  -- Death handled elsewhere
            end
        else
            -- Low rank failures cause injuries
            return "injured"
        end
    end
end

-- Check if class provides death protection (Cleric/Saint)
function Heroes.providesDeathProtection(hero)
    local data = loadHeroData()
    local classData = data.classes[hero.class]
    if classData and classData.special and classData.special.preventsPartyDeath then
        return true
    end
    return false
end

-- Reload hero data (for development)
function Heroes.reload()
    heroData = nil
    loadHeroData()
    print("Hero data reloaded from JSON")
end

return Heroes
