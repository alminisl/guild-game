-- Armory Menu Module
-- Equipment shop, crafting, and inventory management

local Components = require("ui.components")

local ArmoryMenu = {}

-- Menu design dimensions (base size before scaling)
local MENU_DESIGN_WIDTH = 1100
local MENU_DESIGN_HEIGHT = 600

-- Legacy MENU table for backward compatibility (updated dynamically)
local MENU = {
    x = 90,
    y = 60,
    width = 1100,
    height = 600
}

-- Update MENU table with current centered values
local function updateMenuRect()
    local rect = Components.getCenteredMenu(MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)
    MENU.x = rect.x
    MENU.y = rect.y
    MENU.width = rect.width
    MENU.height = rect.height
    MENU.scale = rect.scale
    return MENU
end

-- Tab definitions
local TABS = {
    {id = "shop", label = "Shop"},
    {id = "stables", label = "Stables"},
    {id = "craft", label = "Craft"},
    {id = "inventory", label = "Inventory"}
}

-- State
local currentTab = "shop"
local scrollOffset = 0
local selectedRecipe = nil
local shopFilter = "all" -- all, weapon, armor, accessory

-- Reset state when menu closes
function ArmoryMenu.resetState()
    currentTab = "shop"
    scrollOffset = 0
    selectedRecipe = nil
    shopFilter = "all"
end

-- Draw material counts summary
local function drawMaterialSummary(gameData, Materials, x, y)
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Materials:", x, y)

    local matX = x + 70
    local tierColors = {
        common = {0.6, 0.5, 0.4},
        uncommon = {0.5, 0.65, 0.8},
        rare = {0.7, 0.5, 0.85}
    }

    -- Count by tier
    local counts = {common = 0, uncommon = 0, rare = 0}
    for matId, count in pairs(gameData.inventory.materials) do
        local mat = Materials.get(matId)
        if mat and mat.tier then
            counts[mat.tier] = counts[mat.tier] + count
        end
    end

    for _, tier in ipairs({"common", "uncommon", "rare"}) do
        love.graphics.setColor(tierColors[tier])
        love.graphics.print(tier:sub(1,1):upper() .. ":" .. counts[tier], matX, y)
        matX = matX + 50
    end
end

-- Draw the stables tab (mount shop)
local function drawStablesTab(gameData, Equipment, Economy, x, y, width, height)
    -- Title and info
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Purchase mounts for your heroes", x + 10, y)
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Mounts reduce travel time on quests. All party members need mounts for full effect!", x + 10, y + 18)

    -- Get mount items
    local mountItems = {}
    for id, item in pairs(Equipment.items) do
        if item.slot == "mount" and item.tier == "basic" then
            table.insert(mountItems, item)
        end
    end

    -- Sort by cost
    table.sort(mountItems, function(a, b) return a.cost < b.cost end)

    -- Draw items
    local itemY = y + 50
    local itemHeight = 70
    local maxVisible = 5

    for i = 1, math.min(#mountItems, maxVisible) do
        local idx = i + scrollOffset
        if idx <= #mountItems then
            local item = mountItems[idx]
            local canAfford = Economy.canAfford(gameData, item.cost)

            -- Item card
            local cardColor = canAfford and {0.3, 0.28, 0.25} or {0.2, 0.2, 0.2}
            love.graphics.setColor(cardColor)
            love.graphics.rectangle("fill", x + 10, itemY, width - 20, itemHeight - 5, 5, 5)

            -- Mount icon
            love.graphics.setColor(0.6, 0.45, 0.3)
            love.graphics.rectangle("fill", x + 15, itemY + 5, 55, 55, 3, 3)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("M", x + 15, itemY + 22, 55, "center")

            -- Mount name and rank
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(item.name, x + 80, itemY + 5)

            -- Rank badge
            Components.drawRankBadge(item.rank, x + 80 + love.graphics.getFont():getWidth(item.name) + 10, itemY + 2, 22)

            -- Travel speed bonus
            local speedBonus = math.floor((item.travelSpeed or 0) * 100)
            love.graphics.setColor(0.4, 0.8, 0.5)
            love.graphics.print("-" .. speedBonus .. "% Travel Time", x + 80, itemY + 24)

            -- Stats if any
            local statsStr = Equipment.formatStats(item)
            if statsStr ~= "" then
                love.graphics.setColor(0.5, 0.7, 0.5)
                love.graphics.print(statsStr, x + 230, itemY + 24)
            end

            -- Description
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(item.description, x + 80, itemY + 42)

            -- Price and buy button
            love.graphics.setColor(Components.colors.gold)
            love.graphics.print(item.cost .. "g", x + width - 150, itemY + 15)

            local btnColor = canAfford and Components.colors.buttonActive or Components.colors.buttonDisabled
            love.graphics.setColor(btnColor)
            love.graphics.rectangle("fill", x + width - 80, itemY + 20, 60, 28, 3, 3)
            love.graphics.setColor(Components.colors.text)
            love.graphics.printf("Buy", x + width - 80, itemY + 26, 60, "center")

            itemY = itemY + itemHeight
        end
    end

    -- Scroll indicator if needed
    if #mountItems > maxVisible then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Scroll: " .. (scrollOffset + 1) .. "-" ..
            math.min(scrollOffset + maxVisible, #mountItems) .. " of " .. #mountItems,
            x + 10, y + height - 25)
    end

    -- Tip about mount mechanics
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("TIP: Party travels at the pace of the slowest member. If only some heroes have mounts, the benefit is reduced.",
        x + 10, y + height - 50, width - 20, "left")
end

-- Draw the shop tab
local function drawShopTab(gameData, Equipment, Economy, x, y, width, height)
    -- Filter buttons
    local filters = {
        {id = "all", label = "All"},
        {id = "weapon", label = "Weapons"},
        {id = "armor", label = "Armor"},
        {id = "accessory", label = "Accessories"}
    }

    local filterX = x + 10
    for _, filter in ipairs(filters) do
        local isActive = shopFilter == filter.id
        local btnColor = isActive and Components.colors.buttonActive or Components.colors.button
        love.graphics.setColor(btnColor)
        love.graphics.rectangle("fill", filterX, y, 80, 25, 3, 3)
        love.graphics.setColor(Components.colors.text)
        love.graphics.printf(filter.label, filterX, y + 5, 80, "center")
        filterX = filterX + 90
    end

    -- Get shop items
    local shopItems = Equipment.getShopItems()

    -- Filter items
    local filteredItems = {}
    for _, item in ipairs(shopItems) do
        if shopFilter == "all" or item.slot == shopFilter then
            table.insert(filteredItems, item)
        end
    end

    -- Draw items
    local itemY = y + 40
    local itemHeight = 60
    local maxVisible = 6

    for i = 1, math.min(#filteredItems, maxVisible) do
        local idx = i + scrollOffset
        if idx <= #filteredItems then
            local item = filteredItems[idx]
            local canAfford = Economy.canAfford(gameData, item.cost)

            -- Item card
            local cardColor = canAfford and Components.colors.panelLight or {0.2, 0.2, 0.2}
            love.graphics.setColor(cardColor)
            love.graphics.rectangle("fill", x + 10, itemY, width - 20, itemHeight - 5, 5, 5)

            -- Slot icon/badge
            local slotColors = {
                weapon = {0.7, 0.5, 0.3},
                armor = {0.5, 0.5, 0.6},
                accessory = {0.6, 0.5, 0.7}
            }
            love.graphics.setColor(slotColors[item.slot] or {0.5, 0.5, 0.5})
            love.graphics.rectangle("fill", x + 15, itemY + 5, 45, 45, 3, 3)

            -- Slot letter
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(item.slot:sub(1,1):upper(), x + 15, itemY + 18, 45, "center")

            -- Item name and rank
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(item.name, x + 70, itemY + 8)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(item.rank .. "-rank " .. item.slot, x + 70, itemY + 26)

            -- Stats
            local statsStr = Equipment.formatStats(item)
            love.graphics.setColor(0.3, 0.7, 0.4)
            love.graphics.print(statsStr, x + 250, itemY + 8)

            -- Description
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(item.description, x + 250, itemY + 26)

            -- Price and buy button
            love.graphics.setColor(Components.colors.gold)
            love.graphics.print(item.cost .. "g", x + width - 150, itemY + 10)

            local btnColor = canAfford and Components.colors.buttonActive or Components.colors.buttonDisabled
            love.graphics.setColor(btnColor)
            love.graphics.rectangle("fill", x + width - 80, itemY + 15, 60, 28, 3, 3)
            love.graphics.setColor(Components.colors.text)
            love.graphics.printf("Buy", x + width - 80, itemY + 21, 60, "center")

            itemY = itemY + itemHeight
        end
    end

    -- Scroll indicator if needed
    if #filteredItems > maxVisible then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Scroll: " .. (scrollOffset + 1) .. "-" ..
            math.min(scrollOffset + maxVisible, #filteredItems) .. " of " .. #filteredItems,
            x + 10, y + height - 25)
    end
end

-- Draw the craft tab
local function drawCraftTab(gameData, Materials, Recipes, Equipment, CraftingSystem, x, y, width, height)
    -- Material summary
    drawMaterialSummary(gameData, Materials, x + 10, y)

    -- Get available recipes
    local recipes = CraftingSystem.getAvailableRecipes(gameData)

    -- Draw recipes
    local recipeY = y + 30
    local recipeHeight = 75
    local maxVisible = 5

    if #recipes == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No recipes available at your guild level", x, recipeY + 50, width, "center")
        return
    end

    for i = 1, math.min(#recipes, maxVisible) do
        local idx = i + scrollOffset
        if idx <= #recipes then
            local recipe = recipes[idx]
            local canCraft = CraftingSystem.canCraft(recipe, gameData)

            -- Recipe card
            local cardColor = canCraft and {0.25, 0.3, 0.25} or Components.colors.panelLight
            love.graphics.setColor(cardColor)
            love.graphics.rectangle("fill", x + 10, recipeY, width - 20, recipeHeight - 5, 5, 5)

            -- Category badge
            local catColors = {
                weapon = {0.7, 0.5, 0.3},
                armor = {0.5, 0.5, 0.6},
                accessory = {0.6, 0.5, 0.7},
                material = {0.5, 0.6, 0.5}
            }
            love.graphics.setColor(catColors[recipe.category] or {0.5, 0.5, 0.5})
            love.graphics.rectangle("fill", x + 15, recipeY + 5, 45, 60, 3, 3)

            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(recipe.category:sub(1,1):upper(), x + 15, recipeY + 25, 45, "center")

            -- Recipe name and rank
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(recipe.name, x + 70, recipeY + 5)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(recipe.requiredRank .. "-rank", x + 70, recipeY + 22)

            -- Materials required
            local matX = x + 70
            local matY = recipeY + 42
            for _, req in ipairs(recipe.materials) do
                local mat = Materials.get(req.id)
                local have = gameData.inventory.materials[req.id] or 0
                local hasEnough = have >= req.amount

                love.graphics.setColor(hasEnough and {0.3, 0.7, 0.4} or {0.7, 0.3, 0.3})
                local matText = (mat and mat.name or req.id) .. " x" .. req.amount
                if not hasEnough then
                    matText = matText .. " (" .. have .. ")"
                end
                love.graphics.print(matText, matX, matY)
                matX = matX + 130
            end

            -- Result stats (for equipment)
            if recipe.resultType == "equipment" then
                local resultItem = Equipment.get(recipe.result)
                if resultItem then
                    love.graphics.setColor(0.3, 0.7, 0.4)
                    love.graphics.print("-> " .. Equipment.formatStats(resultItem), x + 420, recipeY + 5)
                end
            end

            -- Craft button
            local btnColor = canCraft and Components.colors.buttonActive or Components.colors.buttonDisabled
            love.graphics.setColor(btnColor)
            love.graphics.rectangle("fill", x + width - 80, recipeY + 22, 60, 28, 3, 3)
            love.graphics.setColor(Components.colors.text)
            love.graphics.printf("Craft", x + width - 80, recipeY + 28, 60, "center")

            recipeY = recipeY + recipeHeight
        end
    end

    -- Scroll indicator
    if #recipes > maxVisible then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Scroll: " .. (scrollOffset + 1) .. "-" ..
            math.min(scrollOffset + maxVisible, #recipes) .. " of " .. #recipes,
            x + 10, y + height - 25)
    end
end

-- Draw the inventory tab
local function drawInventoryTab(gameData, Equipment, Materials, EquipmentSystem, x, y, width, height)
    -- Equipment section
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("EQUIPMENT", x + 10, y)

    local equipList = EquipmentSystem.getInventoryList(gameData)

    if #equipList == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("No equipment in inventory", x + 10, y + 25)
    else
        local equipY = y + 25
        local itemsPerRow = 3
        local itemWidth = math.floor((width - 40) / itemsPerRow)

        for i, entry in ipairs(equipList) do
            local item = entry.item
            local count = entry.count

            local col = ((i - 1) % itemsPerRow)
            local row = math.floor((i - 1) / itemsPerRow)
            local itemX = x + 10 + col * itemWidth
            local itemY = equipY + row * 50

            if row >= 3 then break end -- Limit display

            -- Item card
            local slotColors = {
                weapon = {0.35, 0.3, 0.25},
                armor = {0.3, 0.3, 0.35},
                accessory = {0.35, 0.3, 0.35},
                mount = {0.35, 0.32, 0.25}
            }
            love.graphics.setColor(slotColors[item.slot] or {0.3, 0.3, 0.3})
            love.graphics.rectangle("fill", itemX, itemY, itemWidth - 10, 45, 3, 3)

            -- Item info
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(item.name, itemX + 5, itemY + 5)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(item.rank .. " " .. item.slot, itemX + 5, itemY + 22)

            -- Count badge
            if count > 1 then
                love.graphics.setColor(Components.colors.gold)
                love.graphics.print("x" .. count, itemX + itemWidth - 35, itemY + 5)
            end
        end
    end

    -- Materials section
    local matSectionY = y + 180
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("MATERIALS", x + 10, matSectionY)

    local matList = {}
    for matId, count in pairs(gameData.inventory.materials) do
        if count > 0 then
            local mat = Materials.get(matId)
            if mat then
                table.insert(matList, {material = mat, count = count})
            end
        end
    end

    -- Sort by tier
    local tierOrder = {common = 1, uncommon = 2, rare = 3}
    table.sort(matList, function(a, b)
        return (tierOrder[a.material.tier] or 0) < (tierOrder[b.material.tier] or 0)
    end)

    if #matList == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("No materials - complete quests to gather materials!", x + 10, matSectionY + 25)
    else
        local matY = matSectionY + 25
        local matsPerRow = 3
        local matWidth = math.floor((width - 40) / matsPerRow)

        local tierColors = {
            common = {0.6, 0.5, 0.4},
            uncommon = {0.5, 0.65, 0.8},
            rare = {0.7, 0.5, 0.85}
        }

        for i, entry in ipairs(matList) do
            local mat = entry.material
            local count = entry.count

            local col = ((i - 1) % matsPerRow)
            local row = math.floor((i - 1) / matsPerRow)
            local itemX = x + 10 + col * matWidth
            local itemY = matY + row * 40

            if row >= 4 then break end -- Limit display

            -- Material card with tier color
            love.graphics.setColor(tierColors[mat.tier] or {0.4, 0.4, 0.4})
            love.graphics.rectangle("fill", itemX, itemY, matWidth - 10, 35, 3, 3)

            -- Material info
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(mat.name, itemX + 5, itemY + 5)

            love.graphics.setColor(Components.colors.gold)
            love.graphics.print("x" .. count, itemX + matWidth - 40, itemY + 10)
        end
    end
end

-- Main draw function
function ArmoryMenu.draw(gameData, Equipment, Materials, Recipes, EquipmentSystem, CraftingSystem, Economy, Heroes)
    -- Update menu position for current window size
    updateMenuRect()
    local scale = MENU.scale or 1

    -- Dark background overlay (screen coordinates)
    local windowW, windowH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, windowW, windowH)

    -- Apply transform for scaled menu content
    love.graphics.push()
    love.graphics.translate(MENU.x, MENU.y)
    love.graphics.scale(scale, scale)

    -- Background panel (design coordinates)
    Components.drawPanel(0, 0, MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("IRONFORGE ARMORY", 0, 15, MENU_DESIGN_WIDTH, "center")

    -- Close button
    Components.drawCloseButton(MENU_DESIGN_WIDTH - 40, 10)

    -- Gold display
    Components.drawGold(gameData.gold, 20, 15)

    -- Tabs
    local tabY = 50
    local tabWidth = 100
    local tabX = 20

    for _, tab in ipairs(TABS) do
        local isActive = currentTab == tab.id
        local btnColor = isActive and Components.colors.buttonActive or Components.colors.button
        love.graphics.setColor(btnColor)
        love.graphics.rectangle("fill", tabX, tabY, tabWidth, 30, 5, 5)

        love.graphics.setColor(Components.colors.text)
        love.graphics.printf(tab.label, tabX, tabY + 7, tabWidth, "center")

        tabX = tabX + tabWidth + 10
    end

    -- Content area (design coordinates)
    local contentX = 20
    local contentY = 95
    local contentWidth = MENU_DESIGN_WIDTH - 40
    local contentHeight = MENU_DESIGN_HEIGHT - 110

    if currentTab == "shop" then
        drawShopTab(gameData, Equipment, Economy, contentX, contentY, contentWidth, contentHeight)
    elseif currentTab == "stables" then
        drawStablesTab(gameData, Equipment, Economy, contentX, contentY, contentWidth, contentHeight)
    elseif currentTab == "craft" then
        drawCraftTab(gameData, Materials, Recipes, Equipment, CraftingSystem, contentX, contentY, contentWidth, contentHeight)
    elseif currentTab == "inventory" then
        drawInventoryTab(gameData, Equipment, Materials, EquipmentSystem, contentX, contentY, contentWidth, contentHeight)
    end

    -- Hint text
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Tip: Complete cave/mine quests for bonus materials! Higher luck = more drops.",
        0, MENU_DESIGN_HEIGHT - 25, MENU_DESIGN_WIDTH, "center")

    -- Restore transform
    love.graphics.pop()
end

-- Handle click
function ArmoryMenu.handleClick(x, y, gameData, Equipment, Materials, Recipes, EquipmentSystem, CraftingSystem, Economy, Heroes)
    -- Update menu position for current window size
    updateMenuRect()
    local scale = MENU.scale or 1

    -- Transform screen coordinates to design coordinates
    local designX = (x - MENU.x) / scale
    local designY = (y - MENU.y) / scale

    -- Close button (design coordinates)
    if Components.isPointInRect(designX, designY, MENU_DESIGN_WIDTH - 40, 10, 30, 30) then
        return "close"
    end

    -- Tab clicks (design coordinates)
    local tabY = 50
    local tabWidth = 100
    local tabX = 20

    for _, tab in ipairs(TABS) do
        if Components.isPointInRect(designX, designY, tabX, tabY, tabWidth, 30) then
            currentTab = tab.id
            scrollOffset = 0
            return nil
        end
        tabX = tabX + tabWidth + 10
    end

    local contentX = 20
    local contentY = 95
    local contentWidth = MENU_DESIGN_WIDTH - 40

    -- Stables tab clicks
    if currentTab == "stables" then
        -- Get mount items
        local mountItems = {}
        for id, item in pairs(Equipment.items) do
            if item.slot == "mount" and item.tier == "basic" then
                table.insert(mountItems, item)
            end
        end
        table.sort(mountItems, function(a, b) return a.cost < b.cost end)

        local itemY = contentY + 50
        local itemHeight = 70
        local maxVisible = 5

        for i = 1, math.min(#mountItems, maxVisible) do
            local idx = i + scrollOffset
            if idx <= #mountItems then
                local item = mountItems[idx]

                -- Buy button click
                if Components.isPointInRect(designX, designY, contentX + contentWidth - 80, itemY + 20, 60, 28) then
                    if Economy.canAfford(gameData, item.cost) then
                        local success, msg = Economy.spend(gameData, item.cost, "buying " .. item.name)
                        if success then
                            EquipmentSystem.addToInventory(item.id, 1, gameData)
                            return "purchased", "Bought " .. item.name .. "!"
                        else
                            return "error", msg
                        end
                    else
                        return "error", "Not enough gold!"
                    end
                end

                itemY = itemY + itemHeight
            end
        end
    end

    -- Shop tab clicks
    if currentTab == "shop" then
        -- Filter buttons
        local filters = {"all", "weapon", "armor", "accessory"}
        local filterX = contentX + 10
        for _, filter in ipairs(filters) do
            if Components.isPointInRect(designX, designY, filterX, contentY, 80, 25) then
                shopFilter = filter
                scrollOffset = 0
                return nil
            end
            filterX = filterX + 90
        end

        -- Buy buttons
        local shopItems = Equipment.getShopItems()
        local filteredItems = {}
        for _, item in ipairs(shopItems) do
            if shopFilter == "all" or item.slot == shopFilter then
                table.insert(filteredItems, item)
            end
        end

        local itemY = contentY + 40
        local itemHeight = 60
        local maxVisible = 6

        for i = 1, math.min(#filteredItems, maxVisible) do
            local idx = i + scrollOffset
            if idx <= #filteredItems then
                local item = filteredItems[idx]

                -- Buy button click
                if Components.isPointInRect(designX, designY, contentX + contentWidth - 80, itemY + 15, 60, 28) then
                    if Economy.canAfford(gameData, item.cost) then
                        local success, msg = Economy.spend(gameData, item.cost, "buying " .. item.name)
                        if success then
                            EquipmentSystem.addToInventory(item.id, 1, gameData)
                            return "purchased", "Bought " .. item.name .. "!"
                        else
                            return "error", msg
                        end
                    else
                        return "error", "Not enough gold!"
                    end
                end

                itemY = itemY + itemHeight
            end
        end
    end

    -- Craft tab clicks
    if currentTab == "craft" then
        local recipes = CraftingSystem.getAvailableRecipes(gameData)

        local recipeY = contentY + 30
        local recipeHeight = 75
        local maxVisible = 5

        for i = 1, math.min(#recipes, maxVisible) do
            local idx = i + scrollOffset
            if idx <= #recipes then
                local recipe = recipes[idx]

                -- Craft button click
                if Components.isPointInRect(designX, designY, contentX + contentWidth - 80, recipeY + 22, 60, 28) then
                    if CraftingSystem.canCraft(recipe, gameData) then
                        local success, msg = CraftingSystem.craft(recipe, gameData)
                        if success then
                            return "crafted", msg
                        else
                            return "error", msg
                        end
                    else
                        return "error", "Missing materials!"
                    end
                end

                recipeY = recipeY + recipeHeight
            end
        end
    end

    return nil
end

-- Handle scroll (call from love.wheelmoved)
function ArmoryMenu.scroll(dx, dy)
    scrollOffset = math.max(0, scrollOffset - dy)
end

return ArmoryMenu
