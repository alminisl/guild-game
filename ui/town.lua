-- Town View Module
-- Renders the town with terrain sprites and clickable buildings

local Components = require("ui.components")
local json = require("utils.json")

local Town = {}

-- Design size (1920x1080) - all positions are relative to this
local DESIGN_W, DESIGN_H = 1920, 1080
-- Actual screen size (updated at runtime)
local SCREEN_W, SCREEN_H = 1920, 1080
-- Current scale factor
local currentScale = 1
local offsetX, offsetY = 0, 0

-- Update scale based on current window size
local function updateScale()
    SCREEN_W, SCREEN_H = love.graphics.getDimensions()
    local scaleX = SCREEN_W / DESIGN_W
    local scaleY = SCREEN_H / DESIGN_H
    currentScale = math.min(scaleX, scaleY)
    -- Center the content if aspect ratio differs
    offsetX = (SCREEN_W - DESIGN_W * currentScale) / 2
    offsetY = (SCREEN_H - DESIGN_H * currentScale) / 2
end

-- Transform screen coordinates to design coordinates
function Town.screenToDesign(x, y)
    return (x - offsetX) / currentScale, (y - offsetY) / currentScale
end

-- Loaded sprites
local sprites = {}
local terrainSprites = {}
local spritesLoaded = false

-- Tilemap quads (for extracting tiles from tilemap spritesheet)
local tileQuads = {}
local TILE_SIZE = 64

-- Animation state
local animTime = 0

-- Cloud positions (will drift)
local clouds = {}

-- Decorations (trees, rocks, bushes, sheep)
local decorations = {}

-- Stored tiles (from world layout, for roads/paths)
local storedTiles = {}

-- Hero departure/arrival animations
local heroAnimations = {}  -- {hero, x, y, targetX, targetY, direction, type ("departing"/"arriving"), progress}
local SpriteSystem = nil  -- Will be set when needed

-- Edit mode support
local editModeActive = false
local editModeWorldLayout = nil  -- Reference to EditMode's worldLayout when in edit mode

-- Forward declaration for hero animation function
local updateAndDrawHeroAnimations

-- Building definitions with sprite paths
Town.buildings = {
    -- Main Guild Hall (center top)
    {
        id = "guild",
        name = "Guild Hall",
        sprite = "assets/Buildings/Blue Buildings/Castle.png",
        x = 960,
        y = 180,
        scale = 1.0,
        description = "Manage quests & heroes"
    },
    -- Tavern (left side)
    {
        id = "tavern",
        name = "Tavern",
        sprite = "assets/Buildings/Blue Buildings/Monastery.png",
        x = 400,
        y = 350,
        scale = 0.8,
        description = "Hire adventurers"
    },
    -- Armory (right side)
    {
        id = "armory",
        name = "Armory",
        sprite = "assets/Buildings/Blue Buildings/Barracks.png",
        x = 1520,
        y = 350,
        scale = 0.8,
        description = "Buy equipment & craft"
    },
    -- Potion Shop (center left)
    {
        id = "potion",
        name = "Potion Shop",
        sprite = "assets/Buildings/Blue Buildings/House2.png",
        x = 650,
        y = 550,
        scale = 0.75,
        description = "Rest & potions"
    },
    -- Decorative Tower (center right)
    {
        id = "tower1",
        name = nil,
        sprite = "assets/Buildings/Blue Buildings/Tower.png",
        x = 1270,
        y = 520,
        scale = 0.6,
        description = nil
    },
    -- Decorative houses to fill out the town
    {
        id = "deco_house1",
        name = nil,
        sprite = "assets/Buildings/Blue Buildings/House1.png",
        x = 250,
        y = 580,
        scale = 0.7,
        description = nil
    },
    {
        id = "deco_house2",
        name = nil,
        sprite = "assets/Buildings/Blue Buildings/House3.png",
        x = 1680,
        y = 550,
        scale = 0.7,
        description = nil
    },
    {
        id = "deco_house3",
        name = nil,
        sprite = "assets/Buildings/Blue Buildings/House1.png",
        x = 550,
        y = 750,
        scale = 0.65,
        description = nil
    },
    {
        id = "deco_house4",
        name = nil,
        sprite = "assets/Buildings/Blue Buildings/House2.png",
        x = 1400,
        y = 720,
        scale = 0.65,
        description = nil
    },
    -- Archery range
    {
        id = "deco_archery",
        name = nil,
        sprite = "assets/Buildings/Blue Buildings/Archery.png",
        x = 1750,
        y = 780,
        scale = 0.6,
        description = nil
    }
}

-- Load world layout from JSON (version 2 with buildings, decorations, NPCs)
function Town.loadWorldLayout()
    local worldLayout, err = json.loadFile("data/world_layout.json")

    if not worldLayout then
        print("Failed to load world layout:", err)
        print("Using default buildings")
        decorations = {}
        townNPCs = {}
        movingSheep = {}
        return
    end

    -- Load buildings from JSON if version 2
    if worldLayout.version and worldLayout.version >= 2 and worldLayout.buildings then
        Town.buildings = {}
        for _, b in ipairs(worldLayout.buildings) do
            table.insert(Town.buildings, {
                id = b.id,
                name = b.name,
                sprite = b.sprite,
                x = b.x,
                y = b.y,
                scale = b.scale or 1.0,
                clickable = b.clickable,
                menuTarget = b.menuTarget,
                description = b.description
            })
        end
        print("Loaded", #Town.buildings, "buildings from JSON")
    end

    -- Load decorations
    decorations = {}
    if worldLayout.decorations then
        for _, dec in ipairs(worldLayout.decorations) do
            table.insert(decorations, {
                type = dec.type,
                sprite = dec.sprite,  -- New: direct sprite path
                x = dec.x,
                y = dec.y,
                scale = dec.scale or 1.0,
                layer = dec.layer or 1,
                animOffset = dec.animOffset or 0.0,
                -- Animation settings
                animated = dec.animated or false,
                frameCount = dec.frameCount or 1,
                fps = dec.fps or 8
            })
        end
    end

    -- Load NPCs with behavior support (version 2)
    townNPCs = {}
    if worldLayout.npcs then
        for _, npc in ipairs(worldLayout.npcs) do
            local npcData = {
                x = npc.x or npc.startX or 500,
                y = npc.y or npc.startY or 500,
                speed = npc.speed or 30,
                type = npc.type,
                sprite = npc.sprite,  -- New: direct sprite path
                behavior = npc.behavior or "idle",
                scale = npc.scale or 0.8,
                animOffset = math.random() * 2,
                direction = 1,
                -- Animation settings
                animated = npc.animated or false,
                frameCount = npc.frameCount or 1,
                fps = npc.fps or 8
            }

            -- Behavior-specific fields
            if npc.behavior == "patrol" then
                npcData.waypoints = npc.waypoints or {{npc.x, npc.y}}
                npcData.currentWaypoint = 1
                npcData.loop = npc.loop ~= false  -- Default true
                npcData.goingForward = true
            elseif npc.behavior == "wander" then
                npcData.radius = npc.radius or 100
                npcData.originX = npcData.x
                npcData.originY = npcData.y
                npcData.targetX = npcData.x
                npcData.targetY = npcData.y
                npcData.waitTime = 0
                npcData.minWait = npc.minWait or 1.0
                npcData.maxWait = npc.maxWait or 3.0
            elseif npc.behavior == "idle" then
                -- Idle NPCs just stand in place
                npcData.facing = npc.facing or "right"
            else
                -- Legacy format (startX/endX)
                npcData.targetX = npc.endX or (npc.x + 200)
                npcData.targetY = npc.endY or npc.y
                npcData.direction = (npcData.targetX > npcData.x) and 1 or -1
            end

            table.insert(townNPCs, npcData)
        end
    end

    -- Keep movingSheep empty for now
    movingSheep = {}

    -- Load tiles
    storedTiles = {}
    if worldLayout.tiles then
        for _, tile in ipairs(worldLayout.tiles) do
            table.insert(storedTiles, {
                x = tile.x,
                y = tile.y,
                tilesetPath = tile.tilesetPath,
                tileX = tile.tileX,
                tileY = tile.tileY,
                tileSize = tile.tileSize
            })
        end
    end

    print("World layout loaded:", #decorations, "decorations,", #townNPCs, "NPCs,", #storedTiles, "tiles")
end

-- Load all sprites
function Town.loadSprites()
    if spritesLoaded then return end

    -- Load world layout first (this may update Town.buildings from JSON)
    Town.loadWorldLayout()

    -- Load building sprites
    for _, building in ipairs(Town.buildings) do
        if building.sprite then
            local success, img = pcall(love.graphics.newImage, building.sprite)
            if success then
                sprites[building.id] = img
            else
                print("Failed to load building sprite:", building.sprite)
            end
        end
    end

    -- Load terrain sprites
    local terrainFiles = {
        water = "assets/Terrain/Tileset/Water Background color.png",
        tilemap = "assets/Terrain/Tileset/Tilemap_color1.png",
        foam = "assets/Terrain/Tileset/Water Foam.png",
        tree1 = "assets/Terrain/Resources/Wood/Trees/Tree1.png",
        tree2 = "assets/Terrain/Resources/Wood/Trees/Tree2.png",
        tree3 = "assets/Terrain/Resources/Wood/Trees/Tree3.png",
        tree4 = "assets/Terrain/Resources/Wood/Trees/Tree4.png",
        rock1 = "assets/Terrain/Decorations/Rocks/Rock1.png",
        rock2 = "assets/Terrain/Decorations/Rocks/Rock2.png",
        rock3 = "assets/Terrain/Decorations/Rocks/Rock3.png",
        bush1 = "assets/Terrain/Decorations/Bushes/Bushe1.png",
        bush2 = "assets/Terrain/Decorations/Bushes/Bushe2.png",
        cloud1 = "assets/Terrain/Decorations/Clouds/Clouds_01.png",
        cloud2 = "assets/Terrain/Decorations/Clouds/Clouds_02.png",
        cloud3 = "assets/Terrain/Decorations/Clouds/Clouds_03.png",
        sheep = "assets/Terrain/Resources/Meat/Sheep/Sheep_Idle.png",
        waterRock1 = "assets/Terrain/Decorations/Rocks in the Water/Water Rocks_01.png",
        waterRock2 = "assets/Terrain/Decorations/Rocks in the Water/Water Rocks_02.png"
    }

    for name, path in pairs(terrainFiles) do
        local success, img = pcall(love.graphics.newImage, path)
        if success then
            terrainSprites[name] = img
            img:setFilter("nearest", "nearest")
        end
    end

    -- Create tilemap quads (64x64 tiles)
    if terrainSprites.tilemap then
        local tw = terrainSprites.tilemap:getWidth()
        local th = terrainSprites.tilemap:getHeight()

        -- Top-left grass corner
        tileQuads.grassTopLeft = love.graphics.newQuad(0, 0, 64, 64, tw, th)
        -- Top grass
        tileQuads.grassTop = love.graphics.newQuad(64, 0, 64, 64, tw, th)
        -- Top-right grass corner
        tileQuads.grassTopRight = love.graphics.newQuad(128, 0, 64, 64, tw, th)
        -- Left grass edge
        tileQuads.grassLeft = love.graphics.newQuad(0, 64, 64, 64, tw, th)
        -- Center grass (fill)
        tileQuads.grassCenter = love.graphics.newQuad(64, 64, 64, 64, tw, th)
        -- Right grass edge
        tileQuads.grassRight = love.graphics.newQuad(128, 64, 64, 64, tw, th)
        -- Bottom-left corner
        tileQuads.grassBottomLeft = love.graphics.newQuad(0, 128, 64, 64, tw, th)
        -- Bottom grass
        tileQuads.grassBottom = love.graphics.newQuad(64, 128, 64, 64, tw, th)
        -- Bottom-right corner
        tileQuads.grassBottomRight = love.graphics.newQuad(128, 128, 64, 64, tw, th)
        -- Cliff face
        tileQuads.cliffFace = love.graphics.newQuad(320, 192, 64, 64, tw, th)
        -- Single grass tile
        tileQuads.grassSingle = love.graphics.newQuad(192, 0, 64, 64, tw, th)
    end

    -- Initialize clouds (more clouds for larger screen)
    clouds = {
        {sprite = "cloud1", x = 100, y = 60, speed = 8, scale = 0.9},
        {sprite = "cloud2", x = 400, y = 40, speed = 12, scale = 0.7},
        {sprite = "cloud3", x = 750, y = 80, speed = 6, scale = 0.8},
        {sprite = "cloud1", x = 1100, y = 50, speed = 10, scale = 0.6},
        {sprite = "cloud2", x = 1450, y = 70, speed = 9, scale = 0.75},
        {sprite = "cloud3", x = 1800, y = 45, speed = 11, scale = 0.65}
    }

    -- Load decorative house sprites
    local houseFiles = {
        house1 = "assets/Buildings/Blue Buildings/House1.png",
        house3 = "assets/Buildings/Blue Buildings/House3.png"
    }
    for name, path in pairs(houseFiles) do
        local success, img = pcall(love.graphics.newImage, path)
        if success then
            terrainSprites[name] = img
        end
    end

    -- Load sheep move sprite
    local success, img = pcall(love.graphics.newImage, "assets/Terrain/Resources/Meat/Sheep/Sheep_Move.png")
    if success then
        terrainSprites.sheepMove = img
        img:setFilter("nearest", "nearest")
    end

    -- Load fire sprite for campfire
    success, img = pcall(love.graphics.newImage, "assets/Particle FX/Fire_01.png")
    if success then
        terrainSprites.fire = img
        img:setFilter("nearest", "nearest")
    end

    -- Load NPC sprites (Blue Units)
    local npcFiles = {
        warrior_idle = "assets/Units/Blue Units/Warrior/Warrior_Idle.png",
        warrior_run = "assets/Units/Blue Units/Warrior/Warrior_Run.png",
        archer_idle = "assets/Units/Blue Units/Archer/Archer_Idle.png",
        archer_run = "assets/Units/Blue Units/Archer/Archer_Run.png",
        pawn_idle = "assets/Units/Blue Units/Pawn/Pawn_Idle.png",
        pawn_run = "assets/Units/Blue Units/Pawn/Pawn_Run.png",
        pawn_wood_idle = "assets/Units/Blue Units/Pawn/Pawn_Idle Wood.png",
        pawn_wood_run = "assets/Units/Blue Units/Pawn/Pawn_Run Wood.png",
        pawn_gold_idle = "assets/Units/Blue Units/Pawn/Pawn_Idle Gold.png",
        pawn_gold_run = "assets/Units/Blue Units/Pawn/Pawn_Run Gold.png",
        pawn_meat_idle = "assets/Units/Blue Units/Pawn/Pawn_Idle Meat.png",
        pawn_meat_run = "assets/Units/Blue Units/Pawn/Pawn_Run Meat.png"
    }
    for name, path in pairs(npcFiles) do
        local success, img = pcall(love.graphics.newImage, path)
        if success then
            terrainSprites[name] = img
            img:setFilter("nearest", "nearest")
        end
    end

    spritesLoaded = true
end

-- Get animation frame from spritesheet
local function getAnimFrame(sprite, frameWidth, totalFrames)
    local frame = math.floor(animTime * 4) % totalFrames
    local quad = love.graphics.newQuad(frame * frameWidth, 0, frameWidth, sprite:getHeight(), sprite:getDimensions())
    return quad
end

-- Draw grass platform
local function drawGrassPlatform(x, y, tilesWide, tilesHigh)
    if not terrainSprites.tilemap then return end

    local tm = terrainSprites.tilemap
    love.graphics.setColor(1, 1, 1)

    for ty = 0, tilesHigh - 1 do
        for tx = 0, tilesWide - 1 do
            local quad
            local drawX = x + tx * TILE_SIZE
            local drawY = y + ty * TILE_SIZE

            -- Determine which tile to use
            if ty == 0 then
                -- Top row
                if tx == 0 then
                    quad = tileQuads.grassTopLeft
                elseif tx == tilesWide - 1 then
                    quad = tileQuads.grassTopRight
                else
                    quad = tileQuads.grassTop
                end
            elseif ty == tilesHigh - 1 then
                -- Bottom row
                if tx == 0 then
                    quad = tileQuads.grassBottomLeft
                elseif tx == tilesWide - 1 then
                    quad = tileQuads.grassBottomRight
                else
                    quad = tileQuads.grassBottom
                end
            else
                -- Middle rows
                if tx == 0 then
                    quad = tileQuads.grassLeft
                elseif tx == tilesWide - 1 then
                    quad = tileQuads.grassRight
                else
                    quad = tileQuads.grassCenter
                end
            end

            if quad then
                love.graphics.draw(tm, quad, drawX, drawY)
            end
        end
    end
end

-- Draw a single building
local function drawBuilding(building, isHovered, mouseX, mouseY)
    local b = building
    local sprite = sprites[b.id]

    if not sprite then return end

    local scale = b.scale or 1.0
    local w = sprite:getWidth() * scale
    local h = sprite:getHeight() * scale
    local drawX = b.x - w / 2
    local drawY = b.y

    -- Draw building (bounce up when hovered)
    if isHovered and b.name then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, drawX, drawY - 8, 0, scale * 1.02, scale * 1.02)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, drawX, drawY, 0, scale, scale)
    end

    -- Draw label for interactive buildings
    if b.name then
        local labelWidth = love.graphics.getFont():getWidth(b.name) + 20
        local labelX = b.x - labelWidth / 2
        local labelY = b.y - 25

        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", labelX, labelY, labelWidth, 22, 4, 4)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(b.name, labelX, labelY + 4, labelWidth, "center")

        if isHovered and b.description then
            local tooltipWidth = 180
            local tooltipX = math.min(mouseX + 15, 1280 - tooltipWidth - 10)
            local tooltipY = mouseY + 15

            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, 30, 5, 5)

            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf(b.description, tooltipX + 10, tooltipY + 8, tooltipWidth - 20, "left")
        end
    end
end

-- Sprite cache for custom decoration sprites
local decorationSpriteCache = {}

-- Sprite cache for tilesets
local tilesetSpriteCache = {}

-- Get tileset sprite
local function getTilesetSprite(path)
    if not tilesetSpriteCache[path] then
        local success, img = pcall(love.graphics.newImage, path)
        if success then
            tilesetSpriteCache[path] = img
            img:setFilter("nearest", "nearest")
        end
    end
    return tilesetSpriteCache[path]
end

-- Draw stored tiles
local function drawStoredTiles()
    local tilesToRender = storedTiles
    if editModeActive and editModeWorldLayout and editModeWorldLayout.tiles then
        tilesToRender = editModeWorldLayout.tiles
    end

    if not tilesToRender then return end

    for _, tile in ipairs(tilesToRender) do
        local sprite = getTilesetSprite(tile.tilesetPath)
        if sprite then
            local sw, sh = sprite:getDimensions()
            local quad = love.graphics.newQuad(
                tile.tileX * tile.tileSize,
                tile.tileY * tile.tileSize,
                tile.tileSize, tile.tileSize,
                sw, sh
            )
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(sprite, quad, tile.x, tile.y)
        end
    end
end

-- Get decoration sprite (either from type or custom path)
local function getDecorationSprite(dec)
    -- If has custom sprite path, load it
    if dec.sprite then
        if not decorationSpriteCache[dec.sprite] then
            local success, img = pcall(love.graphics.newImage, dec.sprite)
            if success then
                decorationSpriteCache[dec.sprite] = img
                img:setFilter("nearest", "nearest")
            end
        end
        return decorationSpriteCache[dec.sprite]
    end

    -- Otherwise use type-based sprites
    return terrainSprites[dec.type]
end

-- Draw decoration (tree, rock, bush, sheep, houses, or custom sprites)
local function drawDecoration(dec)
    local sprite = getDecorationSprite(dec)
    if not sprite then return end

    local scale = dec.scale or 1.0
    local spriteW = sprite:getWidth()
    local spriteH = sprite:getHeight()

    -- Check if this decoration should be animated
    if dec.animated and dec.frameCount and dec.frameCount > 1 then
        -- Use animation settings from JSON
        local frameWidth = math.floor(spriteW / dec.frameCount)
        local totalFrames = dec.frameCount
        local fps = dec.fps or 8

        local animOffset = dec.animOffset or 0
        local frame = math.floor((animTime + animOffset) * fps) % totalFrames

        local quad = love.graphics.newQuad(frame * frameWidth, 0, frameWidth, spriteH, sprite:getDimensions())

        love.graphics.setColor(1, 1, 1)
        -- Draw anchored at bottom center
        love.graphics.draw(sprite, quad, dec.x - (frameWidth * scale) / 2, dec.y - spriteH * scale, 0, scale, scale)

    elseif dec.type and (dec.type:find("tree") or dec.type:find("bush") or dec.type == "sheep") then
        -- Legacy handling for built-in animated sprites
        local frameWidth = spriteH
        local totalFrames = math.floor(spriteW / frameWidth)
        if totalFrames < 1 then totalFrames = 1 end

        local frame = 0  -- Default to first frame (static)

        -- Only animate bushes, keep trees static to prevent "moving" appearance
        if dec.type:find("bush") then
            local animOffset = dec.animOffset or 0
            frame = math.floor((animTime + animOffset) * 3) % totalFrames
        end

        local quad = love.graphics.newQuad(frame * frameWidth, 0, frameWidth, spriteH, sprite:getDimensions())

        love.graphics.setColor(1, 1, 1)
        -- Draw anchored at bottom center, position is fixed
        love.graphics.draw(sprite, quad, dec.x - (frameWidth * scale) / 2, dec.y - spriteH * scale, 0, scale, scale)
    else
        -- Static sprites (rocks, water rocks, houses, custom non-animated)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, dec.x - (spriteW * scale) / 2, dec.y - spriteH * scale, 0, scale, scale)
    end
end

-- Update and draw moving sheep
local function updateAndDrawSheep(dt)
    if not movingSheep or not terrainSprites.sheepMove then return end

    local sprite = terrainSprites.sheepMove
    local spriteH = sprite:getHeight()
    local frameWidth = spriteH  -- Square frames
    local totalFrames = math.floor(sprite:getWidth() / frameWidth)
    if totalFrames < 1 then totalFrames = 1 end

    for _, sheep in ipairs(movingSheep) do
        -- Move towards target
        local dx = sheep.targetX - sheep.x
        if math.abs(dx) < 2 then
            -- Reached target, pick new random target
            sheep.direction = sheep.direction * -1
            if sheep.direction > 0 then
                sheep.targetX = sheep.x + math.random(80, 150)
            else
                sheep.targetX = sheep.x - math.random(80, 150)
            end
            -- Clamp to grass area (larger map)
            sheep.targetX = math.max(300, math.min(1600, sheep.targetX))
        else
            sheep.x = sheep.x + (sheep.direction * sheep.speed * dt)
        end

        -- Animate
        local frame = math.floor((animTime + sheep.animOffset) * 4) % totalFrames
        local quad = love.graphics.newQuad(frame * frameWidth, 0, frameWidth, spriteH, sprite:getDimensions())

        love.graphics.setColor(1, 1, 1)
        local scaleX = sheep.scale * sheep.direction
        local drawX = sheep.x - (frameWidth * math.abs(scaleX)) / 2
        love.graphics.draw(sprite, quad, sheep.x, sheep.y - spriteH * sheep.scale, 0, scaleX, sheep.scale, frameWidth/2, 0)
    end
end

-- Sprite cache for custom NPC sprites
local npcSpriteCache = {}

-- Get NPC sprite (either from type or custom path)
local function getNPCSprite(npc, isMoving)
    -- If has custom sprite path, load it
    if npc.sprite then
        local spritePath = npc.sprite

        -- For wandering NPCs, swap between _Idle and _Move sprites based on movement
        if npc.behavior == "wander" or npc.behavior == "patrol" then
            if isMoving then
                -- Try to use _Move variant
                spritePath = spritePath:gsub("_Idle", "_Move")
                spritePath = spritePath:gsub("-Idle", "-Move")
            else
                -- Try to use _Idle variant
                spritePath = spritePath:gsub("_Move", "_Idle")
                spritePath = spritePath:gsub("-Move", "-Idle")
            end
        end

        if not npcSpriteCache[spritePath] then
            local success, img = pcall(love.graphics.newImage, spritePath)
            if success then
                npcSpriteCache[spritePath] = img
                img:setFilter("nearest", "nearest")
            else
                -- Fallback to original sprite if variant doesn't exist
                spritePath = npc.sprite
                if not npcSpriteCache[spritePath] then
                    success, img = pcall(love.graphics.newImage, spritePath)
                    if success then
                        npcSpriteCache[spritePath] = img
                        img:setFilter("nearest", "nearest")
                    end
                end
            end
        end
        return npcSpriteCache[spritePath]
    end

    -- Otherwise use type-based sprites
    local spriteKey = npc.type .. (isMoving and "_run" or "_idle")
    return terrainSprites[spriteKey]
end

-- Update and draw NPCs with behavior support
local function updateAndDrawNPCs(dt)
    -- In edit mode, read directly from edit mode's world layout for live updates
    local npcsToRender = townNPCs
    if editModeActive and editModeWorldLayout and editModeWorldLayout.npcs then
        npcsToRender = editModeWorldLayout.npcs
    end

    if not npcsToRender then return end

    for _, npc in ipairs(npcsToRender) do
        local isMoving = false

        -- Update based on behavior (skip movement updates in edit mode)
        if editModeActive then
            -- In edit mode, just render at current position without behavior updates
            npc.direction = npc.direction or 1
        elseif npc.behavior == "idle" then
            -- Idle: just stand in place
            npc.direction = (npc.facing == "left") and -1 or 1

        elseif npc.behavior == "patrol" then
            -- Patrol: move through waypoints
            if npc.waypoints and #npc.waypoints > 0 then
                local target = npc.waypoints[npc.currentWaypoint]
                if target then
                    local dx = target[1] - npc.x
                    local dy = target[2] - npc.y
                    local dist = math.sqrt(dx * dx + dy * dy)

                    if dist < 5 then
                        -- Reached waypoint, move to next
                        if npc.goingForward then
                            if npc.currentWaypoint < #npc.waypoints then
                                npc.currentWaypoint = npc.currentWaypoint + 1
                            elseif npc.loop then
                                npc.currentWaypoint = 1
                            else
                                npc.goingForward = false
                                npc.currentWaypoint = npc.currentWaypoint - 1
                            end
                        else
                            if npc.currentWaypoint > 1 then
                                npc.currentWaypoint = npc.currentWaypoint - 1
                            else
                                npc.goingForward = true
                                npc.currentWaypoint = npc.currentWaypoint + 1
                            end
                        end
                    else
                        -- Move towards target
                        local moveX = (dx / dist) * npc.speed * dt
                        local moveY = (dy / dist) * npc.speed * dt
                        npc.x = npc.x + moveX
                        npc.y = npc.y + moveY
                        npc.direction = dx > 0 and 1 or -1
                        isMoving = true
                    end
                end
            end

        elseif npc.behavior == "wander" then
            -- Wander: move randomly within radius
            if npc.waitTime > 0 then
                npc.waitTime = npc.waitTime - dt
            else
                local dx = npc.targetX - npc.x
                local dy = npc.targetY - npc.y
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist < 5 then
                    -- Pick new random target
                    local angle = math.random() * math.pi * 2
                    local radius = math.random() * npc.radius
                    npc.targetX = npc.originX + math.cos(angle) * radius
                    npc.targetY = npc.originY + math.sin(angle) * radius
                    npc.waitTime = npc.minWait + math.random() * (npc.maxWait - npc.minWait)
                else
                    -- Move towards target
                    local moveX = (dx / dist) * npc.speed * dt
                    local moveY = (dy / dist) * npc.speed * dt
                    npc.x = npc.x + moveX
                    npc.y = npc.y + moveY
                    npc.direction = dx > 0 and 1 or -1
                    isMoving = true
                end
            end

        else
            -- Legacy behavior (simple back-and-forth)
            local dx = npc.targetX - npc.x
            if math.abs(dx) < 2 then
                npc.direction = npc.direction * -1
                if npc.direction > 0 then
                    npc.targetX = npc.x + math.random(100, 200)
                else
                    npc.targetX = npc.x - math.random(100, 200)
                end
                npc.targetX = math.max(350, math.min(1550, npc.targetX))
            else
                npc.x = npc.x + (npc.direction * npc.speed * dt)
                isMoving = true
            end
        end

        -- Track movement state changes to reset animation timer
        if npc.wasMoving == nil then
            npc.wasMoving = isMoving
            npc.stateAnimTime = 0
        end

        -- Reset animation timer when movement state changes
        if npc.wasMoving ~= isMoving then
            npc.stateAnimTime = 0
            npc.wasMoving = isMoving
        else
            npc.stateAnimTime = (npc.stateAnimTime or 0) + dt
        end

        -- Draw the NPC
        local sprite = getNPCSprite(npc, isMoving)
        if not sprite then
            -- Fallback: draw a simple rectangle
            love.graphics.setColor(0.5, 0.5, 0.8)
            love.graphics.rectangle("fill", npc.x - 20, npc.y - 60, 40, 60)
        else
            local spriteH = sprite:getHeight()
            local spriteW = sprite:getWidth()
            local frameWidth, totalFrames, fps

            -- Use animation settings if available
            -- For wandering NPCs, use moveFrameCount when moving (if specified)
            local frameCount = npc.frameCount
            if isMoving and npc.moveFrameCount then
                frameCount = npc.moveFrameCount
            elseif not isMoving and npc.idleFrameCount then
                frameCount = npc.idleFrameCount
            end

            -- Use separate fps for move vs idle if specified
            local animFps = npc.fps or 8
            if isMoving and npc.moveFps then
                animFps = npc.moveFps
            elseif not isMoving and npc.idleFps then
                animFps = npc.idleFps
            end

            if npc.animated and frameCount and frameCount > 1 then
                frameWidth = math.floor(spriteW / frameCount)
                totalFrames = frameCount
                fps = animFps
            else
                -- Default: assume square frames (auto-detect from sprite dimensions)
                frameWidth = spriteH
                totalFrames = math.floor(spriteW / frameWidth)
                if totalFrames < 1 then totalFrames = 1 end
                fps = 6  -- Default animation speed
            end

            local frame = 0
            -- Use per-NPC state animation timer to avoid flickering when switching states
            local stateTime = npc.stateAnimTime or 0
            -- Animate if moving, or if animated and not idle behavior
            if npc.animated then
                frame = math.floor(stateTime * fps) % totalFrames
            elseif isMoving or npc.behavior ~= "idle" then
                frame = math.floor(stateTime * fps) % totalFrames
            end

            local quad = love.graphics.newQuad(frame * frameWidth, 0, frameWidth, spriteH, sprite:getDimensions())

            love.graphics.setColor(1, 1, 1)
            local scale = npc.scale or 0.8
            local direction = npc.direction or 1
            local scaleX = scale * direction
            -- Draw anchored at bottom-center: origin at (frameWidth/2, spriteH) so position is feet
            love.graphics.draw(sprite, quad, npc.x, npc.y, 0, scaleX, scale, frameWidth/2, spriteH)
        end
    end
end

-- Draw dirt roads connecting buildings
local function drawRoads()
    love.graphics.setColor(0.55, 0.45, 0.35, 0.8)  -- Dirt brown color

    -- Main vertical road from Guild Hall down to market
    love.graphics.rectangle("fill", 920, 420, 80, 250)

    -- Main horizontal road through town center
    love.graphics.rectangle("fill", 350, 620, 1220, 30)

    -- Road to Tavern (left branch)
    love.graphics.rectangle("fill", 380, 520, 30, 100)

    -- Road to Armory (right branch)
    love.graphics.rectangle("fill", 1500, 520, 30, 100)

    -- Road to Potion Shop
    love.graphics.rectangle("fill", 630, 620, 30, 80)

    -- Road going down to lower buildings
    love.graphics.rectangle("fill", 920, 650, 80, 200)

    -- Central market square (larger)
    love.graphics.setColor(0.5, 0.4, 0.3, 0.9)
    love.graphics.rectangle("fill", 820, 580, 280, 100)

    -- Market square border
    love.graphics.setColor(0.4, 0.3, 0.25, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 820, 580, 280, 100)
    love.graphics.setLineWidth(1)
end

-- Draw market stalls/decorations
local function drawMarketSquare()
    -- Draw market stalls using colored rectangles
    love.graphics.setColor(0.6, 0.4, 0.2)  -- Wood color

    -- Left stall
    love.graphics.rectangle("fill", 840, 600, 50, 35)
    love.graphics.setColor(0.8, 0.2, 0.2)  -- Red awning
    love.graphics.rectangle("fill", 835, 588, 60, 14)

    -- Center-left stall
    love.graphics.setColor(0.6, 0.4, 0.2)
    love.graphics.rectangle("fill", 920, 600, 50, 35)
    love.graphics.setColor(0.2, 0.6, 0.3)  -- Green awning
    love.graphics.rectangle("fill", 915, 588, 60, 14)

    -- Center-right stall
    love.graphics.setColor(0.6, 0.4, 0.2)
    love.graphics.rectangle("fill", 1000, 600, 50, 35)
    love.graphics.setColor(0.2, 0.5, 0.8)  -- Blue awning
    love.graphics.rectangle("fill", 995, 588, 60, 14)

    -- Right stall
    love.graphics.setColor(0.6, 0.4, 0.2)
    love.graphics.rectangle("fill", 1030, 645, 50, 35)
    love.graphics.setColor(0.7, 0.5, 0.2)  -- Orange awning
    love.graphics.rectangle("fill", 1025, 633, 60, 14)

    -- Barrels/crates
    love.graphics.setColor(0.5, 0.35, 0.2)
    love.graphics.circle("fill", 870, 660, 12)
    love.graphics.circle("fill", 950, 665, 10)
    love.graphics.setColor(0.4, 0.25, 0.15)
    love.graphics.circle("line", 870, 660, 12)
    love.graphics.circle("line", 950, 665, 10)
end

-- Draw animated campfire at night
local function drawCampfire(x, y, scale)
    local sprite = terrainSprites.fire
    if not sprite then return end

    scale = scale or 2.0
    local spriteW = sprite:getWidth()
    local spriteH = sprite:getHeight()

    -- Fire has 8 frames (horizontal spritesheet)
    local frameCount = 8
    local frameW = spriteW / frameCount
    local frame = math.floor(animTime * 10) % frameCount

    local quad = love.graphics.newQuad(frame * frameW, 0, frameW, spriteH, spriteW, spriteH)

    -- Flickering intensity (subtle variation)
    local flicker = 0.85 + math.sin(animTime * 8) * 0.1 + math.sin(animTime * 13) * 0.05

    -- Draw soft dissipating glow (multiple layers with decreasing opacity)
    for i = 5, 1, -1 do
        local radius = 20 + i * 18
        local alpha = (0.08 / i) * flicker
        love.graphics.setColor(1, 0.5 + i * 0.08, 0.1, alpha)
        love.graphics.circle("fill", x, y + 5, radius)
    end

    -- Draw the fire sprite (smaller)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprite, quad, x, y, 0, scale, scale, frameW / 2, spriteH)

    -- Draw small log/base under fire
    love.graphics.setColor(0.3, 0.18, 0.08)
    love.graphics.ellipse("fill", x, y + 8, 15, 6)
end

-- Draw subtle glowing windows on buildings at night
local function drawBuildingWindows()
    -- Define window positions for each building (relative to building position)
    local buildingWindows = {
        -- Guild Hall (Castle) - multiple windows
        guild = {
            {ox = -60, oy = 120, r = 18},
            {ox = 60, oy = 120, r = 18},
            {ox = -30, oy = 180, r = 20},
            {ox = 30, oy = 180, r = 20},
            {ox = 0, oy = 100, r = 22},
        },
        -- Tavern (Monastery) - warm windows
        tavern = {
            {ox = -40, oy = 100, r = 20},
            {ox = 40, oy = 100, r = 20},
            {ox = 0, oy = 150, r = 22},
        },
        -- Armory (Barracks)
        armory = {
            {ox = -50, oy = 90, r = 16},
            {ox = 50, oy = 90, r = 16},
            {ox = 0, oy = 130, r = 18},
        },
        -- Potion Shop
        potion = {
            {ox = 0, oy = 60, r = 14},
            {ox = -25, oy = 90, r = 12},
        },
        -- Decorative buildings
        deco_house1 = {{ox = 0, oy = 70, r = 14}},
        deco_house2 = {{ox = 0, oy = 65, r = 14}},
        deco_house3 = {{ox = 0, oy = 55, r = 12}},
        deco_house4 = {{ox = 0, oy = 55, r = 12}},
        tower1 = {{ox = 0, oy = 80, r = 12}},
    }

    for _, building in ipairs(Town.buildings) do
        local windows = buildingWindows[building.id]
        if windows then
            for _, win in ipairs(windows) do
                local wx = building.x + win.ox
                local wy = building.y + win.oy
                local r = win.r or 15

                -- Very subtle, soft dissipating glow (multiple layers)
                for i = 4, 1, -1 do
                    local radius = r * (0.3 + i * 0.25)
                    local alpha = 0.04 / i  -- Very subtle
                    love.graphics.setColor(1, 0.85, 0.5, alpha)
                    love.graphics.circle("fill", wx, wy, radius)
                end
            end
        end
    end
end

-- Draw the town scene
function Town.draw(gameData, mouseX, mouseY, TimeSystem, GuildSystem)
    Town.loadSprites()
    updateScale()

    -- Transform mouse coordinates to design space
    local designMouseX, designMouseY = Town.screenToDesign(mouseX, mouseY)

    -- Update animation time
    animTime = animTime + love.timer.getDelta()

    -- Draw water background (fills entire screen)
    if terrainSprites.water then
        love.graphics.setColor(1, 1, 1)
        for x = 0, SCREEN_W, terrainSprites.water:getWidth() do
            for y = 0, SCREEN_H, terrainSprites.water:getHeight() do
                love.graphics.draw(terrainSprites.water, x, y)
            end
        end
    else
        -- Fallback water color
        love.graphics.setColor(0.35, 0.6, 0.65)
        love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)
    end

    -- Apply scaling transform for all town content
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(currentScale, currentScale)

    -- Get decorations source (live from edit mode, or cached)
    local decsToRender = decorations
    if editModeActive and editModeWorldLayout and editModeWorldLayout.decorations then
        decsToRender = editModeWorldLayout.decorations
    end

    -- Draw water rocks (layer 0 - in water, before grass platform)
    for _, dec in ipairs(decsToRender) do
        if (dec.layer or 1) == 0 then
            drawDecoration(dec)
        end
    end

    -- Draw main grass platform (larger for 1920x1080)
    drawGrassPlatform(100, 140, 27, 13)

    -- Draw painted tiles (paths, roads, etc.)
    drawStoredTiles()

    -- Roads and market square removed - use Edit Mode to place custom decorations instead
    -- drawRoads()
    -- drawMarketSquare()

    -- Collect ALL drawable items for layer + Y-sorting
    local drawables = {}

    -- Add decorations (layer 1+)
    for _, dec in ipairs(decsToRender) do
        local layer = dec.layer or 1
        if layer >= 1 then
            -- Get bottom Y for depth sorting
            local sprite = getDecorationSprite(dec)
            local sortY = dec.y  -- decorations anchor at bottom
            table.insert(drawables, {
                type = "decoration",
                data = dec,
                layer = layer,
                y = sortY
            })
        end
    end

    -- Add buildings
    for _, building in ipairs(Town.buildings) do
        local sprite = sprites[building.id]
        if sprite then
            local h = sprite:getHeight() * (building.scale or 1)
            local layer = building.layer or 2  -- Default buildings to layer 2
            table.insert(drawables, {
                type = "building",
                data = building,
                layer = layer,
                y = building.y + h,  -- buildings anchor at top, so bottom = y + h
                isHovered = Town.getBuildingAt(mouseX, mouseY) == building.id
            })
        end
    end

    -- Sort by layer first, then by Y position within each layer
    table.sort(drawables, function(a, b)
        if a.layer ~= b.layer then
            return a.layer < b.layer
        end
        return a.y < b.y
    end)

    -- Draw sorted items (decorations and buildings)
    for _, item in ipairs(drawables) do
        if item.type == "building" then
            drawBuilding(item.data, item.isHovered, designMouseX, designMouseY)
        elseif item.type == "decoration" then
            drawDecoration(item.data)
        end
    end

    -- Draw moving sheep and NPCs in the market area
    -- NPCs are drawn separately as they have their own update logic
    local dt = love.timer.getDelta()
    updateAndDrawSheep(dt)
    updateAndDrawNPCs(dt)

    -- Draw hero departure/arrival animations
    updateAndDrawHeroAnimations(dt)

    -- Draw clouds (floating)
    for _, cloud in ipairs(clouds) do
        local sprite = terrainSprites[cloud.sprite]
        if sprite then
            -- Update cloud position
            cloud.x = cloud.x - cloud.speed * love.timer.getDelta()
            if cloud.x < -200 then
                cloud.x = DESIGN_W + 100
            end

            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.draw(sprite, cloud.x, cloud.y, 0, cloud.scale, cloud.scale)
        end
    end

    -- Restore transform before drawing UI (UI uses screen coordinates)
    love.graphics.pop()

    -- UI Header (screen coordinates, scales to actual screen width)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, 50)

    -- Gold display (offset for settings button)
    Components.drawGold(gameData.gold, 60, 16)

    -- Guild level display
    if GuildSystem and gameData.guild then
        local guildLevel = gameData.guild.level or 1
        love.graphics.setColor(0.4, 0.6, 0.8)
        love.graphics.print("Guild Lv." .. guildLevel, 180, 16)
    end

    -- Day and Time display
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Day " .. gameData.day, 300, 16)

    if TimeSystem then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(TimeSystem.getTimeString(gameData) .. " - " .. TimeSystem.getDayPeriod(gameData), 400, 16)

        if TimeSystem.config.timeScale ~= 1 then
            love.graphics.setColor(Components.colors.warning)
            love.graphics.print(TimeSystem.config.timeScale .. "x", 620, 16)
        end
    end

    -- Active quests indicator
    local activeCount = #gameData.activeQuests
    local questSlots = GuildSystem and GuildSystem.getQuestSlots(gameData) or 2
    love.graphics.setColor(activeCount >= questSlots and Components.colors.warning or Components.colors.textDim)
    love.graphics.print("Quests: " .. activeCount .. "/" .. questSlots, 720, 16)

    -- Resting heroes count
    local restingCount = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "resting" then
            restingCount = restingCount + 1
        end
    end
    if restingCount > 0 then
        love.graphics.setColor(0.6, 0.4, 0.7)
        love.graphics.print("Resting: " .. restingCount, 880, 16)
    end

    -- Heroes count
    local heroSlots = GuildSystem and GuildSystem.getHeroSlots(gameData) or 4
    love.graphics.setColor(#gameData.heroes >= heroSlots and Components.colors.warning or Components.colors.text)
    love.graphics.print("Heroes: " .. #gameData.heroes .. "/" .. heroSlots, 1020, 16)

    -- Time controls hint
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("+/- Speed", 1160, 16)

    -- Graveyard count
    if gameData.graveyard and #gameData.graveyard > 0 then
        love.graphics.setColor(0.6, 0.3, 0.3)
        love.graphics.print("Fallen: " .. #gameData.graveyard, 1280, 16)
    end

end

-- Get building ID at mouse position (screen coordinates)
-- Returns building ID for clickable buildings (used by main.lua to change state)
function Town.getBuildingAt(x, y)
    -- Transform screen coordinates to design coordinates
    updateScale()
    local designX, designY = Town.screenToDesign(x, y)

    for _, building in ipairs(Town.buildings) do
        -- Check if building is clickable (either has name or clickable=true)
        local isClickable = building.name or building.clickable
        if isClickable then
            local sprite = sprites[building.id]
            if sprite then
                local scale = building.scale or 1.0
                local w = sprite:getWidth() * scale
                local h = sprite:getHeight() * scale
                local bx = building.x - w / 2
                local by = building.y

                if Components.isPointInRect(designX, designY, bx, by, w, h) then
                    -- Return lowercase building id for main.lua compatibility
                    -- Use menuTarget if set (but convert to lowercase), otherwise use id
                    if building.menuTarget then
                        return string.lower(building.menuTarget)
                    end
                    return building.id
                end
            end
        end
    end
    return nil
end

-- Hero departure/arrival animation system
-- Guild position (scaled for 1280x720 from 1920x1080)
local GUILD_X = 640  -- Center of screen (960 * 1280/1920)
local GUILD_Y = 280  -- Below guild building
local EXIT_Y = 750   -- Off screen at bottom

-- Add heroes departing the guild (walking out)
function Town.addDepartingHeroes(heroes)
    if not SpriteSystem then
        SpriteSystem = require("systems.sprite_system")
    end

    local spacing = 50
    local startX = GUILD_X - (#heroes - 1) * spacing / 2

    for i, hero in ipairs(heroes) do
        local anim = {
            hero = hero,
            x = startX + (i - 1) * spacing,
            y = GUILD_Y,
            targetY = EXIT_Y,
            speed = 120,  -- pixels per second
            type = "departing",
            animOffset = i * 0.2,
            direction = 1  -- facing right/down
        }
        table.insert(heroAnimations, anim)
    end
end

-- Add heroes arriving at the guild (walking in)
function Town.addArrivingHeroes(heroes)
    if not SpriteSystem then
        SpriteSystem = require("systems.sprite_system")
    end

    local spacing = 50
    local startX = GUILD_X - (#heroes - 1) * spacing / 2

    for i, hero in ipairs(heroes) do
        local anim = {
            hero = hero,
            x = startX + (i - 1) * spacing,
            y = EXIT_Y,
            targetY = GUILD_Y,
            speed = 120,
            type = "arriving",
            animOffset = i * 0.2,
            direction = -1  -- facing left/up
        }
        table.insert(heroAnimations, anim)
    end
end

-- Update and draw hero animations (call from Town.draw)
updateAndDrawHeroAnimations = function(dt)
    if not SpriteSystem then
        SpriteSystem = require("systems.sprite_system")
    end

    local toRemove = {}

    for i, anim in ipairs(heroAnimations) do
        -- Update position
        if anim.type == "departing" then
            anim.y = anim.y + anim.speed * dt
            if anim.y >= anim.targetY then
                table.insert(toRemove, i)
            end
        else  -- arriving
            anim.y = anim.y - anim.speed * dt
            if anim.y <= anim.targetY then
                table.insert(toRemove, i)
            end
        end

        -- Draw hero sprite (using Run animation)
        if anim.hero then
            local animation = "Run"
            local scale = 1.5

            -- Get the sprite
            local sprite = SpriteSystem.loadSprite(anim.hero.class, animation)
            if sprite then
                local spriteH = sprite:getHeight()
                local frameWidth = spriteH  -- Assuming square frames
                local totalFrames = math.floor(sprite:getWidth() / frameWidth)
                if totalFrames < 1 then totalFrames = 1 end

                local frame = math.floor((animTime + anim.animOffset) * 8) % totalFrames
                local quad = love.graphics.newQuad(frame * frameWidth, 0, frameWidth, spriteH, sprite:getDimensions())

                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(sprite, quad, anim.x, anim.y, 0, scale, scale, frameWidth/2, spriteH/2)
            end
        end
    end

    -- Remove completed animations (in reverse order)
    for i = #toRemove, 1, -1 do
        table.remove(heroAnimations, toRemove[i])
    end
end

-- Check if there are active hero animations
function Town.hasActiveAnimations()
    return #heroAnimations > 0
end

-- Clear all animations
function Town.clearAnimations()
    heroAnimations = {}
end

-- Set edit mode state (called from main.lua)
function Town.setEditMode(active, worldLayoutRef)
    editModeActive = active
    editModeWorldLayout = worldLayoutRef
    -- In edit mode, we read directly from editModeWorldLayout in the render functions
    -- This ensures live updates when dragging objects or changing properties
end

return Town
