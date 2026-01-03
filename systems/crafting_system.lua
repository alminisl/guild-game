-- Crafting System Module
-- Handles crafting recipes and material management

local CraftingSystem = {}

-- Load required modules
local Recipes = require("data.recipes")
local Materials = require("data.materials")
local Equipment = require("data.equipment")

-- Check if player has all materials for a recipe
function CraftingSystem.canCraft(recipe, gameData)
    for _, req in ipairs(recipe.materials) do
        local have = gameData.inventory.materials[req.id] or 0
        if have < req.amount then
            return false
        end
    end
    return true
end

-- Check if guild level allows crafting this recipe
function CraftingSystem.meetsGuildRequirement(recipe, gameData)
    local guildLevel = gameData.guild and gameData.guild.level or 1

    -- Map guild levels to craftable ranks
    local guildMaxRank = {
        [1] = "D", [2] = "D",
        [3] = "C", [4] = "C",
        [5] = "B", [6] = "B",
        [7] = "A", [8] = "A",
        [9] = "S", [10] = "S"
    }

    local maxRank = guildMaxRank[guildLevel] or "D"
    local rankValues = {D = 1, C = 2, B = 3, A = 4, S = 5}

    local recipeRankValue = rankValues[recipe.requiredRank] or 1
    local maxRankValue = rankValues[maxRank] or 1

    return recipeRankValue <= maxRankValue
end

-- Get missing materials for a recipe
function CraftingSystem.getMissing(recipe, gameData)
    local missing = {}

    for _, req in ipairs(recipe.materials) do
        local have = gameData.inventory.materials[req.id] or 0
        if have < req.amount then
            local mat = Materials.get(req.id)
            table.insert(missing, {
                id = req.id,
                name = mat and mat.name or req.id,
                need = req.amount,
                have = have,
                short = req.amount - have
            })
        end
    end

    return missing
end

-- Craft a recipe
function CraftingSystem.craft(recipe, gameData)
    -- Check if can craft
    if not CraftingSystem.canCraft(recipe, gameData) then
        return false, "Missing materials"
    end

    -- Check guild requirement
    if not CraftingSystem.meetsGuildRequirement(recipe, gameData) then
        return false, "Guild level too low"
    end

    -- Consume materials
    for _, req in ipairs(recipe.materials) do
        gameData.inventory.materials[req.id] = gameData.inventory.materials[req.id] - req.amount

        -- Clean up zero counts
        if gameData.inventory.materials[req.id] <= 0 then
            gameData.inventory.materials[req.id] = nil
        end
    end

    -- Add result to inventory
    local resultCount = recipe.resultCount or 1

    if recipe.resultType == "equipment" then
        gameData.inventory.equipment[recipe.result] = (gameData.inventory.equipment[recipe.result] or 0) + resultCount
        local item = Equipment.get(recipe.result)
        return true, "Crafted " .. (item and item.name or recipe.result)
    elseif recipe.resultType == "material" then
        gameData.inventory.materials[recipe.result] = (gameData.inventory.materials[recipe.result] or 0) + resultCount
        local mat = Materials.get(recipe.result)
        return true, "Crafted " .. (mat and mat.name or recipe.result)
    end

    return true, "Crafted " .. recipe.name
end

-- Add material to inventory
function CraftingSystem.addMaterial(materialId, count, gameData)
    count = count or 1
    gameData.inventory.materials[materialId] = (gameData.inventory.materials[materialId] or 0) + count
end

-- Remove material from inventory
function CraftingSystem.removeMaterial(materialId, count, gameData)
    count = count or 1
    local current = gameData.inventory.materials[materialId] or 0

    if current < count then
        return false, "Not enough materials"
    end

    gameData.inventory.materials[materialId] = current - count

    -- Clean up zero counts
    if gameData.inventory.materials[materialId] <= 0 then
        gameData.inventory.materials[materialId] = nil
    end

    return true
end

-- Get material count
function CraftingSystem.getMaterialCount(materialId, gameData)
    return gameData.inventory.materials[materialId] or 0
end

-- Get all materials in inventory (with details)
function CraftingSystem.getMaterialsList(gameData)
    local mats = {}

    for matId, count in pairs(gameData.inventory.materials) do
        if count > 0 then
            local mat = Materials.get(matId)
            if mat then
                table.insert(mats, {
                    material = mat,
                    count = count
                })
            end
        end
    end

    -- Sort by tier then alphabetically
    local tierOrder = {common = 1, uncommon = 2, rare = 3}
    table.sort(mats, function(a, b)
        local tierA = tierOrder[a.material.tier] or 0
        local tierB = tierOrder[b.material.tier] or 0
        if tierA ~= tierB then
            return tierA < tierB
        end
        return a.material.name < b.material.name
    end)

    return mats
end

-- Get craftable recipes (that player has materials for)
function CraftingSystem.getCraftableRecipes(gameData)
    local craftable = {}

    for _, recipe in ipairs(Recipes.list) do
        if CraftingSystem.canCraft(recipe, gameData) and
           CraftingSystem.meetsGuildRequirement(recipe, gameData) then
            table.insert(craftable, recipe)
        end
    end

    return craftable
end

-- Get all available recipes (meeting guild level)
function CraftingSystem.getAvailableRecipes(gameData)
    local available = {}

    for _, recipe in ipairs(Recipes.list) do
        if CraftingSystem.meetsGuildRequirement(recipe, gameData) then
            table.insert(available, recipe)
        end
    end

    return available
end

-- Get recipes by category
function CraftingSystem.getRecipesByCategory(category, gameData)
    local recipes = {}

    for _, recipe in ipairs(Recipes.list) do
        if recipe.category == category then
            if CraftingSystem.meetsGuildRequirement(recipe, gameData) then
                table.insert(recipes, recipe)
            end
        end
    end

    return recipes
end

-- Get total material count by tier
function CraftingSystem.getMaterialCountByTier(gameData)
    local counts = {common = 0, uncommon = 0, rare = 0}

    for matId, count in pairs(gameData.inventory.materials) do
        local mat = Materials.get(matId)
        if mat and mat.tier then
            counts[mat.tier] = (counts[mat.tier] or 0) + count
        end
    end

    return counts
end

return CraftingSystem
