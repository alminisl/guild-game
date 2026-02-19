-- ui/guild_menu/helpers.lua
-- Shared utility functions for Guild Menu

local Components = require("ui.components")

local Helpers = {}

-- Menu design dimensions (base size before scaling)
Helpers.MENU_DESIGN_WIDTH = 1100
Helpers.MENU_DESIGN_HEIGHT = 600

-- Tabs configuration
Helpers.TABS = {
    {id = "roster", label = "Roster"},
    {id = "quests", label = "Quests"},
    {id = "active", label = "Active"},
    {id = "parties", label = "Parties"},
    {id = "reputation", label = "Rep"}
}

-- Get dynamic menu position and dimensions (centered and scaled)
function Helpers.getMenuRect()
    return Components.getCenteredMenu(Helpers.MENU_DESIGN_WIDTH, Helpers.MENU_DESIGN_HEIGHT)
end

-- Update MENU table with current centered values
function Helpers.updateMenuRect(State)
    local rect = Helpers.getMenuRect()
    State.MENU.x = rect.x
    State.MENU.y = rect.y
    State.MENU.width = rect.width
    State.MENU.height = rect.height
    State.MENU.scale = rect.scale
    return State.MENU
end

-- Convert design coordinates to screen coordinates for scissor
-- love.graphics.setScissor requires screen coords, not transformed coords
function Helpers.setScissorDesign(State, x, y, w, h)
    local scale = State.MENU.scale or 1
    local screenX = State.MENU.x + x * scale
    local screenY = State.MENU.y + y * scale
    local screenW = w * scale
    local screenH = h * scale
    love.graphics.setScissor(screenX, screenY, screenW, screenH)
end

-- Get quest stat requirements for pentagon chart
function Helpers.getQuestStatRequirements(quest, Quests)
    -- Get expected stat value for this quest rank
    local expectedStats = Quests and Quests.getConfig("expectedStats") or {D = 5, C = 7, B = 10, A = 13, S = 16}
    local expectedValue = expectedStats[quest.rank] or 10

    -- Build stat requirements (main stat at expected, others at low baseline)
    local reqStat = quest.requiredStat or "str"
    local baselineValue = math.floor(expectedValue * 0.2)  -- Base stats at 20% of main

    local reqs = {
        str = reqStat == "str" and expectedValue or baselineValue,
        dex = reqStat == "dex" and expectedValue or baselineValue,
        int = reqStat == "int" and expectedValue or baselineValue,
        vit = baselineValue,
        luck = baselineValue
    }

    -- Add secondary stat requirements
    if quest.secondaryStats then
        for _, secStat in ipairs(quest.secondaryStats) do
            -- Secondary stats at weighted value of expected
            local secValue = math.floor(expectedValue * 0.7 * secStat.weight + expectedValue * 0.3)
            reqs[secStat.stat] = math.max(reqs[secStat.stat], secValue)
        end
    end

    return reqs
end

-- Get combined party stats for pentagon chart
function Helpers.getPartyStats(partyHeroes, EquipmentSystem)
    local stats = {str = 0, dex = 0, int = 0, vit = 0, luck = 0}

    for _, hero in ipairs(partyHeroes) do
        for stat, _ in pairs(stats) do
            local baseValue = hero.stats[stat] or 0
            local equipBonus = EquipmentSystem and EquipmentSystem.getStatBonus(hero, stat) or 0
            stats[stat] = stats[stat] + baseValue + equipBonus
        end
    end

    return stats
end

-- Handle mouse wheel scroll
function Helpers.handleScroll(x, y, scrollY, State)
    -- Transform screen coordinates to design coordinates
    Helpers.updateMenuRect(State)
    local scale = State.MENU.scale or 1
    local designX = (x - State.MENU.x) / scale
    local designY = (y - State.MENU.y) / scale

    -- Roster tab scrolling
    if State.currentTab == "roster" then
        if State.rosterListBounds then
            local b = State.rosterListBounds
            if designX >= b.x and designX <= b.x + b.w and designY >= b.y and designY <= b.y + b.h then
                State.rosterScrollOffset = State.rosterScrollOffset - scrollY * 40
                State.rosterScrollOffset = math.max(0, math.min(State.rosterScrollOffset, b.maxScroll))
                return true
            end
        end
        return false
    end

    -- Quests tab scrolling (only when quest selected)
    if State.currentTab == "quests" and State.selectedQuest then
        if State.questHeroListBounds then
            local b = State.questHeroListBounds
            if designX >= b.x and designX <= b.x + b.w and designY >= b.y and designY <= b.y + b.h then
                State.questHeroScrollOffset = State.questHeroScrollOffset - scrollY * 40
                State.questHeroScrollOffset = math.max(0, math.min(State.questHeroScrollOffset, b.maxScroll))
                return true
            end
        end
    end

    return false
end

return Helpers
