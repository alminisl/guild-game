-- Guild Management Game
-- A game where you hire heroes and send them on quests

-- Load modules
local Heroes = require("data.heroes")
local Quests = require("data.quests")
local Items = require("data.items")
local Materials = require("data.materials")
local Equipment = require("data.equipment")
local Recipes = require("data.recipes")
local Economy = require("systems.economy")
local QuestSystem = require("systems.quest_system")
local TimeSystem = require("systems.time_system")
local GuildSystem = require("systems.guild_system")
local EquipmentSystem = require("systems.equipment_system")
local CraftingSystem = require("systems.crafting_system")
local SpriteSystem = require("systems.sprite_system")
local Components = require("ui.components")
local Town = require("ui.town")
local TavernMenu = require("ui.tavern_menu")
local GuildMenu = require("ui.guild_menu")
local ArmoryMenu = require("ui.armory_menu")
local PotionMenu = require("ui.potion_menu")
local QuestResultModal = require("ui.quest_result_modal")
local SaveMenu = require("ui.save_menu")
local SaveSystem = require("systems.save_system")
local SettingsMenu = require("ui.settings_menu")
local EditMode = require("ui.edit_mode")
local MilestoneSystem = require("systems.milestone_system")
local HeroSelection = require("ui.hero_selection")

-- Game States
local STATE = {
    HERO_SELECT = "hero_select",
    TOWN = "town",
    TAVERN = "tavern",
    GUILD = "guild",
    ARMORY = "armory",
    POTION = "potion",
    SAVE_MENU = "save_menu",
    SETTINGS = "settings",
    EDIT_MODE = "edit_mode"
}

-- Game data (central state)
local gameData = {
    day = 1,
    dayProgress = 0,
    totalTime = 0,
    gold = 100,            -- Start with less gold (tutorial gives more)
    heroes = {},           -- Hired heroes
    tavernPool = {},       -- Heroes available for hire
    availableQuests = {},  -- Quests that can be assigned
    activeQuests = {},     -- Quests in progress
    guild = nil,           -- Guild progression data (initialized in love.load)
    inventory = {          -- Player inventory
        materials = {},    -- {material_id = count}
        equipment = {}     -- {equipment_id = count}
    },
    graveyard = {},        -- Dead heroes (for display/resurrection)
    parties = {},          -- Formed parties (4 heroes with different classes, 3+ quests together)
    protoParties = {},     -- Proto-parties (forming, not yet official)
    sRankQuestsToday = 0,  -- Daily limit tracker for S-rank quests (max 2 per day)
    tutorial = {           -- Tutorial state
        active = true,
        questsCompleted = 0,
        questsRequired = 2,
        welcomeShown = false
    }
}

-- Current game state
local currentState = STATE.HERO_SELECT

-- Notification system
local notifications = {}
local notificationTimer = 0

-- Mouse position for hover effects
local mouseX, mouseY = 0, 0

-- Forward declarations for functions defined later
local drawHeroAnimations
local drawNotifications
local addNotification

-- Quest refresh timer (new quests appear periodically)
local questRefreshTimer = 0
local QUEST_REFRESH_INTERVAL = 60  -- New quest every 60 seconds

-- Initialize game
function love.load()
    love.window.setTitle("Guild Management - Day 1")
    love.window.setMode(1920, 1080, {resizable = true, minwidth = 1280, minheight = 720})
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    -- Set default filter to nearest for crisp text and pixel art
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize font with nearest filtering for crisp text
    local font = love.graphics.newFont(14)
    font:setFilter("nearest", "nearest")
    love.graphics.setFont(font)

    -- Seed random
    math.randomseed(os.time())

    -- Initialize guild progression
    gameData.guild = GuildSystem.initializeData()

    -- Initialize tavern pool (uses guild max rank and level)
    local maxRank = GuildSystem.getMaxTavernRank(gameData)
    local guildLevel = gameData.guild.level or 1
    gameData.tavernPool = Heroes.generateTavernPool(4, maxRank, guildLevel)

    -- Initialize available quests
    if gameData.tutorial.active then
        -- Tutorial: Add 2 easy starter quests with good rewards
        local tutorialQuest1 = Quests.generate("D", {
            name = "Town Patrol",
            description = "Help the guards patrol the town perimeter",
            reward = 60,  -- Enough to hire 1 hero with some left over
            xpReward = 30,
            requiredStat = "str",
            faction = "humans",
            combat = false,
            materialBonus = false,
            timeOfDay = "day",
            possibleRewards = {
                { type = "gold", amount = 20, dropChance = 0.8 }
            }
        })
        tutorialQuest1.isTutorial = true
        
        local tutorialQuest2 = Quests.generate("D", {
            name = "Herb Delivery",
            description = "Deliver herbs to the local healer",
            reward = 50,  -- Together with quest 1, enough to hire 2 heroes
            xpReward = 30,
            requiredStat = "dex",
            faction = "humans",
            combat = false,
            materialBonus = false,
            timeOfDay = "day",
            possibleRewards = {
                { type = "gold", amount = 15, dropChance = 0.8 }
            }
        })
        tutorialQuest2.isTutorial = true
        
        gameData.availableQuests = {tutorialQuest1, tutorialQuest2}
    else
        gameData.availableQuests = Quests.generatePool(5, maxRank, gameData)
    end

    -- Starter hero will be selected by player in hero selection screen
    -- (removed from here)

    -- Give player some starter materials for testing
    gameData.inventory.materials = {
        copper_ore = 5,
        leather_scrap = 5,
        rough_stone = 5
    }

    -- Give player a starter weapon to test equipment display
    gameData.inventory.equipment = {
        rusty_sword = 1
    }

    -- Preload hero sprites
    SpriteSystem.preloadAll()
    
    -- Preload UI assets
    local UIAssets = require("ui.ui_assets")
    UIAssets.preloadAll()

    -- Initialize settings menu
    SettingsMenu.init()

    -- Initialize milestone tracking
    MilestoneSystem.init(gameData)
    
    -- Initialize hero selection screen (generate 4 random heroes to choose from)
    HeroSelection.init(Heroes)
end

-- Update game (real-time)
function love.update(dt)
    -- Update mouse position
    mouseX, mouseY = love.mouse.getPosition()

    -- Update guild menu mouse position for tooltips
    GuildMenu.updateMouse(mouseX, mouseY)
    
    -- Hero selection screen update
    if currentState == STATE.HERO_SELECT then
        HeroSelection.update(dt)
        return  -- Skip game updates during hero selection
    end
    
    -- Tutorial welcome message is now shown after hero selection (removed from here)

    -- Update hero sprite animations
    SpriteSystem.updateAll(gameData.heroes, dt)
    -- Also update tavern pool animations
    if gameData.tavernPool then
        SpriteSystem.updateAll(gameData.tavernPool, dt)
    end

    -- Skip game updates when in Edit Mode
    if currentState == STATE.EDIT_MODE then
        EditMode.update(dt, mouseX, mouseY)
        return
    end

    -- Update time system
    local newDay = TimeSystem.update(gameData, dt)
    if newDay then
        love.window.setTitle("Guild Management - Day " .. gameData.day)
        addNotification("Day " .. gameData.day .. " begins!", "info")

        -- Reset daily S-rank quest limit
        gameData.sRankQuestsToday = 0

        -- Refresh tavern on new day (uses guild max rank and level)
        local maxRank = GuildSystem.getMaxTavernRank(gameData)
        local guildLevel = gameData.guild.level or 1
        gameData.tavernPool = Heroes.generateTavernPool(4, maxRank, guildLevel)
    end

    -- Update quest system (real-time quest progress)
    local questResults = QuestSystem.update(gameData, dt, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
    for _, result in ipairs(questResults) do
        if result.type == "return_complete" then
            -- Heroes have returned from quest - show notification
            addNotification(result.message, "info")
        elseif result.type == "rest_complete" then
            -- Hero finished resting
            addNotification(result.message, "info")
        end
        -- Note: Quest result popups now shown via GuildMenu when clicking awaiting_claim quests
    end

    -- Quest refresh timer (add new quests periodically)
    -- Skip during tutorial
    if not gameData.tutorial.active then
        questRefreshTimer = questRefreshTimer + dt
        if questRefreshTimer >= QUEST_REFRESH_INTERVAL then
            questRefreshTimer = 0
            if #gameData.availableQuests < 5 then
                local maxRank = GuildSystem.getMaxTavernRank(gameData)
                local newQuests = Quests.generatePool(1, maxRank, gameData)
                for _, q in ipairs(newQuests) do
                    table.insert(gameData.availableQuests, q)
                end
                if #newQuests > 0 then
                    addNotification("A new quest is available!", "info")
                end
            end
        end
    end

    -- Update notification timer
    if #notifications > 0 then
        notificationTimer = notificationTimer + dt
        if notificationTimer > 3 then
            table.remove(notifications, 1)
            notificationTimer = 0
        end
    end

    -- Update quest result modal animation
    QuestResultModal.update(dt)
end

-- Note: Max rank is now determined by GuildSystem.getMaxTavernRank() based on guild level

-- Draw game
function love.draw()
    -- Draw based on current state
    if currentState == STATE.HERO_SELECT then
        HeroSelection.draw()
    elseif currentState == STATE.TOWN then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
    elseif currentState == STATE.TAVERN then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        drawHeroAnimations()  -- Draw hero animations behind tavern menu
        TavernMenu.draw(gameData, Economy, GuildSystem)
    elseif currentState == STATE.GUILD then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        drawHeroAnimations()  -- Draw hero animations behind guild menu
        GuildMenu.draw(gameData, QuestSystem, Quests, Heroes, TimeSystem, GuildSystem, Equipment, EquipmentSystem)
    elseif currentState == STATE.ARMORY then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        drawHeroAnimations()  -- Draw hero animations behind armory menu
        ArmoryMenu.draw(gameData, Equipment, Materials, Recipes, EquipmentSystem, CraftingSystem, Economy, Heroes)
    elseif currentState == STATE.POTION then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        drawHeroAnimations()  -- Draw hero animations behind potion menu
        PotionMenu.draw(gameData, Items, Heroes, Economy)
    elseif currentState == STATE.SAVE_MENU then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        drawHeroAnimations()  -- Draw hero animations behind save menu
        SaveMenu.draw(gameData)
    elseif currentState == STATE.SETTINGS then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        drawHeroAnimations()  -- Draw hero animations behind settings menu
        SettingsMenu.draw(gameData)
    elseif currentState == STATE.EDIT_MODE then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        drawHeroAnimations()  -- Draw hero animations behind edit mode
        EditMode.draw(gameData, mouseX, mouseY)
    end

    -- Draw settings button on all town-based screens (except when settings is open or edit mode)
    if currentState ~= STATE.SETTINGS and currentState ~= STATE.EDIT_MODE then
        SettingsMenu.drawSettingsButton()
    end

    -- Draw quest result modal (on top of everything except notifications)
    if QuestResultModal.isOpen() then
        QuestResultModal.draw(Heroes)
    end

    -- Draw notifications
    drawNotifications()
end

-- Hero animation state
local heroAnims = {}
local heroAnimTime = 0
-- Pre-allocated table for removal indices (avoids allocation in update loop)
local animsToRemove = {}

-- Easing function for smooth acceleration/deceleration
-- Uses smoothstep (3t^2 - 2t^3) for smooth start and end
local function smoothEase(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

-- Draw heroes leaving/arriving
drawHeroAnimations = function()
    if #heroAnims == 0 then return end

    local dt = love.timer.getDelta()
    heroAnimTime = heroAnimTime + dt

    -- Clear reusable table
    for i = 1, #animsToRemove do animsToRemove[i] = nil end

    for i, anim in ipairs(heroAnims) do
        -- Update animation time
        anim.time = anim.time + dt
        
        -- Calculate progress (0 to 1)
        local progress = math.min(1, anim.time / anim.duration)
        
        -- Apply easing for smooth movement
        local easedProgress = smoothEase(progress)
        
        -- Calculate position based on eased progress
        anim.y = anim.startY + (anim.targetY - anim.startY) * easedProgress

        -- Check if animation is complete
        if progress >= 1 then
            table.insert(animsToRemove, i)
        end

        -- Calculate fade effect for departing heroes
        local alpha = 1
        if anim.type == "departing" then
            -- Fade out during last 30% of animation
            if progress > 0.7 then
                alpha = 1 - ((progress - 0.7) / 0.3)
            end
        elseif anim.type == "arriving" then
            -- Fade in during first 30% of animation
            if progress < 0.3 then
                alpha = progress / 0.3
            end
        end

        -- Draw the hero sprite using Walk animation
        if anim.hero and anim.hero.class then
            -- Load the walk sprite directly
            local spriteData = SpriteSystem.loadSprite(anim.hero.class, "Walk")
            if spriteData and spriteData.image and spriteData.quads then
                -- Calculate animation frame (8 FPS)
                local frameIndex = math.floor(heroAnimTime * 8) % spriteData.frameCount + 1

                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.draw(
                    spriteData.image,
                    spriteData.quads[frameIndex],
                    anim.x, anim.y,
                    0,  -- rotation
                    2.25, 2.25,  -- scale
                    spriteData.frameWidth / 2,
                    spriteData.frameHeight / 2
                )
            end
        end
    end

    -- Remove finished animations
    for i = #animsToRemove, 1, -1 do
        table.remove(heroAnims, animsToRemove[i])
    end
end

-- Add departing heroes (called from quest system via global lookup)
-- Heroes walk from guild hall toward bottom of screen with smooth easing
-- NOTE: This function is intentionally global as it's called from quest_system.lua
function addDepartingHeroes(heroes)
    local guildX = 640   -- Center of screen (guild position)
    local guildY = 280   -- Below the guild building
    local exitY = 800    -- Off screen at bottom
    local horizontalSpacing = 50  -- Space between heroes walking side by side
    local duration = 2.5  -- Animation duration in seconds (slower for smoother feel)

    -- Center the group horizontally
    local startX = guildX - (#heroes - 1) * horizontalSpacing / 2

    for i, hero in ipairs(heroes) do
        table.insert(heroAnims, {
            hero = hero,
            x = startX + (i - 1) * horizontalSpacing,
            y = guildY,
            startY = guildY,
            targetY = exitY,
            time = 0,
            duration = duration,
            type = "departing"
        })
    end
end

-- Add arriving heroes (called from quest system via global lookup)
-- Heroes walk from bottom of screen back to guild hall with smooth easing
-- NOTE: This function is intentionally global as it's called from quest_system.lua
function addArrivingHeroes(heroes)
    local guildX = 640   -- Center of screen (guild position)
    local guildY = 280   -- Below the guild building
    local exitY = 800    -- Off screen at bottom
    local horizontalSpacing = 50  -- Space between heroes walking side by side
    local duration = 2.5  -- Animation duration in seconds (slower for smoother feel)

    -- Center the group horizontally
    local startX = guildX - (#heroes - 1) * horizontalSpacing / 2

    for i, hero in ipairs(heroes) do
        table.insert(heroAnims, {
            hero = hero,
            x = startX + (i - 1) * horizontalSpacing,
            y = exitY,
            startY = exitY,
            targetY = guildY,
            time = 0,
            duration = duration,
            type = "arriving"
        })
    end
end

-- Draw notification messages (top-right corner)
drawNotifications = function()
    local screenW = love.graphics.getWidth()
    local notifWidth = 350
    local notifHeight = 32
    local notifX = screenW - notifWidth - 10  -- Right side with 10px margin
    local y = 50  -- Start from top (below header bar)

    for _, notif in ipairs(notifications) do
        local alpha = math.min(1, (3 - notificationTimer) * 2)
        love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], alpha * 0.9)

        -- Background (top-right)
        love.graphics.rectangle("fill", notifX, y, notifWidth, notifHeight, 5, 5)

        -- Border
        love.graphics.setColor(1, 1, 1, alpha * 0.3)
        love.graphics.rectangle("line", notifX, y, notifWidth, notifHeight, 5, 5)

        -- Text
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf(notif.message, notifX + 5, y + 8, notifWidth - 10, "center")

        y = y + notifHeight + 5  -- Stack downward
    end
end

-- Add a notification
addNotification = function(message, notifType)
    local color
    if notifType == "success" then
        color = {0.2, 0.5, 0.3}
    elseif notifType == "error" then
        color = {0.5, 0.2, 0.2}
    elseif notifType == "warning" then
        color = {0.5, 0.4, 0.2}
    elseif notifType == "milestone" then
        color = {0.6, 0.5, 0.2}  -- Gold color for milestones
    else
        color = {0.3, 0.3, 0.4}
    end

    table.insert(notifications, 1, {
        message = message,
        color = color
    })
    notificationTimer = 0

    -- Limit notifications
    while #notifications > 3 do
        table.remove(notifications)
    end
end

-- Handle mouse press
function love.mousepressed(x, y, button)
    -- Handle right-click for Edit Mode copy/paste
    if button == 2 and currentState == STATE.EDIT_MODE then
        local result, message = EditMode.handleRightClick(x, y, gameData)
        if result == "copied" then
            addNotification(message, "info")
        elseif result == true then
            -- Paste successful, refresh Town's view
            Town.setEditMode(true, EditMode.getWorldLayout())
            addNotification(message, "success")
        end
        return
    end

    if button ~= 1 then return end

    -- Hero selection screen handling
    if currentState == STATE.HERO_SELECT then
        local result = HeroSelection.handleClick(x, y)
        if result == "confirm" then
            -- Player confirmed their hero choice
            local selectedHero = HeroSelection.getSelectedHero()
            if selectedHero then
                selectedHero.status = "idle"
                table.insert(gameData.heroes, selectedHero)
                
                -- Transition to town (tutorial will show notifications)
                currentState = STATE.TOWN
                
                -- Show welcome notifications after a brief delay
                addNotification("Welcome, Guild Master! Complete 2 starter quests to earn gold.", "info")
            end
        end
        return
    end

    -- Quest result modal takes priority
    if QuestResultModal.isOpen() then
        QuestResultModal.handleClick(x, y)
        return
    end

    -- Check settings button click (on all screens except settings)
    if currentState ~= STATE.SETTINGS and SettingsMenu.isSettingsButtonClicked(x, y) then
        currentState = STATE.SETTINGS
        return
    end

    if currentState == STATE.TOWN then
        -- Check building clicks
        local buildingId = Town.getBuildingAt(x, y)
        if buildingId == "tavern" then
            currentState = STATE.TAVERN
        elseif buildingId == "guild" then
            currentState = STATE.GUILD
        elseif buildingId == "armory" then
            currentState = STATE.ARMORY
        elseif buildingId == "potion" then
            currentState = STATE.POTION
        -- Archives building no longer opens save menu (use Settings instead)
        end

    elseif currentState == STATE.TAVERN then
        local result, message = TavernMenu.handleClick(x, y, gameData, Heroes, Economy, GuildSystem)
        if result == "close" then
            currentState = STATE.TOWN
        elseif result == "hired" then
            addNotification(message, "success")
            -- Check milestones after hiring
            local newMilestones = MilestoneSystem.checkMilestones(gameData)
            for _, milestone in ipairs(newMilestones) do
                local rewardText = milestone.reward and milestone.reward.gold and (" +" .. milestone.reward.gold .. "g") or ""
                addNotification("Milestone: " .. milestone.name .. rewardText, "milestone")
            end
        elseif result == "refreshed" then
            addNotification(message, "info")
        elseif result == "error" then
            addNotification(message, "error")
        end

    elseif currentState == STATE.GUILD then
        local result, message = GuildMenu.handleClick(x, y, gameData, QuestSystem, Quests, Heroes, GuildSystem)
        if result == "close" then
            currentState = STATE.TOWN
            GuildMenu.resetState()
        elseif result == "assigned" then
            addNotification(message, "success")
        elseif result == "equip_changed" then
            addNotification(message, "success")
        elseif result == "fired" then
            addNotification(message, "info")
        elseif result == "execute_quest" then
            -- Player clicked "Execute Quest" button - run combat/narrative and show log
            local quest = message
            local execResult, heroList = QuestSystem.executeQuest(quest, gameData, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
            if execResult then
                -- Build and show combat log / narrative modal immediately
                local modalResult = {
                    quest = quest,
                    success = execResult.success,
                    goldReward = 0,  -- Rewards shown after return
                    xpReward = 0,
                    message = execResult.message,
                    materialDrops = {},
                    heroOutcomes = {},
                    combatLog = execResult.combatLog,
                    combatSummary = execResult.combatSummary,
                    narrative = execResult.narrative,
                    -- Special flag to show this is execution phase (not final result)
                    isExecutionResult = true,
                    _logScrollOffset = 0
                }

                -- Build hero outcomes for display
                for _, hero in ipairs(heroList) do
                    local outcome = {
                        hero = hero,
                        injury = nil,
                        restTime = 0,
                        leveledUp = false,
                        died = false
                    }
                    -- Check for death in combat
                    for _, deadHero in ipairs(execResult.heroDeaths or {}) do
                        if deadHero.id == hero.id then
                            outcome.died = true
                            break
                        end
                    end
                    table.insert(modalResult.heroOutcomes, outcome)
                end

                QuestResultModal.push(modalResult)
                addNotification(quest.name .. ": " .. (execResult.success and "Victory!" or "Defeat!"), execResult.success and "success" or "warning")
            end

        elseif result == "start_return" then
            -- Player clicked "Return" - start heroes returning and process rewards
            local quest = message
            local returnResult = QuestSystem.startReturn(quest, gameData, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
            if returnResult then
                addNotification(quest.name .. ": Heroes returning...", "info")

                -- Track milestone progress
                local heroList = QuestSystem.getQuestHeroes(quest, gameData)
                MilestoneSystem.onQuestComplete(gameData, quest, returnResult.success, heroList, returnResult.deadHeroes)
                local newMilestones = MilestoneSystem.checkMilestones(gameData)
                for _, milestone in ipairs(newMilestones) do
                    local rewardText = milestone.reward and milestone.reward.gold and (" +" .. milestone.reward.gold .. "g") or ""
                    addNotification("Milestone: " .. milestone.name .. rewardText, "milestone")
                end
            end

        elseif result == "claim_quest" then
            -- DEPRECATED: Old flow - keeping for backwards compatibility
            -- message is actually the quest object
            local quest = message
            local claimResult = QuestSystem.claimQuest(quest, gameData, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
            if claimResult then
                -- Build hero list from quest
                local heroList = QuestSystem.getQuestHeroes(quest, gameData)

                -- Build and push modal result
                local modalResult = QuestResultModal.buildResult(
                    claimResult.quest,
                    claimResult,
                    heroList,
                    claimResult.materialDrops,
                    {guildXP = claimResult.guildXP, guildLevelUp = claimResult.guildLevelUp},
                    Heroes
                )
                QuestResultModal.push(modalResult)

                -- Show toast notification
                local msgType = claimResult.success and "success" or "warning"
                addNotification(quest.name .. ": " .. (claimResult.success and "Complete!" or "Failed!"), msgType)

                -- Track tutorial progress
                if gameData.tutorial.active and quest.isTutorial and claimResult.success then
                    gameData.tutorial.questsCompleted = gameData.tutorial.questsCompleted + 1
                    
                    if gameData.tutorial.questsCompleted >= gameData.tutorial.questsRequired then
                        -- Tutorial complete! Enable full game
                        gameData.tutorial.active = false
                        addNotification("Tutorial Complete! The guild is now open for business!", "success")
                        
                        -- Refresh quest pool with normal quests
                        local maxRank = GuildSystem.getMaxTavernRank(gameData)
                        gameData.availableQuests = Quests.generatePool(5, maxRank, gameData)
                    else
                        local remaining = gameData.tutorial.questsRequired - gameData.tutorial.questsCompleted
                        addNotification("Tutorial: Complete " .. remaining .. " more quest" .. (remaining > 1 and "s" or "") .. " to unlock the guild!", "info")
                    end
                end
                
                -- Track milestone progress
                MilestoneSystem.onQuestComplete(gameData, quest, claimResult.success, heroList, claimResult.deadHeroes)
                local newMilestones = MilestoneSystem.checkMilestones(gameData)
                for _, milestone in ipairs(newMilestones) do
                    local rewardText = milestone.reward and milestone.reward.gold and (" +" .. milestone.reward.gold .. "g") or ""
                    addNotification("Milestone: " .. milestone.name .. rewardText, "milestone")
                end

                -- Faction tier change notification
                if claimResult.tierChanged then
                    local factionName = GuildSystem.factions[claimResult.tierChanged.faction].name
                    addNotification("Now " .. claimResult.tierChanged.tier.name .. " with " .. factionName, "info")
                end
            end
        elseif result == "error" then
            addNotification(message, "error")
        end

    elseif currentState == STATE.ARMORY then
        local result, message = ArmoryMenu.handleClick(x, y, gameData, Equipment, Materials, Recipes, EquipmentSystem, CraftingSystem, Economy, Heroes)
        if result == "close" then
            currentState = STATE.TOWN
            ArmoryMenu.resetState()
        elseif result == "purchased" or result == "crafted" or result == "equipped" then
            addNotification(message, "success")
        elseif result == "error" then
            addNotification(message, "error")
        end

    elseif currentState == STATE.POTION then
        local result, message = PotionMenu.handleClick(x, y, gameData, Items, Heroes, Economy)
        if result == "close" then
            currentState = STATE.TOWN
            PotionMenu.resetState()
        elseif result == "purchased" then
            addNotification(message, "success")
        elseif result == "error" then
            addNotification(message, "error")
        end

    elseif currentState == STATE.SAVE_MENU then
        local result, message = SaveMenu.handleClick(x, y, gameData, Heroes, Quests, GuildSystem, TimeSystem)
        if result == "close" then
            currentState = STATE.TOWN
            SaveMenu.resetState()
        elseif result == "saved" then
            addNotification(message, "success")
        elseif result == "loaded" then
            addNotification(message, "success")
        elseif result == "deleted" then
            addNotification(message, "info")
        elseif result == "error" then
            addNotification(message, "error")
        end

    elseif currentState == STATE.SETTINGS then
        local result, message = SettingsMenu.handleClick(x, y, gameData, Heroes, Quests, GuildSystem, TimeSystem)
        if result == "close" then
            currentState = STATE.TOWN
            SettingsMenu.resetState()
        elseif result == "saved" then
            addNotification(message or "Game saved!", "success")
        elseif result == "loaded" then
            addNotification(message or "Game loaded!", "success")
        elseif result == "resolution_changed" then
            addNotification("Resolution changed to " .. (message or ""), "info")
        elseif result == "fullscreen_toggled" then
            addNotification("Fullscreen toggled", "info")
        elseif result == "edit_mode_toggled" then
            local enabled = message
            if enabled then
                addNotification("Edit Mode enabled. Press F2 in town to enter.", "info")
            else
                addNotification("Edit Mode disabled", "info")
            end
        elseif result == "error" then
            addNotification(message, "error")
        end

    elseif currentState == STATE.EDIT_MODE then
        local result, message = EditMode.handleMousePressed(x, y, gameData)
        if result == "exit" then
            currentState = STATE.TOWN
            -- Exit edit mode and reload from JSON
            Town.setEditMode(false, nil)
            Town.loadWorldLayout()
            addNotification("Edit Mode closed", "info")
        elseif result == "saved" then
            -- Refresh Town's view from EditMode's current world layout
            Town.setEditMode(true, EditMode.getWorldLayout())
            addNotification(message or "World layout saved!", "success")
        elseif result == "error" then
            addNotification(message, "error")
        end
    end
end

-- Handle mouse release (for Edit Mode drag-and-drop)
function love.mousereleased(x, y, button)
    if button ~= 1 then return end

    if currentState == STATE.EDIT_MODE then
        EditMode.handleMouseReleased(x, y, gameData)
    end
end

-- Handle key press
function love.keypressed(key)
    -- Don't handle keys if modal is open
    if QuestResultModal.isOpen() then
        return
    end

    -- Handle Edit Mode keys first
    if currentState == STATE.EDIT_MODE then
        local handled, result, msg = EditMode.handleKeyPressed(key)
        if handled then
            if result == "saved" then
                addNotification(msg or "Saved!", "success")
            end
            return
        end
    end

    if key == "escape" then
        if currentState == STATE.EDIT_MODE then
            currentState = STATE.TOWN
            Town.setEditMode(false, nil)
            Town.loadWorldLayout()
            addNotification("Edit Mode closed", "info")
        elseif currentState == STATE.TOWN then
            currentState = STATE.SETTINGS
        else
            currentState = STATE.TOWN
            GuildMenu.resetState()
            PotionMenu.resetState()
            ArmoryMenu.resetState()
            SaveMenu.resetState()
            SettingsMenu.resetState()
        end

    -- F5: Quick save to slot 1
    elseif key == "f5" then
        local success, msg = SaveMenu.quickSave(gameData)
        if success then
            addNotification("Game saved!", "success")
        else
            addNotification("Save failed: " .. msg, "error")
        end

    -- F6: Hot reload UI modules
    elseif key == "f6" then
        local reloaded = {}
        local failed = {}

        -- List of modules to reload
        local modules = {
            {"ui/guild_menu", function(m) GuildMenu = m end},
            {"ui/tavern_menu", function(m) TavernMenu = m end},
            {"ui/potion_menu", function(m) PotionMenu = m end},
            {"ui/armory_menu", function(m) ArmoryMenu = m end},
            {"ui/settings_menu", function(m) SettingsMenu = m end},
            {"ui/town", function(m) Town = m; Town.loadSprites() end},
            {"ui/components", function(m) Components = m end},
            {"ui/edit_mode", function(m) EditMode = m end},
        }

        for _, mod in ipairs(modules) do
            local name, setter = mod[1], mod[2]
            package.loaded[name] = nil
            local success, result = pcall(require, name)
            if success then
                setter(result)
                table.insert(reloaded, name:match("([^/]+)$"))
            else
                table.insert(failed, name:match("([^/]+)$") .. ": " .. tostring(result):sub(1, 50))
            end
        end

        if #failed == 0 then
            addNotification("Reloaded: " .. table.concat(reloaded, ", "), "success")
        else
            addNotification("Reload failed: " .. table.concat(failed, "; "), "error")
        end
        print("[Hot Reload] Reloaded:", table.concat(reloaded, ", "))
        if #failed > 0 then
            print("[Hot Reload] Failed:", table.concat(failed, "; "))
        end

    -- F9: Quick load from slot 1
    elseif key == "f9" then
        local success, msg = SaveMenu.quickLoad(gameData, Heroes, Quests, GuildSystem, TimeSystem)
        if success then
            addNotification("Game loaded!", "success")
        else
            addNotification("Load failed: " .. msg, "error")
        end

    -- F2: Toggle Edit Mode (if enabled in settings)
    elseif key == "f2" then
        if SettingsMenu.isEditModeEnabled() then
            if currentState == STATE.TOWN then
                currentState = STATE.EDIT_MODE
                EditMode.init(gameData)
                -- Tell Town to use EditMode's world layout
                Town.setEditMode(true, EditMode.getWorldLayout())
                addNotification("Edit Mode active", "info")
            elseif currentState == STATE.EDIT_MODE then
                currentState = STATE.TOWN
                -- Exit edit mode and reload from JSON
                Town.setEditMode(false, nil)
                Town.loadWorldLayout()
                addNotification("Edit Mode closed", "info")
            end
        end

    -- Debug: Speed up time
    elseif key == "=" or key == "+" then
        local currentScale = TimeSystem.config.timeScale
        TimeSystem.setTimeScale(math.min(currentScale * 2, 16))
        addNotification("Time speed: " .. TimeSystem.config.timeScale .. "x", "info")
    elseif key == "-" then
        local currentScale = TimeSystem.config.timeScale
        TimeSystem.setTimeScale(math.max(currentScale / 2, 0.5))
        addNotification("Time speed: " .. TimeSystem.config.timeScale .. "x", "info")
    end
end

-- Mouse wheel handler for scrolling
function love.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()

    -- Handle scroll in quest result modal (battle log)
    if QuestResultModal.isOpen() then
        QuestResultModal.handleScroll(y)
        return
    end

    -- Handle scroll in Edit Mode
    if currentState == STATE.EDIT_MODE then
        EditMode.handleWheelMoved(x, y, mx, my)
        return
    end

    -- Handle scroll in guild menu
    if currentState == STATE.GUILD then
        GuildMenu.handleScroll(mx, my, y)
    end
end
