-- ui/guild_menu/modals.lua
-- Modal dialogs and popups
-- TODO: Extract full modal implementations from original guild_menu.lua lines 362-817, 2619-2783

local Components = require("ui.components")

local Modals = {}

-- Draw tooltips for synergy help
function Modals.drawTooltips(State)
    -- Synergy help tooltip
    if State.synergyHelpHovered then
        local lines = {
            "SYNERGIES",
            "Heroes with matching traits gain bonuses:",
            "• Same race: +5% success",
            "• Same class: +3% success  ",
            "• Complementary: +8% success"
        }
        Components.drawTooltip(lines, State.mouseX, State.mouseY)
    end
    
    -- Individual synergy tooltip
    if State.hoveredSynergy and State.hoveredSynergyPos then
        local syn = State.hoveredSynergy
        local lines = {
            syn.name,
            syn.description,
            "Bonus: +" .. math.floor(syn.bonus * 100) .. "% success"
        }
        Components.drawTooltip(lines, State.hoveredSynergyPos.x, State.hoveredSynergyPos.y)
    end
end

-- NOTE: Additional modal implementations needed:
-- - drawHeroDetailPopup (original lines 362-817)
-- - drawPartyCreationModal (original lines 2619-2772)
-- - drawPartyDetailModal (original lines 2775-2778)
-- - drawDisbandConfirmationModal (original lines 2780-2783)

return Modals
