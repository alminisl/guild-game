-- Quest System Module
-- Manages active quests, real-time updates, and resolution

local QuestSystem = {}

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

    -- Calculate party power
    local partyPower = 0
    for _, hero in ipairs(heroes) do
        if hero.status ~= "idle" then
            return false, hero.name .. " is not available"
        end
        partyPower = partyPower + hero.power
    end

    -- Check power requirement
    if partyPower < quest.requiredPower then
        return false, "Party power (" .. partyPower .. ") is less than required (" .. quest.requiredPower .. ")"
    end

    -- Assign heroes to quest
    quest.assignedHeroes = {}
    for _, hero in ipairs(heroes) do
        table.insert(quest.assignedHeroes, hero.id)
        hero.status = "traveling"
        hero.currentQuestId = quest.id
        hero.questPhase = "travel"
        hero.questProgress = 0
        hero.questPhaseMax = quest.travelTime
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
            phaseMax = quest.travelTime
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
                        hero.questPhaseMax = quest.returnTime
                    end
                end
            end
        elseif quest.currentPhase == "return" then
            phaseMax = quest.returnTime
            if quest.phaseProgress >= phaseMax then
                -- Quest complete - resolve it
                local heroList = QuestSystem.getQuestHeroes(quest, gameData)
                local result = Quests.resolve(quest, heroList)

                -- Apply rewards
                Economy.earn(gameData, result.goldReward)

                -- Track dead and revived heroes
                local deadHeroes = {}
                local revivedHeroes = {}

                -- Award XP and handle death/revival
                local xpPerHero = math.floor(result.xpReward / #heroList)
                for _, hero in ipairs(heroList) do
                    local leveledUp = Heroes.addXP(hero, xpPerHero)
                    if leveledUp then
                        result.message = result.message .. " " .. hero.name .. " leveled up!"
                    end

                    -- Check for death on failed COMBAT quests
                    local shouldDie = false
                    if not result.success and quest.combat then
                        -- Combat quest failure - chance of death based on quest rank
                        local deathChance = {D = 0.1, C = 0.15, B = 0.2, A = 0.3, S = 0.4}
                        local roll = math.random()
                        if roll < (deathChance[quest.rank] or 0.1) then
                            shouldDie = true
                        end
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

-- Get party power for UI display
function QuestSystem.getPartyPower(heroes)
    local power = 0
    for _, hero in ipairs(heroes) do
        power = power + hero.power
    end
    return power
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
