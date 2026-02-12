-- Guild System Module
-- Manages guild leveling, faction reputation, and progression unlocks

local Guild = {}

-- Guild level configuration (increased hero slots for more party variety)
-- XP requirements reduced by 20% for levels 5-10 to improve mid-game pacing
Guild.levels = {
    {xp = 0,     heroSlots = 4,  questSlots = 2, maxRank = "C"},  -- Level 1
    {xp = 200,   heroSlots = 8,  questSlots = 3, maxRank = "C"},  -- Level 2: +4 heroes, +1 quest
    {xp = 500,   heroSlots = 10, questSlots = 3, maxRank = "B"},  -- Level 3
    {xp = 1000,  heroSlots = 12, questSlots = 4, maxRank = "B"},  -- Level 4
    {xp = 1800,  heroSlots = 14, questSlots = 4, maxRank = "A"},  -- Level 5 (was 2000, -10%)
    {xp = 3000,  heroSlots = 16, questSlots = 5, maxRank = "A"},  -- Level 6 (was 3500, -14%)
    {xp = 4500,  heroSlots = 18, questSlots = 5, maxRank = "A"},  -- Level 7 (was 5500, -18%)
    {xp = 6500,  heroSlots = 20, questSlots = 6, maxRank = "S"},  -- Level 8 (was 8000, -19%)
    {xp = 9000,  heroSlots = 22, questSlots = 6, maxRank = "S"},  -- Level 9 (was 11000, -18%)
    {xp = 12000, heroSlots = 24, questSlots = 8, maxRank = "S"}   -- Level 10 (was 15000, -20%)
}

-- Faction definitions
Guild.factions = {
    humans = {
        id = "humans",
        name = "Humans",
        color = {0.6, 0.5, 0.4},
        rival = nil,
        description = "Kingdom of men"
    },
    elves = {
        id = "elves",
        name = "Elves",
        color = {0.3, 0.65, 0.35},
        rival = "dwarfs",
        description = "Forest realm"
    },
    dwarfs = {
        id = "dwarfs",
        name = "Dwarfs",
        color = {0.75, 0.55, 0.25},
        rival = "elves",
        description = "Mountain folk"
    },
    orcs = {
        id = "orcs",
        name = "Orcs",
        color = {0.65, 0.3, 0.3},
        rival = nil,
        description = "Warband clans"
    }
}

-- Faction order for UI display
Guild.factionOrder = {"humans", "elves", "dwarfs", "orcs"}

-- Reputation tiers
Guild.reputationTiers = {
    {name = "Hostile",    minRep = -100, maxRep = -50, rewardMult = 0,    color = {0.6, 0.2, 0.2}},
    {name = "Unfriendly", minRep = -49,  maxRep = -10, rewardMult = 0.8,  color = {0.6, 0.4, 0.3}},
    {name = "Neutral",    minRep = -9,   maxRep = 9,   rewardMult = 1.0,  color = {0.5, 0.5, 0.5}},
    {name = "Friendly",   minRep = 10,   maxRep = 49,  rewardMult = 1.1,  color = {0.4, 0.6, 0.4}},
    {name = "Honored",    minRep = 50,   maxRep = 99,  rewardMult = 1.2,  color = {0.3, 0.5, 0.7}},
    {name = "Exalted",    minRep = 100,  maxRep = 100, rewardMult = 1.3,  color = {0.7, 0.6, 0.2}}
}

-- Reputation gain by quest rank
Guild.repGainByRank = {
    D = 5,
    C = 8,
    B = 10,
    A = 12,
    S = 15
}

-- Guild XP gain by quest rank (same as hero XP)
Guild.guildXPByRank = {
    D = 20,
    C = 40,
    B = 80,
    A = 150,
    S = 300
}

-- Initialize guild data (call this when starting new game)
function Guild.initializeData()
    return {
        xp = 0,
        level = 1,
        reputation = {
            humans = 0,
            elves = 0,
            dwarfs = 0,
            orcs = 0
        }
    }
end

-- Get current guild level from XP
function Guild.calculateLevel(guildXP)
    local level = 1
    for i, levelData in ipairs(Guild.levels) do
        if guildXP >= levelData.xp then
            level = i
        else
            break
        end
    end
    return level
end

-- Add XP to guild and check for level up
function Guild.addGuildXP(gameData, amount)
    if not gameData.guild then return false end

    local oldLevel = gameData.guild.level
    gameData.guild.xp = gameData.guild.xp + amount
    gameData.guild.level = Guild.calculateLevel(gameData.guild.xp)

    return gameData.guild.level > oldLevel  -- Returns true if leveled up
end

-- Get XP needed for next level
function Guild.getXPToNextLevel(gameData)
    if not gameData.guild then return 0 end

    local currentLevel = gameData.guild.level
    if currentLevel >= #Guild.levels then
        return 0  -- Max level
    end

    return Guild.levels[currentLevel + 1].xp
end

-- Get XP progress within current level (for progress bar)
function Guild.getXPProgress(gameData)
    if not gameData.guild then return 0, 0, 0 end

    local currentLevel = gameData.guild.level
    local currentXP = gameData.guild.xp

    local currentLevelXP = Guild.levels[currentLevel].xp
    local nextLevelXP = currentLevel < #Guild.levels and Guild.levels[currentLevel + 1].xp or currentLevelXP

    local progress = currentXP - currentLevelXP
    local needed = nextLevelXP - currentLevelXP

    if needed <= 0 then
        return currentXP, currentXP, 1  -- Max level
    end

    return progress, needed, progress / needed
end

-- Get current hero slots based on guild level
function Guild.getHeroSlots(gameData)
    if not gameData.guild then return 4 end
    return Guild.levels[gameData.guild.level].heroSlots
end

-- Get current quest slots based on guild level
function Guild.getQuestSlots(gameData)
    if not gameData.guild then return 2 end
    return Guild.levels[gameData.guild.level].questSlots
end

-- Get max tavern rank based on guild level
function Guild.getMaxTavernRank(gameData)
    if not gameData.guild then return "C" end
    return Guild.levels[gameData.guild.level].maxRank
end

-- Get current level data
function Guild.getCurrentLevelData(gameData)
    if not gameData.guild then return Guild.levels[1] end
    return Guild.levels[gameData.guild.level]
end

-- Add reputation with a faction (handles rival penalty)
function Guild.addReputation(gameData, factionId, amount)
    if not gameData.guild or not gameData.guild.reputation then return end
    if not Guild.factions[factionId] then return end

    -- Add reputation to the faction
    local oldRep = gameData.guild.reputation[factionId] or 0
    gameData.guild.reputation[factionId] = math.max(-100, math.min(100, oldRep + amount))

    -- Apply rival penalty (50% of gain as loss)
    local faction = Guild.factions[factionId]
    if faction.rival and amount > 0 then
        local rivalRep = gameData.guild.reputation[faction.rival] or 0
        local penalty = math.floor(amount * 0.5)
        gameData.guild.reputation[faction.rival] = math.max(-100, rivalRep - penalty)
    end

    -- Return old and new tier for notification
    local oldTier = Guild.getTierForRep(oldRep)
    local newTier = Guild.getTierForRep(gameData.guild.reputation[factionId])

    return oldTier ~= newTier, newTier  -- Returns if tier changed and new tier name
end

-- Get reputation value for a faction
function Guild.getReputation(gameData, factionId)
    if not gameData.guild or not gameData.guild.reputation then return 0 end
    return gameData.guild.reputation[factionId] or 0
end

-- Get tier data for a reputation value
function Guild.getTierForRep(rep)
    for _, tier in ipairs(Guild.reputationTiers) do
        if rep >= tier.minRep and rep <= tier.maxRep then
            return tier
        end
    end
    return Guild.reputationTiers[3]  -- Default to Neutral
end

-- Get reputation tier for a faction
function Guild.getReputationTier(gameData, factionId)
    local rep = Guild.getReputation(gameData, factionId)
    return Guild.getTierForRep(rep)
end

-- Get reward multiplier for a faction
function Guild.getRewardMultiplier(gameData, factionId)
    local tier = Guild.getReputationTier(gameData, factionId)
    return tier.rewardMult
end

-- Check if faction quests are available (not Hostile)
function Guild.canTakeQuestsFrom(gameData, factionId)
    local rep = Guild.getReputation(gameData, factionId)
    return rep > -50  -- Hostile threshold
end

-- Get reputation gain for completing a quest
function Guild.getReputationGain(questRank)
    return Guild.repGainByRank[questRank] or 5
end

-- Get guild XP for completing a quest
function Guild.getGuildXPGain(questRank)
    return Guild.guildXPByRank[questRank] or 20
end

-- Apply quest completion rewards (call from quest_system)
function Guild.onQuestComplete(gameData, quest, success)
    if not gameData.guild or not quest.faction then return {} end

    local results = {}

    if success then
        -- Add guild XP
        local guildXP = Guild.getGuildXPGain(quest.rank)
        local leveledUp = Guild.addGuildXP(gameData, guildXP)
        if leveledUp then
            results.guildLevelUp = gameData.guild.level
        end
        results.guildXP = guildXP

        -- Add reputation
        local repGain = Guild.getReputationGain(quest.rank)
        local tierChanged, newTier = Guild.addReputation(gameData, quest.faction, repGain)
        if tierChanged then
            results.tierChanged = {faction = quest.faction, tier = newTier}
        end
        results.repGain = repGain
        results.faction = quest.faction
    end

    return results
end

-- Get faction info for display
function Guild.getFactionInfo(factionId)
    return Guild.factions[factionId]
end

-- Check if can hire hero (hero slot limit)
function Guild.canHireHero(gameData)
    local maxSlots = Guild.getHeroSlots(gameData)
    return #gameData.heroes < maxSlots
end

-- Check if can start quest (active quest limit)
function Guild.canStartQuest(gameData)
    local maxSlots = Guild.getQuestSlots(gameData)
    return #gameData.activeQuests < maxSlots
end

-- Get remaining slots info
function Guild.getSlotsInfo(gameData)
    return {
        heroSlots = Guild.getHeroSlots(gameData),
        heroesUsed = #gameData.heroes,
        questSlots = Guild.getQuestSlots(gameData),
        questsActive = #gameData.activeQuests
    }
end

return Guild
