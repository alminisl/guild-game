-- Sprite System Module
-- Handles loading and animating character sprites

local SpriteSystem = {}

-- Cache for loaded sprite sheets
local spriteCache = {}

-- Animation state for each hero (keyed by hero ID)
local animationStates = {}

-- Configuration
local config = {
    frameWidth = 100,
    frameHeight = 100,
    defaultFPS = 8,  -- Frames per second for idle animation
    basePath = "assets/Characters(100x100)"
}

-- Class to sprite folder mapping
local classToSprite = {
    -- Base classes
    Knight = "Knight",
    Archer = "Archer",
    Mage = "Wizard",
    Priest = "Priest",
    Rogue = "Swordsman",
    Ranger = "Soldier",

    -- Awakened classes
    Paladin = "Knight Templar",
    Hawkeye = "Archer",  -- Same sprite, could tint later
    Archmage = "Wizard",  -- Same sprite, could tint later
    Shadow = "Swordsman",  -- Same sprite, could tint later
    Saint = "Priest",  -- Same sprite, could tint later
    Warden = "Lancer"
}

-- Get sprite path for a class
local function getSpritePath(class, animation)
    local spriteFolder = classToSprite[class]
    if not spriteFolder then
        spriteFolder = "Knight"  -- Default fallback
    end

    animation = animation or "Idle"

    -- Path format: basePath/[Folder]/[Folder]/[Folder]-[Animation].png
    return string.format("%s/%s/%s/%s-%s.png",
        config.basePath, spriteFolder, spriteFolder, spriteFolder, animation)
end

-- Load a sprite sheet and create quads
function SpriteSystem.loadSprite(class, animation)
    animation = animation or "Idle"
    local cacheKey = class .. "_" .. animation

    -- Return cached sprite if available
    if spriteCache[cacheKey] then
        return spriteCache[cacheKey]
    end

    local path = getSpritePath(class, animation)

    -- Try to load the image
    local success, image = pcall(function()
        return love.graphics.newImage(path)
    end)

    if not success or not image then
        print("Failed to load sprite: " .. path)
        return nil
    end

    -- Use nearest neighbor filtering for crisp pixel art
    image:setFilter("nearest", "nearest")

    -- Calculate number of frames
    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    local frameCount = math.floor(imageWidth / config.frameWidth)

    -- Create quads for each frame
    local quads = {}
    for i = 0, frameCount - 1 do
        local quad = love.graphics.newQuad(
            i * config.frameWidth, 0,
            config.frameWidth, config.frameHeight,
            imageWidth, imageHeight
        )
        table.insert(quads, quad)
    end

    -- Cache the sprite data
    local spriteData = {
        image = image,
        quads = quads,
        frameCount = frameCount,
        frameWidth = config.frameWidth,
        frameHeight = config.frameHeight
    }

    spriteCache[cacheKey] = spriteData
    return spriteData
end

-- Get or create animation state for a hero
local function getAnimationState(heroId)
    if not animationStates[heroId] then
        animationStates[heroId] = {
            currentFrame = 1,
            timer = 0,
            fps = config.defaultFPS
        }
    end
    return animationStates[heroId]
end

-- Update animation for a hero
function SpriteSystem.update(heroId, dt, frameCount)
    local state = getAnimationState(heroId)
    state.timer = state.timer + dt

    local frameTime = 1 / state.fps
    if state.timer >= frameTime then
        state.timer = state.timer - frameTime
        state.currentFrame = state.currentFrame + 1
        if state.currentFrame > (frameCount or 6) then
            state.currentFrame = 1
        end
    end

    return state.currentFrame
end

-- Draw a hero sprite
function SpriteSystem.draw(hero, x, y, scale, animation)
    if not hero or not hero.class then return end

    animation = animation or "Idle"
    scale = scale or 1

    -- Load sprite if not cached
    local spriteData = SpriteSystem.loadSprite(hero.class, animation)
    if not spriteData then return end

    -- Get current animation frame
    local state = getAnimationState(hero.id)
    local frameIndex = math.min(state.currentFrame, spriteData.frameCount)

    -- Draw the sprite
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        spriteData.image,
        spriteData.quads[frameIndex],
        x, y,
        0,  -- rotation
        scale, scale,
        spriteData.frameWidth / 2,  -- origin x (center)
        spriteData.frameHeight / 2   -- origin y (center)
    )
end

-- Draw sprite centered at position with custom size
function SpriteSystem.drawCentered(hero, x, y, width, height, animation)
    if not hero or not hero.class then return end

    animation = animation or "Idle"

    -- Load sprite if not cached
    local spriteData = SpriteSystem.loadSprite(hero.class, animation)
    if not spriteData then return end

    -- Calculate scale to fit desired dimensions
    local scaleX = width / spriteData.frameWidth
    local scaleY = height / spriteData.frameHeight
    local scale = math.min(scaleX, scaleY)

    -- Get current animation frame
    local state = getAnimationState(hero.id)
    local frameIndex = math.min(state.currentFrame, spriteData.frameCount)

    -- Draw the sprite centered
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        spriteData.image,
        spriteData.quads[frameIndex],
        x, y,
        0,  -- rotation
        scale, scale,
        spriteData.frameWidth / 2,  -- origin x (center)
        spriteData.frameHeight / 2   -- origin y (center)
    )
end

-- Draw a static sprite (single frame, no animation)
function SpriteSystem.drawStatic(hero, x, y, width, height, frameIndex)
    if not hero or not hero.class then return end

    -- Load sprite if not cached
    local spriteData = SpriteSystem.loadSprite(hero.class, "Idle")
    if not spriteData then return end

    -- Calculate scale to fit desired dimensions
    local scaleX = width / spriteData.frameWidth
    local scaleY = height / spriteData.frameHeight
    local scale = math.min(scaleX, scaleY)

    -- Use first frame or specified frame
    frameIndex = frameIndex or 1
    frameIndex = math.min(frameIndex, spriteData.frameCount)

    -- Draw the sprite centered
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        spriteData.image,
        spriteData.quads[frameIndex],
        x, y,
        0,  -- rotation
        scale, scale,
        spriteData.frameWidth / 2,  -- origin x (center)
        spriteData.frameHeight / 2   -- origin y (center)
    )
end

-- Update all hero animations (call from love.update)
function SpriteSystem.updateAll(heroes, dt)
    for _, hero in ipairs(heroes) do
        local spriteData = SpriteSystem.loadSprite(hero.class, "Idle")
        if spriteData then
            SpriteSystem.update(hero.id, dt, spriteData.frameCount)
        end
    end
end

-- Clear animation state for a hero (e.g., when hero is removed)
function SpriteSystem.clearState(heroId)
    animationStates[heroId] = nil
end

-- Preload all class sprites
function SpriteSystem.preloadAll()
    for class, _ in pairs(classToSprite) do
        SpriteSystem.loadSprite(class, "Idle")
    end
    print("Preloaded all hero sprites")
end

-- Get the class to sprite mapping (for debugging/display)
function SpriteSystem.getClassMapping()
    return classToSprite
end

-- Check if a class has a sprite available
function SpriteSystem.hasSprite(class)
    return classToSprite[class] ~= nil
end

return SpriteSystem
