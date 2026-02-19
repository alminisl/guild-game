-- ui/guild_menu/state.lua
-- Centralized state management for Guild Menu

local State = {}

-- Tab state
State.currentTab = "roster"

-- Quest assignment state
State.selectedQuest = nil
State.selectedHeroes = {}  -- Table of hero IDs
State.questHeroScrollOffset = 0
State.questHeroListBounds = nil  -- Bounds for scroll area {x, y, w, h, maxScroll}
State.questSelectionMode = "heroes"  -- "heroes" or "parties"
State.selectedPartyId = nil  -- Currently selected party ID (in party mode)

-- Roster state
State.rosterScrollOffset = 0
State.rosterListBounds = nil
State.expandedParties = {}  -- Table of party IDs that are expanded
State.lastHeroClickTime = 0  -- For double-click detection
State.lastHeroClickId = nil

-- Hero detail popup state
State.selectedHeroDetail = nil  -- Hero being viewed in detail popup
State.equipDropdownSlot = nil  -- Which slot's dropdown is open (weapon/armor/accessory)
State.equipDropdownItems = {}
State.statDisplayMode = "bars"  -- "bars" or "graph"
State.heroToFire = nil  -- Hero ID pending fire confirmation

-- Party management state
State.partyCreationActive = false
State.selectedHeroesForParty = {}
State.partyCreationName = ""
State.partyScrollOffset = 0
State.selectedPartyDetail = nil
State.partyToDisband = nil

-- Tooltip/hover state
State.mouseX = 0
State.mouseY = 0
State.hoveredSynergy = nil
State.hoveredSynergyPos = nil
State.synergyHelpHovered = false
State.hoveredHeroId = nil

-- Legacy MENU table for backward compatibility (updated dynamically)
State.MENU = {
    x = 90,
    y = 60,
    width = 1100,
    height = 600,
    scale = 1
}

-- Reset all state to defaults
function State.reset()
    State.currentTab = "roster"
    State.selectedQuest = nil
    State.selectedHeroes = {}
    State.selectedHeroDetail = nil
    State.equipDropdownSlot = nil
    State.equipDropdownItems = {}
    State.hoveredSynergy = nil
    State.hoveredSynergyPos = nil
    State.synergyHelpHovered = false
    State.hoveredHeroId = nil
    State.heroToFire = nil
    State.questHeroScrollOffset = 0
    State.questHeroListBounds = nil
    State.questSelectionMode = "heroes"
    State.selectedPartyId = nil
    State.rosterScrollOffset = 0
    State.rosterListBounds = nil
    State.expandedParties = {}
    State.partyCreationActive = false
    State.selectedHeroesForParty = {}
    State.partyCreationName = ""
    State.partyScrollOffset = 0
    State.selectedPartyDetail = nil
    State.partyToDisband = nil
end

-- Update mouse position for hover effects
function State.updateMouse(mx, my)
    State.mouseX = mx
    State.mouseY = my
end

-- Tab switching helper
function State.setTab(tabId)
    State.currentTab = tabId
    -- Clear tab-specific state when switching
    if tabId ~= "quests" then
        State.selectedQuest = nil
        State.selectedHeroes = {}
        State.selectedPartyId = nil
    end
end

return State
