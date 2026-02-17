-- Town Map Module
-- Enhanced version with animated decorations, water, and floating gold labels

local Components = require("ui.components")

local TownMap = {}

-- Screen dimensions (Full HD)
local SCREEN = {
    width = 1920,
    height = 1080
}

-- Building definitions (8 total: 4 interactive + 4 decorative)
local buildings = {
    -- === INTERACTIVE LOCATIONS ===
    {
        id = "guild",
        name = "Guild Hall",
        sprite = "assets/Buildings/Blue Buildings/Castle.png",
        x = 960,   -- Center
        y = 300,   -- Upper third
        scale = 1.2,
        menu = "guild",
        description = "Manage heroes, quests, and guild operations"
    },
    {
        id = "tavern",
        name = "Tavern",
        sprite = "assets/Buildings/Blue Buildings/Monastery.png",
        x = 450,
        y = 550,
        scale = 1.0,
        menu = "tavern",
        description = "Recruit new heroes"
    },
    {
        id = "potion",
        name = "Potion Shop",
        sprite = "assets/Buildings/Blue Buildings/House1.png",
        x = 750,
        y = 500,
        scale = 0.9,
        menu = "potion",
        description = "Buy health potions and healing items"
    },
    {
        id = "armory",
        name = "Armory",
        sprite = "assets/Buildings/Blue Buildings/Barracks.png",
        x = 1470,
        y = 550,
        scale = 1.0,
        menu = "armory",
        description = "Buy equipment and craft gear"
    },
    
    -- === DECORATIVE BUILDINGS ===
    {
        id = "house1",
        sprite = "assets/Buildings/Blue Buildings/House2.png",
        x = 250,
        y = 800,
        scale = 0.75,
        menu = nil
    },
    {
        id = "house2",
        sprite = "assets/Buildings/Blue Buildings/House3.png",
        x = 650,
        y = 850,
        scale = 0.7,
        menu = nil
    },
    {
        id = "house3",
        sprite = "assets/Buildings/Blue Buildings/House2.png",
        x = 1250,
        y = 830,
        scale = 0.75,
        menu = nil
    },
    {
        id = "tower",
        sprite = "assets/Buildings/Blue Buildings/Tower.png",
        x = 1700,
        y = 720,
        scale = 0.9,
        menu = nil
    }
}

-- Decoration definitions
local trees = {
    {sprite = "Tree1", x = 150, y = 400, scale = 1.0, frame = 0, frameTimer = 0, frameDelay = 0.15},
    {sprite = "Tree2", x = 280, y = 480, scale = 0.9, frame = 0, frameTimer = 0, frameDelay = 0.12},
    {sprite = "Tree3", x = 1650, y = 420, scale = 1.0, frame = 0, frameTimer = 0, frameDelay = 0.18},
    {sprite = "Tree4", x = 1780, y = 500, scale = 0.85, frame = 0, frameTimer = 0, frameDelay = 0.14},
    {sprite = "Tree1", x = 100, y = 700, scale = 0.8, frame = 0, frameTimer = 0, frameDelay = 0.16}
}

local bushes = {
    {sprite = "Bushe1", x = 400, y = 750, scale = 0.7, frame = 0, frameTimer = 0, frameDelay = 0.1},
    {sprite = "Bushe2", x = 1550, y = 780, scale = 0.65, frame = 0, frameTimer = 0, frameDelay = 0.12},
    {sprite = "Bushe3", x = 850, y = 900, scale = 0.6, frame = 0, frameTimer = 0, frameDelay = 0.11},
    {sprite = "Bushe4", x = 1350, y = 880, scale = 0.6, frame = 0, frameTimer = 0, frameDelay = 0.09}
}

local rocks = {
    {sprite = "Rock1", x = 350, y = 820, scale = 0.6},
    {sprite = "Rock2", x = 1500, y = 850, scale = 0.55},
    {sprite = "Rock3", x = 1050, y = 950, scale = 0.5},
    {sprite = "Rock4", x = 200, y = 600, scale = 0.45}
}

-- Water pond state
local water = {
    x = 1600,
    y = 950,
    width = 280,
    height = 160,
    foamFrame = 0,
    foamTimer = 0,
    foamDelay = 0.08
}

-- Cloud state
local clouds = {}

-- Loaded sprites
local sprites = {}
local cloudSprites = {}
local treeSprites = {}
local bushSprites = {}
local rockSprites = {}
local waterFoamSprite = nil
local hoveredBuilding = nil

-- Helper: Load animated sprite sheet (horizontal strip)
local function loadAnimatedSprite(path, frameCount)
    local success, img = pcall(love.graphics.newImage, path)
    if not success then
        print("Failed to load: " .. path)
        return nil
    end
    
    local w, h = img:getDimensions()
    local frameWidth = w / frameCount
    
    local frames = {}
    for i = 0, frameCount - 1 do
        table.insert(frames, love.graphics.newQuad(
            i * frameWidth, 0, frameWidth, h, w, h
        ))
    end
    
    return {
        image = img,
        frames = frames,
        frameCount = frameCount,
        frameWidth = frameWidth,
        frameHeight = h
    }
end

-- Initialize clouds
local function initClouds()
    clouds = {}
    for i = 1, 6 do
        table.insert(clouds, {
            spriteId = math.random(1, 8),
            x = math.random(-200, SCREEN.width),
            y = math.random(30, 250),
            speed = math.random(8, 20),
            scale = math.random(70, 130) / 100,
            opacity = math.random(50, 85) / 100
        })
    end
end

-- Load all assets
function TownMap.load()
    -- Load building sprites
    for _, building in ipairs(buildings) do
        local success, img = pcall(love.graphics.newImage, building.sprite)
        if success then
            sprites[building.id] = img
        else
            print("Failed to load sprite: " .. building.sprite)
        end
    end
    
    -- Load cloud sprites
    for i = 1, 8 do
        local path = "assets/Terrain/Decorations/Clouds/Clouds_0" .. i .. ".png"
        local success, img = pcall(love.graphics.newImage, path)
        if success then
            cloudSprites[i] = img
        else
            print("Failed to load cloud: " .. path)
        end
    end
    
    -- Load tree sprites (animated, 8 frames)
    treeSprites = {
        Tree1 = loadAnimatedSprite("assets/Terrain/Resources/Wood/Trees/Tree1.png", 8),
        Tree2 = loadAnimatedSprite("assets/Terrain/Resources/Wood/Trees/Tree2.png", 8),
        Tree3 = loadAnimatedSprite("assets/Terrain/Resources/Wood/Trees/Tree3.png", 8),
        Tree4 = loadAnimatedSprite("assets/Terrain/Resources/Wood/Trees/Tree4.png", 8)
    }
    
    -- Load bush sprites (animated, 8 frames)
    bushSprites = {
        Bushe1 = loadAnimatedSprite("assets/Terrain/Decorations/Bushes/Bushe1.png", 8),
        Bushe2 = loadAnimatedSprite("assets/Terrain/Decorations/Bushes/Bushe2.png", 8),
        Bushe3 = loadAnimatedSprite("assets/Terrain/Decorations/Bushes/Bushe3.png", 8),
        Bushe4 = loadAnimatedSprite("assets/Terrain/Decorations/Bushes/Bushe4.png", 8)
    }
    
    -- Load rock sprites (static)
    local rockPaths = {
        "assets/Terrain/Decorations/Rocks/Rock1.png",
        "assets/Terrain/Decorations/Rocks/Rock2.png",
        "assets/Terrain/Decorations/Rocks/Rock3.png",
        "assets/Terrain/Decorations/Rocks/Rock4.png"
    }
    for i, path in ipairs(rockPaths) do
        local success, img = pcall(love.graphics.newImage, path)
        if success then
            rockSprites["Rock" .. i] = img
        else
            print("Failed to load rock: " .. path)
        end
    end
    
    -- Load water foam sprite (animated, 8 frames)
    waterFoamSprite = loadAnimatedSprite("assets/Terrain/Tileset/Water Foam.png", 8)
    
    -- Initialize clouds
    initClouds()
end

-- Update animations
local function updateClouds(dt)
    for _, cloud in ipairs(clouds) do
        cloud.x = cloud.x + cloud.speed * dt
        if cloud.x > SCREEN.width + 150 then
            cloud.x = -150
            cloud.y = math.random(30, 250)
            cloud.spriteId = math.random(1, 8)
        end
    end
end

local function updateTrees(dt)
    for _, tree in ipairs(trees) do
        tree.frameTimer = tree.frameTimer + dt
        if tree.frameTimer >= tree.frameDelay then
            tree.frameTimer = tree.frameTimer - tree.frameDelay
            local spriteData = treeSprites[tree.sprite]
            if spriteData then
                tree.frame = (tree.frame + 1) % spriteData.frameCount
            end
        end
    end
end

local function updateBushes(dt)
    for _, bush in ipairs(bushes) do
        bush.frameTimer = bush.frameTimer + dt
        if bush.frameTimer >= bush.frameDelay then
            bush.frameTimer = bush.frameTimer - bush.frameDelay
            local spriteData = bushSprites[bush.sprite]
            if spriteData then
                bush.frame = (bush.frame + 1) % spriteData.frameCount
            end
        end
    end
end

local function updateWater(dt)
    water.foamTimer = water.foamTimer + dt
    if water.foamTimer >= water.foamDelay then
        water.foamTimer = water.foamTimer - water.foamDelay
        water.foamFrame = (water.foamFrame + 1) % 8
    end
end

-- Update function
function TownMap.update(dt)
    -- Update animations
    updateClouds(dt)
    updateTrees(dt)
    updateBushes(dt)
    updateWater(dt)
    
    -- Update hover state
    local mx, my = love.mouse.getPosition()
    hoveredBuilding = nil
    
    for _, building in ipairs(buildings) do
        local sprite = sprites[building.id]
        if sprite and building.menu then
            local scale = building.scale or 1.0
            local w = sprite:getWidth() * scale
            local h = sprite:getHeight() * scale
            local bx = building.x - w/2
            local by = building.y - h/2
            
            if mx >= bx and mx <= bx + w and my >= by and my <= by + h then
                hoveredBuilding = building
                break
            end
        end
    end
end

-- Draw functions
local function drawSky()
    local skyTop = {0.4, 0.6, 0.9}
    local skyBottom = {0.6, 0.75, 0.95}
    
    for y = 0, SCREEN.height do
        local t = y / SCREEN.height
        love.graphics.setColor(
            skyTop[1] + (skyBottom[1] - skyTop[1]) * t,
            skyTop[2] + (skyBottom[2] - skyTop[2]) * t,
            skyTop[3] + (skyBottom[3] - skyTop[3]) * t
        )
        love.graphics.line(0, y, SCREEN.width, y)
    end
end

local function drawClouds()
    for _, cloud in ipairs(clouds) do
        local sprite = cloudSprites[cloud.spriteId]
        if sprite then
            love.graphics.setColor(1, 1, 1, cloud.opacity)
            love.graphics.draw(sprite, cloud.x, cloud.y, 0, cloud.scale, cloud.scale)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawGround()
    love.graphics.setColor(0.35, 0.55, 0.3)
    love.graphics.rectangle("fill", 0, SCREEN.height * 0.55, SCREEN.width, SCREEN.height * 0.45)
end

local function drawWater()
    -- Base water
    love.graphics.setColor(0.25, 0.45, 0.65, 0.9)
    love.graphics.ellipse("fill", water.x, water.y, water.width, water.height)
    
    -- Inner lighter water
    love.graphics.setColor(0.35, 0.55, 0.75, 0.8)
    love.graphics.ellipse("fill", water.x, water.y, water.width - 15, water.height - 12)
    
    -- Animated foam
    if waterFoamSprite and waterFoamSprite.frames then
        love.graphics.setColor(1, 1, 1, 0.6)
        local scaleX = (water.width * 2) / waterFoamSprite.frameWidth
        local scaleY = (water.height * 2) / waterFoamSprite.frameHeight
        love.graphics.draw(
            waterFoamSprite.image,
            waterFoamSprite.frames[water.foamFrame + 1],
            water.x - water.width,
            water.y - water.height,
            0, scaleX, scaleY
        )
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawRoad()
    love.graphics.setColor(0.55, 0.45, 0.35)
    love.graphics.ellipse("fill", SCREEN.width / 2, SCREEN.height * 0.72, 550, 120)
    love.graphics.setColor(0.5, 0.4, 0.3)
    love.graphics.ellipse("fill", SCREEN.width / 2, SCREEN.height * 0.72, 520, 105)
end

local function createRenderables()
    local renderables = {}
    
    -- Add buildings
    for _, b in ipairs(buildings) do
        table.insert(renderables, {type = "building", data = b, y = b.y})
    end
    
    -- Add trees
    for _, t in ipairs(trees) do
        table.insert(renderables, {type = "tree", data = t, y = t.y})
    end
    
    -- Add bushes
    for _, bush in ipairs(bushes) do
        table.insert(renderables, {type = "bush", data = bush, y = bush.y})
    end
    
    -- Add rocks
    for _, rock in ipairs(rocks) do
        table.insert(renderables, {type = "rock", data = rock, y = rock.y})
    end
    
    -- Sort by Y coordinate (top to bottom)
    table.sort(renderables, function(a, b) return a.y < b.y end)
    
    return renderables
end

local function drawBuilding(building)
    local sprite = sprites[building.id]
    if not sprite then return end
    
    local scale = building.scale or 1.0
    local w = sprite:getWidth() * scale
    local h = sprite:getHeight() * scale
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", building.x, building.y + h/2 - 10, w * 0.4, 15)
    
    -- Building (highlight if hovered and clickable)
    if hoveredBuilding == building and building.menu then
        love.graphics.setColor(1.15, 1.15, 1.15)
    else
        love.graphics.setColor(1, 1, 1)
    end
    love.graphics.draw(sprite, building.x - w/2, building.y - h/2, 0, scale, scale)
end

local function drawTree(tree)
    local spriteData = treeSprites[tree.sprite]
    if not spriteData then return end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        spriteData.image,
        spriteData.frames[tree.frame + 1],
        tree.x,
        tree.y,
        0, tree.scale, tree.scale,
        spriteData.frameWidth / 2,
        spriteData.frameHeight
    )
end

local function drawBush(bush)
    local spriteData = bushSprites[bush.sprite]
    if not spriteData then return end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        spriteData.image,
        spriteData.frames[bush.frame + 1],
        bush.x,
        bush.y,
        0, bush.scale, bush.scale,
        spriteData.frameWidth / 2,
        spriteData.frameHeight
    )
end

local function drawRock(rock)
    local sprite = rockSprites[rock.sprite]
    if not sprite then return end
    
    love.graphics.setColor(1, 1, 1, 1)
    local w, h = sprite:getDimensions()
    love.graphics.draw(sprite, rock.x, rock.y, 0, rock.scale, rock.scale, w/2, h)
end

local function drawLabels()
    for _, building in ipairs(buildings) do
        if building.menu then
            local sprite = sprites[building.id]
            if sprite then
                local scale = building.scale or 1.0
                local h = sprite:getHeight() * scale
                local labelX = building.x
                local labelY = building.y - h/2 - 35
                
                -- Shadow
                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.printf(building.name, labelX - 150 + 2, labelY + 2, 300, "center")
                
                -- Gold text
                love.graphics.setColor(1, 0.85, 0.3)
                love.graphics.printf(building.name, labelX - 150, labelY, 300, "center")
            end
        end
    end
end

local function drawTooltip(building)
    local mx, my = love.mouse.getPosition()
    local tooltipWidth = 280
    local tooltipX = math.min(mx + 15, SCREEN.width - tooltipWidth - 10)
    local tooltipY = my + 15
    
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, 60, 5, 5)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(building.name, tooltipX + 10, tooltipY + 8)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(building.description, tooltipX + 10, tooltipY + 30, tooltipWidth - 20, "left")
end

local function drawUI(gameData)
    -- Title
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", SCREEN.width/2 - 150, 15, 300, 45, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("TOWN OF AVENTHEIM", 0, 26, SCREEN.width, "center")
    
    -- Gold display
    Components.drawGold(gameData.gold, 30, 22)
    
    -- Day counter
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", SCREEN.width - 140, 15, 120, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Day " .. (gameData.day or 1), SCREEN.width - 140, 24, 120, "center")
end

-- Main draw function
function TownMap.draw(gameData)
    -- 1. Sky
    drawSky()
    
    -- 2. Clouds
    drawClouds()
    
    -- 3. Ground
    drawGround()
    
    -- 4. Water
    drawWater()
    
    -- 5. Road
    drawRoad()
    
    -- 6. Unified depth-sorted rendering
    local renderables = createRenderables()
    for _, r in ipairs(renderables) do
        if r.type == "building" then
            drawBuilding(r.data)
        elseif r.type == "tree" then
            drawTree(r.data)
        elseif r.type == "bush" then
            drawBush(r.data)
        elseif r.type == "rock" then
            drawRock(r.data)
        end
    end
    
    -- 7. Gold labels (on top)
    drawLabels()
    
    -- 8. Tooltip
    if hoveredBuilding and hoveredBuilding.description then
        drawTooltip(hoveredBuilding)
    end
    
    -- 9. UI elements
    drawUI(gameData)
end

-- Handle click - returns menu to open or nil
function TownMap.handleClick(x, y)
    for _, building in ipairs(buildings) do
        local sprite = sprites[building.id]
        if sprite and building.menu then
            local scale = building.scale or 1.0
            local w = sprite:getWidth() * scale
            local h = sprite:getHeight() * scale
            local bx = building.x - w/2
            local by = building.y - h/2
            
            if x >= bx and x <= bx + w and y >= by and y <= by + h then
                return building.menu
            end
        end
    end
    return nil
end

-- Get hovered building (for cursor changes, etc.)
function TownMap.getHoveredBuilding()
    return hoveredBuilding
end

return TownMap
