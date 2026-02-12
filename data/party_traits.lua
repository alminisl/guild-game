-- Party Traits Module
-- Handles earning and applying party traits through gameplay

local json = require("utils.json")

local PartyTraits = {}

-- Cached trait data
local traitData = nil

-- Load trait data from JSON
local function loadTraitData()
    if traitData then return traitData end
    
    local data, err = json.loadFile("data/party_traits.json")
    if not data then
        print("ERROR loading party_traits.json: " .. (err or "unknown error"))
        -- Fallback empty data
        data = {
            traits = {},
            config = {maxTraitsPerParty = 5}
        }
    end
    
    traitData = data
    return traitData
end

-- Get all trait definitions
function PartyTraits.getAllTraits()
    local data = loadTraitData()
    return data.traits or {}
end

-- Get trait by ID
function PartyTraits.getTraitById(traitId)
    local traits = PartyTraits.getAllTraits()
    for _, trait in ipairs(traits) do
        if trait.id == traitId then
            return trait
        end
    end
    return nil
end

-- Get config
function PartyTraits.getConfig()
    local data = loadTraitData()
    return data.config or {}
end

-- Check if party has a specific trait
function PartyTraits.hasTrait(party, traitId)
    if not party.earnedTraits then return false end
    return party.earnedTraits[traitId] ~= nil
end

-- Get all earned traits for a party
function PartyTraits.getEarnedTraits(party)
    local earned = {}
    if not party.earnedTraits then return earned end
    
    for traitId, traitInfo in pairs(party.earnedTraits) do
        local trait = PartyTraits.getTraitById(traitId)
        if trait then
            table.insert(earned, {
                trait = trait,
                earnedDay = traitInfo.earnedDay,
                earnedQuest = traitInfo.earnedQuest
            })
        end
    end
    
    -- Sort by earned day (oldest first)
    table.sort(earned, function(a, b)
        return (a.earnedDay or 0) < (b.earnedDay or 0)
    end)
    
    return earned
end

-- Check if a requirement is met for an event
function PartyTraits.checkRequirement(trait, event, eventData)
    local req = trait.requirement
    
    if req.type == "survive_failures" then
        -- Failed quest but party survived
        if event == "quest_complete" and not eventData.success and not eventData.anyDeath then
            -- Check if minimum rank requirement met
            if req.minRank then
                local rankOrder = {D = 1, C = 2, B = 3, A = 4, S = 5}
                local questRank = rankOrder[eventData.questRank or "D"]
                local minRank = rankOrder[req.minRank]
                if questRank >= minRank then
                    return true
                end
            else
                return true
            end
        end
        
    elseif req.type == "find_rare_materials" then
        -- Rare material dropped from quest
        if event == "rare_material_drop" then
            return true
        end
        
    elseif req.type == "fast_completions" then
        -- Quest completed under time limit
        if event == "quest_complete" and eventData.success and eventData.duration then
            if eventData.duration <= (req.maxDuration or 30) then
                return true
            end
        end
        
    elseif req.type == "no_deaths" then
        -- Quest completed without deaths
        if event == "quest_complete" and eventData.success and not eventData.anyDeath then
            return true
        end
        
    elseif req.type == "total_gold_earned" then
        -- Track gold earned (checked differently - see updateTraitProgress)
        return false  -- Handled by total tracking
        
    elseif req.type == "perfect_quests" then
        -- Quest completed with no injuries
        if event == "quest_complete" and eventData.success and eventData.noInjuries then
            return true
        end
        
    elseif req.type == "clutch_victories" then
        -- Won after using a re-roll
        if event == "quest_complete" and eventData.success and eventData.usedReroll then
            return true
        end
        
    elseif req.type == "faction_rep" then
        -- Reached specific faction tier (checked differently)
        return false  -- Handled by direct check
        
    elseif req.type == "complete_dungeons" then
        -- Completed a dungeon
        if event == "dungeon_complete" and eventData.success then
            return true
        end
        
    elseif req.type == "complete_s_rank" then
        -- Completed S-rank quest
        if event == "quest_complete" and eventData.success and eventData.questRank == "S" then
            return true
        end
        
    elseif req.type == "complete_night_quests" then
        -- Completed quest at night
        if event == "quest_complete" and eventData.success and eventData.isNight then
            return true
        end
        
    elseif req.type == "near_death_survival" then
        -- Party survived when success chance was very low
        if event == "quest_complete" and eventData.success and eventData.successChance and eventData.successChance < 0.30 then
            return true
        end
    end
    
    return false
end

-- Update trait progress for a party based on an event
function PartyTraits.updateTraitProgress(party, event, eventData, gameData)
    party.traitProgress = party.traitProgress or {}
    party.earnedTraits = party.earnedTraits or {}
    
    local config = PartyTraits.getConfig()
    local maxTraits = config.maxTraitsPerParty or 5
    
    -- Check if already at max traits
    local earnedCount = 0
    for _ in pairs(party.earnedTraits) do
        earnedCount = earnedCount + 1
    end
    if earnedCount >= maxTraits then
        return nil  -- Already at max
    end
    
    local newlyEarned = {}
    
    for _, trait in ipairs(PartyTraits.getAllTraits()) do
        -- Skip if already earned
        if not party.earnedTraits[trait.id] then
            local req = trait.requirement
            
            -- Special handling for cumulative requirements
            if req.type == "total_gold_earned" then
                if event == "quest_complete" and eventData.goldEarned then
                    party.traitProgress[trait.id] = (party.traitProgress[trait.id] or 0) + eventData.goldEarned
                    if party.traitProgress[trait.id] >= req.amount then
                        table.insert(newlyEarned, trait)
                    end
                end
            elseif req.type == "faction_rep" then
                -- Check faction reputation directly
                if event == "check_traits" and gameData and gameData.guild then
                    for factionId, rep in pairs(gameData.guild.reputation or {}) do
                        if rep >= 100 then  -- Exalted
                            if not party.traitProgress[trait.id] then
                                party.traitProgress[trait.id] = 1
                                table.insert(newlyEarned, trait)
                            end
                        end
                    end
                end
            else
                -- Standard incremental requirements
                if PartyTraits.checkRequirement(trait, event, eventData) then
                    party.traitProgress[trait.id] = (party.traitProgress[trait.id] or 0) + 1
                    
                    -- Check if requirement met
                    if party.traitProgress[trait.id] >= req.count then
                        table.insert(newlyEarned, trait)
                    end
                end
            end
        end
    end
    
    -- Award newly earned traits
    for _, trait in ipairs(newlyEarned) do
        party.earnedTraits[trait.id] = {
            earnedDay = gameData.day or 1,
            earnedQuest = party.totalQuestsCompleted or 0
        }
    end
    
    return newlyEarned
end

-- Get current progress for a trait
function PartyTraits.getTraitProgress(party, traitId)
    local trait = PartyTraits.getTraitById(traitId)
    if not trait then return 0, 0 end
    
    local current = party.traitProgress and party.traitProgress[traitId] or 0
    local required = trait.requirement.count or trait.requirement.amount or 1
    
    return current, required
end

-- Calculate total bonuses from all earned traits
function PartyTraits.calculateTotalBonuses(party)
    local totalBonuses = {
        successBonus = 0,
        goldBonus = 0,
        rareDropBonus = 0,
        questDurationReduction = 0,
        survivalBonus = 0,
        reputationBonus = 0,
        dungeonSuccessBonus = 0,
        fatigueReduction = 0,
        synergyMultiplier = 1.0,
        clutchChance = 0,
        protectEquipment = false,
        dailyRevive = false,
        
        -- Rank-specific bonuses
        rankBonuses = {},  -- {A = 0.10, S = 0.30} etc
        questTimeBonuses = {}  -- {night = 0.20} etc
    }
    
    if not party.earnedTraits then return totalBonuses end
    
    for traitId, _ in pairs(party.earnedTraits) do
        local trait = PartyTraits.getTraitById(traitId)
        if trait and trait.bonus then
            local bonus = trait.bonus
            
            -- Add bonuses
            totalBonuses.successBonus = totalBonuses.successBonus + (bonus.successBonus or 0)
            totalBonuses.goldBonus = totalBonuses.goldBonus + (bonus.goldBonus or 0)
            totalBonuses.rareDropBonus = totalBonuses.rareDropBonus + (bonus.rareDropBonus or 0)
            totalBonuses.questDurationReduction = totalBonuses.questDurationReduction + (bonus.questDurationReduction or 0)
            totalBonuses.survivalBonus = totalBonuses.survivalBonus + (bonus.survivalBonus or 0)
            totalBonuses.reputationBonus = totalBonuses.reputationBonus + (bonus.reputationBonus or 0)
            totalBonuses.dungeonSuccessBonus = totalBonuses.dungeonSuccessBonus + (bonus.dungeonSuccessBonus or 0)
            totalBonuses.fatigueReduction = totalBonuses.fatigueReduction + (bonus.fatigueReduction or 0)
            totalBonuses.clutchChance = totalBonuses.clutchChance + (bonus.clutchChance or 0)
            
            -- Multiply synergy multiplier
            if bonus.synergyMultiplier then
                totalBonuses.synergyMultiplier = totalBonuses.synergyMultiplier * bonus.synergyMultiplier
            end
            
            -- Boolean bonuses
            if bonus.protectEquipment then
                totalBonuses.protectEquipment = true
            end
            if bonus.dailyRevive then
                totalBonuses.dailyRevive = true
            end
            
            -- Rank-specific bonuses
            if bonus.questRanks then
                for _, rank in ipairs(bonus.questRanks) do
                    totalBonuses.rankBonuses[rank] = (totalBonuses.rankBonuses[rank] or 0) + (bonus.successBonus or 0)
                end
            end
            
            -- Time-specific bonuses
            if bonus.questTime then
                totalBonuses.questTimeBonuses[bonus.questTime] = (totalBonuses.questTimeBonuses[bonus.questTime] or 0) + (bonus.successBonus or 0)
            end
        end
    end
    
    return totalBonuses
end

-- Get bonus for a specific quest (considering rank, time, etc)
function PartyTraits.getBonusForQuest(party, questRank, questTime, isDungeon)
    local bonuses = PartyTraits.calculateTotalBonuses(party)
    local totalBonus = bonuses.successBonus
    
    -- Add rank-specific bonus
    if questRank and bonuses.rankBonuses[questRank] then
        totalBonus = totalBonus + bonuses.rankBonuses[questRank]
    end
    
    -- Add time-specific bonus
    if questTime and bonuses.questTimeBonuses[questTime] then
        totalBonus = totalBonus + bonuses.questTimeBonuses[questTime]
    end
    
    -- Add dungeon bonus
    if isDungeon and bonuses.dungeonSuccessBonus then
        totalBonus = totalBonus + bonuses.dungeonSuccessBonus
    end
    
    return totalBonus
end

-- Get all quest-specific bonuses for a party (used during quest resolution)
-- Returns a table with all applicable bonuses: successBonus, goldBonus, xpBonus, etc.
function PartyTraits.getQuestBonuses(party, quest)
    local bonuses = {
        successBonus = 0,
        goldBonus = 0,
        xpBonus = 0,
        luckBonus = 0,
        survivalBonus = 0,
        dropBonus = 0
    }
    
    if not party or not party.earnedTraits then
        return bonuses
    end
    
    -- Get base bonuses from traits
    local totalBonuses = PartyTraits.calculateTotalBonuses(party)
    
    -- Success bonus (general + rank + time + dungeon specific)
    bonuses.successBonus = totalBonuses.successBonus or 0
    
    -- Add rank-specific bonus
    if quest.rank and totalBonuses.rankBonuses[quest.rank] then
        bonuses.successBonus = bonuses.successBonus + totalBonuses.rankBonuses[quest.rank]
    end
    
    -- Add dungeon-specific bonus
    if quest.isDungeon and totalBonuses.dungeonSuccessBonus then
        bonuses.successBonus = bonuses.successBonus + totalBonuses.dungeonSuccessBonus
    end
    
    -- Other bonuses
    bonuses.goldBonus = totalBonuses.goldBonus or 0
    bonuses.xpBonus = totalBonuses.xpBonus or 0
    bonuses.luckBonus = totalBonuses.luckBonus or 0
    bonuses.survivalBonus = totalBonuses.survivalBonus or 0
    bonuses.dropBonus = totalBonuses.dropBonus or 0
    
    return bonuses
end

-- Hot reload support
function PartyTraits.reload()
    traitData = nil
    loadTraitData()
end

return PartyTraits
