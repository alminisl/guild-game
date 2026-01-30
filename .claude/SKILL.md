---
name: love2d-guild-game-patterns
description: Coding patterns for Love2D Guild Management Game development
version: 1.0.0
source: local-git-analysis
analyzed_commits: 9
project_type: Love2D Game (Lua)
---

# Love2D Guild Management Game Patterns

This skill defines the coding patterns, architecture, and conventions for the Guild Management Game built with Love2D and Lua.

## Project Overview

A real-time guild management game where players hire heroes, equip them, and send them on quests. Features include:
- Hero recruitment with races, classes, and stats
- Quest system with travel/execute/return phases
- Equipment and crafting systems
- Party formation with synergy bonuses
- Save/load system with JSON persistence
- Faction reputation system

## Code Architecture

```
LovePrototype/
├── main.lua                 # Game entry point, state machine, callbacks
├── conf.lua                 # Love2D window configuration
├── data/                    # Data definitions (JSON + Lua wrappers)
│   ├── heroes.lua           # Hero generation, classes, races
│   ├── heroes.json          # Hero data (classes, races, names)
│   ├── quests.lua           # Quest generation and resolution
│   ├── quests.json          # Quest templates and configurations
│   ├── equipment.lua        # Equipment definitions
│   ├── items.lua            # Consumable items
│   ├── materials.lua        # Crafting materials
│   ├── recipes.lua          # Crafting recipes
│   └── synergies.json       # Party synergy configurations
├── systems/                 # Core game systems
│   ├── quest_system.lua     # Quest assignment, phases, resolution
│   ├── save_system.lua      # Save/load with JSON
│   ├── time_system.lua      # Day/night cycle, time progression
│   ├── economy.lua          # Gold transactions
│   ├── guild_system.lua     # Guild progression, reputation
│   ├── equipment_system.lua # Equipping items, stat bonuses
│   ├── crafting_system.lua  # Item crafting
│   ├── party_system.lua     # Party formation, synergies
│   └── sprite_system.lua    # Hero sprite animations
├── ui/                      # UI modules (one per screen/menu)
│   ├── components.lua       # Reusable UI components
│   ├── town.lua             # Town map view
│   ├── guild_menu.lua       # Hero roster and quest assignment
│   ├── tavern_menu.lua      # Hero recruitment
│   ├── armory_menu.lua      # Equipment and crafting
│   ├── potion_menu.lua      # Consumables shop
│   ├── settings_menu.lua    # Game settings
│   ├── save_menu.lua        # Save/load slots
│   ├── edit_mode.lua        # World layout editor
│   ├── quest_result_modal.lua # Quest completion popup
│   └── town_map.lua         # Town navigation
└── utils/                   # Utility modules
    ├── json.lua             # JSON encoding/decoding
    └── logger.lua           # Debug logging
```

## Module Pattern

All modules follow this pattern:

```lua
-- Module Name
-- Brief description of what this module does

local DependencyModule = require("path.to.dependency")

local ModuleName = {}

-- Constants (SCREAMING_SNAKE_CASE)
local MAX_VALUE = 100
local DEFAULT_CONFIG = {key = "value"}

-- Private functions (local, not in module table)
local function privateHelper(arg)
    return arg * 2
end

-- Public functions (in module table)
function ModuleName.publicFunction(arg1, arg2)
    -- Implementation
    return result
end

-- Initialization function (if needed)
function ModuleName.init(gameData)
    -- Setup code
end

return ModuleName
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Modules | PascalCase | `QuestSystem`, `GuildMenu` |
| Functions | camelCase | `calculateSuccessChance`, `handleClick` |
| Local variables | camelCase | `selectedHero`, `questResults` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_HEROES`, `QUEST_REFRESH_INTERVAL` |
| Private functions | camelCase with `local` | `local function prepareData()` |
| Game state tables | camelCase | `gameData`, `heroData` |
| UI dimensions | SCREAMING_SNAKE_CASE | `MENU_DESIGN_WIDTH` |

## Game State Management

Central game state lives in `gameData` table in main.lua:

```lua
local gameData = {
    -- Time/Progress
    day = 1,
    dayProgress = 0,
    totalTime = 0,

    -- Resources
    gold = 200,
    inventory = {
        materials = {},    -- {material_id = count}
        equipment = {}     -- {equipment_id = count}
    },

    -- Heroes
    heroes = {},           -- Hired heroes in guild
    tavernPool = {},       -- Available for hire
    graveyard = {},        -- Dead heroes

    -- Quests
    availableQuests = {},  -- Can be assigned
    activeQuests = {},     -- In progress

    -- Guild
    guild = nil,           -- Guild progression data
    parties = {},          -- Formed parties
    protoParties = {}      -- Parties in formation
}
```

## State Machine Pattern

Game screens use a state machine:

```lua
local STATE = {
    TOWN = "town",
    TAVERN = "tavern",
    GUILD = "guild",
    ARMORY = "armory",
    -- etc.
}

local currentState = STATE.TOWN

function love.draw()
    if currentState == STATE.TOWN then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
    elseif currentState == STATE.GUILD then
        Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
        GuildMenu.draw(gameData, QuestSystem, Quests, Heroes, ...)
    end
end

function love.mousepressed(x, y, button)
    if currentState == STATE.GUILD then
        local result, message = GuildMenu.handleClick(x, y, gameData, ...)
        if result == "close" then
            currentState = STATE.TOWN
        elseif result == "assigned" then
            addNotification(message, "success")
        end
    end
end
```

## UI Component Patterns

### Reusable Components (ui/components.lua)

```lua
-- Draw a button
Components.drawButton(text, x, y, w, h, {
    disabled = false,
    active = false,
    color = {r, g, b}
})

-- Check if button clicked
if Components.buttonClicked(mouseX, mouseY, btnX, btnY, btnW, btnH) then
    -- Handle click
end

-- Draw panel
Components.drawPanel(x, y, w, h, {
    color = Components.colors.panel,
    cornerRadius = 10,
    border = true
})

-- Draw tooltip
Components.drawTooltip({"Line 1", {text = "Colored", color = {1, 0, 0}}}, x, y)
```

### Menu Module Pattern

```lua
local MenuName = {}

-- Design dimensions (base size before scaling)
local MENU_DESIGN_WIDTH = 800
local MENU_DESIGN_HEIGHT = 600

-- State variables
local selectedItem = nil
local scrollOffset = 0

function MenuName.resetState()
    selectedItem = nil
    scrollOffset = 0
end

function MenuName.draw(gameData, ...)
    local menu = Components.getCenteredMenu(MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)

    -- Apply scaling transform
    love.graphics.push()
    love.graphics.translate(menu.x, menu.y)
    love.graphics.scale(menu.scale, menu.scale)

    -- Draw menu content using design coordinates (0,0 to MENU_DESIGN_WIDTH/HEIGHT)
    Components.drawPanel(0, 0, MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)

    love.graphics.pop()
end

function MenuName.handleClick(x, y, gameData, ...)
    local menu = Components.getCenteredMenu(MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)
    local scale = menu.scale

    -- Transform screen coords to design coords
    local designX = (x - menu.x) / scale
    local designY = (y - menu.y) / scale

    -- Check bounds in design coordinates
    if Components.buttonClicked(designX, designY, btnX, btnY, btnW, btnH) then
        return "action", "Success message"
    end

    return nil
end

return MenuName
```

## Data Loading Pattern

JSON data with Lua wrapper:

```lua
-- data/heroes.lua
local json = require("utils.json")

local Heroes = {}

local heroData = nil
local function loadHeroData()
    if heroData then return heroData end

    local data, err = json.loadFile("data/heroes.json")
    if not data then
        print("ERROR loading heroes.json: " .. (err or "unknown error"))
        -- Fallback data
        data = { config = {}, classes = {}, races = {} }
    end
    heroData = data
    return heroData
end

-- Lazy-loaded accessors using metatables
Heroes.classes = setmetatable({}, {
    __index = function(_, className)
        local data = loadHeroData()
        return data.classes[className]
    end,
    __pairs = function(_)
        local data = loadHeroData()
        return pairs(data.classes)
    end
})

function Heroes.getConfig(key)
    local data = loadHeroData()
    return data.config[key]
end

-- Hot reload support
function Heroes.reload()
    heroData = nil
    loadHeroData()
    print("Hero data reloaded from JSON")
end

return Heroes
```

## Quest System Phases

Quests progress through phases in real-time:

```
available → travel → execute → awaiting_claim → return → completed
                                    ↓
                              (player clicks)
```

```lua
function QuestSystem.update(gameData, dt, ...)
    for i, quest in ipairs(gameData.activeQuests) do
        quest.phaseProgress = quest.phaseProgress + dt

        if quest.currentPhase == "travel" then
            if quest.phaseProgress >= quest.actualTravelTime then
                quest.currentPhase = "execute"
                quest.phaseProgress = 0
                -- Update hero statuses
            end
        elseif quest.currentPhase == "execute" then
            -- Handle execution phase
        elseif quest.currentPhase == "awaiting_claim" then
            -- Wait for player interaction
        elseif quest.currentPhase == "return" then
            -- Heroes returning to guild
        end
    end
end
```

## Hero Generation

```lua
function Heroes.generate(options)
    options = options or {}

    local rank = options.rank or rollRandomRank()
    local race = options.race or selectRace()
    local class = options.class or selectClassForRace(race)

    local hero = {
        id = nextHeroId,
        name = options.name or generateName(rank),
        race = race,
        class = class,
        rank = rank,
        level = options.level or 1,
        xp = 0,
        xpToLevel = 100,
        stats = generateStats(rank, class, race),
        status = "idle",
        hireCost = getRankCost(rank),
        equipment = {
            weapon = nil,
            armor = nil,
            accessory = nil,
            mount = nil
        },
        passive = selectPassive(class)
    }

    nextHeroId = nextHeroId + 1
    return hero
end
```

## Save System Pattern

```lua
function SaveSystem.save(gameData, slot)
    local saveData = prepareDataForSave(gameData)
    local success, err = json.saveFile(getSavePath(slot), saveData, true)
    return success, success and "Saved" or err
end

function SaveSystem.load(slot)
    local data, err = json.loadFile(getSavePath(slot))
    return data, err
end

function SaveSystem.applyLoadedData(gameData, loadedData, Heroes, Quests, ...)
    -- Restore core progress
    gameData.day = loadedData.day or 1
    gameData.gold = loadedData.gold or 200

    -- Restore heroes (reset transient state)
    gameData.heroes = {}
    for _, heroData in ipairs(loadedData.heroes) do
        local hero = {
            -- Persistent data from save
            id = heroData.id,
            name = heroData.name,
            stats = heroData.stats,
            -- Reset transient state
            status = "idle",
            questProgress = 0
        }
        table.insert(gameData.heroes, hero)
    end

    -- Regenerate volatile data
    gameData.activeQuests = {}
    gameData.availableQuests = Quests.generatePool(3, maxRank)
end
```

## Notification System

```lua
local notifications = {}

function addNotification(message, notifType)
    local color
    if notifType == "success" then
        color = {0.2, 0.5, 0.3}
    elseif notifType == "error" then
        color = {0.5, 0.2, 0.2}
    elseif notifType == "warning" then
        color = {0.5, 0.4, 0.2}
    else
        color = {0.3, 0.3, 0.4}  -- info
    end

    table.insert(notifications, 1, {message = message, color = color})

    while #notifications > 3 do
        table.remove(notifications)
    end
end
```

## Hot Reload Support

Press F6 to reload UI modules during development:

```lua
elseif key == "f6" then
    local modules = {
        {"ui/guild_menu", function(m) GuildMenu = m end},
        {"ui/tavern_menu", function(m) TavernMenu = m end},
        -- etc.
    }

    for _, mod in ipairs(modules) do
        local name, setter = mod[1], mod[2]
        package.loaded[name] = nil
        local success, result = pcall(require, name)
        if success then
            setter(result)
        end
    end
end
```

## Color Palette

Defined in `Components.colors`:

```lua
Components.colors = {
    -- Base
    background = {0.15, 0.15, 0.2},
    panel = {0.2, 0.2, 0.25, 0.95},

    -- Ranks (D=gray, C=green, B=blue, A=yellow, S=red)
    rankD = {0.5, 0.5, 0.5},
    rankC = {0.3, 0.7, 0.3},
    rankB = {0.3, 0.5, 0.9},
    rankA = {1, 0.85, 0.2},
    rankS = {0.9, 0.2, 0.2},

    -- Hero status
    idle = {0.3, 0.7, 0.3},
    traveling = {0.5, 0.6, 0.8},
    questing = {0.8, 0.6, 0.2},
    returning = {0.6, 0.5, 0.8},
    resting = {0.5, 0.4, 0.6},

    -- Resources
    gold = {1, 0.85, 0}
}
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Escape | Close menu / Open settings from town |
| F2 | Toggle Edit Mode (if enabled) |
| F5 | Quick save to slot 1 |
| F6 | Hot reload UI modules |
| F9 | Quick load from slot 1 |
| +/= | Speed up time (debug) |
| - | Slow down time (debug) |

## Common Workflows

### Adding a New Menu

1. Create `ui/new_menu.lua` with standard module pattern
2. Add state constant in main.lua: `NEW_MENU = "new_menu"`
3. Add require at top of main.lua
4. Add draw case in `love.draw()`
5. Add click handler case in `love.mousepressed()`
6. Add to F6 hot reload list

### Adding a New System

1. Create `systems/new_system.lua`
2. Add require in main.lua
3. Initialize in `love.load()` if needed
4. Call update in `love.update(dt)` if needed
5. Pass to UI modules that need it

### Adding New Hero Data

1. Add to `data/heroes.json` (classes, races, names, etc.)
2. Add accessor function in `data/heroes.lua` if needed
3. Data is lazy-loaded, no restart needed (use F6 or Heroes.reload())

### Adding a New Quest Type

1. Add quest template to `data/quests.json`
2. Add generation logic in `data/quests.lua`
3. Add resolution logic in `QuestSystem.claimQuest()`
4. Update UI in `guild_menu.lua` if special display needed

## Testing Patterns

- Use `print()` for debug output (shows in Love2D console)
- Hardcode test values during development (mark with `-- TESTING:` comment)
- Use F6 hot reload for rapid iteration
- Time controls (+/-) for testing quest completion

## Performance Considerations

- Preload sprites in `love.load()` via `SpriteSystem.preloadAll()`
- Use `nearest` filter for pixel-crisp rendering
- Lazy-load JSON data (only load once per session)
- Limit notifications to 3 max
- Use scissor rectangles for scrolling content
