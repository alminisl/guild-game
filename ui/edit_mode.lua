-- Edit Mode Module
-- Comprehensive world editor for placing buildings, decorations, NPCs with behaviors
-- Supports dynamic asset browsing, waypoint editing, and inline property editing

local Components = require("ui.components")
local json = require("utils.json")
local Logger = require("utils.logger")

local EditMode = {}

-- Design dimensions (same as Town)
local DESIGN_W, DESIGN_H = 1920, 1080

-- Tool types
local TOOLS = {
    SELECT = "select",
    PLACE = "place",
    WAYPOINT = "waypoint",  -- For adding waypoints to patrol NPCs
    TILE_PAINT = "tile_paint"  -- For painting tiles from tilesets
}

-- Object types for placement
local OBJECT_TYPES = {
    BUILDING = "building",
    DECORATION = "decoration",
    NPC = "npc"
}

-- NPC Behavior types
local BEHAVIORS = {
    IDLE = "idle",
    PATROL = "patrol",
    WANDER = "wander"
}

-- Edit state
local editState = {
    currentTool = TOOLS.SELECT,
    selectedObject = nil,
    selectedObjectType = nil,  -- "building", "decoration", "npc"
    isDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,

    -- Asset browser state
    assetModalOpen = false,
    assetModalScroll = 0,        -- Scroll for sprites area
    folderTreeScroll = 0,        -- Scroll for folder tree
    assetFolderTree = {},        -- Scanned folder structure
    selectedFolder = "assets",   -- Currently selected folder in tree
    expandedFolders = {assets = true},  -- Which folders are expanded
    selectedAsset = nil,         -- Selected sprite path
    placementType = nil,         -- What type to place as (building/decoration/npc)

    -- Preview object while placing
    previewObject = nil,

    -- Grid
    gridEnabled = false,
    gridSize = 32,

    -- Waypoint editing
    draggingWaypoint = nil,      -- Index of waypoint being dragged
    addingWaypoint = false,      -- If true, next click adds waypoint

    -- World data
    worldLayout = {
        version = 2,
        buildings = {},
        decorations = {},
        npcs = {},
        tiles = {},  -- Painted tiles: {x, y, tilesetPath, tileX, tileY, tileSize}
        metadata = {}
    },

    -- ID counters
    nextBuildingId = 1,
    nextDecorationId = 1,
    nextNpcId = 1,

    -- Loaded sprite cache for previews
    spriteCache = {},

    -- Clipboard for copy/paste
    clipboard = nil,         -- Copied object data
    clipboardType = nil,     -- Type of copied object ("building", "decoration", "npc")

    -- Properties panel scroll
    propertiesScroll = 0,

    -- Tile painting state
    tilePickerOpen = false,
    tilesetPath = nil,           -- Currently loaded tileset
    tilesetSprite = nil,         -- Loaded tileset image
    tileSize = 32,               -- Size of each tile in the tileset
    selectedTileX = 0,           -- Selected tile column in tileset
    selectedTileY = 0,           -- Selected tile row in tileset
    tilePickerScroll = 0,        -- Scroll for tileset picker
    isPaintingTiles = false      -- True while mouse is held for continuous painting
}

-- Calculate scale and offset for screen transformation
local currentScale = 1
local offsetX, offsetY = 0, 0

local function updateScale()
    local screenW, screenH = love.graphics.getDimensions()
    local scaleX = screenW / DESIGN_W
    local scaleY = screenH / DESIGN_H
    currentScale = math.min(scaleX, scaleY)
    offsetX = (screenW - DESIGN_W * currentScale) / 2
    offsetY = (screenH - DESIGN_H * currentScale) / 2
end

-- Transform screen coordinates to design coordinates (1920x1080)
local function screenToDesign(screenX, screenY)
    return (screenX - offsetX) / currentScale, (screenY - offsetY) / currentScale
end

-- Scan asset folder recursively
local function scanAssetFolder(basePath)
    local result = {
        path = basePath,
        name = basePath:match("([^/]+)$") or basePath,
        folders = {},
        files = {}
    }

    local items = love.filesystem.getDirectoryItems(basePath)
    for _, item in ipairs(items) do
        local fullPath = basePath .. "/" .. item
        local info = love.filesystem.getInfo(fullPath)

        if info then
            if info.type == "directory" then
                table.insert(result.folders, scanAssetFolder(fullPath))
            elseif info.type == "file" and item:match("%.png$") then
                table.insert(result.files, {
                    path = fullPath,
                    name = item:gsub("%.png$", "")
                })
            end
        end
    end

    -- Sort folders and files alphabetically
    table.sort(result.folders, function(a, b) return a.name < b.name end)
    table.sort(result.files, function(a, b) return a.name < b.name end)

    return result
end

-- Get sprite from cache or load it
local function getSprite(path)
    if not editState.spriteCache[path] then
        local success, sprite = pcall(love.graphics.newImage, path)
        if success then
            editState.spriteCache[path] = sprite
        else
            return nil
        end
    end
    return editState.spriteCache[path]
end

-- Initialize Edit Mode
function EditMode.init(gameData)
    updateScale()

    -- Scan assets folder
    editState.assetFolderTree = scanAssetFolder("assets")

    -- Load world layout from JSON
    local worldLayout, err = json.loadFile("data/world_layout.json")
    if worldLayout then
        editState.worldLayout = worldLayout

        -- Ensure version 2 structure
        if not editState.worldLayout.version or editState.worldLayout.version < 2 then
            editState.worldLayout.version = 2
            editState.worldLayout.buildings = editState.worldLayout.buildings or {}
        end
        editState.worldLayout.decorations = editState.worldLayout.decorations or {}
        editState.worldLayout.npcs = editState.worldLayout.npcs or {}
        editState.worldLayout.tiles = editState.worldLayout.tiles or {}

        -- Find highest IDs for auto-increment
        for _, building in ipairs(editState.worldLayout.buildings or {}) do
            local idNum = tonumber(building.id:match("%d+") or "0")
            if idNum and idNum >= editState.nextBuildingId then
                editState.nextBuildingId = idNum + 1
            end
        end
        for _, dec in ipairs(editState.worldLayout.decorations or {}) do
            local idNum = tonumber(dec.id:match("%d+") or "0")
            if idNum and idNum >= editState.nextDecorationId then
                editState.nextDecorationId = idNum + 1
            end
        end
        for _, npc in ipairs(editState.worldLayout.npcs or {}) do
            local idNum = tonumber(npc.id:match("%d+") or "0")
            if idNum and idNum >= editState.nextNpcId then
                editState.nextNpcId = idNum + 1
            end
        end
    else
        print("Edit Mode: Failed to load world layout:", err)
        Logger.warn("EditMode", "Failed to load world_layout.json, creating default", err)
        -- Create default world layout
        editState.worldLayout = {
            version = 2,
            buildings = {},
            decorations = {},
            npcs = {},
            tiles = {},
            metadata = {
                lastModified = os.time(),
                modifiedBy = "EditMode"
            }
        }
        -- Try to save the new file
        local success, saveErr = json.saveFile("data/world_layout.json", editState.worldLayout)
        if success then
            print("Edit Mode: Created new world_layout.json")
            Logger.info("EditMode", "Created new world_layout.json successfully")
        else
            print("Edit Mode: Could not create world_layout.json:", saveErr)
            Logger.error("EditMode", "Could not create world_layout.json", saveErr)
        end
    end

    -- Reset state
    editState.selectedObject = nil
    editState.selectedObjectType = nil
    editState.isDragging = false
    editState.previewObject = nil
    editState.currentTool = TOOLS.SELECT
    editState.selectedAsset = nil
    editState.draggingWaypoint = nil
    editState.addingWaypoint = false
end

-- Save world layout to JSON
local function saveWorldLayout()
    -- Ensure worldLayout and metadata exist
    if not editState.worldLayout then
        editState.worldLayout = {
            version = 2,
            buildings = {},
            decorations = {},
            npcs = {},
            metadata = {}
        }
    end
    if not editState.worldLayout.metadata then
        editState.worldLayout.metadata = {}
    end

    editState.worldLayout.metadata.lastModified = os.time()
    editState.worldLayout.metadata.modifiedBy = "EditMode"

    local success, err = json.saveFile("data/world_layout.json", editState.worldLayout)
    if success then
        return true, "World layout saved!"
    else
        local errorMsg = "Save failed: " .. (err or "unknown error")
        Logger.error("EditMode", "Failed to save world_layout.json", err)
        return false, errorMsg
    end
end

-- Get object hitbox based on sprite dimensions
local function getObjectHitbox(obj, objType)
    local sprite = getSprite(obj.sprite)
    local scale = obj.scale or 1
    local w, h

    if sprite then
        w = sprite:getWidth() * scale
        h = sprite:getHeight() * scale
        -- For animated sprites, use frame width
        if obj.animated and obj.frameCount and obj.frameCount > 1 then
            w = (sprite:getWidth() / obj.frameCount) * scale
        end
    else
        -- Fallback dimensions
        w = 100 * scale
        h = 100 * scale
    end

    local x, y
    if objType == "building" then
        -- Buildings: y is top of sprite, centered horizontally
        x = obj.x - w/2
        y = obj.y
    else
        -- Decorations/NPCs: y is bottom of sprite (feet), centered horizontally
        x = obj.x - w/2
        y = obj.y - h
    end

    return x, y, w, h
end

-- Find object at position
local function findObjectAt(designX, designY)
    -- Check NPCs first (smallest hitbox typically)
    for i, npc in ipairs(editState.worldLayout.npcs or {}) do
        local x = npc.x or (npc.waypoints and npc.waypoints[1] and npc.waypoints[1][1]) or 0
        local y = npc.y or (npc.waypoints and npc.waypoints[1] and npc.waypoints[1][2]) or 0
        -- NPCs: anchored at bottom-center
        local hitX, hitY, hitW, hitH = getObjectHitbox(npc, "npc")
        -- Override x,y for NPCs that might use waypoints
        hitX = x - hitW/2
        hitY = y - hitH
        if Components.isPointInRect(designX, designY, hitX, hitY, hitW, hitH) then
            return npc, "npc", i
        end
    end

    -- Check decorations
    for i, dec in ipairs(editState.worldLayout.decorations or {}) do
        local hitX, hitY, hitW, hitH = getObjectHitbox(dec, "decoration")
        if Components.isPointInRect(designX, designY, hitX, hitY, hitW, hitH) then
            return dec, "decoration", i
        end
    end

    -- Check buildings (y is TOP of sprite)
    for i, building in ipairs(editState.worldLayout.buildings or {}) do
        local hitX, hitY, hitW, hitH = getObjectHitbox(building, "building")
        if Components.isPointInRect(designX, designY, hitX, hitY, hitW, hitH) then
            return building, "building", i
        end
    end

    return nil, nil, nil
end

-- Find waypoint at position (for patrol NPCs)
local function findWaypointAt(designX, designY, npc)
    if not npc or npc.behavior ~= BEHAVIORS.PATROL or not npc.waypoints then
        return nil
    end

    local pointRadius = 15
    for i, wp in ipairs(npc.waypoints) do
        if math.abs(designX - wp[1]) < pointRadius and math.abs(designY - wp[2]) < pointRadius then
            return i
        end
    end
    return nil
end

-- Delete selected object
local function deleteSelectedObject()
    if not editState.selectedObject or not editState.selectedObjectType then return end

    local list
    if editState.selectedObjectType == "building" then
        list = editState.worldLayout.buildings
    elseif editState.selectedObjectType == "decoration" then
        list = editState.worldLayout.decorations
    elseif editState.selectedObjectType == "npc" then
        list = editState.worldLayout.npcs
    end

    if list then
        for i, obj in ipairs(list) do
            if obj.id == editState.selectedObject.id then
                table.remove(list, i)
                break
            end
        end
    end

    editState.selectedObject = nil
    editState.selectedObjectType = nil
end

-- Draw toolbar
local function drawToolbar()
    local toolbarH = 60
    local toolbarY = 0

    -- Draw toolbar background
    love.graphics.setColor(0.15, 0.15, 0.2, 0.95)
    love.graphics.rectangle("fill", 0, toolbarY, DESIGN_W, toolbarH)

    -- Border
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(0, toolbarH, DESIGN_W, toolbarH)

    -- Edit Mode Title
    love.graphics.setColor(1, 1, 0.3)
    love.graphics.print("EDIT MODE", 20, 20, 0, 1.5, 1.5)

    -- Tool buttons
    local btnX = 180
    local btnY = toolbarY + 10
    local btnW = 120
    local btnH = 40
    local btnSpacing = 10

    -- Add Asset button
    local addColor = editState.assetModalOpen and {0.4, 0.7, 0.5} or {0.3, 0.5, 0.7}
    Components.drawButton("Add Asset", btnX, btnY, btnW, btnH, {color = addColor})

    btnX = btnX + btnW + btnSpacing
    -- Select tool
    local selectColor = (editState.currentTool == TOOLS.SELECT) and {0.3, 0.6, 0.4} or Components.colors.button
    Components.drawButton("Select", btnX, btnY, 80, btnH, {color = selectColor})

    -- Tiles button (tile painting tool)
    btnX = btnX + 90 + btnSpacing
    local tilesColor = (editState.currentTool == TOOLS.TILE_PAINT) and {0.5, 0.6, 0.3} or {0.4, 0.45, 0.5}
    Components.drawButton("Tiles", btnX, btnY, 70, btnH, {color = tilesColor})

    -- Grid toggle
    btnX = btnX + 80 + btnSpacing
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Grid:", btnX, btnY + 12)
    local gridText = editState.gridEnabled and "ON" or "OFF"
    local gridColor = editState.gridEnabled and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
    Components.drawButton(gridText, btnX + 45, btnY, 50, btnH, {color = gridColor})

    -- Mode indicators
    if editState.addingWaypoint then
        btnX = btnX + 120
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("ADDING WAYPOINT - Click to place", btnX, btnY + 12)
    elseif editState.currentTool == TOOLS.TILE_PAINT then
        btnX = btnX + 120
        love.graphics.setColor(0.8, 1, 0.5)
        love.graphics.print("TILE PAINT - Click/drag to paint", btnX, btnY + 12)
    end

    -- Save button
    btnX = DESIGN_W - 220
    Components.drawButton("Save", btnX, btnY, 90, btnH, {color = {0.3, 0.5, 0.7}})

    -- Exit button
    btnX = DESIGN_W - 120
    Components.drawButton("Exit", btnX, btnY, 100, btnH, {color = {0.6, 0.3, 0.3}})
end

-- Calculate total height of folder tree
local function calculateFolderTreeHeight(folder, depth)
    local itemH = 25
    local totalH = itemH  -- This folder

    local isExpanded = editState.expandedFolders[folder.path]
    if isExpanded then
        for _, subfolder in ipairs(folder.folders) do
            totalH = totalH + calculateFolderTreeHeight(subfolder, depth + 1)
        end
    end

    return totalH
end

-- Draw folder tree item
local function drawFolderTree(folder, x, y, depth, maxWidth, scrollOffset)
    local itemH = 25
    local indent = depth * 20
    local currentY = y

    -- Draw folder name
    local isExpanded = editState.expandedFolders[folder.path]
    local isSelected = editState.selectedFolder == folder.path
    local arrow = isExpanded and "v " or "> "

    local drawY = currentY - scrollOffset

    if isSelected then
        love.graphics.setColor(0.3, 0.4, 0.5)
        love.graphics.rectangle("fill", x, drawY, maxWidth, itemH)
    end

    love.graphics.setColor(0.8, 0.8, 0.5)
    love.graphics.print(arrow .. folder.name, x + indent + 5, drawY + 5)
    currentY = currentY + itemH

    -- Draw subfolders if expanded
    if isExpanded then
        for _, subfolder in ipairs(folder.folders) do
            currentY = drawFolderTree(subfolder, x, currentY, depth + 1, maxWidth, scrollOffset)
        end
    end

    return currentY
end

-- Get folder at Y position in tree (accounting for scroll)
local function getFolderAtY(folder, x, startY, targetY, depth, maxWidth, scrollOffset)
    local itemH = 25
    local currentY = startY

    -- Adjust target for scroll
    local adjustedTarget = targetY + scrollOffset

    -- Check this folder
    if adjustedTarget >= currentY and adjustedTarget < currentY + itemH then
        return folder
    end
    currentY = currentY + itemH

    -- Check subfolders if expanded
    local isExpanded = editState.expandedFolders[folder.path]
    if isExpanded then
        for _, subfolder in ipairs(folder.folders) do
            local result
            result, currentY = getFolderAtY(subfolder, x, currentY, adjustedTarget, depth + 1, maxWidth, 0)
            if result then return result, currentY end
        end
    end

    return nil, currentY
end

-- Draw asset browser modal
local function drawAssetModal()
    if not editState.assetModalOpen then return end

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)

    -- Modal window
    local modalW = 1000
    local modalH = 700
    local modalX = (DESIGN_W - modalW) / 2
    local modalY = (DESIGN_H - modalH) / 2

    -- Modal background
    love.graphics.setColor(0.2, 0.2, 0.25, 0.98)
    love.graphics.rectangle("fill", modalX, modalY, modalW, modalH, 10, 10)

    -- Header
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", modalX, modalY, modalW, 50, 10, 10)
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.printf("ASSET BROWSER", modalX, modalY + 15, modalW, "center", 0, 1.3, 1.3)

    -- Close button
    Components.drawButton("X", modalX + modalW - 50, modalY + 10, 35, 35, {color = {0.6, 0.3, 0.3}})

    -- Split layout: folder tree on left, sprites on right
    local treeW = 250
    local contentX = modalX + treeW + 10
    local contentY = modalY + 60
    local contentW = modalW - treeW - 30
    local contentH = modalH - 140

    -- Folder tree background
    local treeAreaX = modalX + 10
    local treeAreaW = treeW - 20  -- Leave room for scrollbar
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", treeAreaX, contentY, treeW - 10, contentH)

    -- Calculate folder tree total height
    local treeHeight = calculateFolderTreeHeight(editState.assetFolderTree, 0)
    local maxTreeScroll = math.max(0, treeHeight - contentH)
    editState.folderTreeScroll = math.max(0, math.min(editState.folderTreeScroll, maxTreeScroll))

    -- Draw folder tree with scroll
    love.graphics.setScissor(treeAreaX * currentScale + offsetX, contentY * currentScale + offsetY,
                             treeAreaW * currentScale, contentH * currentScale)
    drawFolderTree(editState.assetFolderTree, treeAreaX, contentY, 0, treeAreaW, editState.folderTreeScroll)
    love.graphics.setScissor()

    -- Draw scrollbar for folder tree if needed
    if treeHeight > contentH then
        local scrollbarX = modalX + treeW - 12
        local scrollbarW = 8
        local scrollbarH = contentH
        local thumbH = math.max(30, (contentH / treeHeight) * scrollbarH)
        local thumbY = contentY + (editState.folderTreeScroll / maxTreeScroll) * (scrollbarH - thumbH)

        -- Scrollbar track
        love.graphics.setColor(0.1, 0.1, 0.12)
        love.graphics.rectangle("fill", scrollbarX, contentY, scrollbarW, scrollbarH, 4, 4)

        -- Scrollbar thumb
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("fill", scrollbarX, thumbY, scrollbarW, thumbH, 4, 4)
    end

    -- Sprites area background
    love.graphics.setColor(0.18, 0.18, 0.22)
    love.graphics.rectangle("fill", contentX, contentY, contentW, contentH)

    -- Draw sprites in selected folder
    local selectedFolderData = nil
    local function findFolder(folder, path)
        if folder.path == path then return folder end
        for _, sub in ipairs(folder.folders) do
            local result = findFolder(sub, path)
            if result then return result end
        end
        return nil
    end
    selectedFolderData = findFolder(editState.assetFolderTree, editState.selectedFolder)

    if selectedFolderData then
        local thumbSize = 80
        local padding = 10
        local cols = math.floor(contentW / (thumbSize + padding))
        local row, col = 0, 0

        love.graphics.setScissor(contentX * currentScale + offsetX, contentY * currentScale + offsetY,
                                 contentW * currentScale, contentH * currentScale)

        for _, file in ipairs(selectedFolderData.files) do
            local thumbX = contentX + padding + col * (thumbSize + padding)
            local thumbY = contentY + padding + row * (thumbSize + padding + 20) - editState.assetModalScroll

            -- Only draw if visible
            if thumbY + thumbSize + 20 > contentY and thumbY < contentY + contentH then
                -- Thumbnail background
                local isSelected = editState.selectedAsset == file.path
                local bgColor = isSelected and {0.4, 0.6, 0.5} or {0.25, 0.25, 0.3}
                love.graphics.setColor(bgColor)
                love.graphics.rectangle("fill", thumbX, thumbY, thumbSize, thumbSize, 5, 5)

                -- Draw sprite thumbnail
                local sprite = getSprite(file.path)
                if sprite then
                    local sw, sh = sprite:getDimensions()
                    local scale = math.min((thumbSize - 10) / sw, (thumbSize - 10) / sh)
                    local drawX = thumbX + (thumbSize - sw * scale) / 2
                    local drawY = thumbY + (thumbSize - sh * scale) / 2
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(sprite, drawX, drawY, 0, scale, scale)
                end

                -- Selection border
                if isSelected then
                    love.graphics.setColor(0.5, 1, 0.6)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line", thumbX, thumbY, thumbSize, thumbSize, 5, 5)
                    love.graphics.setLineWidth(1)
                end

                -- File name
                love.graphics.setColor(1, 1, 1)
                local shortName = file.name:sub(1, 12)
                if #file.name > 12 then shortName = shortName .. ".." end
                love.graphics.printf(shortName, thumbX, thumbY + thumbSize + 2, thumbSize, "center")
            end

            col = col + 1
            if col >= cols then
                col = 0
                row = row + 1
            end
        end

        love.graphics.setScissor()
    end

    -- Bottom panel with placement options
    local bottomY = modalY + modalH - 70
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", modalX, bottomY, modalW, 70, 10, 10)

    if editState.selectedAsset then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Selected: " .. editState.selectedAsset:match("([^/]+)$"), modalX + 20, bottomY + 10)

        -- Placement type buttons
        local btnY = bottomY + 30
        local btnW = 140
        local btnH = 30
        local btnX = modalX + modalW - 480

        Components.drawButton("As Decoration", btnX, btnY, btnW, btnH, {color = {0.3, 0.5, 0.4}})
        btnX = btnX + btnW + 10
        Components.drawButton("As Building", btnX, btnY, btnW, btnH, {color = {0.4, 0.4, 0.5}})
        btnX = btnX + btnW + 10
        Components.drawButton("As NPC", btnX, btnY, btnW, btnH, {color = {0.5, 0.4, 0.4}})
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("Select a sprite from the folder tree above", modalX + 20, bottomY + 25)
    end
end

-- Draw tile picker modal
local function drawTilePickerModal()
    if not editState.tilePickerOpen then return end

    local modalW = 600
    local modalH = 500
    local modalX = (DESIGN_W - modalW) / 2
    local modalY = (DESIGN_H - modalH) / 2

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, DESIGN_W, DESIGN_H)

    -- Modal background
    love.graphics.setColor(0.2, 0.2, 0.25, 0.98)
    love.graphics.rectangle("fill", modalX, modalY, modalW, modalH, 10, 10)

    -- Border
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", modalX, modalY, modalW, modalH, 10, 10)

    -- Title
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.print("TILE PICKER", modalX + 20, modalY + 15, 0, 1.3, 1.3)

    -- Close button
    love.graphics.setColor(0.6, 0.3, 0.3)
    love.graphics.rectangle("fill", modalX + modalW - 35, modalY + 10, 25, 25, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("X", modalX + modalW - 28, modalY + 13)

    -- Tileset selection buttons
    local btnY = modalY + 50
    local btnX = modalX + 20
    local btnH = 30
    local tilesets = {
        {path = "assets/Terrain/Tileset/Path_Tile.png", name = "Path Tiles"},
        {path = "assets/Terrain/Tileset/Tilemap_color1.png", name = "Grass/Terrain"},
    }

    for i, ts in ipairs(tilesets) do
        local isSelected = editState.tilesetPath == ts.path
        local color = isSelected and {0.4, 0.6, 0.5} or {0.3, 0.35, 0.4}
        Components.drawButton(ts.name, btnX, btnY, 130, btnH, {color = color})
        btnX = btnX + 140
    end

    -- Tile size selector
    btnX = modalX + 320
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Size:", btnX, btnY + 8)
    local sizes = {8, 12, 16, 32, 64}
    btnX = btnX + 40
    for _, size in ipairs(sizes) do
        local isSelected = editState.tileSize == size
        local color = isSelected and {0.4, 0.6, 0.5} or {0.3, 0.35, 0.4}
        Components.drawButton(tostring(size), btnX, btnY, 40, btnH, {color = color})
        btnX = btnX + 45
    end

    -- Tileset display area
    local tileAreaY = modalY + 90
    local tileAreaH = modalH - 150
    local tileAreaW = modalW - 40

    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.rectangle("fill", modalX + 20, tileAreaY, tileAreaW, tileAreaH, 5, 5)

    if editState.tilesetSprite then
        local sprite = editState.tilesetSprite
        local sw, sh = sprite:getDimensions()
        local tileSize = editState.tileSize

        -- Calculate display scale to fit in area
        local maxScale = math.min(tileAreaW / sw, tileAreaH / sh, 2)
        local displayScale = maxScale

        -- Draw tileset
        local drawX = modalX + 20 + (tileAreaW - sw * displayScale) / 2
        local drawY = tileAreaY + (tileAreaH - sh * displayScale) / 2

        -- Set scissor for tile area
        love.graphics.setScissor(
            (modalX + 20) * currentScale + offsetX,
            tileAreaY * currentScale + offsetY,
            tileAreaW * currentScale,
            tileAreaH * currentScale
        )

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprite, drawX, drawY, 0, displayScale, displayScale)

        -- Draw grid overlay
        love.graphics.setColor(1, 1, 1, 0.3)
        local tilesX = math.floor(sw / tileSize)
        local tilesY = math.floor(sh / tileSize)

        for tx = 0, tilesX do
            local lineX = drawX + tx * tileSize * displayScale
            love.graphics.line(lineX, drawY, lineX, drawY + sh * displayScale)
        end
        for ty = 0, tilesY do
            local lineY = drawY + ty * tileSize * displayScale
            love.graphics.line(drawX, lineY, drawX + sw * displayScale, lineY)
        end

        -- Highlight selected tile
        local selX = drawX + editState.selectedTileX * tileSize * displayScale
        local selY = drawY + editState.selectedTileY * tileSize * displayScale
        local selSize = tileSize * displayScale

        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", selX, selY, selSize, selSize)
        love.graphics.setLineWidth(1)

        -- Store these for click detection
        editState.tileDisplayX = drawX
        editState.tileDisplayY = drawY
        editState.tileDisplayScale = displayScale

        love.graphics.setScissor()
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("Select a tileset above", modalX + 20, tileAreaY + tileAreaH/2 - 10, tileAreaW, "center")
    end

    -- Bottom info panel
    local bottomY = modalY + modalH - 50
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", modalX, bottomY, modalW, 50, 10, 10)

    if editState.tilesetSprite then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(string.format("Selected tile: (%d, %d)", editState.selectedTileX, editState.selectedTileY), modalX + 20, bottomY + 15)

        -- Confirm button
        Components.drawButton("Use Tile", modalX + modalW - 120, bottomY + 10, 100, 30, {color = {0.3, 0.6, 0.4}})
    end
end

-- Calculate properties panel content height
local function calculatePropertiesContentHeight(obj, objType)
    if not obj then return 100 end

    local height = 0
    height = height + 35  -- Title
    height = height + 25  -- Type
    height = height + 30  -- ID
    height = height + 22 + 35  -- Position header + inputs
    height = height + 40  -- Scale
    height = height + 22 + 35 + 35  -- Layer section: header + layer input + forward/back buttons

    if objType == "building" then
        height = height + 22 + 35  -- Building Options header + clickable
        if obj.clickable then
            height = height + 35  -- Menu dropdown
        end
    elseif objType == "npc" then
        height = height + 22 + 35  -- NPC Behavior header + mode
        height = height + 40  -- Speed

        if obj.behavior == "patrol" then
            height = height + 22 + 25 + 35 + 35  -- Patrol Path header + waypoints + add button + loop
        elseif obj.behavior == "wander" then
            height = height + 22 + 35  -- Wander Area header + radius
        end

        height = height + 22 + 35  -- Animation header + toggle
        if obj.animated then
            height = height + 35 + 35  -- Frames + FPS
        end
    elseif objType == "decoration" then
        height = height + 22 + 35  -- Animation header + toggle
        if obj.animated then
            height = height + 35 + 35  -- Frames + FPS
        end
    end

    height = height + 50  -- Delete button
    return height
end

-- Draw properties panel
local function drawPropertiesPanel()
    local panelW = 280
    local panelH = 500
    local panelX = DESIGN_W - panelW - 10
    local panelY = 70
    local contentAreaH = panelH - 60  -- Leave room for title and delete button area

    -- Panel background
    love.graphics.setColor(0.2, 0.2, 0.25, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 5, 5)

    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 5, 5)

    local textX = panelX + 15
    local inputW = 80
    local inputH = 28

    -- Title (fixed, not scrolled)
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.print("PROPERTIES", textX, panelY + 15, 0, 1.2, 1.2)

    if not editState.selectedObject then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("No object selected", textX, panelY + 55)
        love.graphics.print("", textX, panelY + 75)
        love.graphics.print("Click on an object to", textX, panelY + 95)
        love.graphics.print("view/edit its properties", textX, panelY + 115)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.print("Right-click to copy/paste", textX, panelY + 155)
        return
    end

    local obj = editState.selectedObject
    local objType = editState.selectedObjectType

    -- Calculate content height and max scroll
    local contentHeight = calculatePropertiesContentHeight(obj, objType)
    local maxScroll = math.max(0, contentHeight - contentAreaH)
    editState.propertiesScroll = math.max(0, math.min(editState.propertiesScroll, maxScroll))

    -- Set up scissor for scrollable content area
    local scrollAreaY = panelY + 50
    local scrollAreaH = panelH - 100  -- Leave room for title and delete button
    love.graphics.setScissor(
        panelX * currentScale + offsetX,
        scrollAreaY * currentScale + offsetY,
        panelW * currentScale,
        scrollAreaH * currentScale
    )

    -- Start drawing scrollable content
    local textY = scrollAreaY - editState.propertiesScroll

    -- Object type
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Type:", textX, textY)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(objType:upper(), textX + 50, textY)
    textY = textY + 25

    -- ID
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("ID:", textX, textY)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(obj.id or "unknown", textX + 50, textY)
    textY = textY + 30

    -- Position
    love.graphics.setColor(1, 1, 0.7)
    love.graphics.print("Position", textX, textY)
    textY = textY + 22

    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("X:", textX, textY + 5)
    Components.drawTextInput("prop_x", math.floor(obj.x or 0), textX + 25, textY, inputW, inputH, {numeric = true})

    love.graphics.print("Y:", textX + 130, textY + 5)
    Components.drawTextInput("prop_y", math.floor(obj.y or 0), textX + 155, textY, inputW, inputH, {numeric = true})
    textY = textY + 35

    -- Scale
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Scale:", textX, textY + 5)
    Components.drawTextInput("prop_scale", string.format("%.2f", obj.scale or 1), textX + 50, textY, 60, inputH, {numeric = true, minValue = 0.1, maxValue = 5})
    textY = textY + 40

    -- Layer section (for all object types)
    love.graphics.setColor(1, 1, 0.7)
    love.graphics.print("Layer / Z-Order", textX, textY)
    textY = textY + 22

    -- Default layer based on type if not set
    local defaultLayer = 2  -- Default: buildings layer
    if objType == "decoration" then defaultLayer = 1 end
    if objType == "npc" then defaultLayer = 3 end
    local currentLayer = obj.layer or defaultLayer

    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Layer:", textX, textY + 5)
    Components.drawTextInput("prop_layer", currentLayer, textX + 50, textY, 40, inputH, {numeric = true, minValue = 0, maxValue = 5})

    -- Layer hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("0=back 5=front", textX + 100, textY + 8)
    textY = textY + 35

    -- Bring Forward / Send Backward buttons
    Components.drawButton("Back", textX, textY, 60, inputH, {color = {0.4, 0.4, 0.5}})
    Components.drawButton("Forward", textX + 70, textY, 70, inputH, {color = {0.4, 0.5, 0.4}})
    textY = textY + 35

    -- Type-specific properties
    if objType == "building" then
        -- Clickable toggle
        love.graphics.setColor(1, 1, 0.7)
        love.graphics.print("Building Options", textX, textY)
        textY = textY + 22

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Clickable:", textX, textY + 8)
        local clickColor = obj.clickable and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
        Components.drawButton(obj.clickable and "YES" or "NO", textX + 80, textY, 50, inputH, {color = clickColor})
        textY = textY + 35

        if obj.clickable then
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Menu:", textX, textY + 5)
            Components.drawDropdown("prop_menu", obj.menuTarget or "NONE",
                {"NONE", "GUILD", "TAVERN", "ARMORY", "POTION", "SETTINGS"},
                textX + 50, textY, 100, inputH)
            textY = textY + 35
        end

    elseif objType == "npc" then
        -- Behavior dropdown
        love.graphics.setColor(1, 1, 0.7)
        love.graphics.print("NPC Behavior", textX, textY)
        textY = textY + 22

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Mode:", textX, textY + 5)
        Components.drawDropdown("prop_behavior", obj.behavior or "idle",
            {"idle", "patrol", "wander"},
            textX + 50, textY, 100, inputH)
        textY = textY + 35

        -- Speed
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Speed:", textX, textY + 5)
        Components.drawTextInput("prop_speed", obj.speed or 30, textX + 55, textY, 60, inputH, {numeric = true, minValue = 5, maxValue = 200})
        textY = textY + 40

        -- Behavior-specific options
        if obj.behavior == "patrol" then
            love.graphics.setColor(1, 1, 0.7)
            love.graphics.print("Patrol Path", textX, textY)
            textY = textY + 22

            local wpCount = obj.waypoints and #obj.waypoints or 0
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Waypoints: " .. wpCount, textX, textY)
            textY = textY + 25

            -- Add waypoint button
            local addWpColor = editState.addingWaypoint and {0.5, 0.7, 0.4} or {0.3, 0.5, 0.4}
            Components.drawButton(editState.addingWaypoint and "Click Map..." or "Add Waypoint", textX, textY, 120, inputH, {color = addWpColor})
            textY = textY + 35

            -- Loop toggle
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Loop:", textX, textY + 5)
            local loopColor = obj.loop and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
            Components.drawButton(obj.loop and "YES" or "NO", textX + 50, textY, 50, inputH, {color = loopColor})
            textY = textY + 35

        elseif obj.behavior == "wander" then
            love.graphics.setColor(1, 1, 0.7)
            love.graphics.print("Wander Area", textX, textY)
            textY = textY + 22

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Radius:", textX, textY + 5)
            Components.drawTextInput("prop_radius", obj.radius or 100, textX + 60, textY, 60, inputH, {numeric = true, minValue = 20, maxValue = 500})
            textY = textY + 35
        end

        -- Animation section for NPCs
        love.graphics.setColor(1, 1, 0.7)
        love.graphics.print("Animation", textX, textY)
        textY = textY + 22

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Animated:", textX, textY + 5)
        local animColor = obj.animated and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
        Components.drawButton(obj.animated and "YES" or "NO", textX + 75, textY, 50, inputH, {color = animColor})
        textY = textY + 35

        if obj.animated then
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Idle Frames:", textX, textY + 5)
            Components.drawTextInput("prop_frameCount", obj.frameCount or 1, textX + 85, textY, 50, inputH, {numeric = true, minValue = 1, maxValue = 32})
            textY = textY + 35

            -- Move frames (for wander/patrol behavior)
            if obj.behavior == "wander" or obj.behavior == "patrol" then
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print("Move Frames:", textX, textY + 5)
                Components.drawTextInput("prop_moveFrameCount", obj.moveFrameCount or obj.frameCount or 1, textX + 95, textY, 50, inputH, {numeric = true, minValue = 1, maxValue = 32})
                textY = textY + 35
            end

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("FPS:", textX, textY + 5)
            Components.drawTextInput("prop_fps", obj.fps or 8, textX + 40, textY, 50, inputH, {numeric = true, minValue = 1, maxValue = 30})
            textY = textY + 35
        end

    elseif objType == "decoration" then
        -- Animation section
        love.graphics.setColor(1, 1, 0.7)
        love.graphics.print("Animation", textX, textY)
        textY = textY + 22

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Animated:", textX, textY + 5)
        local animColor = obj.animated and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
        Components.drawButton(obj.animated and "YES" or "NO", textX + 75, textY, 50, inputH, {color = animColor})
        textY = textY + 35

        if obj.animated then
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Frames:", textX, textY + 5)
            Components.drawTextInput("prop_frameCount", obj.frameCount or 1, textX + 60, textY, 50, inputH, {numeric = true, minValue = 1, maxValue = 32})
            textY = textY + 35

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("FPS:", textX, textY + 5)
            Components.drawTextInput("prop_fps", obj.fps or 8, textX + 40, textY, 50, inputH, {numeric = true, minValue = 1, maxValue = 30})
            textY = textY + 35
        end
    end

    -- End scissor
    love.graphics.setScissor()

    -- Draw scrollbar if needed
    if maxScroll > 0 then
        local scrollbarX = panelX + panelW - 12
        local scrollbarW = 8
        local scrollbarH = scrollAreaH
        local thumbH = math.max(30, (scrollAreaH / contentHeight) * scrollbarH)
        local thumbY = scrollAreaY + (editState.propertiesScroll / maxScroll) * (scrollbarH - thumbH)

        -- Scrollbar track
        love.graphics.setColor(0.1, 0.1, 0.12)
        love.graphics.rectangle("fill", scrollbarX, scrollAreaY, scrollbarW, scrollbarH, 4, 4)

        -- Scrollbar thumb
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("fill", scrollbarX, thumbY, scrollbarW, thumbH, 4, 4)
    end

    -- Delete button at bottom (fixed, not scrolled)
    local deleteY = panelY + panelH - 50
    Components.drawButton("Delete Object", textX, deleteY, panelW - 30, 35, {color = {0.6, 0.3, 0.3}})
end

-- Draw grid overlay
local function drawGrid()
    if not editState.gridEnabled then return end

    love.graphics.setColor(1, 1, 1, 0.1)
    local gridSize = editState.gridSize

    for x = 0, DESIGN_W, gridSize do
        love.graphics.line(x, 60, x, DESIGN_H)
    end

    for y = 60, DESIGN_H, gridSize do
        love.graphics.line(0, y, DESIGN_W, y)
    end
end

-- Get sprite dimensions for an object
local function getObjectSpriteDimensions(obj)
    local sprite = getSprite(obj.sprite)
    if sprite then
        local scale = obj.scale or 1
        local w = sprite:getWidth() * scale
        local h = sprite:getHeight() * scale
        -- For animated sprites (width > height), use frame width
        if obj.animated and obj.frameCount and obj.frameCount > 1 then
            w = (sprite:getWidth() / obj.frameCount) * scale
        end
        return w, h
    end
    -- Fallback dimensions
    return 100 * (obj.scale or 1), 100 * (obj.scale or 1)
end

-- Draw selection highlight and waypoints
local function drawSelectionHighlight()
    if not editState.selectedObject then return end

    local obj = editState.selectedObject
    local objType = editState.selectedObjectType

    -- Selection box
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setLineWidth(3)

    if objType == "building" then
        -- Buildings: x,y is top-left anchor point, centered horizontally
        -- Town draws at: drawX = b.x - w/2, drawY = b.y
        local w, h = getObjectSpriteDimensions(obj)
        love.graphics.rectangle("line", obj.x - w/2, obj.y, w, h)

    elseif objType == "decoration" then
        -- Decorations: anchored at bottom-center (x is center, y is bottom)
        local w, h = getObjectSpriteDimensions(obj)
        love.graphics.rectangle("line", obj.x - w/2, obj.y - h, w, h)

    elseif objType == "npc" then
        -- NPCs: anchored at bottom-center (x is center, y is bottom/feet)
        local x = obj.x or (obj.waypoints and obj.waypoints[1] and obj.waypoints[1][1]) or 0
        local y = obj.y or (obj.waypoints and obj.waypoints[1] and obj.waypoints[1][2]) or 0
        local w, h = getObjectSpriteDimensions(obj)
        love.graphics.rectangle("line", x - w/2, y - h, w, h)

        -- Draw waypoints for patrol behavior
        if obj.behavior == "patrol" and obj.waypoints then
            -- Draw path lines
            love.graphics.setColor(0.5, 0.8, 1, 0.6)
            love.graphics.setLineWidth(2)
            for i = 1, #obj.waypoints - 1 do
                local wp1 = obj.waypoints[i]
                local wp2 = obj.waypoints[i + 1]
                love.graphics.line(wp1[1], wp1[2], wp2[1], wp2[2])
            end
            -- Loop back line
            if obj.loop and #obj.waypoints > 1 then
                local first = obj.waypoints[1]
                local last = obj.waypoints[#obj.waypoints]
                love.graphics.setColor(0.5, 0.8, 1, 0.3)
                love.graphics.line(last[1], last[2], first[1], first[2])
            end

            -- Draw waypoint circles
            for i, wp in ipairs(obj.waypoints) do
                local isFirst = i == 1
                love.graphics.setColor(isFirst and {0.3, 0.8, 0.4} or {0.3, 0.6, 1})
                love.graphics.circle("fill", wp[1], wp[2], 10)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(tostring(i), wp[1] - 10, wp[2] - 7, 20, "center")
            end
        end

        -- Draw wander radius
        if obj.behavior == "wander" and obj.radius then
            love.graphics.setColor(0.8, 0.6, 0.3, 0.3)
            love.graphics.circle("fill", x, y, obj.radius)
            love.graphics.setColor(0.8, 0.6, 0.3, 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", x, y, obj.radius)
        end
    end

    love.graphics.setLineWidth(1)
end

-- Draw preview object while placing
local function drawPreview(mouseX, mouseY)
    if not editState.previewObject then return end

    local designX, designY = screenToDesign(mouseX, mouseY)

    -- Apply grid snapping
    if editState.gridEnabled then
        designX = math.floor(designX / editState.gridSize + 0.5) * editState.gridSize
        designY = math.floor(designY / editState.gridSize + 0.5) * editState.gridSize
    end

    -- Draw sprite preview at half opacity
    local sprite = getSprite(editState.previewObject.sprite)
    if sprite then
        local scale = editState.previewObject.scale or 1
        local sw, sh = sprite:getDimensions()
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.draw(sprite, designX - (sw * scale) / 2, designY - sh * scale, 0, scale, scale)
    end

    -- Position indicator
    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.circle("line", designX, designY, 5)
end

-- Draw painted tiles
local function drawPaintedTiles()
    local tiles = editState.worldLayout.tiles or {}
    for _, tile in ipairs(tiles) do
        local sprite = getSprite(tile.tilesetPath)
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

-- Handle tile picker modal clicks
local function handleTilePickerClick(designX, designY)
    local modalW = 600
    local modalH = 500
    local modalX = (DESIGN_W - modalW) / 2
    local modalY = (DESIGN_H - modalH) / 2

    -- Close button
    if Components.isPointInRect(designX, designY, modalX + modalW - 35, modalY + 10, 25, 25) then
        editState.tilePickerOpen = false
        return nil
    end

    -- Tileset selection buttons
    local btnY = modalY + 50
    local btnX = modalX + 20
    local btnH = 30
    local tilesets = {
        {path = "assets/Terrain/Tileset/Path_Tile.png", name = "Path Tiles"},
        {path = "assets/Terrain/Tileset/Tilemap_color1.png", name = "Grass/Terrain"},
    }

    for i, ts in ipairs(tilesets) do
        if Components.isPointInRect(designX, designY, btnX, btnY, 130, btnH) then
            editState.tilesetPath = ts.path
            editState.tilesetSprite = getSprite(ts.path)
            editState.selectedTileX = 0
            editState.selectedTileY = 0
            return nil
        end
        btnX = btnX + 140
    end

    -- Tile size selector
    btnX = modalX + 360
    local sizes = {8, 12, 16, 32, 64}
    for _, size in ipairs(sizes) do
        if Components.isPointInRect(designX, designY, btnX, btnY, 40, btnH) then
            editState.tileSize = size
            return nil
        end
        btnX = btnX + 45
    end

    -- Tile selection in tileset display area
    if editState.tilesetSprite and editState.tileDisplayX then
        local tileAreaY = modalY + 90
        local tileAreaH = modalH - 150
        local tileAreaW = modalW - 40

        if Components.isPointInRect(designX, designY, modalX + 20, tileAreaY, tileAreaW, tileAreaH) then
            local sprite = editState.tilesetSprite
            local sw, sh = sprite:getDimensions()
            local tileSize = editState.tileSize
            local displayScale = editState.tileDisplayScale

            -- Calculate which tile was clicked
            local relX = (designX - editState.tileDisplayX) / displayScale
            local relY = (designY - editState.tileDisplayY) / displayScale

            if relX >= 0 and relY >= 0 and relX < sw and relY < sh then
                editState.selectedTileX = math.floor(relX / tileSize)
                editState.selectedTileY = math.floor(relY / tileSize)
            end
            return nil
        end
    end

    -- Use Tile button
    local bottomY = modalY + modalH - 50
    if editState.tilesetSprite and Components.isPointInRect(designX, designY, modalX + modalW - 120, bottomY + 10, 100, 30) then
        editState.tilePickerOpen = false
        editState.currentTool = TOOLS.TILE_PAINT
        editState.selectedObject = nil
        editState.previewObject = nil
        return nil
    end

    return nil
end

-- Paint a tile at the given position
local function paintTile(designX, designY)
    if not editState.tilesetSprite or not editState.tilesetPath then return false end

    local tileSize = editState.tileSize
    local snapX = math.floor(designX / tileSize) * tileSize
    local snapY = math.floor(designY / tileSize) * tileSize

    -- Check if there's already a tile at this position, remove it
    local tiles = editState.worldLayout.tiles or {}
    for i = #tiles, 1, -1 do
        if tiles[i].x == snapX and tiles[i].y == snapY and tiles[i].tileSize == tileSize then
            table.remove(tiles, i)
        end
    end

    -- Add new tile
    table.insert(tiles, {
        x = snapX,
        y = snapY,
        tilesetPath = editState.tilesetPath,
        tileX = editState.selectedTileX,
        tileY = editState.selectedTileY,
        tileSize = tileSize
    })

    editState.worldLayout.tiles = tiles
    saveWorldLayout()
    return true
end

-- Erase a tile at the given position
local function eraseTile(designX, designY)
    local tileSize = editState.tileSize
    local snapX = math.floor(designX / tileSize) * tileSize
    local snapY = math.floor(designY / tileSize) * tileSize

    local tiles = editState.worldLayout.tiles or {}
    for i = #tiles, 1, -1 do
        if tiles[i].x == snapX and tiles[i].y == snapY then
            table.remove(tiles, i)
            editState.worldLayout.tiles = tiles
            saveWorldLayout()
            return true
        end
    end
    return false
end

-- Main draw function
function EditMode.draw(gameData, mouseX, mouseY)
    updateScale()

    -- Transform to design space
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(currentScale, currentScale)

    -- Draw painted tiles (under grid but visible)
    drawPaintedTiles()

    -- Draw grid
    drawGrid()

    -- Draw selection highlight
    drawSelectionHighlight()

    -- Draw preview
    drawPreview(mouseX, mouseY)

    -- Draw tile paint preview (if in tile paint mode)
    if editState.currentTool == TOOLS.TILE_PAINT and editState.tilesetSprite then
        local designX, designY = screenToDesign(mouseX, mouseY)
        local tileSize = editState.tileSize

        -- Snap to grid
        local snapX = math.floor(designX / tileSize) * tileSize
        local snapY = math.floor(designY / tileSize) * tileSize

        -- Draw preview tile
        local sprite = editState.tilesetSprite
        local sw, sh = sprite:getDimensions()
        local quad = love.graphics.newQuad(
            editState.selectedTileX * tileSize,
            editState.selectedTileY * tileSize,
            tileSize, tileSize,
            sw, sh
        )

        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.draw(sprite, quad, snapX, snapY)

        -- Draw border
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", snapX, snapY, tileSize, tileSize)
        love.graphics.setLineWidth(1)
    end

    -- Draw UI
    drawToolbar()
    drawPropertiesPanel()

    -- Draw modals (on top of everything)
    drawAssetModal()
    drawTilePickerModal()

    love.graphics.pop()
end

-- Update function
function EditMode.update(dt, mouseX, mouseY)
    if editState.isDragging and editState.selectedObject then
        local designX, designY = screenToDesign(mouseX, mouseY)

        -- Apply grid snapping
        if editState.gridEnabled then
            designX = math.floor(designX / editState.gridSize + 0.5) * editState.gridSize
            designY = math.floor(designY / editState.gridSize + 0.5) * editState.gridSize
        end

        -- Check if dragging a waypoint
        if editState.draggingWaypoint and editState.selectedObject.waypoints then
            editState.selectedObject.waypoints[editState.draggingWaypoint][1] = designX
            editState.selectedObject.waypoints[editState.draggingWaypoint][2] = designY
        else
            -- Moving the whole object
            editState.selectedObject.x = designX - editState.dragOffsetX
            editState.selectedObject.y = designY - editState.dragOffsetY
        end
    end

    -- Continuous tile painting while mouse is held
    if editState.isPaintingTiles and editState.currentTool == TOOLS.TILE_PAINT then
        local designX, designY = screenToDesign(mouseX, mouseY)
        if designY > 60 and designX < DESIGN_W - 290 then
            paintTile(designX, designY)
        end
    end
end

-- Handle mouse pressed
function EditMode.handleMousePressed(x, y, gameData)
    local designX, designY = screenToDesign(x, y)

    -- Check if modal is open
    if editState.assetModalOpen then
        return handleAssetModalClick(designX, designY)
    end

    -- Check tile picker modal first
    if editState.tilePickerOpen then
        return handleTilePickerClick(designX, designY)
    end

    -- Check toolbar clicks
    local btnY = 10
    local btnH = 40
    local btnX = 180

    -- Add Asset button
    if Components.isPointInRect(designX, designY, btnX, btnY, 120, btnH) then
        editState.assetModalOpen = true
        return nil
    end
    btnX = btnX + 130  -- 120 + 10 spacing

    -- Select tool
    if Components.isPointInRect(designX, designY, btnX, btnY, 80, btnH) then
        editState.currentTool = TOOLS.SELECT
        editState.previewObject = nil
        editState.addingWaypoint = false
        return nil
    end
    btnX = btnX + 90  -- 80 + 10 spacing

    -- Tiles button
    if Components.isPointInRect(designX, designY, btnX, btnY, 70, btnH) then
        editState.tilePickerOpen = true
        return nil
    end
    btnX = btnX + 80  -- 70 + 10 spacing

    -- Grid toggle (skip "Grid:" label width)
    if Components.isPointInRect(designX, designY, btnX + 45, btnY, 50, btnH) then
        editState.gridEnabled = not editState.gridEnabled
        return nil
    end

    -- Save button
    if Components.isPointInRect(designX, designY, DESIGN_W - 220, btnY, 90, btnH) then
        local success, msg = saveWorldLayout()
        return success and "saved" or "error", msg
    end

    -- Exit button
    if Components.isPointInRect(designX, designY, DESIGN_W - 120, btnY, 100, btnH) then
        return "exit"
    end

    -- Check properties panel clicks
    local panelX = DESIGN_W - 290
    local panelY = 70
    local panelW = 280
    local panelH = 500

    if Components.isPointInRect(designX, designY, panelX, panelY, panelW, panelH) then
        return handlePropertiesPanelClick(designX, designY, panelX, panelY, panelW, panelH)
    end

    -- Adding waypoint mode
    if editState.addingWaypoint and editState.selectedObject and
       editState.selectedObject.behavior == "patrol" and designY > 60 then
        if not editState.selectedObject.waypoints then
            editState.selectedObject.waypoints = {}
        end
        table.insert(editState.selectedObject.waypoints, {designX, designY})
        saveWorldLayout()
        -- Don't exit waypoint mode, allow multiple additions
        return "saved"
    end

    -- Placing new object
    if editState.previewObject and designY > 60 then
        placeNewObject(designX, designY)
        return "saved", "Object placed!"
    end

    -- Tile painting mode
    if editState.currentTool == TOOLS.TILE_PAINT and designY > 60 then
        -- Check we're not clicking on the properties panel
        local panelX2 = DESIGN_W - 290
        if designX < panelX2 then
            editState.isPaintingTiles = true
            paintTile(designX, designY)
            return nil
        end
    end

    -- Select mode - find and select objects
    if editState.currentTool == TOOLS.SELECT and designY > 60 then
        -- Don't process select logic if clicking on properties panel
        local panelX2 = DESIGN_W - 290
        if designX >= panelX2 then
            return nil  -- Let properties panel handle it
        end

        -- First check if clicking a waypoint of selected NPC
        if editState.selectedObject and editState.selectedObjectType == "npc" then
            local wpIndex = findWaypointAt(designX, designY, editState.selectedObject)
            if wpIndex then
                editState.isDragging = true
                editState.draggingWaypoint = wpIndex
                return nil
            end
        end

        -- Find object at click position
        local obj, objType, index = findObjectAt(designX, designY)
        if obj then
            editState.selectedObject = obj
            editState.selectedObjectType = objType
            editState.isDragging = true
            editState.draggingWaypoint = nil
            editState.dragOffsetX = designX - (obj.x or 0)
            editState.dragOffsetY = designY - (obj.y or 0)
        else
            editState.selectedObject = nil
            editState.selectedObjectType = nil
        end
        editState.addingWaypoint = false
    end

    return nil
end

-- Handle asset modal click
function handleAssetModalClick(designX, designY)
    local modalW = 1000
    local modalH = 700
    local modalX = (DESIGN_W - modalW) / 2
    local modalY = (DESIGN_H - modalH) / 2

    -- Close button
    if Components.isPointInRect(designX, designY, modalX + modalW - 50, modalY + 10, 35, 35) then
        editState.assetModalOpen = false
        return nil
    end

    -- Folder tree area
    local treeW = 250
    local contentY = modalY + 60
    local contentH = modalH - 140

    if Components.isPointInRect(designX, designY, modalX + 10, contentY, treeW - 10, contentH) then
        -- Find clicked folder (accounting for scroll)
        local clickedFolder = getFolderAtY(editState.assetFolderTree, modalX + 10, contentY, designY, 0, treeW - 10, editState.folderTreeScroll)
        if clickedFolder then
            -- Toggle expansion
            if editState.expandedFolders[clickedFolder.path] then
                editState.expandedFolders[clickedFolder.path] = nil
            else
                editState.expandedFolders[clickedFolder.path] = true
            end
            editState.selectedFolder = clickedFolder.path
        end
        return nil
    end

    -- Sprites area
    local contentX = modalX + treeW + 10
    local contentW = modalW - treeW - 30

    if Components.isPointInRect(designX, designY, contentX, contentY, contentW, contentH) then
        -- Find selected folder data
        local function findFolder(folder, path)
            if folder.path == path then return folder end
            for _, sub in ipairs(folder.folders) do
                local result = findFolder(sub, path)
                if result then return result end
            end
            return nil
        end
        local selectedFolderData = findFolder(editState.assetFolderTree, editState.selectedFolder)

        if selectedFolderData then
            local thumbSize = 80
            local padding = 10
            local cols = math.floor(contentW / (thumbSize + padding))
            local row, col = 0, 0

            for _, file in ipairs(selectedFolderData.files) do
                local thumbX = contentX + padding + col * (thumbSize + padding)
                local thumbY = contentY + padding + row * (thumbSize + padding + 20) - editState.assetModalScroll

                if Components.isPointInRect(designX, designY, thumbX, thumbY, thumbSize, thumbSize + 20) then
                    editState.selectedAsset = file.path
                    return nil
                end

                col = col + 1
                if col >= cols then
                    col = 0
                    row = row + 1
                end
            end
        end
        return nil
    end

    -- Bottom panel - placement buttons
    local bottomY = modalY + modalH - 70
    if editState.selectedAsset and Components.isPointInRect(designX, designY, modalX, bottomY, modalW, 70) then
        local btnY = bottomY + 30
        local btnW = 140
        local btnH = 30
        local btnX = modalX + modalW - 480

        -- As Decoration
        if Components.isPointInRect(designX, designY, btnX, btnY, btnW, btnH) then
            editState.previewObject = {
                sprite = editState.selectedAsset,
                scale = 1.0,
                type = "decoration"
            }
            editState.placementType = OBJECT_TYPES.DECORATION
            editState.assetModalOpen = false
            editState.currentTool = TOOLS.PLACE
            return nil
        end

        btnX = btnX + btnW + 10
        -- As Building
        if Components.isPointInRect(designX, designY, btnX, btnY, btnW, btnH) then
            editState.previewObject = {
                sprite = editState.selectedAsset,
                scale = 1.0,
                type = "building"
            }
            editState.placementType = OBJECT_TYPES.BUILDING
            editState.assetModalOpen = false
            editState.currentTool = TOOLS.PLACE
            return nil
        end

        btnX = btnX + btnW + 10
        -- As NPC
        if Components.isPointInRect(designX, designY, btnX, btnY, btnW, btnH) then
            editState.previewObject = {
                sprite = editState.selectedAsset,
                scale = 0.8,
                type = "npc"
            }
            editState.placementType = OBJECT_TYPES.NPC
            editState.assetModalOpen = false
            editState.currentTool = TOOLS.PLACE
            return nil
        end
    end

    -- Click outside modal
    if not Components.isPointInRect(designX, designY, modalX, modalY, modalW, modalH) then
        editState.assetModalOpen = false
    end

    return nil
end

-- Handle properties panel click
function handlePropertiesPanelClick(designX, designY, panelX, panelY, panelW, panelH)
    local textX = panelX + 15
    local inputH = 28

    if not editState.selectedObject then return nil end

    local obj = editState.selectedObject
    local objType = editState.selectedObjectType

    -- Delete button (at bottom of panel, not scrolled)
    local deleteY = panelY + panelH - 50
    if Components.isPointInRect(designX, designY, textX, deleteY, panelW - 30, 35) then
        deleteSelectedObject()
        saveWorldLayout()
        return "saved", "Object deleted"
    end

    -- Scrollable content area - must match drawing code exactly
    local scrollAreaY = panelY + 50
    local scroll = editState.propertiesScroll or 0

    -- Start of scrollable content (Type: and ID: are first)
    -- Type label + ID label = 25 + 30 = 55 pixels, then Position header = 22
    local textY = scrollAreaY - scroll  -- Start at top of scroll area
    textY = textY + 25  -- After "Type:" row
    textY = textY + 30  -- After "ID:" row
    textY = textY + 22  -- After "Position" header

    -- X input
    local action = Components.handleTextInputClick("prop_x", designX, designY, textX + 25, textY, 80, inputH, {numeric = true})
    if action == "minus" then
        obj.x = (obj.x or 0) - 10
        saveWorldLayout()
    elseif action == "plus" then
        obj.x = (obj.x or 0) + 10
        saveWorldLayout()
    end

    -- Y input
    action = Components.handleTextInputClick("prop_y", designX, designY, textX + 155, textY, 80, inputH, {numeric = true})
    if action == "minus" then
        obj.y = (obj.y or 0) - 10
        saveWorldLayout()
    elseif action == "plus" then
        obj.y = (obj.y or 0) + 10
        saveWorldLayout()
    end

    textY = textY + 35

    -- Scale input
    action = Components.handleTextInputClick("prop_scale", designX, designY, textX + 50, textY, 60, inputH, {numeric = true})
    if action == "minus" then
        obj.scale = math.max(0.1, (obj.scale or 1) - 0.1)
        saveWorldLayout()
    elseif action == "plus" then
        obj.scale = math.min(5, (obj.scale or 1) + 0.1)
        saveWorldLayout()
    end

    textY = textY + 40

    -- Layer section (for all object types)
    textY = textY + 22  -- Header

    -- Default layer based on type if not set
    local defaultLayer = 2
    if objType == "decoration" then defaultLayer = 1 end
    if objType == "npc" then defaultLayer = 3 end

    -- Layer input
    action = Components.handleTextInputClick("prop_layer", designX, designY, textX + 50, textY, 40, inputH, {numeric = true})
    if action == "minus" then
        obj.layer = math.max(0, (obj.layer or defaultLayer) - 1)
        saveWorldLayout()
    elseif action == "plus" then
        obj.layer = math.min(5, (obj.layer or defaultLayer) + 1)
        saveWorldLayout()
    end
    textY = textY + 35

    -- Back button (decrease layer)
    if Components.isPointInRect(designX, designY, textX, textY, 60, inputH) then
        obj.layer = math.max(0, (obj.layer or defaultLayer) - 1)
        saveWorldLayout()
        return true  -- Click handled
    end

    -- Forward button (increase layer)
    if Components.isPointInRect(designX, designY, textX + 70, textY, 70, inputH) then
        obj.layer = math.min(5, (obj.layer or defaultLayer) + 1)
        saveWorldLayout()
        return true  -- Click handled
    end
    textY = textY + 35

    -- Type-specific properties
    if objType == "building" then
        textY = textY + 22  -- Header

        -- Clickable toggle
        if Components.isPointInRect(designX, designY, textX + 80, textY, 50, inputH) then
            obj.clickable = not obj.clickable
            saveWorldLayout()
        end
        textY = textY + 35

        -- Menu dropdown
        if obj.clickable then
            local selected = Components.handleDropdownClick("prop_menu", designX, designY,
                {"NONE", "GUILD", "TAVERN", "ARMORY", "POTION", "SETTINGS"},
                textX + 50, textY, 100, inputH)
            if selected then
                obj.menuTarget = selected == "NONE" and nil or selected
                saveWorldLayout()
            end
        end

    elseif objType == "npc" then
        textY = textY + 22  -- Header

        -- Behavior dropdown
        local selected = Components.handleDropdownClick("prop_behavior", designX, designY,
            {"idle", "patrol", "wander"},
            textX + 50, textY, 100, inputH)
        if selected then
            obj.behavior = selected
            -- Initialize behavior-specific fields
            if selected == "patrol" and not obj.waypoints then
                obj.waypoints = {{obj.x or 500, obj.y or 500}}
            elseif selected == "wander" and not obj.radius then
                obj.radius = 100
            end
            saveWorldLayout()
        end
        textY = textY + 35

        -- Speed input
        action = Components.handleTextInputClick("prop_speed", designX, designY, textX + 55, textY, 60, inputH, {numeric = true})
        if action == "minus" then
            obj.speed = math.max(5, (obj.speed or 30) - 5)
            saveWorldLayout()
        elseif action == "plus" then
            obj.speed = math.min(200, (obj.speed or 30) + 5)
            saveWorldLayout()
        end
        textY = textY + 40

        -- Patrol-specific
        if obj.behavior == "patrol" then
            textY = textY + 22 + 25  -- Header + waypoint count

            -- Add waypoint button
            if Components.isPointInRect(designX, designY, textX, textY, 120, inputH) then
                editState.addingWaypoint = not editState.addingWaypoint
            end
            textY = textY + 35

            -- Loop toggle
            if Components.isPointInRect(designX, designY, textX + 50, textY, 50, inputH) then
                obj.loop = not obj.loop
                saveWorldLayout()
            end

        elseif obj.behavior == "wander" then
            textY = textY + 22  -- Header

            -- Radius input
            action = Components.handleTextInputClick("prop_radius", designX, designY, textX + 60, textY, 60, inputH, {numeric = true})
            if action == "minus" then
                obj.radius = math.max(20, (obj.radius or 100) - 20)
                saveWorldLayout()
            elseif action == "plus" then
                obj.radius = math.min(500, (obj.radius or 100) + 20)
                saveWorldLayout()
            end
            textY = textY + 35
        end

        -- Animation section for NPCs
        textY = textY + 22  -- Header

        -- Animated toggle
        if Components.isPointInRect(designX, designY, textX + 75, textY, 50, inputH) then
            obj.animated = not obj.animated
            -- Auto-detect frame count if enabling animation
            if obj.animated and obj.sprite then
                local sprite = getSprite(obj.sprite)
                if sprite then
                    local w, h = sprite:getDimensions()
                    -- Assume square frames (frame width = height)
                    obj.frameCount = math.floor(w / h)
                    if obj.frameCount < 1 then obj.frameCount = 1 end
                    obj.fps = obj.fps or 8
                end
            end
            saveWorldLayout()
        end
        textY = textY + 35

        if obj.animated then
            -- Idle Frame count input
            action = Components.handleTextInputClick("prop_frameCount", designX, designY, textX + 85, textY, 50, inputH, {numeric = true})
            if action == "minus" then
                obj.frameCount = math.max(1, (obj.frameCount or 1) - 1)
                saveWorldLayout()
            elseif action == "plus" then
                obj.frameCount = math.min(32, (obj.frameCount or 1) + 1)
                saveWorldLayout()
            end
            textY = textY + 35

            -- Move frame count (for wander/patrol)
            if obj.behavior == "wander" or obj.behavior == "patrol" then
                action = Components.handleTextInputClick("prop_moveFrameCount", designX, designY, textX + 95, textY, 50, inputH, {numeric = true})
                if action == "minus" then
                    obj.moveFrameCount = math.max(1, (obj.moveFrameCount or obj.frameCount or 1) - 1)
                    saveWorldLayout()
                elseif action == "plus" then
                    obj.moveFrameCount = math.min(32, (obj.moveFrameCount or obj.frameCount or 1) + 1)
                    saveWorldLayout()
                end
                textY = textY + 35
            end

            -- FPS input
            action = Components.handleTextInputClick("prop_fps", designX, designY, textX + 40, textY, 50, inputH, {numeric = true})
            if action == "minus" then
                obj.fps = math.max(1, (obj.fps or 8) - 1)
                saveWorldLayout()
            elseif action == "plus" then
                obj.fps = math.min(30, (obj.fps or 8) + 1)
                saveWorldLayout()
            end
        end

    elseif objType == "decoration" then
        -- Animation section for decorations
        textY = textY + 22  -- Header

        -- Animated toggle
        if Components.isPointInRect(designX, designY, textX + 75, textY, 50, inputH) then
            obj.animated = not obj.animated
            -- Auto-detect frame count if enabling animation
            if obj.animated and obj.sprite then
                local sprite = getSprite(obj.sprite)
                if sprite then
                    local w, h = sprite:getDimensions()
                    -- Assume square frames (frame width = height)
                    obj.frameCount = math.floor(w / h)
                    if obj.frameCount < 1 then obj.frameCount = 1 end
                    obj.fps = obj.fps or 8
                end
            end
            saveWorldLayout()
        end
        textY = textY + 35

        if obj.animated then
            -- Frame count input
            action = Components.handleTextInputClick("prop_frameCount", designX, designY, textX + 60, textY, 50, inputH, {numeric = true})
            if action == "minus" then
                obj.frameCount = math.max(1, (obj.frameCount or 1) - 1)
                saveWorldLayout()
            elseif action == "plus" then
                obj.frameCount = math.min(32, (obj.frameCount or 1) + 1)
                saveWorldLayout()
            end
            textY = textY + 35

            -- FPS input
            action = Components.handleTextInputClick("prop_fps", designX, designY, textX + 40, textY, 50, inputH, {numeric = true})
            if action == "minus" then
                obj.fps = math.max(1, (obj.fps or 8) - 1)
                saveWorldLayout()
            elseif action == "plus" then
                obj.fps = math.min(30, (obj.fps or 8) + 1)
                saveWorldLayout()
            end
        end
    end

    return nil
end

-- Place new object
function placeNewObject(designX, designY)
    if not editState.previewObject then return end

    -- Apply grid snapping
    if editState.gridEnabled then
        designX = math.floor(designX / editState.gridSize + 0.5) * editState.gridSize
        designY = math.floor(designY / editState.gridSize + 0.5) * editState.gridSize
    end

    local placementType = editState.placementType

    if placementType == OBJECT_TYPES.BUILDING then
        local newBuilding = {
            id = "building_" .. string.format("%03d", editState.nextBuildingId),
            name = nil,
            sprite = editState.previewObject.sprite,
            x = designX,
            y = designY,
            scale = editState.previewObject.scale,
            layer = 2,  -- Default layer for buildings
            clickable = false,
            menuTarget = nil,
            description = nil
        }
        table.insert(editState.worldLayout.buildings, newBuilding)
        editState.nextBuildingId = editState.nextBuildingId + 1

    elseif placementType == OBJECT_TYPES.DECORATION then
        -- Check if sprite looks like an animation (width > height suggests spritesheet)
        local animated = false
        local frameCount = 1
        local sprite = getSprite(editState.previewObject.sprite)
        if sprite then
            local w, h = sprite:getDimensions()
            if w > h then
                animated = true
                frameCount = math.floor(w / h)
                if frameCount < 1 then frameCount = 1 end
            end
        end

        local newDec = {
            id = "decoration_" .. string.format("%03d", editState.nextDecorationId),
            sprite = editState.previewObject.sprite,
            x = designX,
            y = designY,
            scale = editState.previewObject.scale,
            layer = 1,
            animOffset = math.random() * 2,
            animated = animated,
            frameCount = frameCount,
            fps = 8
        }
        table.insert(editState.worldLayout.decorations, newDec)
        editState.nextDecorationId = editState.nextDecorationId + 1

    elseif placementType == OBJECT_TYPES.NPC then
        -- Check if sprite looks like an animation (width > height suggests spritesheet)
        local animated = false
        local frameCount = 1
        local sprite = getSprite(editState.previewObject.sprite)
        if sprite then
            local w, h = sprite:getDimensions()
            if w > h then
                animated = true
                frameCount = math.floor(w / h)
                if frameCount < 1 then frameCount = 1 end
            end
        end

        local newNpc = {
            id = "npc_" .. string.format("%03d", editState.nextNpcId),
            sprite = editState.previewObject.sprite,
            x = designX,
            y = designY,
            scale = editState.previewObject.scale,
            layer = 3,  -- Default layer for NPCs
            behavior = "idle",
            speed = 30,
            animated = animated,
            frameCount = frameCount,
            fps = 8
        }
        table.insert(editState.worldLayout.npcs, newNpc)
        editState.nextNpcId = editState.nextNpcId + 1
    end

    saveWorldLayout()

    -- Reset to select mode after placing
    editState.previewObject = nil
    editState.placementType = nil
    editState.currentTool = TOOLS.SELECT
end

-- Handle mouse released
function EditMode.handleMouseReleased(x, y, gameData)
    if editState.isDragging then
        editState.isDragging = false
        editState.draggingWaypoint = nil
        saveWorldLayout()
    end

    -- Stop tile painting
    if editState.isPaintingTiles then
        editState.isPaintingTiles = false
    end
end

-- Handle keyboard input
function EditMode.handleKeyPressed(key)
    if key == "a" and not Components.activeTextInput then
        editState.assetModalOpen = not editState.assetModalOpen
        return true
    elseif key == "escape" then
        if editState.assetModalOpen then
            editState.assetModalOpen = false
            return true
        elseif editState.addingWaypoint then
            editState.addingWaypoint = false
            return true
        elseif editState.previewObject then
            editState.previewObject = nil
            editState.currentTool = TOOLS.SELECT
            return true
        end
    elseif key == "delete" and editState.selectedObject then
        -- Delete selected waypoint if in waypoint mode
        if editState.selectedObject.behavior == "patrol" and editState.selectedObject.waypoints then
            -- For now, just delete the last waypoint
            if #editState.selectedObject.waypoints > 1 then
                table.remove(editState.selectedObject.waypoints)
                saveWorldLayout()
                return true
            end
        else
            deleteSelectedObject()
            saveWorldLayout()
            return true, "saved", "Object deleted"
        end
    elseif key == "g" then
        editState.gridEnabled = not editState.gridEnabled
        return true
    end

    -- Handle text input
    if Components.activeTextInput then
        local obj = editState.selectedObject
        if obj then
            if Components.activeTextInput == "prop_x" then
                local newVal = Components.handleTextInputKey(key, obj.x, {numeric = true})
                if newVal then obj.x = newVal; saveWorldLayout() end
            elseif Components.activeTextInput == "prop_y" then
                local newVal = Components.handleTextInputKey(key, obj.y, {numeric = true})
                if newVal then obj.y = newVal; saveWorldLayout() end
            elseif Components.activeTextInput == "prop_scale" then
                local newVal = Components.handleTextInputKey(key, obj.scale, {numeric = true, minValue = 0.1, maxValue = 5})
                if newVal then obj.scale = newVal; saveWorldLayout() end
            elseif Components.activeTextInput == "prop_speed" then
                local newVal = Components.handleTextInputKey(key, obj.speed, {numeric = true, minValue = 5, maxValue = 200})
                if newVal then obj.speed = newVal; saveWorldLayout() end
            elseif Components.activeTextInput == "prop_radius" then
                local newVal = Components.handleTextInputKey(key, obj.radius, {numeric = true, minValue = 20, maxValue = 500})
                if newVal then obj.radius = newVal; saveWorldLayout() end
            elseif Components.activeTextInput == "prop_layer" then
                local newVal = Components.handleTextInputKey(key, obj.layer, {numeric = true, minValue = 0, maxValue = 10})
                if newVal then obj.layer = newVal; saveWorldLayout() end
            end
        end
        return true
    end

    return false
end

-- Handle text input
function EditMode.handleTextInput(text)
    if Components.activeTextInput then
        local obj = editState.selectedObject
        if obj then
            if Components.activeTextInput == "prop_x" then
                local newVal = Components.handleTextInput(text, obj.x, {numeric = true})
                if newVal then obj.x = newVal end
            elseif Components.activeTextInput == "prop_y" then
                local newVal = Components.handleTextInput(text, obj.y, {numeric = true})
                if newVal then obj.y = newVal end
            elseif Components.activeTextInput == "prop_scale" then
                local newVal = Components.handleTextInput(text, obj.scale, {numeric = true})
                if newVal then obj.scale = newVal end
            elseif Components.activeTextInput == "prop_speed" then
                local newVal = Components.handleTextInput(text, obj.speed, {numeric = true})
                if newVal then obj.speed = newVal end
            elseif Components.activeTextInput == "prop_radius" then
                local newVal = Components.handleTextInput(text, obj.radius, {numeric = true})
                if newVal then obj.radius = newVal end
            elseif Components.activeTextInput == "prop_layer" then
                local newVal = Components.handleTextInput(text, obj.layer, {numeric = true})
                if newVal then obj.layer = newVal end
            end
        end
        return true
    end
    return false
end

-- Handle mouse wheel (for scrolling)
function EditMode.handleWheelMoved(x, y, mouseX, mouseY)
    local designX, designY = (mouseX - offsetX) / currentScale, (mouseY - offsetY) / currentScale

    if editState.assetModalOpen then
        local modalW = 1000
        local modalH = 700
        local modalX = (DESIGN_W - modalW) / 2
        local modalY = (DESIGN_H - modalH) / 2
        local treeW = 250
        local contentY = modalY + 60
        local contentH = modalH - 140

        -- Check if mouse is over folder tree
        if Components.isPointInRect(designX, designY, modalX + 10, contentY, treeW - 10, contentH) then
            -- Scroll folder tree
            local treeHeight = calculateFolderTreeHeight(editState.assetFolderTree, 0)
            local maxScroll = math.max(0, treeHeight - contentH)
            editState.folderTreeScroll = math.max(0, math.min(maxScroll, editState.folderTreeScroll - y * 40))
        else
            -- Scroll sprites area
            editState.assetModalScroll = math.max(0, editState.assetModalScroll - y * 40)
        end
        return true
    end

    -- Check if mouse is over properties panel
    local panelW = 280
    local panelH = 500
    local panelX = DESIGN_W - panelW - 10
    local panelY = 70

    if Components.isPointInRect(designX, designY, panelX, panelY, panelW, panelH) then
        -- Scroll properties panel
        if editState.selectedObject then
            local contentHeight = calculatePropertiesContentHeight(editState.selectedObject, editState.selectedObjectType)
            local scrollAreaH = panelH - 100
            local maxScroll = math.max(0, contentHeight - scrollAreaH)
            editState.propertiesScroll = math.max(0, math.min(maxScroll, editState.propertiesScroll - y * 30))
            return true
        end
    end

    return false
end

-- Deep copy an object for clipboard
local function deepCopy(obj)
    if type(obj) ~= "table" then return obj end
    local copy = {}
    for k, v in pairs(obj) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-- Copy selected object to clipboard
local function copyObject(obj, objType)
    editState.clipboard = deepCopy(obj)
    editState.clipboardType = objType
    print("[EditMode] Copied " .. objType .. ": " .. (obj.id or "unknown"))
end

-- Paste object from clipboard at position
local function pasteObject(designX, designY)
    if not editState.clipboard or not editState.clipboardType then
        return false, "Nothing to paste"
    end

    -- Apply grid snapping
    if editState.gridEnabled then
        designX = math.floor(designX / editState.gridSize + 0.5) * editState.gridSize
        designY = math.floor(designY / editState.gridSize + 0.5) * editState.gridSize
    end

    local newObj = deepCopy(editState.clipboard)
    newObj.x = designX
    newObj.y = designY

    if editState.clipboardType == "building" then
        newObj.id = "building_" .. string.format("%03d", editState.nextBuildingId)
        editState.nextBuildingId = editState.nextBuildingId + 1
        table.insert(editState.worldLayout.buildings, newObj)

    elseif editState.clipboardType == "decoration" then
        newObj.id = "decoration_" .. string.format("%03d", editState.nextDecorationId)
        newObj.animOffset = math.random() * 2  -- Randomize animation offset
        editState.nextDecorationId = editState.nextDecorationId + 1
        table.insert(editState.worldLayout.decorations, newObj)

    elseif editState.clipboardType == "npc" then
        newObj.id = "npc_" .. string.format("%03d", editState.nextNpcId)
        -- For patrol NPCs, offset waypoints relative to new position
        if newObj.behavior == "patrol" and newObj.waypoints and editState.clipboard.x then
            local offsetX = designX - editState.clipboard.x
            local offsetY = designY - editState.clipboard.y
            newObj.waypoints = {}
            for i, wp in ipairs(editState.clipboard.waypoints) do
                newObj.waypoints[i] = {wp[1] + offsetX, wp[2] + offsetY}
            end
        end
        editState.nextNpcId = editState.nextNpcId + 1
        table.insert(editState.worldLayout.npcs, newObj)
    end

    saveWorldLayout()
    print("[EditMode] Pasted " .. editState.clipboardType .. " at " .. designX .. ", " .. designY)
    return true, "Object pasted!"
end

-- Handle right mouse click (copy/paste)
function EditMode.handleRightClick(x, y, gameData)
    local designX, designY = screenToDesign(x, y)

    -- Don't handle if modal is open or in toolbar area
    if editState.assetModalOpen then return nil end
    if editState.tilePickerOpen then return nil end
    if designY <= 60 then return nil end

    -- Check if clicking on properties panel
    local panelW = 280
    local panelX = DESIGN_W - panelW - 10
    local panelY = 70
    local panelH = 500
    if Components.isPointInRect(designX, designY, panelX, panelY, panelW, panelH) then
        return nil
    end

    -- In tile paint mode, right-click erases tiles
    if editState.currentTool == TOOLS.TILE_PAINT then
        if eraseTile(designX, designY) then
            return true, "Tile erased"
        end
        return nil
    end

    -- Check if right-clicking on an object (copy it)
    local obj, objType, index = findObjectAt(designX, designY)
    if obj then
        copyObject(obj, objType)
        -- Select the object too
        editState.selectedObject = obj
        editState.selectedObjectType = objType
        editState.propertiesScroll = 0
        return "copied", "Object copied!"
    end

    -- Right-click on empty space (paste)
    if editState.clipboard then
        return pasteObject(designX, designY)
    end

    return nil
end

-- Get world layout (for Town to use)
function EditMode.getWorldLayout()
    return editState.worldLayout
end

return EditMode
