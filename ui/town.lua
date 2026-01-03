-- Town View Module
-- Renders the town with terrain sprites and clickable buildings

local Components = require("ui.components")

local Town = {}

-- Screen size (1920x1080 default)
local SCREEN_W, SCREEN_H = 1920, 1080

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

-- Load all sprites
function Town.loadSprites()
    if spritesLoaded then return end

    -- Load building sprites
    for _, building in ipairs(Town.buildings) do
        if building.sprite then
            local success, img = pcall(love.graphics.newImage, building.sprite)
            if success then
                sprites[building.id] = img
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

    -- Initialize decorations for larger map
    decorations = {
        -- Trees along left edge
        {type = "tree1", x = 50, y = 400, scale = 0.7, layer = 1, animOffset = 0.0},
        {type = "tree2", x = 80, y = 600, scale = 0.75, layer = 1, animOffset = 0.5},
        {type = "tree1", x = 45, y = 800, scale = 0.7, layer = 1, animOffset = 1.0},
        -- Trees along right edge
        {type = "tree3", x = 1870, y = 380, scale = 0.7, layer = 1, animOffset = 0.3},
        {type = "tree4", x = 1850, y = 580, scale = 0.65, layer = 1, animOffset = 0.8},
        {type = "tree2", x = 1875, y = 780, scale = 0.7, layer = 1, animOffset = 1.2},
        -- Trees in town (spread out)
        {type = "tree1", x = 800, y = 900, scale = 0.6, layer = 2, animOffset = 0.2},
        {type = "tree3", x = 1100, y = 920, scale = 0.55, layer = 2, animOffset = 0.7},
        {type = "tree4", x = 180, y = 850, scale = 0.55, layer = 2, animOffset = 0.4},
        {type = "tree2", x = 1700, y = 900, scale = 0.5, layer = 2, animOffset = 0.9},
        -- Bushes scattered around
        {type = "bush1", x = 300, y = 700, scale = 1.0, layer = 1, animOffset = 0.1},
        {type = "bush2", x = 500, y = 850, scale = 0.9, layer = 2, animOffset = 0.6},
        {type = "bush1", x = 1200, y = 680, scale = 1.0, layer = 1, animOffset = 0.4},
        {type = "bush2", x = 1500, y = 870, scale = 0.85, layer = 2, animOffset = 0.9},
        {type = "bush1", x = 750, y = 680, scale = 0.9, layer = 1, animOffset = 0.2},
        {type = "bush2", x = 1600, y = 650, scale = 0.8, layer = 1, animOffset = 0.5},
        -- Rocks
        {type = "rock1", x = 220, y = 450, scale = 1.2, layer = 1},
        {type = "rock2", x = 1650, y = 420, scale = 1.0, layer = 1},
        {type = "rock3", x = 850, y = 800, scale = 0.9, layer = 1},
        {type = "rock1", x = 1350, y = 850, scale = 1.0, layer = 1},
        {type = "rock2", x = 350, y = 920, scale = 0.85, layer = 2},
        -- Water rocks
        {type = "waterRock1", x = 60, y = 1000, scale = 1.0, layer = 0},
        {type = "waterRock2", x = 1860, y = 980, scale = 0.9, layer = 0},
        {type = "waterRock1", x = 600, y = 1050, scale = 0.8, layer = 0},
        {type = "waterRock2", x = 1400, y = 1040, scale = 0.85, layer = 0}
    }

    -- Initialize moving sheep (in the town center/market area)
    movingSheep = {
        {x = 850, y = 650, targetX = 1050, targetY = 650, speed = 20, scale = 1.3, animOffset = 0.0, direction = 1},
        {x = 1100, y = 700, targetX = 900, targetY = 700, speed = 15, scale = 1.2, animOffset = 0.5, direction = -1},
        {x = 750, y = 750, targetX = 950, targetY = 750, speed = 18, scale = 1.4, animOffset = 1.0, direction = 1},
        {x = 1200, y = 800, targetX = 1000, targetY = 800, speed = 16, scale = 1.25, animOffset = 0.3, direction = -1}
    }

    -- Initialize wandering NPCs (more NPCs for larger town)
    townNPCs = {
        {x = 700, y = 600, targetX = 900, targetY = 600, speed = 25, type = "warrior", animOffset = 0.0, direction = 1},
        {x = 1100, y = 620, targetX = 850, targetY = 620, speed = 22, type = "archer", animOffset = 0.3, direction = -1},
        {x = 1300, y = 650, targetX = 1500, targetY = 650, speed = 20, type = "warrior", animOffset = 0.6, direction = 1},
        {x = 500, y = 700, targetX = 700, targetY = 700, speed = 23, type = "archer", animOffset = 0.9, direction = 1},
        {x = 1400, y = 750, targetX = 1150, targetY = 750, speed = 21, type = "warrior", animOffset = 0.2, direction = -1}
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
        archer_run = "assets/Units/Blue Units/Archer/Archer_Run.png"
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

-- Draw decoration (tree, rock, bush, sheep, houses)
local function drawDecoration(dec)
    local sprite = terrainSprites[dec.type]
    if not sprite then return end

    local scale = dec.scale or 1.0
    local spriteW = sprite:getWidth()
    local spriteH = sprite:getHeight()

    -- Handle animated sprites (spritesheets with horizontal frames)
    if dec.type:find("tree") or dec.type:find("bush") or dec.type == "sheep" then
        -- Frame width equals frame height for these sprites
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
        -- Static sprites (rocks, water rocks, houses)
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

-- Update and draw wandering NPCs
local function updateAndDrawNPCs(dt)
    if not townNPCs then return end

    for _, npc in ipairs(townNPCs) do
        -- Move towards target
        local dx = npc.targetX - npc.x
        if math.abs(dx) < 2 then
            -- Reached target, pick new random target
            npc.direction = npc.direction * -1
            if npc.direction > 0 then
                npc.targetX = npc.x + math.random(100, 200)
            else
                npc.targetX = npc.x - math.random(100, 200)
            end
            -- Clamp to grass area (larger map)
            npc.targetX = math.max(350, math.min(1550, npc.targetX))
        else
            npc.x = npc.x + (npc.direction * npc.speed * dt)
        end

        -- Get sprite based on movement
        local spriteKey = npc.type .. "_run"
        local sprite = terrainSprites[spriteKey]
        if not sprite then return end

        local spriteH = sprite:getHeight()
        local frameWidth = spriteH
        local totalFrames = math.floor(sprite:getWidth() / frameWidth)
        if totalFrames < 1 then totalFrames = 1 end

        local frame = math.floor((animTime + npc.animOffset) * 6) % totalFrames
        local quad = love.graphics.newQuad(frame * frameWidth, 0, frameWidth, spriteH, sprite:getDimensions())

        love.graphics.setColor(1, 1, 1)
        local scale = 0.8
        local scaleX = scale * npc.direction
        love.graphics.draw(sprite, quad, npc.x, npc.y - spriteH * scale, 0, scaleX, scale, frameWidth/2, 0)
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

    -- Update animation time
    animTime = animTime + love.timer.getDelta()

    -- Get time of day for lighting
    local dayProgress = gameData.dayProgress or 0
    local isNight = dayProgress > 0.75 or dayProgress < 0.1

    -- Draw water background
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

    -- Draw water rocks (layer 0 - in water)
    for _, dec in ipairs(decorations) do
        if dec.layer == 0 then
            drawDecoration(dec)
        end
    end

    -- Draw main grass platform (larger for 1920x1080)
    drawGrassPlatform(100, 140, 27, 13)

    -- Draw roads (on top of grass, below buildings)
    drawRoads()

    -- Draw market square decorations
    drawMarketSquare()

    -- Draw decorations layer 1 (behind buildings)
    for _, dec in ipairs(decorations) do
        if dec.layer == 1 then
            drawDecoration(dec)
        end
    end

    -- Collect all drawable items for Y-sorting
    local drawables = {}

    -- Add buildings
    for _, building in ipairs(Town.buildings) do
        local sprite = sprites[building.id]
        if sprite then
            local h = sprite:getHeight() * (building.scale or 1)
            table.insert(drawables, {
                type = "building",
                data = building,
                y = building.y + h,
                isHovered = Town.getBuildingAt(mouseX, mouseY) == building.id
            })
        end
    end

    -- Sort by Y position
    table.sort(drawables, function(a, b) return a.y < b.y end)

    -- Draw sorted items
    for _, item in ipairs(drawables) do
        if item.type == "building" then
            drawBuilding(item.data, item.isHovered, mouseX, mouseY)
        end
    end

    -- Draw moving sheep and NPCs in the market area
    local dt = love.timer.getDelta()
    updateAndDrawSheep(dt)
    updateAndDrawNPCs(dt)

    -- Draw decorations layer 2 (in front)
    for _, dec in ipairs(decorations) do
        if dec.layer == 2 then
            drawDecoration(dec)
        end
    end

    -- Draw clouds (floating)
    for _, cloud in ipairs(clouds) do
        local sprite = terrainSprites[cloud.sprite]
        if sprite then
            -- Update cloud position
            cloud.x = cloud.x - cloud.speed * love.timer.getDelta()
            if cloud.x < -200 then
                cloud.x = SCREEN_W + 100
            end

            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.draw(sprite, cloud.x, cloud.y, 0, cloud.scale, cloud.scale)
        end
    end

    -- Night overlay (darker)
    if isNight then
        love.graphics.setColor(0.05, 0.05, 0.15, 0.55)
        love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)

        -- Draw campfire in market square
        drawCampfire(960, 640, 4.0)

        -- Draw glowing windows on buildings
        drawBuildingWindows()
    end

    -- UI Header (wider for 1920 screen)
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

    -- Day/Night toggle button (moved right for wider screen)
    local isNightTime = TimeSystem and TimeSystem.isNight(gameData) or false
    local progress = gameData.dayProgress or 0

    local canToggle = false
    local timeRemaining = ""
    if isNightTime then
        canToggle = progress >= 0.95
        local remaining = (1.0 - progress) * TimeSystem.config.dayDuration
        timeRemaining = TimeSystem.formatDuration(remaining)
    else
        canToggle = progress >= 0.70
        local remaining = (0.75 - progress) * TimeSystem.config.dayDuration
        timeRemaining = TimeSystem.formatDuration(math.max(0, remaining))
    end

    local btnText = isNightTime and "Move to Day" or "Move to Night"
    local btnColor
    if canToggle then
        btnColor = isNightTime and {0.7, 0.6, 0.3} or {0.3, 0.3, 0.6}
    else
        btnColor = {0.3, 0.3, 0.3}
    end

    local dayNightBtnX = SCREEN_W - 220
    love.graphics.setColor(btnColor)
    love.graphics.rectangle("fill", dayNightBtnX, 8, 170, 34, 5, 5)
    love.graphics.setColor(canToggle and {0.9, 0.9, 0.9} or {0.5, 0.5, 0.5})
    love.graphics.rectangle("line", dayNightBtnX, 8, 170, 34, 5, 5)

    if isNightTime then
        love.graphics.setColor(canToggle and {1, 0.9, 0.5} or {0.6, 0.5, 0.3})
        love.graphics.circle("fill", dayNightBtnX + 20, 25, 8)
    else
        love.graphics.setColor(canToggle and {0.9, 0.9, 1} or {0.5, 0.5, 0.6})
        love.graphics.circle("fill", dayNightBtnX + 20, 25, 8)
        love.graphics.setColor(btnColor)
        love.graphics.circle("fill", dayNightBtnX + 16, 23, 6)
    end

    if canToggle then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(btnText, dayNightBtnX + 35, 15)
    else
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("Wait " .. timeRemaining, dayNightBtnX + 35, 15)
    end

    -- Instructions (centered for larger screen)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Click a building to enter", 0, SCREEN_H - 40, SCREEN_W, "center")
end

-- Check if day/night button was clicked
function Town.getDayNightButtonAt(x, y, gameData, TimeSystem)
    local dayNightBtnX = SCREEN_W - 220
    if not Components.isPointInRect(x, y, dayNightBtnX, 8, 170, 34) then
        return false
    end

    local isNight = TimeSystem and TimeSystem.isNight(gameData) or false
    local progress = gameData.dayProgress or 0

    if isNight then
        return progress >= 0.95
    else
        return progress >= 0.70
    end
end

-- Get building ID at mouse position
function Town.getBuildingAt(x, y)
    for _, building in ipairs(Town.buildings) do
        if building.name then
            local sprite = sprites[building.id]
            if sprite then
                local scale = building.scale or 1.0
                local w = sprite:getWidth() * scale
                local h = sprite:getHeight() * scale
                local bx = building.x - w / 2
                local by = building.y

                if Components.isPointInRect(x, y, bx, by, w, h) then
                    return building.id
                end
            end
        end
    end
    return nil
end

return Town
