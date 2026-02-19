-- ui/guild_menu/reputation_tab.lua
-- Reputation tab - Show faction standings

local Components = require("ui.components")

local ReputationTab = {}

-- Main reputation tab draw function
function ReputationTab.draw(gameData, startY, height, GuildSystem, State, Helpers)
    local MENU_DESIGN_WIDTH = Helpers.MENU_DESIGN_WIDTH
    
    if not GuildSystem then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("Guild system not available", 0, startY + 50, MENU_DESIGN_WIDTH, "center")
        return
    end

    -- Guild level info
    local guildLevel = gameData.guild and gameData.guild.level or 1
    local progress, needed, percent = GuildSystem.getXPProgress(gameData)
    local currentXP = gameData.guild and gameData.guild.xp or 0

    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Guild Level " .. guildLevel, 20, startY)

    -- Guild XP bar
    local nextLevelXP = GuildSystem.getXPToNextLevel(gameData)
    if nextLevelXP > 0 then
        Components.drawProgressBar(150, startY, 200, 18, percent, {
            fgColor = {0.4, 0.6, 0.8},
            text = progress .. "/" .. needed .. " XP"
        })
    else
        love.graphics.setColor(Components.colors.success)
        love.graphics.print("MAX LEVEL", 150, startY)
    end

    -- Slots info
    local slotsInfo = GuildSystem.getSlotsInfo(gameData)
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Heroes: " .. slotsInfo.heroesUsed .. "/" .. slotsInfo.heroSlots ..
        "  |  Quests: " .. slotsInfo.questsActive .. "/" .. slotsInfo.questSlots, 400, startY)

    -- Faction reputation section
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Faction Reputation", 20, startY + 40)

    local y = startY + 65
    local cardHeight = 70
    local cardWidth = MENU_DESIGN_WIDTH - 40

    for _, factionId in ipairs(GuildSystem.factionOrder) do
        local faction = GuildSystem.factions[factionId]
        local rep = GuildSystem.getReputation(gameData, factionId)
        local tier = GuildSystem.getReputationTier(gameData, factionId)

        -- Card background
        Components.drawPanel(20, y, cardWidth, cardHeight, {
            color = Components.colors.panelLight,
            cornerRadius = 5
        })

        -- Faction color dot
        love.graphics.setColor(faction.color)
        love.graphics.circle("fill", 40, y + 25, 12)

        -- Faction name
        love.graphics.setColor(Components.colors.text)
        love.graphics.print(faction.name, 60, y + 10)

        -- Faction description
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(faction.description, 60, y + 30)

        -- Rival indicator
        if faction.rival then
            love.graphics.setColor(Components.colors.warning)
            love.graphics.print("Rival: " .. GuildSystem.factions[faction.rival].name, 60, y + 48)
        end

        -- Reputation value and tier
        love.graphics.setColor(tier.color)
        love.graphics.print(tier.name, 280, y + 10)

        -- Rep value (with sign)
        local repStr = rep >= 0 and ("+" .. rep) or tostring(rep)
        love.graphics.print("(" .. repStr .. ")", 380, y + 10)

        -- Reputation bar
        local repPercent = (rep + 100) / 200  -- -100 to 100 => 0 to 1
        Components.drawProgressBar(280, y + 32, 200, 14, repPercent, {
            fgColor = tier.color,
            bgColor = {0.2, 0.2, 0.2}
        })

        -- Reward multiplier
        local multStr = tier.rewardMult == 0 and "No quests" or
            (tier.rewardMult < 1 and (math.floor(tier.rewardMult * 100) .. "% rewards") or
            (tier.rewardMult > 1 and ("+" .. math.floor((tier.rewardMult - 1) * 100) .. "% rewards") or "Normal"))
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(multStr, 500, y + 30)

        y = y + cardHeight + 8
    end

    -- Info text at bottom
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Complete quests to gain reputation. Rival factions lose rep when you favor their enemies.",
        20, y + 10, cardWidth, "center")
end

return ReputationTab
