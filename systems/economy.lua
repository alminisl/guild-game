-- Economy System Module
-- Gold management, costs, and rewards

local Economy = {}

-- Default starting values
Economy.startingGold = 200

-- Cost multipliers
Economy.costs = {
    tavernRefresh = 25,     -- Cost to refresh tavern pool
    rosterSlot = 100,       -- Cost per additional roster slot (future)
}

-- Initialize economy state
function Economy.init()
    return {
        gold = Economy.startingGold
    }
end

-- Check if can afford an amount
function Economy.canAfford(gameData, amount)
    return gameData.gold >= amount
end

-- Spend gold (returns true if successful)
function Economy.spend(gameData, amount, reason)
    if Economy.canAfford(gameData, amount) then
        gameData.gold = gameData.gold - amount
        return true, "Spent " .. amount .. " gold" .. (reason and (" on " .. reason) or "")
    else
        return false, "Not enough gold! Need " .. amount .. ", have " .. gameData.gold
    end
end

-- Earn gold
function Economy.earn(gameData, amount, reason)
    gameData.gold = gameData.gold + amount
    return true, "Earned " .. amount .. " gold" .. (reason and (" from " .. reason) or "")
end

-- Get formatted gold string
function Economy.formatGold(amount)
    if amount >= 1000 then
        return string.format("%.1fk", amount / 1000)
    end
    return tostring(amount)
end

return Economy
