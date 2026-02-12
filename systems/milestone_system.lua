-- Milestone System
-- Tracks player achievements and progression milestones for dopamine hits

local MilestoneSystem = {}

-- Milestone definitions with rewards
MilestoneSystem.milestones = {
    -- Early game milestones (first 10 minutes)
    {
        id = "first_quest",
        name = "First Steps",
        description = "Complete your first quest",
        check = function(gameData) return (gameData.stats.questsCompleted or 0) >= 1 end,
        reward = {gold = 25},
        category = "early"
    },
    {
        id = "hire_fourth",
        name = "Full Roster",
        description = "Have 4 heroes in your guild",
        check = function(gameData) return #gameData.heroes >= 4 end,
        reward = {gold = 50},
        category = "early"
    },
    {
        id = "first_party_quest",
        name = "Strength in Numbers",
        description = "Send 3+ heroes on a single quest",
        check = function(gameData) return (gameData.stats.maxPartySize or 0) >= 3 end,
        reward = {gold = 30},
        category = "early"
    },
    {
        id = "first_level_up",
        name = "Growth",
        description = "Level up a hero for the first time",
        check = function(gameData) return (gameData.stats.totalLevelUps or 0) >= 1 end,
        reward = {gold = 20},
        category = "early"
    },
    {
        id = "ten_quests",
        name = "Getting Started",
        description = "Complete 10 quests",
        check = function(gameData) return (gameData.stats.questsCompleted or 0) >= 10 end,
        reward = {gold = 100},
        category = "early"
    },

    -- Guild progression
    {
        id = "guild_level_2",
        name = "Rising Guild",
        description = "Reach Guild Level 2",
        check = function(gameData) return gameData.guild and gameData.guild.level >= 2 end,
        reward = {gold = 150},
        category = "guild"
    },
    {
        id = "guild_level_5",
        name = "Established Guild",
        description = "Reach Guild Level 5",
        check = function(gameData) return gameData.guild and gameData.guild.level >= 5 end,
        reward = {gold = 500},
        category = "guild"
    },

    -- Combat milestones
    {
        id = "first_c_quest",
        name = "Stepping Up",
        description = "Complete a C-rank quest",
        check = function(gameData) return (gameData.stats.cRankCompleted or 0) >= 1 end,
        reward = {gold = 75},
        category = "combat"
    },
    {
        id = "first_b_quest",
        name = "Veteran Adventurers",
        description = "Complete a B-rank quest",
        check = function(gameData) return (gameData.stats.bRankCompleted or 0) >= 1 end,
        reward = {gold = 200},
        category = "combat"
    },
    {
        id = "no_deaths_10",
        name = "Safety First",
        description = "Complete 10 combat quests with no deaths",
        check = function(gameData) return (gameData.stats.combatQuestsNoDeath or 0) >= 10 end,
        reward = {gold = 150},
        category = "combat"
    },

    -- Party milestones
    {
        id = "first_party",
        name = "Bonds of Adventure",
        description = "Form your first official party",
        check = function(gameData) return #(gameData.parties or {}) >= 1 end,
        reward = {gold = 200},
        category = "party"
    },
    {
        id = "balanced_party",
        name = "Well Rounded",
        description = "Complete a quest with Tank, Healer, DPS, and Support",
        check = function(gameData) return gameData.stats.balancedPartyQuest or false end,
        reward = {gold = 100},
        category = "party"
    },

    -- Wealth milestones
    {
        id = "gold_500",
        name = "Savings Account",
        description = "Accumulate 500 gold",
        check = function(gameData) return (gameData.stats.maxGold or 0) >= 500 end,
        reward = {gold = 50},
        category = "wealth"
    },
    {
        id = "gold_2000",
        name = "Guild Treasury",
        description = "Accumulate 2000 gold",
        check = function(gameData) return (gameData.stats.maxGold or 0) >= 2000 end,
        reward = {gold = 200},
        category = "wealth"
    },

    -- Collection milestones
    {
        id = "all_classes",
        name = "Diverse Guild",
        description = "Have one hero of each base class",
        check = function(gameData)
            local classes = {}
            for _, hero in ipairs(gameData.heroes) do
                local baseClass = hero.class
                -- Map awakened classes to base
                if baseClass == "Paladin" then baseClass = "Knight"
                elseif baseClass == "Hawkeye" then baseClass = "Archer"
                elseif baseClass == "Archmage" then baseClass = "Mage"
                elseif baseClass == "Shadow" then baseClass = "Rogue"
                elseif baseClass == "Saint" then baseClass = "Priest"
                elseif baseClass == "Warden" then baseClass = "Ranger"
                end
                classes[baseClass] = true
            end
            return classes.Knight and classes.Archer and classes.Mage and
                   classes.Rogue and classes.Priest and classes.Ranger
        end,
        reward = {gold = 300},
        category = "collection"
    }
}

-- Initialize milestone tracking in gameData
function MilestoneSystem.init(gameData)
    if not gameData.milestones then
        gameData.milestones = {
            completed = {},  -- {milestone_id = timestamp}
            newlyCompleted = {}  -- For popup notification
        }
    end
    if not gameData.stats then
        gameData.stats = {
            questsCompleted = 0,
            questsFailed = 0,
            totalLevelUps = 0,
            maxPartySize = 0,
            maxGold = 0,
            cRankCompleted = 0,
            bRankCompleted = 0,
            aRankCompleted = 0,
            sRankCompleted = 0,
            combatQuestsNoDeath = 0,
            balancedPartyQuest = false
        }
    end
end

-- Update stats when events happen
function MilestoneSystem.onQuestComplete(gameData, quest, success, heroes, deaths)
    if not gameData.stats then MilestoneSystem.init(gameData) end

    if success then
        gameData.stats.questsCompleted = (gameData.stats.questsCompleted or 0) + 1

        -- Track rank completions
        if quest.rank == "C" then
            gameData.stats.cRankCompleted = (gameData.stats.cRankCompleted or 0) + 1
        elseif quest.rank == "B" then
            gameData.stats.bRankCompleted = (gameData.stats.bRankCompleted or 0) + 1
        elseif quest.rank == "A" then
            gameData.stats.aRankCompleted = (gameData.stats.aRankCompleted or 0) + 1
        elseif quest.rank == "S" then
            gameData.stats.sRankCompleted = (gameData.stats.sRankCompleted or 0) + 1
        end

        -- Track combat quests without deaths
        if quest.combat and (not deaths or #deaths == 0) then
            gameData.stats.combatQuestsNoDeath = (gameData.stats.combatQuestsNoDeath or 0) + 1
        elseif deaths and #deaths > 0 then
            gameData.stats.combatQuestsNoDeath = 0  -- Reset streak
        end

        -- Track max party size
        if heroes and #heroes > (gameData.stats.maxPartySize or 0) then
            gameData.stats.maxPartySize = #heroes
        end

        -- Track balanced party (all 4 roles)
        if heroes and #heroes >= 4 then
            local Quests = require("data.quests")
            local roles = Quests.getPartyRoles(heroes)
            if roles.tank.active and roles.healer.active and roles.dps.active and roles.support.active then
                gameData.stats.balancedPartyQuest = true
            end
        end
    else
        gameData.stats.questsFailed = (gameData.stats.questsFailed or 0) + 1
    end

    -- Track max gold
    if gameData.gold > (gameData.stats.maxGold or 0) then
        gameData.stats.maxGold = gameData.gold
    end
end

function MilestoneSystem.onLevelUp(gameData)
    if not gameData.stats then MilestoneSystem.init(gameData) end
    gameData.stats.totalLevelUps = (gameData.stats.totalLevelUps or 0) + 1
end

function MilestoneSystem.onGoldChange(gameData)
    if not gameData.stats then MilestoneSystem.init(gameData) end
    if gameData.gold > (gameData.stats.maxGold or 0) then
        gameData.stats.maxGold = gameData.gold
    end
end

-- Check all milestones and return newly completed ones
function MilestoneSystem.checkMilestones(gameData)
    if not gameData.milestones then MilestoneSystem.init(gameData) end

    local newlyCompleted = {}

    for _, milestone in ipairs(MilestoneSystem.milestones) do
        -- Skip if already completed
        if not gameData.milestones.completed[milestone.id] then
            -- Check if milestone is now complete
            if milestone.check(gameData) then
                gameData.milestones.completed[milestone.id] = os.time()
                table.insert(newlyCompleted, milestone)

                -- Apply reward
                if milestone.reward then
                    if milestone.reward.gold then
                        gameData.gold = gameData.gold + milestone.reward.gold
                    end
                end
            end
        end
    end

    -- Store for UI notification
    for _, m in ipairs(newlyCompleted) do
        table.insert(gameData.milestones.newlyCompleted, m)
    end

    return newlyCompleted
end

-- Get milestone by ID
function MilestoneSystem.getMilestone(milestoneId)
    for _, m in ipairs(MilestoneSystem.milestones) do
        if m.id == milestoneId then return m end
    end
    return nil
end

-- Get all milestones with completion status
function MilestoneSystem.getAllMilestones(gameData)
    if not gameData.milestones then MilestoneSystem.init(gameData) end

    local result = {}
    for _, milestone in ipairs(MilestoneSystem.milestones) do
        table.insert(result, {
            milestone = milestone,
            completed = gameData.milestones.completed[milestone.id] ~= nil,
            completedAt = gameData.milestones.completed[milestone.id]
        })
    end
    return result
end

-- Get completion percentage
function MilestoneSystem.getProgress(gameData)
    if not gameData.milestones then return 0, 0 end

    local total = #MilestoneSystem.milestones
    local completed = 0
    for _ in pairs(gameData.milestones.completed) do
        completed = completed + 1
    end

    return completed, total
end

-- Pop next milestone notification (for UI)
function MilestoneSystem.popNotification(gameData)
    if not gameData.milestones or not gameData.milestones.newlyCompleted then
        return nil
    end
    return table.remove(gameData.milestones.newlyCompleted, 1)
end

-- Get milestones by category
function MilestoneSystem.getByCategory(gameData, category)
    local result = {}
    for _, milestone in ipairs(MilestoneSystem.milestones) do
        if milestone.category == category then
            table.insert(result, {
                milestone = milestone,
                completed = gameData.milestones and gameData.milestones.completed[milestone.id] ~= nil
            })
        end
    end
    return result
end

return MilestoneSystem
