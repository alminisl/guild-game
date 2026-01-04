-- Quest System Module
-- Manages active quests, real-time updates, and resolution

local QuestSystem = {}

-- Load EquipmentSystem for mount calculations
local EquipmentSystem = require("systems.equipment_system")
local PartySystem = require("systems.party_system")

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
    local adjustedTravelTime = math.floor(quest.travelTime * travelMultiplier)
    local adjustedReturnTime = math.floor(quest.returnTime * travelMultiplier)

    -- Store adjusted times on the quest
    quest.actualTravelTime = adjustedTravelTime
    quest.actualReturnTime = adjustedReturnTime
    quest.travelSpeedMultiplier = travelMultiplier

    -- Assign heroes to quest
    quest.assignedHeroes = {}
    for _, hero in ipairs(heroes) do
        table.insert(quest.assignedHeroes, hero.id)
        hero.status = "traveling"
        hero.currentQuestId = quest.id
        hero.questPhase = "travel"
        hero.questProgress = 0
        hero.questPhaseMax = adjustedTravelTime
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

    return true, "Party sent on " .. quest.name .. "!"
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
                quest.currentPhase = "execute"
                quest.phaseProgress = 0
                -- Update heroes
                for _, heroId in ipairs(quest.assignedHeroes) do
                    local hero = QuestSystem.getHeroById(heroId, gameData)
                    if hero then
                        hero.status = "questing"
                        hero.questPhase = "execute"
                        hero.questProgress = 0
                        hero.questPhaseMax = quest.executeTime
                    end
                end
            end
        elseif quest.currentPhase == "execute" then
            phaseMax = quest.executeTime
            if quest.phaseProgress >= phaseMax then
                phaseComplete = true
                quest.currentPhase = "return"
                quest.phaseProgress = 0
                -- Update heroes
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
        elseif quest.currentPhase == "return" then
            phaseMax = quest.actualReturnTime or quest.returnTime
            if quest.phaseProgress >= phaseMax then
                -- Quest complete - resolve it
                local heroList = QuestSystem.getQuestHeroes(quest, gameData)

                -- Check for party luck bonus before resolution
                local partyLuckBonus = PartySystem.getLuckBonus(heroList, gameData)

                local result = Quests.resolve(quest, heroList, partyLuckBonus)

                -- Party re-roll mechanic: if quest failed and heroes are a formed party, try again
                if not result.success and PartySystem.canReroll(heroList, gameData) then
                    local rerollResult = Quests.resolve(quest, heroList, partyLuckBonus)
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
                local baseXpPerHero = math.floor(result.xpReward / #heroList)
                for _, hero in ipairs(heroList) do
                    -- Calculate rank-differential XP bonus
                    -- Heroes completing quests above their rank get bonus XP
                    local heroRankValue = rankValues[hero.rank] or 1
                    local rankDiff = questRankValue - heroRankValue
                    local xpMultiplier = 1.0
                    if rankDiff > 0 and result.success then
                        -- 50% bonus XP per rank above hero's rank (only on success)
                        xpMultiplier = 1.0 + (rankDiff * 0.5)
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
                    local shouldDie = false
                    if not result.success and quest.combat then
                        -- Formed parties with a cleric have guaranteed death protection
                        local hasPartyClericProtection = PartySystem.hasClericProtection(heroList, gameData)
                        if hasPartyClericProtection then
                            -- Party cleric saves everyone - no death rolls
                            shouldDie = false
                        else
                            -- Only A/S rank combat quest failures can cause death
                            local deathChance = {A = 0.30, S = 0.50}
                            local chance = deathChance[quest.rank]
                            if chance then
                                local roll = math.random()
                                if roll < chance then
                                    shouldDie = true
                                end
                            end
                        end
                        -- D/C/B rank quests CANNOT cause death
                    end

                    -- Check for Phoenix Feather if would die
                    if shouldDie then
                        local hasFeather = hero.equipment and hero.equipment.accessory == "phoenix_feather"
                        if hasFeather then
                            -- Consume Phoenix Feather and revive
                            hero.equipment.accessory = nil
                            shouldDie = false
                            table.insert(revivedHeroes, hero)
                            result.message = result.message .. " " .. hero.name .. "'s Phoenix Feather saved them!"
                        else
                            table.insert(deadHeroes, hero)
                        end
                    end

                    -- Clear quest state
                    hero.currentQuestId = nil
                    hero.questPhase = nil
                    hero.questProgress = 0

                    if not shouldDie then
                        -- Check if party has cleric protection
                        local hasClericProtection = false
                        for _, h in ipairs(heroList) do
                            if Heroes.providesDeathProtection(h) then
                                hasClericProtection = true
                                break
                            end
                        end

                        -- Determine and apply injury based on quest outcome
                        local wasRevived = false
                        for _, revived in ipairs(revivedHeroes) do
                            if revived.id == hero.id then wasRevived = true break end
                        end

                        if wasRevived then
                            -- Revived heroes are severely wounded
                            Heroes.applyInjury(hero, "wounded")
                        else
                            -- Determine injury from quest outcome
                            local injuryState = Heroes.determineInjury(quest.rank, result.success, hasClericProtection)
                            if injuryState then
                                Heroes.applyInjury(hero, injuryState)
                            end
                        end

                        -- Start resting (injury multiplier is applied inside startResting)
                        Heroes.startResting(hero, quest.rank, not result.success)
                    end
                end

                -- Remove dead heroes from roster and add to graveyard
                for _, deadHero in ipairs(deadHeroes) do
                    for i, hero in ipairs(gameData.heroes) do
                        if hero.id == deadHero.id then
                            table.remove(gameData.heroes, i)
                            -- Add to graveyard
                            deadHero.deathQuest = quest.name
                            deadHero.deathDay = gameData.day
                            table.insert(gameData.graveyard, deadHero)
                            result.message = result.message .. " " .. deadHero.name .. " has fallen in combat!"
                            break
                        end
                    end
                end

                quest.status = result.success and "completed" or "failed"
                table.insert(questsToRemove, i)

                -- Handle guild XP and reputation
                local guildResult = {}
                if GuildSystem then
                    guildResult = GuildSystem.onQuestComplete(gameData, quest, result.success)
                end

                -- Calculate and add material drops (only on success)
                local materialDrops = {}
                if result.success and Materials then
                    materialDrops = Materials.calculateDrops(quest, heroList, EquipmentSystem)

                    -- Add materials to inventory
                    for matId, count in pairs(materialDrops) do
                        gameData.inventory.materials[matId] = (gameData.inventory.materials[matId] or 0) + count
                    end
                end

                table.insert(results, {
                    quest = quest,
                    success = result.success,
                    goldReward = result.goldReward,
                    xpReward = result.xpReward,
                    message = result.message,
                    deadHeroes = deadHeroes,
                    materialDrops = materialDrops,
                    -- Guild progression info
                    guildLevelUp = guildResult.guildLevelUp,
                    guildXP = guildResult.guildXP,
                    tierChanged = guildResult.tierChanged
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

-- Get hero by ID from game data
function QuestSystem.getHeroById(heroId, gameData)
    for _, hero in ipairs(gameData.heroes) do
        if hero.id == heroId then
            return hero
        end
    end
    return nil
end

-- Get heroes assigned to a quest
function QuestSystem.getQuestHeroes(quest, gameData)
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

return QuestSystem
