-- Edit Mode Module
-- In-game tooling for placing characters, decorations, and editing world layout

local Components = require("ui.components")
local json = require("utils.json")

local EditMode = {}

-- Design dimensions (same as Town)
local DESIGN_W, DESIGN_H = 1920, 1080

-- Tool types
local TOOLS = {
    SELECT = "select",
    CHARACTER = "character",
    DECORATION = "decoration"
}

-- Asset catalog (all available assets for placement)
local ASSET_CATALOG = {
    decorations = {
        trees = {
            {type = "tree1", name = "Oak Tree", sprite = "tree1"},
            {type = "tree2", name = "Pine Tree", sprite = "tree2"},
            {type = "tree3", name = "Birch Tree", sprite = "tree3"},
            {type = "tree4", name = "Willow Tree", sprite = "tree4"}
        },
        bushes = {
            {type = "bush1", name = "Bush 1", sprite = "bush1"},
            {type = "bush2", name = "Bush 2", sprite = "bush2"}
        },
        rocks = {
            {type = "rock1", name = "Rock 1", sprite = "rock1"},
            {type = "rock2", name = "Rock 2", sprite = "rock2"},
            {type = "rock3", name = "Rock 3", sprite = "rock3"}
        },
        waterRocks = {
            {type = "waterRock1", name = "Water Rock 1", sprite = "waterRock1"},
            {type = "waterRock2", name = "Water Rock 2", sprite = "waterRock2"}
        }
    },
    characters = {
        warriors = {
            {type = "warrior", name = "Warrior"}
        },
        archers = {
            {type = "archer", name = "Archer"}
        },
        pawns = {
            {type = "pawn", name = "Villager"},
            {type = "pawn_wood", name = "Woodcutter"},
            {type = "pawn_gold", name = "Merchant"},
            {type = "pawn_meat", name = "Butcher"}
        }
    }
}

-- Edit state
local editState = {
    currentTool = TOOLS.SELECT,
    selectedAssetType = nil,
    selectedObject = nil,
    isDragging = false,
    dragObject = nil,
    dragOffsetX = 0,
    dragOffsetY = 0,
    previewObject = nil,
    gridEnabled = false,
    gridSize = 32,
    assetBrowserCategory = "trees",
    assetBrowserScroll = 0,
    worldLayout = {
        version = 1,
        decorations = {},
        npcs = {},
        metadata = {}
    },
    nextDecorationId = 1,
    nextNpcId = 1,
    draggingPathPoint = nil  -- "start" or "end" when dragging character path endpoints
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

-- Initialize Edit Mode
function EditMode.init(gameData)
    updateScale()

    -- Load world layout from JSON
    local worldLayout, err = json.loadFile("data/world_layout.json")
    if worldLayout then
        editState.worldLayout = worldLayout

        -- Find highest IDs for auto-increment
        for _, dec in ipairs(editState.worldLayout.decorations or {}) do
            local idNum = tonumber(dec.id:match("%d+"))
            if idNum and idNum >= editState.nextDecorationId then
                editState.nextDecorationId = idNum + 1
            end
        end
        for _, npc in ipairs(editState.worldLayout.npcs or {}) do
            local idNum = tonumber(npc.id:match("%d+"))
            if idNum and idNum >= editState.nextNpcId then
                editState.nextNpcId = idNum + 1
            end
        end
    else
        print("Edit Mode: Failed to load world layout:", err)
        editState.worldLayout = {
            version = 1,
            decorations = {},
            npcs = {},
            metadata = {}
        }
    end

    -- Reset state
    editState.selectedObject = nil
    editState.isDragging = false
    editState.dragObject = nil
    editState.previewObject = nil
    editState.currentTool = TOOLS.SELECT
    editState.selectedAssetType = nil
    editState.draggingPathPoint = nil
end

-- Save world layout to JSON
local function saveWorldLayout()
    editState.worldLayout.metadata.lastModified = os.time()
    editState.worldLayout.metadata.modifiedBy = "EditMode"

    local success, err = json.saveFile("data/world_layout.json", editState.worldLayout)
    if success then
        return true, "World layout saved!"
    else
        return false, "Save failed: " .. (err or "unknown error")
    end
end

-- Find object at position
local function findObjectAt(designX, designY)
    -- Check NPCs first (prioritize smaller objects)
    for _, npc in ipairs(editState.worldLayout.npcs or {}) do
        local hitboxW, hitboxH = 60, 90
        if Components.isPointInRect(designX, designY, npc.startX - hitboxW/2, npc.startY - hitboxH, hitboxW, hitboxH) then
            npc.objectType = "npc"
            return npc
        end
    end

    -- Check decorations
    for _, dec in ipairs(editState.worldLayout.decorations or {}) do
        local hitboxW, hitboxH = 100 * (dec.scale or 1), 120 * (dec.scale or 1)
        if Components.isPointInRect(designX, designY, dec.x - hitboxW/2, dec.y - hitboxH, hitboxW, hitboxH) then
            dec.objectType = "decoration"
            return dec
        end
    end

    return nil
end

-- Check if dragging character path point
local function findPathPointAt(designX, designY, npc)
    if not npc or npc.objectType ~= "npc" then return nil end

    local pointRadius = 10
    -- Check start point
    if math.abs(designX - npc.startX) < pointRadius and math.abs(designY - npc.startY) < pointRadius then
        return "start"
    end
    -- Check end point
    if math.abs(designX - npc.endX) < pointRadius and math.abs(designY - npc.endY) < pointRadius then
        return "end"
    end
    return nil
end

-- Delete selected object
local function deleteSelectedObject()
    if not editState.selectedObject then return end

    if editState.selectedObject.objectType == "decoration" then
        for i, dec in ipairs(editState.worldLayout.decorations) do
            if dec.id == editState.selectedObject.id then
                table.remove(editState.worldLayout.decorations, i)
                break
            end
        end
    elseif editState.selectedObject.objectType == "npc" then
        for i, npc in ipairs(editState.worldLayout.npcs) do
            if npc.id == editState.selectedObject.id then
                table.remove(editState.worldLayout.npcs, i)
                break
            end
        end
    end

    editState.selectedObject = nil
end

-- Draw toolbar
local function drawToolbar()
    local toolbarH = 60
    local toolbarY = 0

    -- Draw toolbar background
    love.graphics.setColor(0.15, 0.15, 0.2, 0.95)
    love.graphics.rectangle("fill", 0, toolbarY, DESIGN_W, toolbarH)

    -- Tool buttons
    local btnX = 20
    local btnY = toolbarY + 10
    local btnW = 100
    local btnH = 40
    local btnSpacing = 10

    -- Select tool
    local selectColor = (editState.currentTool == TOOLS.SELECT) and {0.3, 0.6, 0.4} or Components.colors.button
    Components.drawButton("Select", btnX, btnY, btnW, btnH, {color = selectColor})

    btnX = btnX + btnW + btnSpacing
    -- Character tool
    local charColor = (editState.currentTool == TOOLS.CHARACTER) and {0.3, 0.6, 0.4} or Components.colors.button
    Components.drawButton("Character", btnX, btnY, btnW, btnH, {color = charColor})

    btnX = btnX + btnW + btnSpacing
    -- Decoration tool
    local decColor = (editState.currentTool == TOOLS.DECORATION) and {0.3, 0.6, 0.4} or Components.colors.button
    Components.drawButton("Decoration", btnX, btnY, btnW, btnH, {color = decColor})

    -- Grid toggle
    btnX = btnX + btnW + 40
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Grid:", btnX, btnY + 12)
    local gridText = editState.gridEnabled and "ON" or "OFF"
    local gridColor = editState.gridEnabled and {0.3, 0.6, 0.4} or {0.5, 0.3, 0.3}
    Components.drawButton(gridText, btnX + 50, btnY, 60, btnH, {color = gridColor})

    -- Save button
    btnX = DESIGN_W - 220
    Components.drawButton("Save", btnX, btnY, 90, btnH, {color = {0.3, 0.5, 0.7}})

    -- Exit button
    btnX = DESIGN_W - 120
    Components.drawButton("Exit", btnX, btnY, 100, btnH, {color = {0.6, 0.3, 0.3}})
end

-- Draw asset browser
local function drawAssetBrowser()
    local browserW = 250
    local browserH = DESIGN_H - 60  -- Full height minus toolbar
    local browserX = 0
    local browserY = 60

    -- Draw browser background
    love.graphics.setColor(0.2, 0.2, 0.25, 0.95)
    love.graphics.rectangle("fill", browserX, browserY, browserW, browserH)

    -- Category tabs
    local categories = {"trees", "bushes", "rocks", "waterRocks", "characters"}
    local categoryLabels = {trees = "Trees", bushes = "Bushes", rocks = "Rocks", waterRocks = "Water", characters = "Characters"}
    local tabH = 35
    local tabY = browserY + 10

    for _, cat in ipairs(categories) do
        local isSelected = editState.assetBrowserCategory == cat
        local tabColor = isSelected and {0.3, 0.6, 0.4} or Components.colors.button

        love.graphics.setColor(tabColor[1], tabColor[2], tabColor[3])
        love.graphics.rectangle("fill", browserX + 10, tabY, browserW - 20, tabH - 5, 3, 3)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(categoryLabels[cat], browserX + 10, tabY + 8, browserW - 20, "center")

        tabY = tabY + tabH
    end

    -- Asset list
    local listY = browserY + 10 + (#categories * 35) + 10
    local assets = {}

    if editState.assetBrowserCategory == "characters" then
        -- Flatten character categories
        for catName, catAssets in pairs(ASSET_CATALOG.characters) do
            for _, asset in ipairs(catAssets) do
                table.insert(assets, asset)
            end
        end
    else
        assets = ASSET_CATALOG.decorations[editState.assetBrowserCategory] or {}
    end

    -- Draw assets
    for i, asset in ipairs(assets) do
        local itemH = 40
        local itemY = listY + (i - 1) * (itemH + 5)

        local isSelected = editState.selectedAssetType == asset.type
        local itemColor = isSelected and {0.4, 0.4, 0.5} or {0.25, 0.25, 0.3}

        love.graphics.setColor(itemColor[1], itemColor[2], itemColor[3])
        love.graphics.rectangle("fill", browserX + 15, itemY, browserW - 30, itemH, 3, 3)

        love.graphics.setColor(Components.colors.text)
        love.graphics.print(asset.name, browserX + 25, itemY + 12)
    end
end

-- Draw properties panel
local function drawPropertiesPanel()
    if not editState.selectedObject then return end

    local panelW = 250
    local panelH = 400
    local panelX = DESIGN_W - panelW
    local panelY = 70

    -- Draw panel background
    love.graphics.setColor(0.2, 0.2, 0.25, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)

    love.graphics.setColor(Components.colors.text)
    local textX = panelX + 15
    local textY = panelY + 15

    -- Title
    love.graphics.print("Properties", textX, textY)
    textY = textY + 30

    -- Type
    love.graphics.print("Type: " .. (editState.selectedObject.type or "unknown"), textX, textY)
    textY = textY + 25

    -- Position
    if editState.selectedObject.objectType == "decoration" then
        love.graphics.print("X: " .. math.floor(editState.selectedObject.x), textX, textY)
        textY = textY + 20
        love.graphics.print("Y: " .. math.floor(editState.selectedObject.y), textX, textY)
        textY = textY + 25

        -- Scale
        love.graphics.print("Scale: " .. string.format("%.2f", editState.selectedObject.scale or 1.0), textX, textY)
        textY = textY + 20

        -- Layer
        love.graphics.print("Layer: " .. (editState.selectedObject.layer or 1), textX, textY)
        textY = textY + 30

    elseif editState.selectedObject.objectType == "npc" then
        love.graphics.print("Start X: " .. math.floor(editState.selectedObject.startX), textX, textY)
        textY = textY + 20
        love.graphics.print("Start Y: " .. math.floor(editState.selectedObject.startY), textX, textY)
        textY = textY + 20
        love.graphics.print("End X: " .. math.floor(editState.selectedObject.endX), textX, textY)
        textY = textY + 20
        love.graphics.print("End Y: " .. math.floor(editState.selectedObject.endY), textX, textY)
        textY = textY + 25

        -- Speed
        love.graphics.print("Speed: " .. (editState.selectedObject.speed or 20), textX, textY)
        textY = textY + 30
    end

    -- Delete button
    Components.drawButton("Delete", panelX + 75, panelY + panelH - 50, 100, 35, {color = {0.6, 0.3, 0.3}})
end

-- Draw grid overlay
local function drawGrid()
    if not editState.gridEnabled then return end

    love.graphics.setColor(1, 1, 1, 0.15)
    local gridSize = editState.gridSize

    -- Vertical lines
    for x = 0, DESIGN_W, gridSize do
        love.graphics.line(x, 60, x, DESIGN_H)
    end

    -- Horizontal lines
    for y = 60, DESIGN_H, gridSize do
        love.graphics.line(0, y, DESIGN_W, y)
    end
end

-- Draw selection highlight
local function drawSelectionHighlight()
    if not editState.selectedObject then return end

    love.graphics.setColor(1, 1, 0, 0.8)
    love.graphics.setLineWidth(3)

    if editState.selectedObject.objectType == "decoration" then
        local x = editState.selectedObject.x
        local y = editState.selectedObject.y
        local w = 100 * (editState.selectedObject.scale or 1)
        local h = 120 * (editState.selectedObject.scale or 1)
        love.graphics.rectangle("line", x - w/2, y - h, w, h)

    elseif editState.selectedObject.objectType == "npc" then
        local x = editState.selectedObject.startX
        local y = editState.selectedObject.startY
        local w = 60
        local h = 90
        love.graphics.rectangle("line", x - w/2, y - h, w, h)

        -- Draw path line
        love.graphics.setColor(0.5, 0.8, 1, 0.8)
        love.graphics.line(editState.selectedObject.startX, editState.selectedObject.startY,
                          editState.selectedObject.endX, editState.selectedObject.endY)

        -- Draw path points
        love.graphics.setColor(0.3, 0.6, 1, 0.9)
        love.graphics.circle("fill", editState.selectedObject.startX, editState.selectedObject.startY, 8)
        love.graphics.setColor(0.6, 0.3, 1, 0.9)
        love.graphics.circle("fill", editState.selectedObject.endX, editState.selectedObject.endY, 8)
    end

    love.graphics.setLineWidth(1)
end

-- Draw preview object
local function drawPreview()
    if not editState.previewObject then return end

    love.graphics.setColor(1, 1, 1, 0.5)
    local x = editState.previewObject.x
    local y = editState.previewObject.y

    if editState.previewObject.objectType == "decoration" then
        local w = 100 * (editState.previewObject.scale or 1)
        local h = 120 * (editState.previewObject.scale or 1)
        love.graphics.rectangle("fill", x - w/2, y - h, w, h)
    elseif editState.previewObject.objectType == "npc" then
        local w = 60
        local h = 90
        love.graphics.rectangle("fill", x - w/2, y - h, w, h)
    end
end

-- Main draw function
function EditMode.draw(gameData, mouseX, mouseY)
    updateScale()

    -- Transform to design space
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(currentScale, currentScale)

    -- Draw grid
    drawGrid()

    -- Draw selection highlight
    drawSelectionHighlight()

    -- Draw preview
    drawPreview()

    -- Draw UI
    drawToolbar()
    drawAssetBrowser()
    drawPropertiesPanel()

    love.graphics.pop()
end

-- Update function
function EditMode.update(dt, mouseX, mouseY)
    if editState.isDragging and (editState.dragObject or editState.previewObject or editState.draggingPathPoint) then
        local designX, designY = screenToDesign(mouseX, mouseY)

        -- Apply grid snapping
        if editState.gridEnabled then
            designX = math.floor(designX / editState.gridSize + 0.5) * editState.gridSize
            designY = math.floor(designY / editState.gridSize + 0.5) * editState.gridSize
        end

        -- Update dragged object position
        if editState.dragObject then
            if editState.dragObject.objectType == "decoration" then
                editState.dragObject.x = designX - editState.dragOffsetX
                editState.dragObject.y = designY - editState.dragOffsetY
            elseif editState.dragObject.objectType == "npc" then
                local dx = (designX - editState.dragOffsetX) - editState.dragObject.startX
                local dy = (designY - editState.dragOffsetY) - editState.dragObject.startY
                editState.dragObject.startX = editState.dragObject.startX + dx
                editState.dragObject.startY = editState.dragObject.startY + dy
                editState.dragObject.endX = editState.dragObject.endX + dx
                editState.dragObject.endY = editState.dragObject.endY + dy
            end
        elseif editState.previewObject then
            editState.previewObject.x = designX
            editState.previewObject.y = designY
        elseif editState.draggingPathPoint and editState.selectedObject and editState.selectedObject.objectType == "npc" then
            -- Update path endpoint
            if editState.draggingPathPoint == "start" then
                editState.selectedObject.startX = designX
                editState.selectedObject.startY = designY
            elseif editState.draggingPathPoint == "end" then
                editState.selectedObject.endX = designX
                editState.selectedObject.endY = designY
            end
        end
    end
end

-- Handle mouse pressed
function EditMode.handleMousePressed(x, y, gameData)
    local designX, designY = screenToDesign(x, y)

    -- Check toolbar clicks
    local btnY = 10
    local btnH = 40

    -- Select tool
    if Components.isPointInRect(designX, designY, 20, btnY, 100, btnH) then
        editState.currentTool = TOOLS.SELECT
        editState.selectedAssetType = nil
        return nil
    end

    -- Character tool
    if Components.isPointInRect(designX, designY, 130, btnY, 100, btnH) then
        editState.currentTool = TOOLS.CHARACTER
        editState.assetBrowserCategory = "characters"
        return nil
    end

    -- Decoration tool
    if Components.isPointInRect(designX, designY, 240, btnY, 100, btnH) then
        editState.currentTool = TOOLS.DECORATION
        editState.assetBrowserCategory = "trees"
        return nil
    end

    -- Grid toggle
    if Components.isPointInRect(designX, designY, 390, btnY, 60, btnH) then
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

    -- Check delete button
    if editState.selectedObject then
        local panelX = DESIGN_W - 250
        local panelY = 70
        local panelH = 400
        if Components.isPointInRect(designX, designY, panelX + 75, panelY + panelH - 50, 100, 35) then
            deleteSelectedObject()
            saveWorldLayout()
            return "saved", "Object deleted"
        end
    end

    -- Check asset browser clicks
    local browserW = 250
    if designX >= 0 and designX <= browserW and designY >= 60 then
        -- Category tabs
        local categories = {"trees", "bushes", "rocks", "waterRocks", "characters"}
        local tabH = 35
        local tabY = 70

        for _, cat in ipairs(categories) do
            if Components.isPointInRect(designX, designY, 10, tabY, browserW - 20, tabH - 5) then
                editState.assetBrowserCategory = cat
                if cat == "characters" then
                    editState.currentTool = TOOLS.CHARACTER
                else
                    editState.currentTool = TOOLS.DECORATION
                end
                return nil
            end
            tabY = tabY + tabH
        end

        -- Asset list
        local listY = 70 + (#categories * 35) + 10
        local assets = {}

        if editState.assetBrowserCategory == "characters" then
            for catName, catAssets in pairs(ASSET_CATALOG.characters) do
                for _, asset in ipairs(catAssets) do
                    table.insert(assets, asset)
                end
            end
        else
            assets = ASSET_CATALOG.decorations[editState.assetBrowserCategory] or {}
        end

        for i, asset in ipairs(assets) do
            local itemH = 40
            local itemY = listY + (i - 1) * (itemH + 5)

            if Components.isPointInRect(designX, designY, 15, itemY, browserW - 30, itemH) then
                editState.selectedAssetType = asset.type
                if editState.assetBrowserCategory == "characters" then
                    editState.currentTool = TOOLS.CHARACTER
                else
                    editState.currentTool = TOOLS.DECORATION
                end
                return nil
            end
        end

        return nil
    end

    -- Check if clicking existing object (Select tool or path editing)
    if editState.currentTool == TOOLS.SELECT or (editState.selectedObject and editState.selectedObject.objectType == "npc") then
        -- Check path points first if an NPC is selected
        if editState.selectedObject and editState.selectedObject.objectType == "npc" then
            local pathPoint = findPathPointAt(designX, designY, editState.selectedObject)
            if pathPoint then
                editState.isDragging = true
                editState.draggingPathPoint = pathPoint
                return nil
            end
        end

        local clickedObj = findObjectAt(designX, designY)
        if clickedObj then
            editState.selectedObject = clickedObj
            editState.isDragging = true
            editState.dragObject = clickedObj
            if clickedObj.objectType == "decoration" then
                editState.dragOffsetX = designX - clickedObj.x
                editState.dragOffsetY = designY - clickedObj.y
            elseif clickedObj.objectType == "npc" then
                editState.dragOffsetX = designX - clickedObj.startX
                editState.dragOffsetY = designY - clickedObj.startY
            end
            return nil
        else
            -- Clicked empty space
            editState.selectedObject = nil
        end
    end

    -- Check if placing new object
    if editState.selectedAssetType and designY > 60 then
        if editState.currentTool == TOOLS.DECORATION then
            -- Create preview
            editState.previewObject = {
                type = editState.selectedAssetType,
                x = designX,
                y = designY,
                scale = 1.0,
                layer = 1,
                animOffset = math.random() * 2,
                objectType = "decoration"
            }
            editState.isDragging = true

        elseif editState.currentTool == TOOLS.CHARACTER then
            -- Create preview
            editState.previewObject = {
                type = editState.selectedAssetType,
                x = designX,
                y = designY,
                objectType = "npc"
            }
            editState.isDragging = true
        end
    end

    return nil
end

-- Handle mouse released
function EditMode.handleMouseReleased(x, y, gameData)
    local designX, designY = screenToDesign(x, y)

    if editState.isDragging then
        -- Finalize placement
        if editState.previewObject and designY > 60 then
            if editState.previewObject.objectType == "decoration" then
                local newDec = {
                    id = "decoration_" .. string.format("%03d", editState.nextDecorationId),
                    type = editState.previewObject.type,
                    x = editState.previewObject.x,
                    y = editState.previewObject.y,
                    scale = editState.previewObject.scale,
                    layer = editState.previewObject.layer,
                    animOffset = editState.previewObject.animOffset
                }
                table.insert(editState.worldLayout.decorations, newDec)
                editState.nextDecorationId = editState.nextDecorationId + 1
                saveWorldLayout()

            elseif editState.previewObject.objectType == "npc" then
                local newNpc = {
                    id = "npc_" .. string.format("%03d", editState.nextNpcId),
                    type = editState.previewObject.type,
                    startX = editState.previewObject.x,
                    startY = editState.previewObject.y,
                    endX = editState.previewObject.x + 200,  -- Default path offset
                    endY = editState.previewObject.y,
                    speed = 20,
                    scale = 0.8
                }
                table.insert(editState.worldLayout.npcs, newNpc)
                editState.nextNpcId = editState.nextNpcId + 1
                saveWorldLayout()
            end

            editState.previewObject = nil
        elseif editState.dragObject or editState.draggingPathPoint then
            -- Object was moved, save
            saveWorldLayout()
        end

        editState.isDragging = false
        editState.dragObject = nil
        editState.draggingPathPoint = nil
    end
end

return EditMode
