-- ui/guild_menu/init.lua
-- Guild Menu main orchestrator - Public API entry point

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")
local PartySystem = require("systems.party_system")
local UIAssets = require("ui.ui_assets")

-- Import all submodules
local State = require("ui.guild_menu.state")
local Helpers = require("ui.guild_menu.helpers")
local RosterTab = require("ui.guild_menu.roster_tab")
local QuestsTab = require("ui.guild_menu.quests_tab")
local ActiveTab = require("ui.guild_menu.active_tab")
local PartiesTab = require("ui.guild_menu.parties_tab")
local ReputationTab = require("ui.guild_menu.reputation_tab")
local Modals = require("ui.guild_menu.modals")
local ClickHandlers = require("ui.guild_menu.click_handlers")

local GuildMenu = {}

-- Module-level references (set during draw, used in click handler)
local _Equipment = nil
local _EquipmentSystem = nil

-- Reset all state to defaults
function GuildMenu.resetState()
    State.reset()
end

-- Handle mouse wheel scroll
function GuildMenu.handleScroll(x, y, scrollY)
    return Helpers.handleScroll(x, y, scrollY, State)
end

-- Update mouse position for hover effects
function GuildMenu.updateMouse(mx, my)
    State.updateMouse(mx, my)
end

-- Main draw function
function GuildMenu.draw(gameData, QuestSystem, Quests, Heroes, TimeSystem, GuildSystem, Equipment, EquipmentSystem)
    -- Update menu position for current window size
    Helpers.updateMenuRect(State)
    local currentScale = State.MENU.scale or 1
    
    -- Store references for click handler
    _Equipment = Equipment
    _EquipmentSystem = EquipmentSystem
    
    -- Set references for roster and quest tabs
    RosterTab.setReferences(Equipment, EquipmentSystem, gameData)
    QuestsTab.setReferences(EquipmentSystem)
    
    -- Dark background overlay (screen coordinates)
    local windowW, windowH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, windowW, windowH)
    
    -- Apply transform for scaled menu content
    love.graphics.push()
    love.graphics.translate(State.MENU.x, State.MENU.y)
    love.graphics.scale(currentScale, currentScale)
    
    -- Background panel (design coordinates)
    Components.drawPanel(0, 0, Helpers.MENU_DESIGN_WIDTH, Helpers.MENU_DESIGN_HEIGHT)
    
    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("GUILD HALL", 0, 15, Helpers.MENU_DESIGN_WIDTH, "center")
    
    -- Close button
    Components.drawCloseButton(Helpers.MENU_DESIGN_WIDTH - 40, 10)
    
    -- Gold display
    Components.drawGold(gameData.gold, 20, 15)
    
    -- Tabs
    local tabY = 50
    Components.drawTabs(Helpers.TABS, State.currentTab, 20, tabY, 100, 30)
    
    -- Tab content area
    local contentStartY = tabY + 35
    local contentHeight = Helpers.MENU_DESIGN_HEIGHT - contentStartY - 20
    
    -- Draw active tab content
    if State.currentTab == "roster" then
        RosterTab.draw(gameData, contentStartY, contentHeight, Heroes, TimeSystem, GuildSystem, State, Helpers)
    elseif State.currentTab == "quests" then
        QuestsTab.draw(gameData, contentStartY, contentHeight, QuestSystem, Quests, TimeSystem, GuildSystem, State, Helpers)
    elseif State.currentTab == "active" then
        ActiveTab.draw(gameData, contentStartY, contentHeight, QuestSystem, Quests, TimeSystem, State, Helpers)
    elseif State.currentTab == "parties" then
        PartiesTab.draw(gameData, contentStartY, contentHeight, Heroes, TimeSystem, State, Helpers)
    elseif State.currentTab == "reputation" then
        ReputationTab.draw(gameData, contentStartY, contentHeight, GuildSystem, State, Helpers)
    end
    
    -- End transform
    love.graphics.pop()
    
    -- Draw modals/tooltips (no transform - screen coordinates)
    Modals.drawTooltips(State)
    
    -- TODO: Add other modals (hero detail, party creation, etc.)
end

-- Handle click events
function GuildMenu.handleClick(x, y, gameData, QuestSystem, Quests, Heroes, GuildSystem)
    return ClickHandlers.handle(x, y, gameData, QuestSystem, Quests, Heroes, GuildSystem, State, Helpers, _Equipment, _EquipmentSystem)
end

return GuildMenu
