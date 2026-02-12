-- Quest System Module
-- Manages active quests, real-time updates, and resolution

local QuestSystem = {}

-- Load EquipmentSystem for mount calculations
local EquipmentSystem = require("systems.equipment_system")
local PartySystem = require("systems.party_system")
local Heroes = require("data.heroes")

-- Hero lookup cache for O(1) access (rebuilt when needed)
local heroLookupCache = {}
local lastCacheRebuild = 0

-- Rebuild hero lookup cache
local function rebuildHeroLookup(gameData)
    heroLookupCache = {}
    -- Add heroes from guild roster
    for _, hero in ipairs(gameData.heroes or {}) do
        heroLookupCache[hero.id] = hero
    end
    -- Add heroes on active quests
    for _, quest in ipairs(gameData.activeQuests or {}) do
        if quest.heroesOnQuest then
            for _, hero in ipairs(quest.heroesOnQuest) do
                heroLookupCache[hero.id] = hero
            end
        end
    end
    lastCacheRebuild = love.timer.getTime()
end

-- Invalidate cache (call when heroes are added/removed)
function QuestSystem.invalidateHeroCache()
    heroLookupCache = {}
end

-- Assign heroes to a quest (starts the quest)
function QuestSystem.assignParty(quest, heroes, gameData)
    if quest.status ~= "available" then
        return false, "Quest is not available"
    end

    -- Check hero count limit
    local maxHeroes = quest.maxHeroes or 6
    if #heroes > maxHeroes then
        return false, "Too many heroes! Max " .. maxHeroes .. " for this quest."
    end

    -- Check hero availability
    for _, hero in ipairs(heroes) do
        if hero.status ~= "idle" then
            return false, hero.name .. " is not available"
        end
    end

    -- Calculate travel speed based on party mounts
    local travelMultiplier = EquipmentSystem.getPartyTravelSpeed(heroes)

    -- Get passive time reductions
    local passiveEffects = Heroes.getPartyPassiveEffects(heroes)
    local travelReduction = 1 - (passiveEffects.travelTimeReduction or 0)
    local executeReduction = 1 - (passiveEffects.executeTimeReduction or 0)
    local questTimeReduction = 1 - (passiveEffects.questTimeReduction or 0)

    -- Apply all time modifiers
    local adjustedTravelTime = math.floor(quest.travelTime * travelMultiplier * travelReduction * questTimeReduction)
    local adjustedReturnTime = math.floor(quest.returnTime * travelMultiplier * travelReduction * questTimeReduction)
    local adjustedExecuteTime = math.floor(quest.executeTime * executeReduction * questTimeReduction)

    -- Store adjusted times on the quest
    quest.actualTravelTime = adjustedTravelTime
    quest.actualReturnTime = adjustedReturnTime
    quest.actualExecuteTime = adjustedExecuteTime
    quest.travelSpeedMultiplier = travelMultiplier
    quest.passiveEffects = passiveEffects  -- Store for later use

    -- Assign heroes to quest
    quest.assignedHeroes = {}
    quest.heroesOnQuest = {}  -- Store actual hero data (they leave the guild!)
    for _, hero in ipairs(heroes) do
        table.insert(quest.assignedHeroes, hero.id)
        hero.status = "traveling"
        hero.currentQuestId = quest.id
        hero.questPhase = "travel"
        hero.questProgress = 0
        hero.questPhaseMax = adjustedTravelTime
        -- Store the hero on the quest itself
        table.insert(quest.heroesOnQuest, hero)
    end

    -- Remove heroes from guild roster (they're off adventuring!)
    -- Collect indices first, then remove in reverse order to avoid index shifting
    local indicesToRemove = {}
    for _, hero in ipairs(heroes) do
        for i, guildHero in ipairs(gameData.heroes) do
            if guildHero.id == hero.id then
                table.insert(indicesToRemove, i)
                break
            end
        end
    end
    table.sort(indicesToRemove, function(a, b) return a > b end)
    for _, i in ipairs(indicesToRemove) do
        table.remove(gameData.heroes, i)
    end

    quest.status = "active"
    quest.currentPhase = "travel"
    quest.phaseProgress = 0

    -- Move quest to active quests
    table.insert(gameData.activeQuests, quest)

    -- Remove from available quests
    for i, q in ipairs(gameData.availableQuests) do
        if q.id == quest.id then
            table.remove(gameData.availableQuests, i)
            break
        end
    end

    -- Trigger departure animation (heroes walking out of guild)
    if addDepartingHeroes then
        addDepartingHeroes(heroes)
    end

    -- Build a fun departure message
    local heroNames = {}
    for _, hero in ipairs(heroes) do
        table.insert(heroNames, hero.name)
    end
    local departureMsg = table.concat(heroNames, ", ") .. " waved goodbye and left the guild for " .. quest.name .. "!"
    return true, departureMsg
end

-- Update all active quests (call every frame with dt)
function QuestSystem.update(gameData, dt, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
    local results = {}

    local questsToRemove = {}

    for i, quest in ipairs(gameData.activeQuests) do
        quest.phaseProgress = quest.phaseProgress + dt

        -- Update hero states
        for _, heroId in ipairs(quest.assignedHeroes) do
            local hero = QuestSystem.getHeroById(heroId, gameData)
            if hero then
                hero.questProgress = quest.phaseProgress
            end
        end

        -- Check for phase transition
        local phaseComplete = false
        local phaseMax = 0

        if quest.currentPhase == "travel" then
            phaseMax = quest.actualTravelTime or quest.travelTime
            if quest.phaseProgress >= phaseMax then
                phaseComplete = true
                -- Transition to awaiting_execute - wait for player to click "Execute"
                quest.currentPhase = "awaiting_execute"
                quest.phaseProgress = 0
                -- Update heroes
                for _, heroId in ipairs(quest.assignedHeroes) do
                    local hero = QuestSystem.getHeroById(heroId, gameData)
                    if hero then
                        hero.status = "at_location"
                        hero.questPhase = "awaiting_execute"
                    end
                end
            end
        elseif quest.currentPhase == "awaiting_execute" then
            -- Waiting for player to click "Execute Quest" button
            -- No automatic progression
        elseif quest.currentPhase == "execute" then
            phaseMax = quest.actualExecuteTime or quest.executeTime

            -- Dungeon multi-floor handling
            if quest.isDungeon and quest.floorCount > 0 then
                local floorTime = phaseMax / quest.floorCount
                local currentFloorFromProgress = math.floor(quest.phaseProgress / floorTime) + 1

                -- Check if we've advanced to a new floor
                if currentFloorFromProgress > quest.currentFloor and quest.currentFloor < quest.floorCount then
                    -- Resolve the completed floor
                    local floorResult = QuestSystem.resolveFloor(quest, gameData, Heroes, Quests, EquipmentSystem)
                    table.insert(quest.floorsCleared, floorResult)
                    quest.currentFloor = currentFloorFromProgress

                    -- Update fatigue
                    local dungeonConfig = Quests.getDungeonConfig()
                    quest.partyFatigue = quest.currentFloor * dungeonConfig.fatiguePerFloor

                    -- Check for party wipe or retreat
                    if floorResult.partyWiped or quest.hasRetreated then
                        -- End dungeon early - transition to return
                        quest.currentPhase = "return"
                        quest.phaseProgress = 0
                        for _, heroId in ipairs(quest.assignedHeroes) do
                            local hero = QuestSystem.getHeroById(heroId, gameData)
                            if hero then
                                hero.status = "returning"
                                hero.questPhase = "return"
                                hero.questProgress = 0
                                hero.questPhaseMax = quest.actualReturnTime or quest.returnTime
                            end
                        end
                    end
                end
            end

            if quest.phaseProgress >= phaseMax and quest.currentPhase == "execute" then
                -- For dungeons, resolve the final floor if not already done
                if quest.isDungeon and quest.currentFloor < quest.floorCount then
                    local floorResult = QuestSystem.resolveFloor(quest, gameData, Heroes, Quests, EquipmentSystem)
                    table.insert(quest.floorsCleared, floorResult)
                    quest.currentFloor = quest.floorCount
                end

                phaseComplete = true
                -- Transition to awaiting_claim - wait for player to click before showing result
                quest.currentPhase = "awaiting_claim"
                quest.phaseProgress = 0
                -- Update heroes to "awaiting" status (quest done, waiting for claim)
                for _, heroId in ipairs(quest.assignedHeroes) do
                    local hero = QuestSystem.getHeroById(heroId, gameData)
                    if hero then
                        hero.status = "awaiting"
                        hero.questPhase = "awaiting_claim"
                    end
                end
            end
        elseif quest.currentPhase == "awaiting_claim" then
            -- Quest execution complete - waiting for player to claim
            -- No automatic progression - player must click to claim
        elseif quest.currentPhase == "return" then
            -- Heroes are returning after quest was claimed
            phaseMax = quest.actualReturnTime or quest.returnTime
            if quest.phaseProgress >= phaseMax then
                -- Return complete - heroes arrive back and start resting
                local heroList = QuestSystem.getQuestHeroes(quest, gameData)

                for _, hero in ipairs(heroList) do
                    -- Skip dead heroes
                    local isDead = false
                    for _, deadHero in ipairs(gameData.graveyard) do
                        if deadHero.id == hero.id then
                            isDead = true
                            break
                        end
                    end

                    if not isDead then
                        hero.status = "resting"
                        hero.restTime = 0
                        hero.questPhase = nil
                        hero.questProgress = nil
                        hero.questPhaseMax = nil
                        hero.currentQuestId = nil

                        -- Calculate rest time based on fatigue
                        local baseRestTime = Heroes.getBaseRestTime and Heroes.getBaseRestTime(hero) or 10
                        local fatigueMultiplier = 1.0
                        if hero.fatigueLevel then
                            fatigueMultiplier = 1.0 + (hero.fatigueLevel * 0.25)
                        end
                        hero.restTimeMax = baseRestTime * fatigueMultiplier

                        -- CRITICAL: Add hero back to guild roster
                        local alreadyInRoster = false
                        for _, h in ipairs(gameData.heroes) do
                            if h.id == hero.id then
                                alreadyInRoster = true
                                break
                            end
                        end
                        if not alreadyInRoster then
                            table.insert(gameData.heroes, hero)
                        end
                    end
                end

                -- Trigger arrival animation (heroes walking back to guild)
                local arrivedHeroes = {}
                for _, hero in ipairs(heroList) do
                    local isDead = false
                    for _, deadHero in ipairs(gameData.graveyard) do
                        if deadHero.id == hero.id then
                            isDead = true
                            break
                        end
                    end
                    if not isDead then
                        table.insert(arrivedHeroes, hero)
                    end
                end
                if addArrivingHeroes and #arrivedHeroes > 0 then
                    addArrivingHeroes(arrivedHeroes)
                end

                -- Mark for removal
                table.insert(questsToRemove, i)

                -- Notify that heroes returned
                table.insert(results, {
                    type = "return_complete",
                    quest = quest,
                    message = "Heroes returned from " .. quest.name
                })
            end
        end
    end

    -- Remove completed quests (in reverse order to maintain indices)
    for i = #questsToRemove, 1, -1 do
        table.remove(gameData.activeQuests, questsToRemove[i])
    end

    -- Update resting heroes
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            local finished = Heroes.updateRest(hero, dt)
            if finished then
                table.insert(results, {
                    type = "rest_complete",
                    hero = hero,
                    message = hero.name .. " is ready for action!"
                })
            end
        end
    end

    return results
end

-- Execute a quest (called when player clicks "Execute Quest" button)
-- Resolves combat/narrative and returns result for display
function QuestSystem.executeQuest(quest, gameData, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
    if quest.currentPhase ~= "awaiting_execute" then
        return nil  -- Quest not ready to execute
    end

    local heroList = QuestSystem.getQuestHeroes(quest, gameData)

    -- Check for party luck bonus before resolution
    local partyLuckBonus = PartySystem.getLuckBonus(heroList, gameData)

    local result
    if quest.isDungeon then
        -- Dungeon: compile results from floor clears
        result = QuestSystem.compileDungeonResult(quest, heroList, gameData, Quests, partyLuckBonus)
    else
        -- Normal quest resolution
        result = Quests.resolve(quest, heroList, partyLuckBonus, gameData)
    end

    -- Party re-roll mechanic: if quest failed and heroes are a formed party, try again
    if not result.success and PartySystem.canReroll(heroList, gameData) then
        local rerollResult = Quests.resolve(quest, heroList, partyLuckBonus, gameData)
        if rerollResult.success then
            result = rerollResult
            result.message = "Party bond triggered a re-roll! " .. result.message
        else
            result.message = result.message .. " (Party re-roll also failed)"
        end
    end

    -- Store result in quest for later reference
    quest.executionResult = result

    -- Transition to awaiting_return - waiting for player to click "Return"
    quest.currentPhase = "awaiting_return"
    for _, heroId in ipairs(quest.assignedHeroes) do
        local hero = QuestSystem.getHeroById(heroId, gameData)
        if hero then
            hero.status = "awaiting_return"
            hero.questPhase = "awaiting_return"
        end
    end

    return result, heroList
end

-- Start the return phase (called when player clicks "Return" after viewing combat log)
function QuestSystem.startReturn(quest, gameData, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
    if quest.currentPhase ~= "awaiting_return" then
        return nil  -- Quest not ready for return
    end

    local heroList = QuestSystem.getQuestHeroes(quest, gameData)
    local result = quest.executionResult

    if not result then
        return nil  -- No execution result stored
    end

    -- Track quest for party formation (only on success)
    if result.success then
        local party, justFormed = PartySystem.recordQuestSuccess(heroList, gameData)
        if justFormed and party then
            result.message = result.message .. " " .. party.name .. " has officially formed!"
        end
    end

    -- Apply rewards
    Economy.earn(gameData, result.goldReward)

    -- Track dead and revived heroes
    local deadHeroes = {}
    local revivedHeroes = {}

    -- Rank values for XP bonus calculation
    local rankValues = {D = 1, C = 2, B = 3, A = 4, S = 5}
    local questRankValue = rankValues[quest.rank] or 1

    -- Award XP and handle death/revival
    local baseXpPerHero = #heroList > 0 and math.floor(result.xpReward / #heroList) or 0
    for _, hero in ipairs(heroList) do
        -- Check if hero died in combat
        local diedInCombat = false
        for _, deadHero in ipairs(result.heroDeaths or {}) do
            if deadHero.id == hero.id then
                diedInCombat = true
                break
            end
        end

        if diedInCombat then
            table.insert(deadHeroes, hero)
        else
            -- Calculate rank-differential XP bonus
            local heroRankValue = rankValues[hero.rank] or 1
            local rankDiff = questRankValue - heroRankValue
            local xpMultiplier = 1.0
            if rankDiff > 0 and result.success then
                xpMultiplier = 1.0 + (rankDiff * 0.3)
            end
            local xpForHero = math.floor(baseXpPerHero * xpMultiplier)

            local leveledUp = Heroes.addXP(hero, xpForHero)
            if leveledUp then
                result.message = result.message .. " " .. hero.name .. " leveled up!"
            end
        end
    end

    -- Remove dead heroes from roster
    for _, deadHero in ipairs(deadHeroes) do
        for i, hero in ipairs(gameData.heroes) do
            if hero.id == deadHero.id then
                table.remove(gameData.heroes, i)
                break
            end
        end
        deadHero.deathQuest = quest.name
        deadHero.deathDay = gameData.day
        table.insert(gameData.graveyard, deadHero)
        result.message = result.message .. " " .. deadHero.name .. " has fallen in combat!"
    end

    -- Handle guild XP and reputation
    local guildResult = {}
    if GuildSystem then
        guildResult = GuildSystem.onQuestComplete(gameData, quest, result.success)
    end

    -- Calculate and add material drops (only on success)
    local materialDrops = {}
    if result.success and Materials then
        materialDrops = Materials.calculateDrops(quest, heroList, EquipmentSystem)
        for matId, count in pairs(materialDrops) do
            gameData.inventory.materials[matId] = (gameData.inventory.materials[matId] or 0) + count
        end
    end

    -- Now start the return phase
    quest.currentPhase = "return"
    quest.phaseProgress = 0

    -- Build a set of dead hero IDs for quick lookup
    local deadHeroIds = {}
    for _, deadHero in ipairs(deadHeroes) do
        deadHeroIds[deadHero.id] = true
    end

    for _, heroId in ipairs(quest.assignedHeroes) do
        local hero = QuestSystem.getHeroById(heroId, gameData)
        if hero and not deadHeroIds[heroId] then
            hero.status = "returning"
            hero.questPhase = "return"
            hero.questProgress = 0
            hero.questPhaseMax = quest.actualReturnTime or quest.returnTime
        end
    end

    -- Mark quest status
    quest.status = result.success and "completed" or "failed"

    -- Return full result for the popup
    return {
        quest = quest,
        success = result.success,
        goldReward = result.goldReward,
        xpReward = result.xpReward,
        message = result.message,
        deadHeroes = deadHeroes,
        materialDrops = materialDrops,
        guildLevelUp = guildResult.guildLevelUp,
        guildXP = guildResult.guildXP,
        tierChanged = guildResult.tierChanged,
        combatLog = result.combatLog,
        combatSummary = result.combatSummary,
        narrative = result.narrative
    }
end

-- Claim a completed quest (called when player clicks on awaiting_claim quest)
-- Returns the result to show in the popup, and starts the return phase
-- DEPRECATED: Use executeQuest + startReturn instead for new flow
function QuestSystem.claimQuest(quest, gameData, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
    if quest.currentPhase ~= "awaiting_claim" then
        return nil  -- Quest not ready to claim
    end

    local heroList = QuestSystem.getQuestHeroes(quest, gameData)

    -- Check for party luck bonus before resolution
    local partyLuckBonus = PartySystem.getLuckBonus(heroList, gameData)

    local result
    if quest.isDungeon then
        -- Dungeon: compile results from floor clears
        result = QuestSystem.compileDungeonResult(quest, heroList, gameData, Quests, partyLuckBonus)
    else
        -- Normal quest resolution
        result = Quests.resolve(quest, heroList, partyLuckBonus, gameData)
    end

    -- Party re-roll mechanic: if quest failed and heroes are a formed party, try again
    if not result.success and PartySystem.canReroll(heroList, gameData) then
        local rerollResult = Quests.resolve(quest, heroList, partyLuckBonus, gameData)
        if rerollResult.success then
            result = rerollResult
            result.message = "Party bond triggered a re-roll! " .. result.message
        else
            result.message = result.message .. " (Party re-roll also failed)"
        end
    end

    -- Track quest for party formation (only on success)
    if result.success then
        local party, justFormed = PartySystem.recordQuestSuccess(heroList, gameData)
        if justFormed and party then
            result.message = result.message .. " " .. party.name .. " has officially formed!"
        end
    end

    -- Apply rewards
    Economy.earn(gameData, result.goldReward)

    -- Track dead and revived heroes
    local deadHeroes = {}
    local revivedHeroes = {}

    -- Rank values for XP bonus calculation
    local rankValues = {D = 1, C = 2, B = 3, A = 4, S = 5}
    local questRankValue = rankValues[quest.rank] or 1

    -- Award XP and handle death/revival
    local baseXpPerHero = #heroList > 0 and math.floor(result.xpReward / #heroList) or 0
    for _, hero in ipairs(heroList) do
        -- Calculate rank-differential XP bonus
        local heroRankValue = rankValues[hero.rank] or 1
        local rankDiff = questRankValue - heroRankValue
        local xpMultiplier = 1.0
        if rankDiff > 0 and result.success then
            xpMultiplier = 1.0 + (rankDiff * 0.3)
        end
        local xpForHero = math.floor(baseXpPerHero * xpMultiplier)

        local leveledUp = Heroes.addXP(hero, xpForHero)
        if leveledUp then
            result.message = result.message .. " " .. hero.name .. " leveled up!"
        end
        if rankDiff > 0 and result.success then
            result.message = result.message .. " " .. hero.name .. " gained bonus XP for besting a higher rank quest!"
        end

        -- Check for death on failed COMBAT quests (A/S rank ONLY)
        if not result.success and quest.combat then
            local deathChance = {A = 0.30, S = 0.50}
            local chance = deathChance[quest.rank]
            if chance then
                local hasPartyClericProtection = PartySystem.hasClericProtection(heroList, gameData)
                if hasPartyClericProtection then
                    chance = chance * 0.3
                end
                if math.random() < chance then
                    -- Check for phoenix feather revival
                    local revived = false
                    if EquipmentSystem and EquipmentSystem.hasReviveItem then
                        revived = EquipmentSystem.hasReviveItem(hero)
                        if revived then
                            EquipmentSystem.consumeReviveItem(hero)
                            table.insert(revivedHeroes, hero)
                        end
                    end
                    if not revived then
                        table.insert(deadHeroes, hero)
                    end
                end
            end
        end
    end

    -- Remove dead heroes from roster
    for _, deadHero in ipairs(deadHeroes) do
        for i, hero in ipairs(gameData.heroes) do
            if hero.id == deadHero.id then
                table.remove(gameData.heroes, i)
                break
            end
        end
        deadHero.deathQuest = quest.name
        deadHero.deathDay = gameData.day
        table.insert(gameData.graveyard, deadHero)
        result.message = result.message .. " " .. deadHero.name .. " has fallen in combat!"
    end

    -- Handle guild XP and reputation
    local guildResult = {}
    if GuildSystem then
        guildResult = GuildSystem.onQuestComplete(gameData, quest, result.success)
    end

    -- Calculate and add material drops (only on success)
    local materialDrops = {}
    if result.success and Materials then
        materialDrops = Materials.calculateDrops(quest, heroList, EquipmentSystem)
        for matId, count in pairs(materialDrops) do
            gameData.inventory.materials[matId] = (gameData.inventory.materials[matId] or 0) + count
        end
    end

    -- Now start the return phase
    quest.currentPhase = "return"
    quest.phaseProgress = 0

    -- Build a set of dead hero IDs for quick lookup
    local deadHeroIds = {}
    for _, deadHero in ipairs(deadHeroes) do
        deadHeroIds[deadHero.id] = true
    end

    for _, heroId in ipairs(quest.assignedHeroes) do
        local hero = QuestSystem.getHeroById(heroId, gameData)
        if hero and not deadHeroIds[heroId] then
            hero.status = "returning"
            hero.questPhase = "return"
            hero.questProgress = 0
            hero.questPhaseMax = quest.actualReturnTime or quest.returnTime
        end
    end

    -- Mark quest status
    quest.status = result.success and "completed" or "failed"

    -- Return full result for the popup
    return {
        quest = quest,
        success = result.success,
        goldReward = result.goldReward,
        xpReward = result.xpReward,
        message = result.message,
        deadHeroes = deadHeroes,
        materialDrops = materialDrops,
        guildLevelUp = guildResult.guildLevelUp,
        guildXP = guildResult.guildXP,
        tierChanged = guildResult.tierChanged
    }
end

-- Get hero by ID from game data (checks guild roster AND heroes on quests)
-- Uses cached lookup for O(1) performance when cache is valid
function QuestSystem.getHeroById(heroId, gameData)
    -- Try cache first (rebuilds if empty)
    if not heroLookupCache[heroId] then
        -- Cache miss - rebuild and try again
        rebuildHeroLookup(gameData)
    end

    local cachedHero = heroLookupCache[heroId]
    if cachedHero then
        return cachedHero
    end

    -- Fallback: linear search (cache may be stale)
    -- Check guild roster first
    for _, hero in ipairs(gameData.heroes or {}) do
        if hero.id == heroId then
            heroLookupCache[heroId] = hero  -- Update cache
            return hero
        end
    end
    -- Check heroes on active quests (they've left the guild temporarily!)
    for _, quest in ipairs(gameData.activeQuests or {}) do
        if quest.heroesOnQuest then
            for _, hero in ipairs(quest.heroesOnQuest) do
                if hero.id == heroId then
                    heroLookupCache[heroId] = hero  -- Update cache
                    return hero
                end
            end
        end
    end
    return nil
end

-- Get heroes assigned to a quest
function QuestSystem.getQuestHeroes(quest, gameData)
    -- Use heroesOnQuest directly if available (heroes have left the guild!)
    if quest.heroesOnQuest and #quest.heroesOnQuest > 0 then
        return quest.heroesOnQuest
    end
    -- Fallback to old method for backwards compatibility
    local heroes = {}
    for _, heroId in ipairs(quest.assignedHeroes) do
        local hero = QuestSystem.getHeroById(heroId, gameData)
        if hero then
            table.insert(heroes, hero)
        end
    end
    return heroes
end

-- Calculate success chance for UI display
function QuestSystem.getSuccessChance(quest, heroes, Quests, EquipmentSystem)
    if #heroes == 0 then return 0 end
    return Quests.calculateSuccessChance(quest, heroes, EquipmentSystem)
end


-- Get count of available heroes
function QuestSystem.getAvailableHeroCount(gameData)
    local count = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "idle" then
            count = count + 1
        end
    end
    return count
end

-- Get count of resting heroes
function QuestSystem.getRestingHeroCount(gameData)
    local count = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            count = count + 1
        end
    end
    return count
end

-- Resolve a single dungeon floor
function QuestSystem.resolveFloor(quest, gameData, Heroes, Quests, EquipmentSystem)
    local heroList = QuestSystem.getQuestHeroes(quest, gameData)
    local floorNumber = quest.currentFloor + 1  -- Next floor to resolve
    local dungeonConfig = Quests.getDungeonConfig()

    local result = {
        floor = floorNumber,
        success = false,
        rewards = {},
        deaths = {},
        injuries = {},
        partyWiped = false
    }

    -- Calculate success chance with fatigue penalty (includes party trait bonuses)
    local successChance = Quests.calculateFloorSuccessChance(quest, heroList, floorNumber, EquipmentSystem, gameData)
    result.success = math.random() <= successChance

    if result.success then
        -- Roll floor loot
        local totalLuck = 0
        for _, hero in ipairs(heroList) do
            totalLuck = totalLuck + (hero.stats.luck or 5)
        end
        local avgLuck = totalLuck / #heroList
        local luckMultiplier = 1.0 + (avgLuck - 5) * 0.05

        result.rewards = Quests.rollFloorRewards(quest, luckMultiplier, floorNumber)
    else
        -- Floor failed - check for deaths (floor 3+)
        local deathRisk = Quests.getFloorDeathRisk(quest, floorNumber)
        if deathRisk.canKill and quest.combat then
            local hasCleric = Quests.partyHasCleric(heroList)
            local effectiveDeathChance = deathRisk.deathChance
            if hasCleric then
                effectiveDeathChance = effectiveDeathChance * 0.30  -- 70% reduction
            end

            for _, hero in ipairs(heroList) do
                if math.random() <= effectiveDeathChance then
                    table.insert(result.deaths, hero.id)
                else
                    table.insert(result.injuries, hero.id)
                end
            end
        else
            -- No death risk, just injuries
            for _, hero in ipairs(heroList) do
                table.insert(result.injuries, hero.id)
            end
        end

        -- Check for party wipe
        result.partyWiped = #result.deaths >= #heroList
    end

    return result
end

-- Compile final dungeon result from all floor results
function QuestSystem.compileDungeonResult(quest, heroList, gameData, Quests, partyLuckBonus)
    local dungeonConfig = Quests.getDungeonConfig()

    -- Count successful floors
    local floorsSucceeded = 0
    local allRewards = {}
    local allDeaths = {}
    local allInjuries = {}

    for _, floorResult in ipairs(quest.floorsCleared) do
        if floorResult.success then
            floorsSucceeded = floorsSucceeded + 1
            -- Collect rewards from successful floors
            for _, reward in ipairs(floorResult.rewards or {}) do
                table.insert(allRewards, reward)
            end
        end

        -- Track deaths/injuries across all floors
        for _, heroId in ipairs(floorResult.deaths or {}) do
            allDeaths[heroId] = true
        end
        for _, heroId in ipairs(floorResult.injuries or {}) do
            if not allDeaths[heroId] then
                allInjuries[heroId] = true
            end
        end
    end

    -- Determine if dungeon was fully completed
    local dungeonComplete = floorsSucceeded == quest.floorCount and not quest.hasRetreated

    -- Calculate rewards
    local baseGold = quest.reward
    local baseXP = quest.xpReward
    local goldReward, xpReward

    if dungeonComplete then
        -- Full completion: apply dungeon bonuses
        goldReward = math.floor(baseGold * (1 + dungeonConfig.rewards.completionBonusMultiplier))
        xpReward = math.floor(baseXP * dungeonConfig.rewards.xpMultiplier)
    else
        -- Partial completion or retreat
        local floorRatio = floorsSucceeded / quest.floorCount
        goldReward = math.floor(baseGold * floorRatio * 0.5)
        xpReward = math.floor(baseXP * floorRatio * 0.5)
    end

    -- Build result in same format as normal quest resolution
    local result = {
        quest = quest,
        success = dungeonComplete,
        goldReward = goldReward,
        xpReward = xpReward,
        bonusRewards = allRewards,
        message = "",
        -- Dungeon-specific fields
        isDungeon = true,
        floorsCleared = floorsSucceeded,
        totalFloors = quest.floorCount,
        hasRetreated = quest.hasRetreated,
        floorBreakdown = quest.floorsCleared,
        dungeonDeaths = allDeaths,
        dungeonInjuries = allInjuries
    }

    if dungeonComplete then
        result.message = "DUNGEON COMPLETED! All " .. quest.floorCount .. " floors cleared!"
    elseif quest.hasRetreated then
        result.message = "Party retreated after clearing " .. floorsSucceeded .. "/" .. quest.floorCount .. " floors."
    else
        result.message = "Dungeon failed! Only " .. floorsSucceeded .. "/" .. quest.floorCount .. " floors cleared."
    end

    return result
end

-- Handle dungeon retreat
function QuestSystem.retreatFromDungeon(quest, gameData, Heroes)
    if not quest.isDungeon or quest.currentPhase ~= "execute" then
        return false, "Cannot retreat from this quest"
    end

    if quest.currentFloor < 1 then
        return false, "Must clear at least one floor before retreating"
    end

    quest.hasRetreated = true
    quest.currentPhase = "return"
    quest.phaseProgress = 0

    -- Mark heroes as returning
    for _, heroId in ipairs(quest.assignedHeroes) do
        local hero = QuestSystem.getHeroById(heroId, gameData)
        if hero then
            hero.status = "returning"
            hero.questPhase = "return"
            hero.questProgress = 0
            hero.questPhaseMax = quest.actualReturnTime or quest.returnTime
        end
    end

    return true, "Retreating from dungeon with " .. quest.currentFloor .. " floor(s) cleared"
end

return QuestSystem
