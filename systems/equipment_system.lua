-- Equipment System Module
-- Handles equipping, unequipping, and stat calculations

local EquipmentSystem = {}

-- Load equipment data
local Equipment = require("data.equipment")

-- Get stat bonus from a single equipped item
function EquipmentSystem.getItemStatBonus(hero, slot, statName)
    local equipId = hero.equipment[slot]
    if not equipId then return 0 end

    local item = Equipment.get(equipId)
    if not item or not item.stats then return 0 end

    return item.stats[statName] or 0
end

-- Get total stat bonus from all equipment for a specific stat
function EquipmentSystem.getStatBonus(hero, statName)
    local totalBonus = 0

    for _, slot in ipairs(Equipment.slots) do
        totalBonus = totalBonus + EquipmentSystem.getItemStatBonus(hero, slot, statName)
    end

    return totalBonus
end

-- Get all stat bonuses from equipment
function EquipmentSystem.getTotalBonuses(hero)
    local bonuses = {str = 0, dex = 0, int = 0, vit = 0, luck = 0}

    for _, slot in ipairs(Equipment.slots) do
        local equipId = hero.equipment[slot]
        if equipId then
            local item = Equipment.get(equipId)
            if item and item.stats then
                for stat, value in pairs(item.stats) do
                    bonuses[stat] = bonuses[stat] + value
                end
            end
        end
    end

    return bonuses
end

-- Get effective stat (base + equipment)
function EquipmentSystem.getEffectiveStat(hero, statName)
    local base = hero.stats[statName] or 0
    local bonus = EquipmentSystem.getStatBonus(hero, statName)
    return base + bonus
end

-- Check if hero can equip an item
function EquipmentSystem.canEquip(hero, equipmentId)
    local item = Equipment.get(equipmentId)
    if not item then return false, "Item not found" end

    -- Check rank requirement
    local heroRankValue = Equipment.rankValues[hero.rank] or 1
    local itemRankValue = Equipment.rankValues[item.rank] or 1

    if heroRankValue < itemRankValue then
        return false, "Requires " .. item.rank .. "-rank hero"
    end

    -- Check if hero is available (not on quest)
    if hero.status ~= "idle" and hero.status ~= "resting" then
        return false, "Hero is busy"
    end

    return true
end

-- Equip an item to a hero
function EquipmentSystem.equip(hero, equipmentId, gameData)
    local item = Equipment.get(equipmentId)
    if not item then return false, "Item not found" end

    -- Check if hero can equip
    local canEquip, reason = EquipmentSystem.canEquip(hero, equipmentId)
    if not canEquip then return false, reason end

    -- Ensure inventory exists
    if not gameData.inventory then gameData.inventory = {} end
    if not gameData.inventory.equipment then gameData.inventory.equipment = {} end

    -- Check inventory
    local inventoryCount = gameData.inventory.equipment[equipmentId] or 0
    if inventoryCount < 1 then
        return false, "Item not in inventory"
    end

    local slot = item.slot

    -- Unequip current item if any
    if hero.equipment[slot] then
        local oldItemId = hero.equipment[slot]
        gameData.inventory.equipment[oldItemId] = (gameData.inventory.equipment[oldItemId] or 0) + 1
    end

    -- Equip new item
    hero.equipment[slot] = equipmentId
    gameData.inventory.equipment[equipmentId] = inventoryCount - 1

    -- Clean up zero counts
    if gameData.inventory.equipment[equipmentId] <= 0 then
        gameData.inventory.equipment[equipmentId] = nil
    end

    return true, "Equipped " .. item.name
end

-- Unequip an item from a hero
function EquipmentSystem.unequip(hero, slot, gameData)
    if not hero.equipment[slot] then
        return false, "No item in slot"
    end

    -- Check if hero is available
    if hero.status ~= "idle" and hero.status ~= "resting" then
        return false, "Hero is busy"
    end

    -- Ensure inventory exists
    if not gameData.inventory then gameData.inventory = {} end
    if not gameData.inventory.equipment then gameData.inventory.equipment = {} end

    local itemId = hero.equipment[slot]
    gameData.inventory.equipment[itemId] = (gameData.inventory.equipment[itemId] or 0) + 1
    hero.equipment[slot] = nil

    local item = Equipment.get(itemId)
    return true, "Unequipped " .. (item and item.name or "item")
end

-- Get equipped item in a slot
function EquipmentSystem.getEquipped(hero, slot)
    local equipId = hero.equipment[slot]
    if not equipId then return nil end
    return Equipment.get(equipId)
end

-- Check if hero has any equipment
function EquipmentSystem.hasAnyEquipment(hero)
    for _, slot in ipairs(Equipment.slots) do
        if hero.equipment[slot] then
            return true
        end
    end
    return false
end

-- Get list of heroes that can equip an item
function EquipmentSystem.getEligibleHeroes(equipmentId, gameData)
    local eligible = {}

    for _, hero in ipairs(gameData.heroes) do
        local canEquip = EquipmentSystem.canEquip(hero, equipmentId)
        if canEquip then
            table.insert(eligible, hero)
        end
    end

    return eligible
end

-- Add equipment to inventory
function EquipmentSystem.addToInventory(equipmentId, count, gameData)
    count = count or 1
    gameData.inventory.equipment[equipmentId] = (gameData.inventory.equipment[equipmentId] or 0) + count
end

-- Remove equipment from inventory
function EquipmentSystem.removeFromInventory(equipmentId, count, gameData)
    count = count or 1
    local current = gameData.inventory.equipment[equipmentId] or 0

    if current < count then
        return false, "Not enough in inventory"
    end

    gameData.inventory.equipment[equipmentId] = current - count

    -- Clean up zero counts
    if gameData.inventory.equipment[equipmentId] <= 0 then
        gameData.inventory.equipment[equipmentId] = nil
    end

    return true
end

-- Get inventory count for equipment
function EquipmentSystem.getInventoryCount(equipmentId, gameData)
    if not gameData.inventory or not gameData.inventory.equipment then
        return 0
    end
    return gameData.inventory.equipment[equipmentId] or 0
end

-- Get all equipment in inventory (with counts)
function EquipmentSystem.getInventoryList(gameData)
    local items = {}

    if not gameData.inventory or not gameData.inventory.equipment then
        return items
    end

    for equipId, count in pairs(gameData.inventory.equipment) do
        if count > 0 then
            local item = Equipment.get(equipId)
            if item then
                table.insert(items, {
                    item = item,
                    count = count
                })
            end
        end
    end

    -- Sort by slot then by rank
    table.sort(items, function(a, b)
        if a.item.slot ~= b.item.slot then
            local slotOrder = {weapon = 1, armor = 2, accessory = 3, mount = 4}
            return (slotOrder[a.item.slot] or 5) < (slotOrder[b.item.slot] or 5)
        end
        local rankOrder = {D = 1, C = 2, B = 3, A = 4, S = 5}
        return (rankOrder[a.item.rank] or 0) < (rankOrder[b.item.rank] or 0)
    end)

    return items
end

-- Get available equipment for a specific slot (from inventory, matching hero rank)
function EquipmentSystem.getAvailableForSlot(gameData, slot, heroRank)
    local available = {}

    if not gameData then
        return available
    end

    local rankValues = {D = 1, C = 2, B = 3, A = 4, S = 5}
    local heroRankValue = rankValues[heroRank] or 1

    if not gameData.inventory or not gameData.inventory.equipment then
        return available
    end

    for equipId, count in pairs(gameData.inventory.equipment) do
        if count > 0 then
            local item = Equipment.get(equipId)
            if item and item.slot == slot then
                -- Check if hero can equip (item rank <= hero rank)
                local itemRankValue = rankValues[item.rank] or 1
                if itemRankValue <= heroRankValue then
                    table.insert(available, {
                        item = item,
                        count = count
                    })
                end
            end
        end
    end

    -- Sort by rank (best first)
    table.sort(available, function(a, b)
        local rankA = rankValues[a.item.rank] or 0
        local rankB = rankValues[b.item.rank] or 0
        return rankA > rankB
    end)

    return available
end

-- Get mount travel speed bonus for a single hero
function EquipmentSystem.getMountSpeed(hero)
    local mountId = hero.equipment and hero.equipment.mount
    if not mountId then return 0 end

    local mount = Equipment.get(mountId)
    if not mount or not mount.travelSpeed then return 0 end

    return mount.travelSpeed
end

-- Calculate party travel speed multiplier
-- Logic: Party moves at the pace of the slowest member
-- If some heroes have mounts and others don't, the benefit is reduced
-- Formula: Average mount speed, weighted by how many are mounted
function EquipmentSystem.getPartyTravelSpeed(partyHeroes)
    if not partyHeroes or #partyHeroes == 0 then
        return 1.0  -- No speed change
    end

    local mountedCount = 0
    local totalMountSpeed = 0
    local slowestMountSpeed = 999

    for _, hero in ipairs(partyHeroes) do
        local mountSpeed = EquipmentSystem.getMountSpeed(hero)
        if mountSpeed > 0 then
            mountedCount = mountedCount + 1
            totalMountSpeed = totalMountSpeed + mountSpeed
            slowestMountSpeed = math.min(slowestMountSpeed, mountSpeed)
        else
            -- Hero without mount - they're walking (0% bonus)
            slowestMountSpeed = 0
        end
    end

    -- If nobody has a mount, no bonus
    if mountedCount == 0 then
        return 1.0
    end

    -- If everyone has a mount, use the slowest mount's speed
    -- (party moves at pace of slowest)
    if mountedCount == #partyHeroes then
        return 1.0 - slowestMountSpeed  -- e.g., 0.30 bonus = 0.70 travel time
    end

    -- Partial mounts: Calculate reduced benefit
    -- The unmounted heroes slow everyone down significantly
    -- Benefit = (mounted% * slowest_mount_speed * 0.5)
    -- So if 2 of 4 heroes have mounts (50%), and slowest is 0.20,
    -- you only get 0.50 * 0.20 * 0.5 = 0.05 (5%) reduction
    local mountedPercent = mountedCount / #partyHeroes
    local effectiveSpeed = mountedPercent * slowestMountSpeed * 0.5

    return 1.0 - effectiveSpeed
end

-- Get formatted party travel info for UI display
function EquipmentSystem.getPartyTravelInfo(partyHeroes)
    if not partyHeroes or #partyHeroes == 0 then
        return {
            multiplier = 1.0,
            mountedCount = 0,
            totalCount = 0,
            description = "No party"
        }
    end

    local mountedCount = 0
    for _, hero in ipairs(partyHeroes) do
        if EquipmentSystem.getMountSpeed(hero) > 0 then
            mountedCount = mountedCount + 1
        end
    end

    local multiplier = EquipmentSystem.getPartyTravelSpeed(partyHeroes)
    local bonus = math.floor((1 - multiplier) * 100)

    local description
    if mountedCount == 0 then
        description = "On foot"
    elseif mountedCount == #partyHeroes then
        description = "All mounted (-" .. bonus .. "% time)"
    else
        description = mountedCount .. "/" .. #partyHeroes .. " mounted (-" .. bonus .. "% time)"
    end

    return {
        multiplier = multiplier,
        mountedCount = mountedCount,
        totalCount = #partyHeroes,
        bonus = bonus,
        description = description
    }
end

return EquipmentSystem
