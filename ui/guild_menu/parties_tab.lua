-- ui/guild_menu/parties_tab.lua
-- Parties tab - View and manage formed parties

local Components = require("ui.components")
local DesignSystem = require("ui.design_system")
local UIAssets = require("ui.ui_assets")
local PartySystem = require("systems.party_system")

local PartiesTab = {}

-- Main parties tab draw function
function PartiesTab.draw(gameData, startY, height, Heroes, TimeSystem, State, Helpers)
    local MENU_DESIGN_WIDTH = Helpers.MENU_DESIGN_WIDTH
    
    -- Header with create button
    love.graphics.setColor(DesignSystem.colors.text.primary)
    love.graphics.print("Active Parties (" .. #(gameData.parties or {}) .. "/4)", 20, startY)
    
    -- Create Party button (top right)
    local createBtnX = MENU_DESIGN_WIDTH - 180
    local createBtnY = startY - 5
    local createBtnW = 160
    local createBtnH = 32
    
    -- Check if can create more parties
    local canCreateParty = #(gameData.parties or {}) < 4
    
    UIAssets.drawButton("bigBlue", createBtnX, createBtnY, createBtnW, createBtnH, {
        text = "+ Create Party",
        disabled = not canCreateParty,
        color = canCreateParty and {1, 1, 1, 1} or {0.5, 0.5, 0.5, 0.7}
    })
    
    -- Scroll area for parties
    local scrollY = startY + 40
    local scrollHeight = height - 50
    local cardHeight = 180
    local cardSpacing = 12
    
    gameData.parties = gameData.parties or {}
    
    if #gameData.parties == 0 then
        -- No parties yet
        love.graphics.setColor(DesignSystem.colors.text.secondary)
        love.graphics.printf("No parties formed yet. Create your first party to unlock bonuses!",
            40, startY + height / 2 - 40, MENU_DESIGN_WIDTH - 80, "center")
        
        love.graphics.setColor(DesignSystem.colors.text.disabled)
        love.graphics.printf("Parties gain experience and bonuses as they quest together.",
            40, startY + height / 2, MENU_DESIGN_WIDTH - 80, "center")
    else
        -- Draw party cards (simplified for now)
        local y = scrollY - State.partyScrollOffset
        
        for i, party in ipairs(gameData.parties) do
            if y + cardHeight > scrollY and y < scrollY + scrollHeight then
                -- Simple party card
                Components.drawPanel(20, y, MENU_DESIGN_WIDTH - 40, cardHeight, {
                    color = Components.colors.panelLight,
                    cornerRadius = 5
                })
                
                -- Party name
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(party.name or "Unnamed Party", 30, y + 10)
                
                -- Status
                local statusText = PartySystem.getStatusText and PartySystem.getStatusText(party, gameData) or "Active"
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print(statusText, 30, y + 30)
                
                -- Quests completed
                love.graphics.print("Quests: " .. (party.totalQuestsCompleted or 0), 30, y + 50)
            end
            y = y + cardHeight + cardSpacing
        end
    end
end

return PartiesTab
