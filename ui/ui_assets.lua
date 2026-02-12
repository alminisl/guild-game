-- UI Assets Module
-- Manages loading and drawing of UI sprite assets
-- Uses the Tiny Swords UI Elements pack

local UIAssets = {}

-- Asset paths
local ASSET_PATH = "assets/UI Elements/UI Elements/"

-- Loaded assets cache
local assets = {}

-- ============================================================================
-- ASSET DEFINITIONS
-- ============================================================================

UIAssets.buttons = {
    bigBlue = {
        regular = ASSET_PATH .. "Buttons/BigBlueButton_Regular.png",
        pressed = ASSET_PATH .. "Buttons/BigBlueButton_Pressed.png",
        size = {320, 320}
    },
    bigRed = {
        regular = ASSET_PATH .. "Buttons/BigRedButton_Regular.png",
        pressed = ASSET_PATH .. "Buttons/BigRedButton_Pressed.png",
        size = {320, 320}
    },
    smallBlueRound = {
        regular = ASSET_PATH .. "Buttons/SmallBlueRoundButton_Regular.png",
        pressed = ASSET_PATH .. "Buttons/SmallBlueRoundButton_Pressed.png"
    },
    smallBlueSquare = {
        regular = ASSET_PATH .. "Buttons/SmallBlueSquareButton_Regular.png",
        pressed = ASSET_PATH .. "Buttons/SmallBlueSquareButton_Pressed.png"
    },
    smallRedRound = {
        regular = ASSET_PATH .. "Buttons/SmallRedRoundButton_Regular.png",
        pressed = ASSET_PATH .. "Buttons/SmallRedRoundButton_Pressed.png"
    },
    smallRedSquare = {
        regular = ASSET_PATH .. "Buttons/SmallRedSquareButton_Regular.png",
        pressed = ASSET_PATH .. "Buttons/SmallRedSquareButton_Pressed.png"
    },
    tinyRoundBlue = {
        regular = ASSET_PATH .. "Buttons/TinyRoundBlueButton.png"
    },
    tinyRoundRed = {
        regular = ASSET_PATH .. "Buttons/TinyRoundRedButton.png"
    },
    tinySquareBlue = {
        regular = ASSET_PATH .. "Buttons/TinySquareBlueButton.png"
    },
    tinySquareRed = {
        regular = ASSET_PATH .. "Buttons/TinySquareRedButton.png"
    }
}

UIAssets.bars = {
    big = {
        base = ASSET_PATH .. "Bars/BigBar_Base.png",
        fill = ASSET_PATH .. "Bars/BigBar_Fill.png",
        size = {320, 64}
    },
    small = {
        base = ASSET_PATH .. "Bars/SmallBar_Base.png",
        fill = ASSET_PATH .. "Bars/SmallBar_Fill.png"
    }
}

UIAssets.banners = {
    regular = ASSET_PATH .. "Banners/Banner.png",
    slots = ASSET_PATH .. "Banners/Banner_Slots.png"
}

UIAssets.papers = {
    regular = ASSET_PATH .. "Papers/RegularPaper.png",
    special = ASSET_PATH .. "Papers/SpecialPaper.png"
}

UIAssets.ribbons = {
    big = ASSET_PATH .. "Ribbons/BigRibbons.png",
    small = ASSET_PATH .. "Ribbons/SmallRibbons.png"
}

UIAssets.woodTable = {
    table = ASSET_PATH .. "Wood Table/WoodTable.png",
    slots = ASSET_PATH .. "Wood Table/WoodTable_Slots.png"
}

-- Icon paths (12 icons available)
UIAssets.icons = {}
for i = 1, 12 do
    UIAssets.icons[i] = ASSET_PATH .. "Icons/Icon_" .. string.format("%02d", i) .. ".png"
end

-- ============================================================================
-- LOADING FUNCTIONS
-- ============================================================================

-- Load a single asset
local function loadAsset(path)
    if assets[path] then
        return assets[path]
    end
    
    local success, image = pcall(love.graphics.newImage, path)
    if success then
        assets[path] = image
        return image
    else
        print("Warning: Failed to load UI asset: " .. path)
        return nil
    end
end

-- Preload all UI assets
function UIAssets.preloadAll()
    print("Loading UI assets...")
    local count = 0
    
    -- Load buttons
    for _, btnData in pairs(UIAssets.buttons) do
        if btnData.regular then loadAsset(btnData.regular); count = count + 1 end
        if btnData.pressed then loadAsset(btnData.pressed); count = count + 1 end
    end
    
    -- Load bars
    for _, barData in pairs(UIAssets.bars) do
        if barData.base then loadAsset(barData.base); count = count + 1 end
        if barData.fill then loadAsset(barData.fill); count = count + 1 end
    end
    
    -- Load other assets
    if UIAssets.banners.regular then loadAsset(UIAssets.banners.regular); count = count + 1 end
    if UIAssets.banners.slots then loadAsset(UIAssets.banners.slots); count = count + 1 end
    if UIAssets.papers.regular then loadAsset(UIAssets.papers.regular); count = count + 1 end
    if UIAssets.papers.special then loadAsset(UIAssets.papers.special); count = count + 1 end
    if UIAssets.ribbons.big then loadAsset(UIAssets.ribbons.big); count = count + 1 end
    if UIAssets.ribbons.small then loadAsset(UIAssets.ribbons.small); count = count + 1 end
    if UIAssets.woodTable.table then loadAsset(UIAssets.woodTable.table); count = count + 1 end
    if UIAssets.woodTable.slots then loadAsset(UIAssets.woodTable.slots); count = count + 1 end
    
    -- Load icons
    for _, iconPath in pairs(UIAssets.icons) do
        loadAsset(iconPath)
        count = count + 1
    end
    
    print("Loaded " .. count .. " UI assets")
end

-- ============================================================================
-- DRAWING FUNCTIONS
-- ============================================================================

-- Draw a button with the asset sprites
function UIAssets.drawButton(buttonType, x, y, w, h, options)
    options = options or {}
    local pressed = options.pressed or false
    local disabled = options.disabled or false
    local text = options.text
    local color = options.color or {1, 1, 1, 1}
    
    local btnData = UIAssets.buttons[buttonType]
    if not btnData then
        print("Warning: Unknown button type: " .. tostring(buttonType))
        return
    end
    
    local imagePath = (pressed and btnData.pressed) or btnData.regular
    local image = loadAsset(imagePath)
    
    if not image then return end
    
    -- Calculate scale to fit button size
    local imgW, imgH = image:getDimensions()
    local scaleX = w / imgW
    local scaleY = h / imgH
    
    -- Apply color tint (darker if disabled)
    if disabled then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
    else
        love.graphics.setColor(color)
    end
    
    -- Draw button image
    love.graphics.draw(image, x, y, 0, scaleX, scaleY)
    
    -- Draw text if provided
    if text and not disabled then
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text, x + (w - textWidth) / 2, y + (h - textHeight) / 2)
    elseif text and disabled then
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text, x + (w - textWidth) / 2, y + (h - textHeight) / 2)
    end
end

-- Draw a progress bar using the bar assets
function UIAssets.drawProgressBar(barType, progress, x, y, w, h, options)
    options = options or {}
    local fillColor = options.fillColor or {0.3, 0.7, 0.9, 1}
    local text = options.text
    
    local barData = UIAssets.bars[barType]
    if not barData then
        print("Warning: Unknown bar type: " .. tostring(barType))
        return
    end
    
    local baseImage = loadAsset(barData.base)
    local fillImage = loadAsset(barData.fill)
    
    if not baseImage or not fillImage then return end
    
    -- Calculate scale
    local imgW, imgH = baseImage:getDimensions()
    local scaleX = w / imgW
    local scaleY = h / imgH
    
    -- Draw base
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(baseImage, x, y, 0, scaleX, scaleY)
    
    -- Draw fill (with scissor for progress)
    love.graphics.setColor(fillColor)
    local fillWidth = w * math.min(progress, 1)
    
    -- Use scissor to clip the fill image
    love.graphics.setScissor(x, y, fillWidth, h)
    love.graphics.draw(fillImage, x, y, 0, scaleX, scaleY)
    love.graphics.setScissor()
    
    -- Draw text
    if text then
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text, x + (w - textWidth) / 2, y + (h - textHeight) / 2)
    end
end

-- Draw a banner
function UIAssets.drawBanner(x, y, w, h, options)
    options = options or {}
    local useSlots = options.useSlots or false
    local color = options.color or {1, 1, 1, 1}
    local text = options.text
    
    local imagePath = useSlots and UIAssets.banners.slots or UIAssets.banners.regular
    local image = loadAsset(imagePath)
    
    if not image then return end
    
    -- Calculate scale
    local imgW, imgH = image:getDimensions()
    local scaleX = w / imgW
    local scaleY = h / imgH
    
    love.graphics.setColor(color)
    love.graphics.draw(image, x, y, 0, scaleX, scaleY)
    
    -- Draw text
    if text then
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()
        love.graphics.print(text, x + (w - textWidth) / 2, y + (h - textHeight) / 2)
    end
end

-- Draw a paper background - SIMPLIFIED VERSION
-- Just draws the CENTER piece stretched to fill the ENTIRE panel
function UIAssets.drawPaper(x, y, w, h, options)
    options = options or {}
    local special = options.special or false
    local color = options.color or {1, 1, 1, 1}
    local alpha = options.alpha or 1
    
    local imagePath = special and UIAssets.papers.special or UIAssets.papers.regular
    local image = loadAsset(imagePath)
    
    if not image then return end
    
    -- Get actual sprite dimensions
    local imgW, imgH = image:getDimensions()
    
    -- Calculate center section position in sprite
    -- Sprite is 3x3 grid, so center is the middle third
    local sectionSize = math.floor(imgW / 3)
    local centerX_sprite = sectionSize
    local centerY_sprite = sectionSize
    local centerW_sprite = sectionSize
    local centerH_sprite = sectionSize
    
    -- Create quad for center section
    local centerQuad = love.graphics.newQuad(
        centerX_sprite, centerY_sprite, 
        centerW_sprite, centerH_sprite, 
        imgW, imgH
    )
    
    -- Apply color
    love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, (color[4] or 1) * alpha)
    
    -- Calculate scale to stretch center piece across ENTIRE panel (no margins)
    local scaleX = w / centerW_sprite
    local scaleY = h / centerH_sprite
    
    -- Draw center piece stretched to fill FULL panel from x,y to x+w,y+h
    love.graphics.draw(image, centerQuad, x, y, 0, scaleX, scaleY)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw an icon
function UIAssets.drawIcon(iconIndex, x, y, size, options)
    options = options or {}
    local color = options.color or {1, 1, 1, 1}
    
    if iconIndex < 1 or iconIndex > 12 then
        print("Warning: Icon index must be 1-12, got: " .. tostring(iconIndex))
        return
    end
    
    local image = loadAsset(UIAssets.icons[iconIndex])
    if not image then return end
    
    local imgW, imgH = image:getDimensions()
    local scale = size / imgW
    
    love.graphics.setColor(color)
    love.graphics.draw(image, x, y, 0, scale, scale)
end

-- Draw wood table background
function UIAssets.drawWoodTable(x, y, w, h, options)
    options = options or {}
    local useSlots = options.useSlots or false
    local color = options.color or {1, 1, 1, 1}
    
    local imagePath = useSlots and UIAssets.woodTable.slots or UIAssets.woodTable.table
    local image = loadAsset(imagePath)
    
    if not image then return end
    
    local imgW, imgH = image:getDimensions()
    local scaleX = w / imgW
    local scaleY = h / imgH
    
    love.graphics.setColor(color)
    love.graphics.draw(image, x, y, 0, scaleX, scaleY)
end

return UIAssets
