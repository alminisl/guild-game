-- Party System Module
-- Manages hero parties, tracking, and party bonuses

local PartySystem = {}

-- Load party traits module
local PartyTraits = require("data.party_traits")

-- Party name generation pools
local partyNameAdjectives = {
    "Brave", "Fierce", "Noble", "Shadow", "Iron", "Golden", "Silver", "Crimson",
    "Azure", "Emerald", "Phantom", "Thunder", "Storm", "Frost", "Flame", "Steel",
    "Wild", "Silent", "Swift", "Mighty", "Dread", "Valiant", "Reckless", "Fearless"
}

local partyNameNouns = {
    "Wolves", "Dragons", "Hawks", "Lions", "Bears", "Serpents", "Phoenixes",
    "Knights", "Sentinels", "Guardians", "Hunters", "Seekers", "Raiders", "Wardens",
    "Blades", "Shields", "Arrows", "Fangs", "Claws", "Wings", "Hearts", "Souls"
}

-- Party configuration
PartySystem.config = {
    requiredMembers = 4,           -- Heroes needed to form a party
    questsToForm = 3,              -- Successful quests together to become official (DEPRECATED - using tiers now)
    luckBonus = 3,                 -- Flat luck bonus for party members (DEPRECATED - using tier bonuses)
    rerollsPerQuest = 1,           -- Number of re-rolls on failed quests (DEPRECATED - using tier bonuses)
    replacementPenalty = {         -- Penalties for replacing members
        tierDrop = 0.5,            -- Tier drops by 0.5 (mild)
        questLoss = 3,             -- Lose 3 quests from total
        bondingQuests = 2,         -- New member needs 2 quests to bond
        successPenalty = 0.05,     -- -5% success while bonding
        trainingCost = 300         -- Gold cost to reduce penalties
    }
}

-- Party Tier System (5 tiers: Fresh → Bonded → Veteran → Elite → Legendary)
PartySystem.tiers = {
    {
        name = "Fresh",
        minQuests = 0,
        maxQuests = 2,
        bonuses = {
            successBonus = 0,         -- No bonus
            luckBonus = 0,
            rerolls = 0,
            travelReduction = 0
        },
        stars = 0,
        color = {0.6, 0.6, 0.6}      -- Gray
    },
    {
        name = "Bonded",
        minQuests = 3,
        maxQuests = 5,
        bonuses = {
            successBonus = 0.05,      -- +5% success
            luckBonus = 1,
            rerolls = 0,
            travelReduction = 0
        },
        stars = 1,
        color = {0.4, 0.7, 0.4}      -- Green
    },
    {
        name = "Veteran",
        minQuests = 6,
        maxQuests = 10,
        bonuses = {
            successBonus = 0.10,      -- +10% success
            luckBonus = 2,
            rerolls = 1,              -- 1 re-roll per quest
            travelReduction = 0
        },
        stars = 2,
        color = {0.4, 0.6, 0.9}      -- Blue
    },
    {
        name = "Elite",
        minQuests = 11,
        maxQuests = 19,
        bonuses = {
            successBonus = 0.15,      -- +15% success
            luckBonus = 3,
            rerolls = 1,
            travelReduction = 0.10    -- -10% travel time
        },
        stars = 3,
        color = {0.9, 0.7, 0.3}      -- Gold
    },
    {
        name = "Legendary",
        minQuests = 20,
        maxQuests = 999,
        bonuses = {
            successBonus = 0.20,      -- +20% success
            luckBonus = 5,
            rerolls = 2,              -- 2 re-rolls per quest
            travelReduction = 0.15,   -- -15% travel time
            guaranteedRareDrop = true -- 1 guaranteed rare drop per day
        },
        stars = 4,
        icon = "👑",
        color = {0.9, 0.3, 0.9}      -- Purple/Magenta
    }
}

-- Internal party ID counter
local nextPartyId = 1

-- Generate a random party name
function PartySystem.generateName()
    local adj = partyNameAdjectives[math.random(#partyNameAdjectives)]
    local noun = partyNameNouns[math.random(#partyNameNouns)]
    return "The " .. adj .. " " .. noun
end

-- Get party tier based on total quests completed
function PartySystem.getTier(party)
    local questCount = party.totalQuestsCompleted or 0
    
    for i = #PartySystem.tiers, 1, -1 do
        local tier = PartySystem.tiers[i]
        if questCount >= tier.minQuests then
            return tier, i
        end
    end
    
    return PartySystem.tiers[1], 1  -- Default to Fresh
end

-- Get progress to next tier (0-1)
function PartySystem.getProgressToNextTier(party)
    local currentTier, tierIndex = PartySystem.getTier(party)
    
    if tierIndex >= #PartySystem.tiers then
        return 1.0  -- Max tier reached
    end
    
    local nextTier = PartySystem.tiers[tierIndex + 1]
    local progress = (party.totalQuestsCompleted or 0) - currentTier.minQuests
    local needed = nextTier.minQuests - currentTier.minQuests
    
    return progress / needed
end

-- Get all bonuses from party tier
function PartySystem.getTierBonuses(party)
    local tier = PartySystem.getTier(party)
    return tier.bonuses
end

-- Get luck bonus from party tier
function PartySystem.getLuckBonus(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    if isParty and party then
        local bonuses = PartySystem.getTierBonuses(party)
        return bonuses.luckBonus or 0
    end
    return 0
end

-- Check if party can re-roll a failed quest
function PartySystem.canReroll(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    if isParty and party then
        local bonuses = PartySystem.getTierBonuses(party)
        return (bonuses.rerolls or 0) > 0
    end
    return false
end

-- Create a new party (MANUAL CREATION - instant formation)
function PartySystem.createParty(heroIds, customName)
    local party = {
        id = nextPartyId,
        name = customName or PartySystem.generateName(),
        memberIds = {},              -- Hero IDs in this party
        questsTogether = {},         -- DEPRECATED (keeping for compatibility)
        isFormed = true,             -- Instantly formed (manual creation)
        formedDate = nil,            -- Set when first created
        totalQuestsCompleted = 0,    -- Total quests completed (used for tier)
        
        -- NEW: Tier progression tracking
        createdDay = 0,              -- Day party was created
        
        -- NEW: Replacement tracking
        bondingMembers = {},         -- {heroId = {questsNeeded, questsCompleted, bonusType}}
        replacementHistory = {},     -- Track member changes
        totalReplacements = 0,       -- Total replacements over party lifetime
        
        -- NEW: Earned traits
        earnedTraits = {},           -- {traitId = {earnedDay, earnedQuest}}
        traitProgress = {},          -- {traitId = progressCount}
    }

    -- Initialize member tracking
    for _, heroId in ipairs(heroIds) do
        table.insert(party.memberIds, heroId)
        party.questsTogether[heroId] = 0  -- Compatibility with old system
    end

    nextPartyId = nextPartyId + 1
    return party
end

-- Check if a group of heroes can form a party (4 different classes)
function PartySystem.canFormParty(heroes)
    if #heroes ~= PartySystem.config.requiredMembers then
        return false, "Party requires exactly " .. PartySystem.config.requiredMembers .. " heroes"
    end

    -- Check for unique classes
    local classes = {}
    for _, hero in ipairs(heroes) do
        if classes[hero.class] then
            return false, "Party members must have different classes"
        end
        classes[hero.class] = true
    end

    -- Check if any hero is already in a formed party
    for _, hero in ipairs(heroes) do
        if hero.partyId then
            return false, hero.name .. " is already in a party"
        end
    end

    return true, "Can form party"
end

-- Find or create a proto-party for a group of heroes questing together
function PartySystem.getOrCreateProtoParty(heroes, gameData)
    if #heroes ~= PartySystem.config.requiredMembers then
        return nil
    end

    -- Check for unique classes
    local classes = {}
    for _, hero in ipairs(heroes) do
        if classes[hero.class] then
            return nil  -- Can't form party without unique classes
        end
        classes[hero.class] = true
    end

    -- Get hero IDs sorted for consistent comparison
    local heroIds = {}
    for _, hero in ipairs(heroes) do
        table.insert(heroIds, hero.id)
    end
    table.sort(heroIds)

    -- Check if this exact group already has a proto-party
    gameData.protoParties = gameData.protoParties or {}
    for _, party in ipairs(gameData.protoParties) do
        local partyIds = {}
        for _, id in ipairs(party.memberIds) do
            table.insert(partyIds, id)
        end
        table.sort(partyIds)

        -- Compare sorted ID lists
        local match = #partyIds == #heroIds
        if match then
            for i, id in ipairs(heroIds) do
                if partyIds[i] ~= id then
                    match = false
                    break
                end
            end
        end

        if match then
            return party
        end
    end

    -- Create new proto-party
    local party = PartySystem.createParty(heroIds)
    table.insert(gameData.protoParties, party)
    return party
end

-- Record a successful quest for a party
function PartySystem.recordQuestSuccess(heroes, gameData)
    if #heroes ~= PartySystem.config.requiredMembers then
        return nil
    end

    local party = PartySystem.getOrCreateProtoParty(heroes, gameData)
    if not party then
        return nil
    end

    -- Increment quest count for each hero
    local allFormed = true
    for _, hero in ipairs(heroes) do
        party.questsTogether[hero.id] = (party.questsTogether[hero.id] or 0) + 1
        if party.questsTogether[hero.id] < PartySystem.config.questsToForm then
            allFormed = false
        end
    end

    -- Check if party should now be officially formed
    if allFormed and not party.isFormed then
        party.isFormed = true
        party.formedDate = gameData.day or 1

        -- Assign party ID to all members
        for _, hero in ipairs(heroes) do
            hero.partyId = party.id
        end

        -- Move from proto-parties to official parties
        gameData.parties = gameData.parties or {}
        table.insert(gameData.parties, party)

        -- Remove from proto-parties
        for i, p in ipairs(gameData.protoParties) do
            if p.id == party.id then
                table.remove(gameData.protoParties, i)
                break
            end
        end

        return party, true  -- Return party and "just formed" flag
    end

    if party.isFormed then
        party.totalQuestsCompleted = party.totalQuestsCompleted + 1
    end

    return party, false
end

-- Get a party by ID
function PartySystem.getParty(partyId, gameData)
    gameData.parties = gameData.parties or {}
    for _, party in ipairs(gameData.parties) do
        if party.id == partyId then
            return party
        end
    end
    return nil
end

-- Get party members (hero objects)
function PartySystem.getPartyMembers(party, gameData)
    local members = {}
    for _, heroId in ipairs(party.memberIds) do
        for _, hero in ipairs(gameData.heroes) do
            if hero.id == heroId then
                table.insert(members, hero)
                break
            end
        end
    end
    return members
end

-- Find party by member list (checks if these heroes form a party)
-- Returns party object if found, nil otherwise
function PartySystem.findPartyByMembers(heroes, gameData)
    if not gameData then
        -- If no gameData provided, try to use global state
        -- This is needed for quest resolution where gameData might not be passed
        return nil
    end
    
    if #heroes ~= PartySystem.config.requiredMembers then
        return nil
    end
    
    -- Get hero IDs sorted for consistent comparison
    local heroIds = {}
    for _, hero in ipairs(heroes) do
        table.insert(heroIds, hero.id)
    end
    table.sort(heroIds)
    
    -- Check formed parties first
    gameData.parties = gameData.parties or {}
    for _, party in ipairs(gameData.parties) do
        local partyIds = {}
        for _, id in ipairs(party.memberIds) do
            table.insert(partyIds, id)
        end
        table.sort(partyIds)
        
        -- Compare sorted ID lists
        local match = #partyIds == #heroIds
        if match then
            for i, id in ipairs(heroIds) do
                if partyIds[i] ~= id then
                    match = false
                    break
                end
            end
        end
        
        if match then
            return party
        end
    end
    
    -- Check proto-parties (not yet officially formed)
    gameData.protoParties = gameData.protoParties or {}
    for _, party in ipairs(gameData.protoParties) do
        local partyIds = {}
        for _, id in ipairs(party.memberIds) do
            table.insert(partyIds, id)
        end
        table.sort(partyIds)
        
        -- Compare sorted ID lists
        local match = #partyIds == #heroIds
        if match then
            for i, id in ipairs(heroIds) do
                if partyIds[i] ~= id then
                    match = false
                    break
                end
            end
        end
        
        if match then
            return party
        end
    end
    
    return nil
end

-- Check if heroes are a formed party
function PartySystem.isFormedParty(heroes, gameData)
    if #heroes ~= PartySystem.config.requiredMembers then
        return false, nil
    end

    -- Check if all heroes share the same party ID
    local partyId = heroes[1].partyId
    if not partyId then
        return false, nil
    end

    for _, hero in ipairs(heroes) do
        if hero.partyId ~= partyId then
            return false, nil
        end
    end

    local party = PartySystem.getParty(partyId, gameData)
    if party and party.isFormed then
        return true, party
    end

    return false, nil
end

-- Check if a hero's party has a cleric for guaranteed death protection
function PartySystem.hasClericProtection(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    if not isParty then
        return false
    end

    -- Check if any party member is a Priest or Saint
    for _, hero in ipairs(heroes) do
        if hero.class == "Priest" or hero.class == "Saint" then
            return true
        end
    end

    return false
end

-- Get luck bonus for party members
function PartySystem.getLuckBonus(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    if isParty then
        return PartySystem.config.luckBonus
    end
    return 0
end

-- Check if party can re-roll a failed quest
function PartySystem.canReroll(heroes, gameData)
    local isParty, party = PartySystem.isFormedParty(heroes, gameData)
    return isParty and party ~= nil
end

-- Handle party member death/removal
function PartySystem.removeMember(heroId, gameData)
    gameData.parties = gameData.parties or {}

    for _, party in ipairs(gameData.parties) do
        for i, memberId in ipairs(party.memberIds) do
            if memberId == heroId then
                -- Don't remove from memberIds, just mark quest count as needing rebuild
                -- The party continues but new member needs to quest to earn bonuses
                party.questsTogether[heroId] = 0

                -- Clear party ID from the removed hero (they might be dead)
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId then
                        hero.partyId = nil
                        break
                    end
                end

                return party
            end
        end
    end

    return nil
end

-- Add a new member to a party (replacing a removed/dead member)
function PartySystem.addMember(party, newHero, gameData)
    -- Check if hero has different class from existing members
    local members = PartySystem.getPartyMembers(party, gameData)
    for _, member in ipairs(members) do
        if member.class == newHero.class then
            return false, "Party already has a " .. newHero.class
        end
    end

    -- Check if hero is already in a party
    if newHero.partyId then
        return false, newHero.name .. " is already in a party"
    end

    -- Find an empty slot (member with 0 quests who isn't in heroes anymore)
    local slotFound = false
    for i, memberId in ipairs(party.memberIds) do
        local memberExists = false
        for _, hero in ipairs(gameData.heroes) do
            if hero.id == memberId and hero.partyId == party.id then
                memberExists = true
                break
            end
        end

        if not memberExists or party.questsTogether[memberId] == 0 then
            -- Replace this slot
            party.memberIds[i] = newHero.id
            party.questsTogether[newHero.id] = 0
            newHero.partyId = party.id
            slotFound = true
            break
        end
    end

    if not slotFound then
        return false, "No open slots in party"
    end

    return true, newHero.name .. " joined the party (needs " .. PartySystem.config.questsToForm .. " quests for full bonuses)"
end

-- Check if all party members have full bonuses
function PartySystem.allMembersQualified(party)
    for _, count in pairs(party.questsTogether) do
        if count < PartySystem.config.questsToForm then
            return false
        end
    end
    return true
end

-- Get party status text
function PartySystem.getStatusText(party, gameData)
    if not party.isFormed then
        -- Count progress
        local minQuests = math.huge
        for _, count in pairs(party.questsTogether) do
            minQuests = math.min(minQuests, count)
        end
        return string.format("Forming... (%d/%d quests)", minQuests, PartySystem.config.questsToForm)
    end

    if not PartySystem.allMembersQualified(party) then
        return "Rebuilding bonds..."
    end

    return "Active"
end

-- Rename a party
function PartySystem.renameParty(party, newName)
    if newName and #newName > 0 and #newName <= 30 then
        party.name = newName
        return true
    end
    return false
end

-- Disband a party
function PartySystem.disbandParty(party, gameData)
    -- Clear party ID from all members
    for _, heroId in ipairs(party.memberIds) do
        for _, hero in ipairs(gameData.heroes) do
            if hero.id == heroId then
                hero.partyId = nil
                break
            end
        end
    end

    -- Remove from parties list
    for i, p in ipairs(gameData.parties) do
        if p.id == party.id then
            table.remove(gameData.parties, i)
            break
        end
    end

    return true
end

-- Initialize party data in game data
function PartySystem.initGameData(gameData)
    gameData.parties = gameData.parties or {}
    gameData.protoParties = gameData.protoParties or {}
end

-- Set next party ID (for save/load)
function PartySystem.setNextId(id)
    nextPartyId = id
end

-- Get next party ID (for save/load)
function PartySystem.getNextId()
    return nextPartyId
end

-- ============================================================================
-- PARTY TRAITS INTEGRATION
-- ============================================================================

-- Update trait progress after a quest
function PartySystem.updateTraitsAfterQuest(party, questResult, gameData)
    if not party or not questResult then return end
    
    -- Build event data for trait checking
    local eventData = {
        success = questResult.success or false,
        questRank = questResult.questRank,
        goldEarned = questResult.goldReward or 0,
        duration = questResult.duration,
        anyDeath = questResult.anyDeath or false,
        noInjuries = questResult.noInjuries or true,
        usedReroll = questResult.usedReroll or false,
        isNight = questResult.isNight or false,
        successChance = questResult.successChance,
        isDungeon = questResult.isDungeon or false
    }
    
    -- Check for rare material drops
    if questResult.materialDrops then
        for _, material in ipairs(questResult.materialDrops) do
            if material.rarity == "rare" or material.rarity == "epic" then
                PartyTraits.updateTraitProgress(party, "rare_material_drop", {material = material.id}, gameData)
            end
        end
    end
    
    -- Update main quest completion traits
    local newTraits = PartyTraits.updateTraitProgress(party, "quest_complete", eventData, gameData)
    
    -- Check dungeon completion
    if questResult.isDungeon and questResult.success then
        PartyTraits.updateTraitProgress(party, "dungeon_complete", eventData, gameData)
    end
    
    -- Periodic faction check
    if party.totalQuestsCompleted and party.totalQuestsCompleted % 5 == 0 then
        PartyTraits.updateTraitProgress(party, "check_traits", {}, gameData)
    end
    
    return newTraits
end

-- Get all traits for a party
function PartySystem.getPartyTraits(party)
    return PartyTraits.getEarnedTraits(party)
end

-- Get trait bonuses for a specific quest
function PartySystem.getTraitBonusForQuest(party, questRank, questTime, isDungeon)
    return PartyTraits.getBonusForQuest(party, questRank, questTime, isDungeon)
end

-- Calculate all trait bonuses
function PartySystem.getTraitBonuses(party)
    return PartyTraits.calculateTotalBonuses(party)
end

-- Check if party has a specific trait
function PartySystem.hasPartyTrait(party, traitId)
    return PartyTraits.hasTrait(party, traitId)
end

-- Get progress toward earning a trait
function PartySystem.getTraitProgress(party, traitId)
    return PartyTraits.getTraitProgress(party, traitId)
end

-- ============================================================================
-- MEMBER REPLACEMENT SYSTEM
-- ============================================================================

-- Get available heroes for replacement (same class as leaving hero)
function PartySystem.getReplacementCandidates(party, leavingHeroId, gameData)
    local leavingHero = nil
    for _, hero in ipairs(gameData.heroes) do
        if hero.id == leavingHeroId then
            leavingHero = hero
            break
        end
    end
    
    if not leavingHero then return {}, {} end
    
    local succession = {}  -- Same class
    local standard = {}    -- Different class but not in party
    
    for _, hero in ipairs(gameData.heroes) do
        if hero.id ~= leavingHeroId and (hero.status == "idle" or not hero.status) and not hero.partyId then
            -- Check if class is already in party (excluding leaving hero)
            local classInParty = false
            for _, memberId in ipairs(party.memberIds) do
                if memberId ~= leavingHeroId then
                    for _, h in ipairs(gameData.heroes) do
                        if h.id == memberId and h.class == hero.class then
                            classInParty = true
                            break
                        end
                    end
                end
            end
            
            if not classInParty then
                if hero.class == leavingHero.class then
                    table.insert(succession, hero)
                else
                    table.insert(standard, hero)
                end
            end
        end
    end
    
    return succession, standard
end

-- Calculate replacement penalty
function PartySystem.calculateReplacementPenalty(replacementType, useTraining)
    local config = PartySystem.config.replacementPenalty
    local penalty = {
        tierDrop = config.tierDrop,
        questLoss = config.questLoss,
        bondingQuests = config.bondingQuests,
        successPenalty = config.successPenalty,
        trainingCost = useTraining and config.trainingCost or 0
    }
    
    if replacementType == "succession" then
        -- Reduced penalties for same class
        penalty.tierDrop = config.tierDrop * 0.5  -- 0.25 instead of 0.5
        penalty.questLoss = math.floor(config.questLoss / 3)  -- 1 instead of 3
        penalty.bondingQuests = math.floor(config.bondingQuests / 2)  -- 1 instead of 2
        penalty.successPenalty = config.successPenalty * 0.6  -- 3% instead of 5%
    end
    
    if useTraining then
        penalty.tierDrop = 0
        penalty.questLoss = 0
        penalty.bondingQuests = math.max(1, penalty.bondingQuests - 1)
        penalty.successPenalty = config.successPenalty * 0.4  -- 2%
    end
    
    return penalty
end

-- Replace a party member
function PartySystem.replaceMember(party, leavingHeroId, newHero, options, gameData)
    options = options or {}
    local replacementType = options.type or "standard"  -- "standard" or "succession"
    local useTraining = options.training or false
    
    -- Calculate penalties
    local penalty = PartySystem.calculateReplacementPenalty(replacementType, useTraining)
    
    -- Apply quest loss
    party.totalQuestsCompleted = math.max(0, party.totalQuestsCompleted - penalty.questLoss)
    
    -- Replace in memberIds
    for i, heroId in ipairs(party.memberIds) do
        if heroId == leavingHeroId then
            party.memberIds[i] = newHero.id
            break
        end
    end
    
    -- Add to bonding tracking
    party.bondingMembers = party.bondingMembers or {}
    party.bondingMembers[newHero.id] = {
        heroId = newHero.id,
        questsNeeded = penalty.bondingQuests,
        questsCompleted = 0,
        successPenalty = penalty.successPenalty,
        bonusType = replacementType
    }
    
    -- Update replacement tracking
    party.replacementHistory = party.replacementHistory or {}
    table.insert(party.replacementHistory, {
        originalHeroId = leavingHeroId,
        newHeroId = newHero.id,
        replacementType = replacementType,
        day = gameData.day or 1,
        trainingUsed = useTraining
    })
    
    party.totalReplacements = (party.totalReplacements or 0) + 1
    
    -- Deduct training cost
    if useTraining and gameData.gold then
        gameData.gold = gameData.gold - penalty.trainingCost
    end
    
    -- Update hero party assignments
    newHero.partyId = party.id
    
    -- Clear leaving hero's party ID
    for _, hero in ipairs(gameData.heroes) do
        if hero.id == leavingHeroId then
            hero.partyId = nil
            break
        end
    end
    
    return party, penalty
end

-- Update bonding progress after quest
function PartySystem.updateBonding(party, completedQuestHeroes)
    if not party.bondingMembers then return nil end
    
    local newlyBonded = {}
    
    for _, hero in ipairs(completedQuestHeroes) do
        local bonding = party.bondingMembers[hero.id]
        if bonding then
            bonding.questsCompleted = bonding.questsCompleted + 1
            
            if bonding.questsCompleted >= bonding.questsNeeded then
                -- Fully bonded!
                party.bondingMembers[hero.id] = nil
                table.insert(newlyBonded, {hero = hero, type = bonding.bonusType})
            end
        end
    end
    
    return #newlyBonded > 0 and newlyBonded or nil
end

-- Get total bonding penalty for party
function PartySystem.getBondingPenalty(party)
    if not party.bondingMembers then return 0 end
    
    local totalPenalty = 0
    for _, bonding in pairs(party.bondingMembers) do
        totalPenalty = totalPenalty + (bonding.successPenalty or 0)
    end
    
    return totalPenalty
end

-- Check if party can accept more replacements
function PartySystem.canReplaceMoreMembers(party)
    local recentReplacements = party.totalReplacements or 0
    
    if recentReplacements >= 2 then
        return false, "Too many replacements. Consider creating a new party."
    end
    
    return true
end

return PartySystem
