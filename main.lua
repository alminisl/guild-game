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

-- Game States
local STATE = {
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
    gold = 200,
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
    protoParties = {}      -- Proto-parties (forming, not yet official)
}

-- Current game state
local currentState = STATE.TOWN

-- Notification system
local notifications = {}
local notificationTimer = 0

-- Mouse position for hover effects
local mouseX, mouseY = 0, 0

-- Quest refresh timer (new quests appear periodically)
local questRefreshTimer = 0
local QUEST_REFRESH_INTERVAL = 60  -- New quest every 60 seconds

-- Initialize game
function love.load()
    love.window.setTitle("Guild Management - Day 1")
    love.window.setMode(1920, 1080, {resizable = true, minwidth = 1280, minheight = 720})
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    -- Seed random
    math.randomseed(os.time())

    -- Initialize guild progression
    gameData.guild = GuildSystem.initializeData()

    -- Initialize tavern pool (uses guild max rank and level)
    local maxRank = GuildSystem.getMaxTavernRank(gameData)
    local guildLevel = gameData.guild.level or 1
    gameData.tavernPool = Heroes.generateTavernPool(4, maxRank, guildLevel)

    -- Initialize available quests
    gameData.availableQuests = Quests.generatePool(5, maxRank)

    -- Give player one starter hero (Human Knight)
    local starterHero = Heroes.generate({rank = "D", name = "Recruit Marcus", race = "Human", class = "Knight"})
    starterHero.status = "idle"
    table.insert(gameData.heroes, starterHero)

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

    -- Initialize settings menu
    SettingsMenu.init()
end

-- Update game (real-time)
function love.update(dt)
    -- Update mouse position
    mouseX, mouseY = love.mouse.getPosition()

    -- Update guild menu mouse position for tooltips
    GuildMenu.updateMouse(mouseX, mouseY)

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

        -- Refresh tavern on new day (uses guild max rank and level)
        local maxRank = GuildSystem.getMaxTavernRank(gameData)
        local guildLevel = gameData.guild.level or 1
        gameData.tavernPool = Heroes.generateTavernPool(4, maxRank, guildLevel)
    end

    -- Update quest system (real-time quest progress)
    local questResults = QuestSystem.update(gameData, dt, Heroes, Quests, Economy, GuildSystem, Materials, EquipmentSystem)
    for _, result in ipairs(questResults) do
        if result.quest then
            -- Quest completed - show modal with detailed results
            -- Build hero list from quest
            local heroList = {}
            for _, heroId in ipairs(result.quest.assignedHeroes or {}) do
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId then
                        table.insert(heroList, hero)
                        break
                    end
                end
            end

            -- Also check graveyard for fallen heroes
            for _, hero in ipairs(gameData.graveyard) do
                for _, heroId in ipairs(result.quest.assignedHeroes or {}) do
                    if hero.id == heroId then
                        table.insert(heroList, hero)
                        break
                    end
                end
            end

            -- Build and push modal result
            local modalResult = QuestResultModal.buildResult(
                result.quest,
                result,
                heroList,
                result.materialDrops,
                {guildXP = result.guildXP, guildLevelUp = result.guildLevelUp},
                Heroes
            )
            QuestResultModal.push(modalResult)

            -- Still show toast for quick info
            local msgType = result.success and "success" or "warning"
            addNotification(result.quest.name .. ": " .. (result.success and "Complete!" or "Failed!"), msgType)

            -- Faction tier change notification (keep as toast since it's separate info)
            if result.tierChanged then
                local factionName = GuildSystem.factions[result.tierChanged.faction].name
                addNotification("Now " .. result.tierChanged.tier.name .. " with " .. factionName, "info")
            end
        elseif result.type == "rest_complete" then
            -- Hero finished resting
            addNotification(result.message, "info")
        end
    end

    -- Quest refresh timer (add new quests periodically)
    questRefreshTimer = questRefreshTimer + dt
    if questRefreshTimer >= QUEST_REFRESH_INTERVAL then
        questRefreshTimer = 0
        if #gameData.availableQuests < 5 then
            local maxRank = GuildSystem.getMaxTavernRank(gameData)
            local newQuests = Quests.generatePool(1, maxRank)
            for _, q in ipairs(newQuests) do
                table.insert(gameData.availableQuests, q)
            end
            addNotification("A new quest is available!", "info")
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
end

-- Get max rank based on day
function getMaxRankForDay(day)
    if day >= 25 then return "S"
    elseif day >= 15 then return "A"
    elseif day >= 7 then return "B"
    else return "C"
    end
end

-- Draw game
function love.draw()
    -- Draw based on current state
    if currentState == STATE.TOWN then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
    elseif currentState == STATE.TAVERN then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        TavernMenu.draw(gameData, Economy, GuildSystem)
    elseif currentState == STATE.GUILD then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        GuildMenu.draw(gameData, QuestSystem, Quests, Heroes, TimeSystem, GuildSystem, Equipment, EquipmentSystem)
    elseif currentState == STATE.ARMORY then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        ArmoryMenu.draw(gameData, Equipment, Materials, Recipes, EquipmentSystem, CraftingSystem, Economy, Heroes)
    elseif currentState == STATE.POTION then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        PotionMenu.draw(gameData, Items, Heroes, Economy)
    elseif currentState == STATE.SAVE_MENU then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        SaveMenu.draw(gameData)
    elseif currentState == STATE.SETTINGS then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        SettingsMenu.draw(gameData)
    elseif currentState == STATE.EDIT_MODE then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
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

    -- Draw hero departure/arrival animations (on top of menus)
    drawHeroAnimations()

    -- Draw notifications
    drawNotifications()
end

-- Hero animation state
local heroAnims = {}
local heroAnimTime = 0

-- Draw heroes leaving/arriving
function drawHeroAnimations()
    local dt = love.timer.getDelta()
    heroAnimTime = heroAnimTime + dt
    local toRemove = {}

    for i, anim in ipairs(heroAnims) do
        -- Update position
        anim.y = anim.y + anim.speedY * dt

        -- Check if done
        if anim.type == "departing" and anim.y > 800 then
            table.insert(toRemove, i)
        elseif anim.type == "arriving" and anim.y < anim.targetY then
            table.insert(toRemove, i)
        end

        -- Draw the hero sprite using Walk animation
        if anim.hero and anim.hero.class then
            -- Load the walk sprite directly
            local spriteData = SpriteSystem.loadSprite(anim.hero.class, "Walk")
            if spriteData and spriteData.image and spriteData.quads then
                -- Calculate animation frame (8 FPS)
                local frameIndex = math.floor(heroAnimTime * 8) % spriteData.frameCount + 1

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    spriteData.image,
                    spriteData.quads[frameIndex],
                    anim.x, anim.y,
                    0,  -- rotation
                    2.25, 2.25,  -- scale (50% larger than before)
                    spriteData.frameWidth / 2,
                    spriteData.frameHeight / 2
                )
            end
        end
    end

    -- Remove finished animations
    for i = #toRemove, 1, -1 do
        table.remove(heroAnims, toRemove[i])
    end
end

-- Add departing heroes (called from quest system)
-- Heroes walk in single file line from guild down
function addDepartingHeroes(heroes)
    local startX = 640  -- Center of screen (guild position)
    local verticalSpacing = 60  -- Space between heroes in the line

    for i, hero in ipairs(heroes) do
        table.insert(heroAnims, {
            hero = hero,
            x = startX,
            y = 150 - (i - 1) * verticalSpacing,  -- Staggered start (leader first)
            speedY = 180,
            type = "departing"
        })
    end
end

-- Add arriving heroes (called from quest system)
-- Heroes walk in single file line back to guild
function addArrivingHeroes(heroes)
    local startX = 640  -- Center of screen (guild position)
    local verticalSpacing = 60  -- Space between heroes in the line

    for i, hero in ipairs(heroes) do
        table.insert(heroAnims, {
            hero = hero,
            x = startX,
            y = 800 + (i - 1) * verticalSpacing,  -- Staggered start (leader first)
            targetY = 150,
            speedY = -180,
            type = "arriving"
        })
    end
end

-- Draw notification messages (top-right corner)
function drawNotifications()
    local notifWidth = 350
    local notifHeight = 32
    local notifX = 1280 - notifWidth - 10  -- Right side with 10px margin
    local y = 50  -- Start from top (below header bar)

    for i, notif in ipairs(notifications) do
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
function addNotification(message, notifType)
    local color
    if notifType == "success" then
        color = {0.2, 0.5, 0.3}
    elseif notifType == "error" then
        color = {0.5, 0.2, 0.2}
    elseif notifType == "warning" then
        color = {0.5, 0.4, 0.2}
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
    if button ~= 1 then return end

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
            addNotification("Edit Mode closed", "info")
        elseif result == "saved" then
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

    if key == "escape" then
        if currentState ~= STATE.TOWN then
            currentState = STATE.TOWN
            GuildMenu.resetState()
            PotionMenu.resetState()
            ArmoryMenu.resetState()
            SaveMenu.resetState()
            SettingsMenu.resetState()
        else
            love.event.quit()
        end

    -- F5: Quick save to slot 1
    elseif key == "f5" then
        local success, msg = SaveMenu.quickSave(gameData)
        if success then
            addNotification("Game saved!", "success")
        else
            addNotification("Save failed: " .. msg, "error")
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
                addNotification("Edit Mode active", "info")
            elseif currentState == STATE.EDIT_MODE then
                currentState = STATE.TOWN
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

    -- Handle scroll in guild menu
    if currentState == STATE.GUILD then
        GuildMenu.handleScroll(mx, my, y)
    end
end
