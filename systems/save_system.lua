-- Save System Module
-- Handles saving and loading game state

local json = require("utils.json")

local SaveSystem = {}

-- Deep copy helper to avoid shared table references
local function deepCopy(obj)
    if type(obj) ~= "table" then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-- Save file configuration
SaveSystem.SAVE_SLOTS = 3
SaveSystem.SAVE_PREFIX = "save_slot_"
SaveSystem.SAVE_EXT = ".json"

-- Get save file path for a slot
function SaveSystem.getSavePath(slot)
    return SaveSystem.SAVE_PREFIX .. slot .. SaveSystem.SAVE_EXT
end

-- Check if a save slot exists
function SaveSystem.saveExists(slot)
    local path = SaveSystem.getSavePath(slot)
    return love.filesystem.getInfo(path) ~= nil
end

-- Get save slot info (for display in menu)
function SaveSystem.getSaveInfo(slot)
    if not SaveSystem.saveExists(slot) then
        return nil
    end

    local path = SaveSystem.getSavePath(slot)
    local info = love.filesystem.getInfo(path)

    -- Load save to get metadata (with pcall protection for corrupted files)
    local success, data, err = pcall(function()
        return json.loadFile(path)
    end)

    if not success then
        return {
            slot = slot,
            exists = true,
            corrupted = true,
            error = tostring(data)  -- data contains error message on pcall failure
        }
    end

    if not data then
        return {
            slot = slot,
            exists = true,
            corrupted = true,
            error = err or "Unknown error"
        }
    end

    return {
        slot = slot,
        exists = true,
        corrupted = false,
        day = data.day or 1,
        gold = data.gold or 0,
        heroCount = data.heroes and #data.heroes or 0,
        guildLevel = data.guild and data.guild.level or 1,
        timestamp = info.modtime,
        totalTime = data.totalTime or 0
    }
end

-- Get all save slot info
function SaveSystem.getAllSaveInfo()
    local saves = {}
    for slot = 1, SaveSystem.SAVE_SLOTS do
        saves[slot] = SaveSystem.getSaveInfo(slot)
    end
    return saves
end

-- Prepare game data for saving (remove non-serializable data)
local function prepareDataForSave(gameData)
    local saveData = {
        -- Core progress
        day = gameData.day,
        dayProgress = gameData.dayProgress,
        totalTime = gameData.totalTime,
        gold = gameData.gold,
        sRankQuestsToday = gameData.sRankQuestsToday or 0,

        -- Guild data
        guild = gameData.guild,

        -- Inventory
        inventory = gameData.inventory,

        -- Graveyard
        graveyard = {},

        -- Heroes (serialized)
        heroes = {}
    }

    -- Serialize heroes (only save persistent data)
    for _, hero in ipairs(gameData.heroes) do
        local savedHero = {
            id = hero.id,
            name = hero.name,
            race = hero.race,
            class = hero.class,
            rank = hero.rank,
            level = hero.level,
            xp = hero.xp,
            xpToLevel = hero.xpToLevel,
            stats = deepCopy(hero.stats),
            status = "idle",  -- Reset to idle on load
            hireCost = hero.hireCost,
            isAwakened = hero.isAwakened,
            failureCount = hero.failureCount or 0,
            injuryState = deepCopy(hero.injuryState),
            equipment = deepCopy(hero.equipment),
            dungeonsCleared = hero.dungeonsCleared or 0,
            partyId = hero.partyId,
            -- Quest-related fields reset on load
            currentQuestId = nil,
            questPhase = nil,
            questProgress = 0,
            questPhaseMax = 0,
            restProgress = 0,
            restTimeMax = 0,
            restSpeedBonus = 1
        }
        table.insert(saveData.heroes, savedHero)
    end

    -- Serialize parties (deep copy to avoid shared references)
    saveData.parties = deepCopy(gameData.parties) or {}
    saveData.protoParties = deepCopy(gameData.protoParties) or {}

    -- Serialize graveyard
    for _, hero in ipairs(gameData.graveyard) do
        table.insert(saveData.graveyard, {
            id = hero.id,
            name = hero.name,
            race = hero.race,
            class = hero.class,
            rank = hero.rank,
            level = hero.level,
            deathQuest = hero.deathQuest,
            deathDay = hero.deathDay
        })
    end

    -- Save version for future compatibility
    saveData._version = 1
    saveData._savedAt = os.time()

    return saveData
end

-- Save game to a slot
function SaveSystem.save(gameData, slot)
    if slot < 1 or slot > SaveSystem.SAVE_SLOTS then
        return false, "Invalid save slot"
    end

    local path = SaveSystem.getSavePath(slot)
    local saveData = prepareDataForSave(gameData)

    local success, err = json.saveFile(path, saveData, true)  -- Pretty print for debugging
    if not success then
        return false, "Failed to save: " .. (err or "unknown error")
    end

    return true, "Game saved to slot " .. slot
end

-- Load game from a slot
function SaveSystem.load(slot)
    if slot < 1 or slot > SaveSystem.SAVE_SLOTS then
        return nil, "Invalid save slot"
    end

    if not SaveSystem.saveExists(slot) then
        return nil, "No save in slot " .. slot
    end

    local path = SaveSystem.getSavePath(slot)

    -- Use pcall to safely load JSON (handles corrupted files)
    local success, data, err = pcall(function()
        return json.loadFile(path)
    end)

    if not success then
        return nil, "Failed to load save: " .. tostring(data)
    end

    if not data then
        return nil, "Failed to load save: " .. (err or "unknown error")
    end

    return data, nil
end

-- Apply loaded data to game state
function SaveSystem.applyLoadedData(gameData, loadedData, Heroes, Quests, GuildSystem, TimeSystem)
    -- Core progress
    gameData.day = loadedData.day or 1
    gameData.dayProgress = loadedData.dayProgress or 0
    gameData.totalTime = loadedData.totalTime or 0
    gameData.gold = loadedData.gold or 200
    gameData.sRankQuestsToday = loadedData.sRankQuestsToday or 0

    -- Guild data
    if loadedData.guild then
        gameData.guild = loadedData.guild
    end

    -- Inventory
    if loadedData.inventory then
        gameData.inventory = loadedData.inventory
    end

    -- Heroes
    gameData.heroes = {}
    if loadedData.heroes then
        for _, heroData in ipairs(loadedData.heroes) do
            -- Restore hero with all saved fields
            local hero = {
                id = heroData.id,
                name = heroData.name,
                race = heroData.race,
                class = heroData.class,
                rank = heroData.rank,
                level = heroData.level,
                xp = heroData.xp,
                xpToLevel = heroData.xpToLevel,
                stats = deepCopy(heroData.stats),
                status = "idle",
                hireCost = heroData.hireCost,
                isAwakened = heroData.isAwakened,
                failureCount = heroData.failureCount or 0,
                injuryState = deepCopy(heroData.injuryState),
                equipment = deepCopy(heroData.equipment) or {weapon = nil, armor = nil, accessory = nil, mount = nil},
                dungeonsCleared = heroData.dungeonsCleared or 0,
                partyId = heroData.partyId,
                currentQuestId = nil,
                questPhase = nil,
                questProgress = 0,
                questPhaseMax = 0,
                restProgress = 0,
                restTimeMax = 0,
                restSpeedBonus = 1
            }
            table.insert(gameData.heroes, hero)
        end
    end

    -- Parties and proto-parties (deep copy to avoid shared references)
    gameData.parties = deepCopy(loadedData.parties) or {}
    gameData.protoParties = deepCopy(loadedData.protoParties) or {}

    -- Restore party system next ID
    local PartySystem = require("systems.party_system")
    local maxPartyId = 0
    for _, party in ipairs(gameData.parties) do
        if party.id > maxPartyId then maxPartyId = party.id end
    end
    for _, party in ipairs(gameData.protoParties) do
        if party.id > maxPartyId then maxPartyId = party.id end
    end
    PartySystem.setNextId(maxPartyId + 1)

    -- Restore hero system next ID to prevent ID collisions with new heroes
    local maxHeroId = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.id > maxHeroId then maxHeroId = hero.id end
    end
    for _, hero in ipairs(gameData.graveyard or {}) do
        if hero.id and hero.id > maxHeroId then maxHeroId = hero.id end
    end
    Heroes.setNextId(maxHeroId + 1)

    -- Graveyard
    gameData.graveyard = loadedData.graveyard or {}

    -- Clear active quests (they don't persist)
    gameData.activeQuests = {}

    -- Regenerate available quests and tavern pool
    local maxRank = GuildSystem and GuildSystem.getMaxTavernRank(gameData) or "B"
    gameData.availableQuests = Quests.generatePool(3, maxRank)
    gameData.tavernPool = Heroes.generateTavernPool(4, maxRank, gameData.guild and gameData.guild.level or 1)

    return true
end

-- Delete a save slot
function SaveSystem.deleteSave(slot)
    if slot < 1 or slot > SaveSystem.SAVE_SLOTS then
        return false, "Invalid save slot"
    end

    if not SaveSystem.saveExists(slot) then
        return false, "No save in slot " .. slot
    end

    local path = SaveSystem.getSavePath(slot)
    local success = love.filesystem.remove(path)

    if success then
        return true, "Save deleted"
    else
        return false, "Failed to delete save"
    end
end

-- Format timestamp for display
function SaveSystem.formatTimestamp(timestamp)
    if not timestamp then return "Unknown" end
    return os.date("%Y-%m-%d %H:%M", timestamp)
end

-- Format play time for display
function SaveSystem.formatPlayTime(totalTime)
    if not totalTime then return "0:00" end
    local hours = math.floor(totalTime / 3600)
    local minutes = math.floor((totalTime % 3600) / 60)
    return string.format("%d:%02d", hours, minutes)
end

return SaveSystem
