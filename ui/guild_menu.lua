-- Guild Menu Module
-- UI for managing heroes and assigning quests

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")
local PartySystem = require("systems.party_system")

local GuildMenu = {}

-- Menu design dimensions (base size before scaling)
local MENU_DESIGN_WIDTH = 1100
local MENU_DESIGN_HEIGHT = 600

-- Get dynamic menu position and dimensions (centered and scaled)
local function getMenuRect()
    return Components.getCenteredMenu(MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)
end

-- Legacy MENU table for backward compatibility (updated dynamically)
local MENU = {
    x = 90,
    y = 60,
    width = 1100,
    height = 600
}

-- Update MENU table with current centered values
local function updateMenuRect()
    local rect = getMenuRect()
    MENU.x = rect.x
    MENU.y = rect.y
    MENU.width = rect.width
    MENU.height = rect.height
    MENU.scale = rect.scale
    return MENU
end

-- Tabs
local TABS = {
    {id = "roster", label = "Roster"},
    {id = "quests", label = "Quests"},
    {id = "active", label = "Active"},
    {id = "reputation", label = "Rep"}
}

-- State
local currentTab = "roster"
local selectedQuest = nil
local selectedHeroes = {}  -- Table of hero IDs
local selectedHeroDetail = nil  -- Hero being viewed in detail popup
local equipDropdownSlot = nil  -- Which slot's dropdown is open (weapon/armor/accessory)
local equipDropdownItems = {}  -- Items available in dropdown
local statDisplayMode = "bars"  -- "bars" or "graph" for hero detail popup
local heroToFire = nil  -- Hero ID pending fire confirmation
local questHeroScrollOffset = 0  -- Scroll offset for hero list in quest tab
local questHeroListBounds = nil  -- Bounds for scroll area {x, y, w, h, maxScroll}
local questSelectionMode = "heroes"  -- "heroes" or "parties" - toggle between individual and party selection
local selectedPartyId = nil  -- Currently selected party ID (in party mode)
local rosterScrollOffset = 0  -- Scroll offset for roster tab
local rosterListBounds = nil  -- Bounds for roster scroll area
local expandedParties = {}  -- Table of party IDs that are expanded (true = expanded)
local lastHeroClickTime = 0  -- For double-click detection
local lastHeroClickId = nil  -- Which hero was last clicked

-- Tooltip/hover state
local mouseX, mouseY = 0, 0
local hoveredSynergy = nil  -- Synergy currently being hovered
local hoveredSynergyPos = nil  -- Position for tooltip
local synergyHelpHovered = false  -- Is the synergy "?" icon hovered
local hoveredHeroId = nil  -- Hero card being hovered (for status bar)

-- Helper: Convert design coordinates to screen coordinates for scissor
-- love.graphics.setScissor requires screen coords, not transformed coords
local function setScissorDesign(x, y, w, h)
    local scale = MENU.scale or 1
    local screenX = MENU.x + x * scale
    local screenY = MENU.y + y * scale
    local screenW = w * scale
    local screenH = h * scale
    love.graphics.setScissor(screenX, screenY, screenW, screenH)
end

-- Reset selection state
function GuildMenu.resetState()
    currentTab = "roster"
    selectedQuest = nil
    selectedHeroes = {}
    selectedHeroDetail = nil
    equipDropdownSlot = nil
    equipDropdownItems = {}
    hoveredSynergy = nil
    hoveredSynergyPos = nil
    synergyHelpHovered = false
    hoveredHeroId = nil
    heroToFire = nil
    questHeroScrollOffset = 0
    questHeroListBounds = nil
    questSelectionMode = "heroes"
    selectedPartyId = nil
    rosterScrollOffset = 0
    rosterListBounds = nil
    expandedParties = {}
end

-- Handle mouse wheel scroll for hero list
function GuildMenu.handleScroll(x, y, scrollY)
    -- Transform screen coordinates to design coordinates
    updateMenuRect()
    local scale = MENU.scale or 1
    local designX = (x - MENU.x) / scale
    local designY = (y - MENU.y) / scale

    -- Roster tab scrolling
    if currentTab == "roster" then
        if rosterListBounds then
            local b = rosterListBounds
            if designX >= b.x and designX <= b.x + b.w and designY >= b.y and designY <= b.y + b.h then
                rosterScrollOffset = rosterScrollOffset - scrollY * 40
                rosterScrollOffset = math.max(0, math.min(rosterScrollOffset, b.maxScroll))
                return true
            end
        end
        return false
    end

    -- Only scroll when in quests tab with a quest selected
    if currentTab ~= "quests" or not selectedQuest then return false end

    -- Check if mouse is within the hero list bounds
    if questHeroListBounds then
        local b = questHeroListBounds
        if designX >= b.x and designX <= b.x + b.w and designY >= b.y and designY <= b.y + b.h then
            -- Scroll the list
            questHeroScrollOffset = questHeroScrollOffset - scrollY * 40  -- 40px per scroll tick
            -- Clamp scroll offset
            questHeroScrollOffset = math.max(0, math.min(questHeroScrollOffset, b.maxScroll))
            return true
        end
    end
    return false
end

-- Update mouse position for hover effects (call from main update)
function GuildMenu.updateMouse(mx, my)
    mouseX = mx
    mouseY = my
end

-- Store module references for use in local functions
local _Equipment = nil
local _EquipmentSystem = nil
local _equipSlotPositions = {}
local _gameData = nil
local _Quests = nil  -- For quest stat requirements
local _toggleBtnPos = nil  -- For stats display toggle button

-- Helper: Get quest stat requirements for pentagon chart
local function getQuestStatRequirements(quest, Quests)
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

-- Helper: Get combined party stats for pentagon chart
local function getPartyStats(partyHeroes, EquipmentSystem)
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

-- Store current scale for use in sub-functions
local currentScale = 1

-- Draw the guild menu
function GuildMenu.draw(gameData, QuestSystem, Quests, Heroes, TimeSystem, GuildSystem, Equipment, EquipmentSystem)
    -- Update menu position for current window size
    updateMenuRect()
    currentScale = MENU.scale or 1

    -- Store references for popup and helpers
    _Equipment = Equipment
    _EquipmentSystem = EquipmentSystem
    _gameData = gameData
    _Quests = Quests

    -- Dark background overlay (screen coordinates)
    local windowW, windowH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, windowW, windowH)

    -- Apply transform for scaled menu content
    love.graphics.push()
    love.graphics.translate(MENU.x, MENU.y)
    love.graphics.scale(currentScale, currentScale)

    -- Background panel (design coordinates)
    Components.drawPanel(0, 0, MENU_DESIGN_WIDTH, MENU_DESIGN_HEIGHT)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("GUILD HALL", 0, 15, MENU_DESIGN_WIDTH, "center")

    -- Close button
    Components.drawCloseButton(MENU_DESIGN_WIDTH - 40, 10)

    -- Gold display
    Components.drawGold(gameData.gold, 20, 15)

    -- Tabs
    local tabY = 50
    Components.drawTabs(TABS, currentTab, 20, tabY, 100, 30)

    -- Active quests count badge
    if #gameData.activeQuests > 0 then
        love.graphics.setColor(Components.colors.warning)
        love.graphics.circle("fill", 320, tabY + 15, 10)
        love.graphics.setColor(Components.colors.text)
        love.graphics.printf(tostring(#gameData.activeQuests), 310, tabY + 8, 20, "center")
    end

    -- Content area (design coordinates)
    local contentY = tabY + 50
    local contentHeight = MENU_DESIGN_HEIGHT - 120

    if currentTab == "roster" then
        drawRosterTab(gameData, contentY, contentHeight, Heroes, TimeSystem, GuildSystem)
    elseif currentTab == "quests" then
        drawQuestsTab(gameData, contentY, contentHeight, QuestSystem, Quests, TimeSystem, GuildSystem)
    elseif currentTab == "active" then
        drawActiveTab(gameData, contentY, contentHeight, QuestSystem, Quests, TimeSystem)
    elseif currentTab == "reputation" then
        drawReputationTab(gameData, contentY, contentHeight, GuildSystem)
    end

    -- Restore transform before popups (they handle their own positioning)
    love.graphics.pop()

    -- Hero detail popup (draws on top with its own transform) - only for non-roster tabs
    -- Roster tab uses the side panel drawn within the tab
    if selectedHeroDetail and currentTab ~= "roster" then
        drawHeroDetailPopup(selectedHeroDetail, Heroes)
    end

    -- Draw tooltips last (on top of everything)
    drawTooltips()
end

-- Draw tooltips for synergies and help icons
function drawTooltips()
    -- Synergy help tooltip
    if synergyHelpHovered then
        local helpLines = {
            {text = "SYNERGIES", color = Components.colors.synergy},
            "",
            "Party combinations that grant bonuses!",
            "",
            {text = "Examples:", color = Components.colors.textDim},
            "- 2 Knights: +10% survival",
            "- 2 Mages: +15% INT quests",
            "- Rogue + Ranger: +25% drops",
            "- Priest: Death protection",
            "",
            "Hover over active synergies for details."
        }
        Components.drawTooltip(helpLines, mouseX + 15, mouseY + 15, {maxWidth = 280})
    end

    -- Specific synergy tooltip
    if hoveredSynergy and hoveredSynergyPos then
        local bonusText = ""
        if hoveredSynergy.bonus then
            local bonuses = {}
            if hoveredSynergy.bonus.deathProtection then
                table.insert(bonuses, "Prevents death on A/S quests")
            end
            if hoveredSynergy.bonus.survivalBonus then
                table.insert(bonuses, "+" .. math.floor(hoveredSynergy.bonus.survivalBonus * 100) .. "% survival")
            end
            if hoveredSynergy.bonus.successBonus then
                table.insert(bonuses, "+" .. math.floor(hoveredSynergy.bonus.successBonus * 100) .. "% success")
            end
            if hoveredSynergy.bonus.dropBonus then
                table.insert(bonuses, "+" .. math.floor(hoveredSynergy.bonus.dropBonus * 100) .. "% material drops")
            end
            if hoveredSynergy.bonus.allBonus then
                table.insert(bonuses, "+" .. math.floor(hoveredSynergy.bonus.allBonus * 100) .. "% all bonuses")
            end
            if hoveredSynergy.bonus.statBonus then
                for stat, val in pairs(hoveredSynergy.bonus.statBonus) do
                    table.insert(bonuses, "+" .. math.floor(val * 100) .. "% " .. stat:upper() .. " quests")
                end
            end
            if hoveredSynergy.bonus.travelTimeReduction then
                table.insert(bonuses, "-" .. math.floor(hoveredSynergy.bonus.travelTimeReduction * 100) .. "% travel time")
            end
            bonusText = table.concat(bonuses, ", ")
        end

        local lines = {
            {text = hoveredSynergy.name, color = Components.colors.synergy},
            hoveredSynergy.description or "",
            "",
            {text = "Bonus: " .. bonusText, color = Components.colors.success}
        }
        Components.drawTooltip(lines, hoveredSynergyPos.x, hoveredSynergyPos.y, {maxWidth = 300})
    end
end

-- Draw hero detail popup
function drawHeroDetailPopup(hero, Heroes)
    local windowW, windowH = love.graphics.getDimensions()

    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, windowW, windowH)

    -- Popup dimensions (increased width for pentagon chart, height for passive)
    local popupW, popupH = 580, 560
    local popupX = (windowW - popupW) / 2
    local popupY = (windowH - popupH) / 2

    -- Popup background
    Components.drawPanel(popupX, popupY, popupW, popupH)

    -- Close button
    Components.drawCloseButton(popupX + popupW - 40, popupY + 10)

    -- Hero name and class
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf(hero.name, popupX, popupY + 15, popupW, "center")

    -- Large animated sprite portrait (left side)
    local spritePortraitX = popupX + 60
    local spritePortraitY = popupY + 75
    -- Background frame for portrait
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", spritePortraitX - 45, spritePortraitY - 45, 90, 90, 5, 5)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", spritePortraitX - 45, spritePortraitY - 45, 90, 90, 5, 5)
    -- Draw the sprite (larger to compensate for sprite padding)
    SpriteSystem.drawCentered(hero, spritePortraitX, spritePortraitY, 216, 216, "Idle")

    -- Rank badge (right of portrait)
    Components.drawRankBadge(hero.rank, popupX + 130, popupY + 40, 36)

    -- Race, Class and level (right of portrait)
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print(hero.race or "Human", popupX + 175, popupY + 42)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(hero.class .. " - Level " .. hero.level, popupX + 175, popupY + 62)

    -- XP bar
    local xpPercent = hero.xpToLevel > 0 and (hero.xp / hero.xpToLevel) or 1
    Components.drawProgressBar(popupX + 175, popupY + 82, 150, 16, xpPercent, {
        fgColor = {0.5, 0.3, 0.7},
        text = hero.xp .. "/" .. hero.xpToLevel .. " XP"
    })

    -- Calculate effective stats (base + equipment + injury)
    local effectiveStats = {}
    local baseStats = {}
    for _, stat in ipairs({"str", "dex", "int", "vit", "luck"}) do
        local base = hero.stats[stat] or 0
        local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat) or 0
        baseStats[stat] = base
        effectiveStats[stat] = base + equipBonus
    end

    local hasEquipment = false
    for stat, val in pairs(effectiveStats) do
        if val > baseStats[stat] then hasEquipment = true break end
    end

    -- Stats section header (left side)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("STATS", popupX + 20, popupY + 115)

    -- Bars/Graph toggle button (right side)
    local toggleBtnX = popupX + popupW - 110
    local toggleBtnY = popupY + 112
    local toggleBtnW = 90
    local toggleBtnH = 22

    -- Toggle button background
    love.graphics.setColor(0.25, 0.3, 0.35)
    love.graphics.rectangle("fill", toggleBtnX, toggleBtnY, toggleBtnW, toggleBtnH, 3, 3)

    -- Bars half
    local barsSelected = statDisplayMode == "bars"
    if barsSelected then
        love.graphics.setColor(0.4, 0.5, 0.6)
    else
        love.graphics.setColor(0.2, 0.25, 0.3)
    end
    love.graphics.rectangle("fill", toggleBtnX + 2, toggleBtnY + 2, toggleBtnW/2 - 4, toggleBtnH - 4, 2, 2)
    love.graphics.setColor(barsSelected and Components.colors.text or Components.colors.textDim)
    love.graphics.printf("Bars", toggleBtnX + 2, toggleBtnY + 4, toggleBtnW/2 - 4, "center")

    -- Graph half
    if not barsSelected then
        love.graphics.setColor(0.4, 0.5, 0.6)
    else
        love.graphics.setColor(0.2, 0.25, 0.3)
    end
    love.graphics.rectangle("fill", toggleBtnX + toggleBtnW/2, toggleBtnY + 2, toggleBtnW/2 - 2, toggleBtnH - 4, 2, 2)
    love.graphics.setColor(not barsSelected and Components.colors.text or Components.colors.textDim)
    love.graphics.printf("Graph", toggleBtnX + toggleBtnW/2, toggleBtnY + 4, toggleBtnW/2 - 2, "center")

    -- Store toggle button position for click handling
    _toggleBtnPos = {x = toggleBtnX, y = toggleBtnY, w = toggleBtnW, h = toggleBtnH}

    local statY = popupY + 138
    local statData = {
        {name = "STR", key = "str", color = {0.8, 0.4, 0.4}},
        {name = "DEX", key = "dex", color = {0.4, 0.8, 0.4}},
        {name = "INT", key = "int", color = {0.4, 0.4, 0.8}},
        {name = "VIT", key = "vit", color = {0.8, 0.6, 0.3}},
        {name = "LCK", key = "luck", color = {0.7, 0.5, 0.8}}
    }

    -- Get injury penalty
    local injuryPenalty = 1.0
    if Heroes and Heroes.getInjuryInfo then
        local injuryInfo = Heroes.getInjuryInfo(hero)
        injuryPenalty = injuryInfo.statPenalty or 1.0
    end

    -- Stats display area (full width, below header)
    if statDisplayMode == "bars" then
        -- Bars mode: show stat bars across full width
        for _, stat in ipairs(statData) do
            local baseValue = hero.stats[stat.key] or 0
            local effectiveValue = math.floor(baseValue * injuryPenalty)
            local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat.key) or 0

            love.graphics.setColor(stat.color)
            love.graphics.print(stat.name, popupX + 30, statY)

            -- Stat bar (wider now)
            local barW = 200
            local barH = 14
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", popupX + 70, statY + 1, barW, barH)

            -- Effective stat (with injury)
            love.graphics.setColor(stat.color[1] * 0.7, stat.color[2] * 0.7, stat.color[3] * 0.7)
            love.graphics.rectangle("fill", popupX + 70, statY + 1, barW * math.min(effectiveValue / 20, 1), barH)

            -- Equipment bonus
            if equipBonus > 0 then
                love.graphics.setColor(stat.color)
                love.graphics.rectangle("fill", popupX + 70 + barW * (effectiveValue / 20), statY + 1,
                    barW * math.min(equipBonus / 20, 1 - effectiveValue / 20), barH)
            end

            -- Value display
            love.graphics.setColor(Components.colors.text)
            if injuryPenalty < 1 then
                love.graphics.setColor(Components.colors.injured)
                love.graphics.print(effectiveValue, popupX + 280, statY)
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print("(" .. baseValue .. ")", popupX + 305, statY)
            else
                love.graphics.print(baseValue, popupX + 280, statY)
            end
            if equipBonus > 0 then
                love.graphics.setColor(Components.colors.success)
                love.graphics.print("+" .. equipBonus, popupX + 320, statY)
            end

            statY = statY + 22
        end
    else
        -- Graph mode: show pentagon centered in the popup
        local graphCenterX = popupX + popupW / 2
        local graphCenterY = popupY + 210

        if hasEquipment then
            Components.drawPentagonChart(effectiveStats, graphCenterX, graphCenterY, 75, {
                showLabels = true,
                fillColor = {0.3, 0.7, 0.3, 0.5},
                lineColor = {0.4, 0.9, 0.4, 1},
                overlayStats = baseStats,
                overlayColor = {1, 0.9, 0.3, 0.6}
            })
            -- Equipment indicator
            love.graphics.setColor(Components.colors.success)
            love.graphics.printf("+ Gear", graphCenterX - 30, graphCenterY + 85, 60, "center")
        else
            Components.drawPentagonChart(effectiveStats, graphCenterX, graphCenterY, 75, {
                showLabels = true,
                fillColor = {0.8, 0.7, 0.2, 0.5},
                lineColor = {1, 0.9, 0.3, 1}
            })
        end

        -- Skip the stat value list in graph mode - the graph labels show the values
        statY = popupY + 300  -- Skip past the graph for subsequent content
    end

    -- Status section
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("STATUS", popupX + 20, statY + 8)

    statY = statY + 30

    -- Current status
    local statusColor = Components.getStatusColor(hero.status)
    love.graphics.setColor(statusColor)
    love.graphics.print("Status: " .. (hero.status or "unknown"):upper(), popupX + 30, statY)

    -- Injury state
    if Heroes and Heroes.getInjuryInfo then
        local injuryInfo = Heroes.getInjuryInfo(hero)
        local injuryColor = Components.getInjuryColor(hero.injuryState)
        love.graphics.setColor(injuryColor)
        love.graphics.print("Health: " .. injuryInfo.name, popupX + 180, statY)
    end

    statY = statY + 18

    -- Passive ability (only visible for heroes in formed parties)
    local catColors = {
        OFFENSE = {0.9, 0.4, 0.3},
        DEFENSE = {0.3, 0.6, 0.9},
        WEALTH = {1, 0.85, 0.2},
        SPEED = {0.4, 0.9, 0.5}
    }

    if hero.partyId and hero.passive then
        -- Hero is in a formed party - show their passive
        local catColor = catColors[hero.passive.category] or Components.colors.text
        love.graphics.setColor(catColor)
        love.graphics.print("Passive: " .. hero.passive.name, popupX + 30, statY)
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("[" .. hero.passive.category .. "]", popupX + 180, statY)
        statY = statY + 16
        love.graphics.print(hero.passive.description, popupX + 30, statY)
        statY = statY + 18

        -- Show party synergy info
        if _gameData then
            local party = PartySystem.getParty(hero.partyId, _gameData)
            if party and party.isFormed then
                local members = PartySystem.getPartyMembers(party, _gameData)
                local synergyInfo = Heroes.getSynergyInfo(members)

                if synergyInfo and synergyInfo.name ~= "No Synergy" then
                    love.graphics.setColor(Components.colors.synergy or {0.8, 0.6, 1})
                    love.graphics.print("Party Synergy: " .. synergyInfo.name, popupX + 30, statY)
                    statY = statY + 16

                    love.graphics.setColor(Components.colors.textDim)
                    love.graphics.print(synergyInfo.description, popupX + 30, statY)
                    statY = statY + 16

                    -- Show bonuses
                    if synergyInfo.bonuses then
                        local bonusTexts = {}
                        if synergyInfo.bonuses.successBonus then
                            table.insert(bonusTexts, "+" .. math.floor(synergyInfo.bonuses.successBonus * 100) .. "% success")
                        end
                        if synergyInfo.bonuses.injuryReduction then
                            table.insert(bonusTexts, "-" .. math.floor(synergyInfo.bonuses.injuryReduction * 100) .. "% injury")
                        end
                        if synergyInfo.bonuses.goldBonus then
                            table.insert(bonusTexts, "+" .. math.floor(synergyInfo.bonuses.goldBonus * 100) .. "% gold")
                        end
                        if synergyInfo.bonuses.questTimeReduction then
                            table.insert(bonusTexts, "-" .. math.floor(synergyInfo.bonuses.questTimeReduction * 100) .. "% time")
                        end
                        if synergyInfo.bonuses.xpBonus then
                            table.insert(bonusTexts, "+" .. math.floor(synergyInfo.bonuses.xpBonus * 100) .. "% XP")
                        end
                        if synergyInfo.bonuses.recoveryBonus then
                            table.insert(bonusTexts, "+" .. math.floor(synergyInfo.bonuses.recoveryBonus * 100) .. "% recovery")
                        end

                        if #bonusTexts > 0 then
                            love.graphics.setColor(Components.colors.success)
                            love.graphics.print(table.concat(bonusTexts, ", "), popupX + 30, statY)
                            statY = statY + 16
                        end
                    end

                    -- Show category composition
                    if synergyInfo.categoryCounts then
                        local compParts = {}
                        for cat, count in pairs(synergyInfo.categoryCounts) do
                            if count > 0 then
                                table.insert(compParts, cat:sub(1,3) .. ":" .. count)
                            end
                        end
                        love.graphics.setColor(Components.colors.textDim)
                        love.graphics.print("Composition: " .. table.concat(compParts, " "), popupX + 30, statY)
                        statY = statY + 2
                    end
                end
            end
        end
    elseif hero.passive then
        -- Hero has a passive but is NOT in a formed party - show locked message
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Passive: [Locked]", popupX + 30, statY)
        statY = statY + 16
        love.graphics.print("Complete 3 quests as a party to unlock", popupX + 30, statY)
        statY = statY + 2
    end

    statY = statY + 18

    -- Failure count
    local failures = hero.failureCount or 0
    local failColor = failures >= 2 and Components.colors.danger or Components.colors.textDim
    love.graphics.setColor(failColor)
    love.graphics.print("Failures: " .. failures .. "/3", popupX + 30, statY)

    -- Equipment section
    statY = statY + 30
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("EQUIPMENT", popupX + 20, statY)

    statY = statY + 25
    local equipSlots = {
        {key = "weapon", label = "Weapon", icon = "[W]"},
        {key = "armor", label = "Armor", icon = "[A]"},
        {key = "accessory", label = "Accessory", icon = "[C]"},
        {key = "mount", label = "Mount", icon = "[M]"}
    }

    -- Store slot positions for click handling
    _equipSlotPositions = {}

    for _, slot in ipairs(equipSlots) do
        local equippedId = hero.equipment and hero.equipment[slot.key]

        -- Slot background
        Components.drawPanel(popupX + 30, statY, popupW - 90, 28, {
            color = equippedId and {0.25, 0.35, 0.3} or {0.2, 0.2, 0.2},
            cornerRadius = 3
        })

        -- Store position for click handling
        table.insert(_equipSlotPositions, {
            key = slot.key,
            x = popupX + 30,
            y = statY,
            width = popupW - 90,
            height = 28,
            equipped = equippedId
        })

        -- Slot label
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(slot.icon, popupX + 35, statY + 6)

        if equippedId and _Equipment then
            local item = _Equipment.get(equippedId)
            if item then
                -- Item name
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(item.name, popupX + 70, statY + 6)

                -- Item stats (compact)
                local statsStr = _Equipment.formatStats(item)
                love.graphics.setColor(Components.colors.success)
                love.graphics.printf(statsStr, popupX + 150, statY + 6, 120, "right")

                -- Unequip button [X]
                love.graphics.setColor(Components.colors.danger)
                love.graphics.rectangle("fill", popupX + popupW - 55, statY + 2, 24, 24, 3, 3)
                love.graphics.setColor(Components.colors.text)
                love.graphics.printf("X", popupX + popupW - 55, statY + 6, 24, "center")
            else
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print("(unknown item)", popupX + 70, statY + 6)
            end
        else
            -- Check if there's equipment available to equip
            local hasAvailable = false
            if _EquipmentSystem and _gameData then
                local available = _EquipmentSystem.getAvailableForSlot(_gameData, slot.key, hero.rank)
                hasAvailable = #available > 0
            end

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("(empty)", popupX + 70, statY + 6)

            -- Equip button [+] if items available
            if hasAvailable then
                love.graphics.setColor(Components.colors.success)
                love.graphics.rectangle("fill", popupX + popupW - 55, statY + 2, 24, 24, 3, 3)
                love.graphics.setColor(Components.colors.text)
                love.graphics.printf("+", popupX + popupW - 55, statY + 5, 24, "center")
            end
        end

        statY = statY + 32
    end

    -- Draw equipment dropdown if open
    if equipDropdownSlot and #equipDropdownItems > 0 then
        -- Find the slot position
        local dropdownX, dropdownY = popupX + 30, popupY + 250
        for _, slotPos in ipairs(_equipSlotPositions) do
            if slotPos.key == equipDropdownSlot then
                dropdownX = slotPos.x
                dropdownY = slotPos.y + slotPos.height + 2
                break
            end
        end

        local dropdownW = popupW - 60
        local itemHeight = 32
        local dropdownH = math.min(#equipDropdownItems * itemHeight + 10, 150)

        -- Dropdown background
        love.graphics.setColor(0.15, 0.15, 0.2, 0.98)
        love.graphics.rectangle("fill", dropdownX, dropdownY, dropdownW, dropdownH, 5, 5)
        love.graphics.setColor(0.4, 0.5, 0.6)
        love.graphics.rectangle("line", dropdownX, dropdownY, dropdownW, dropdownH, 5, 5)

        -- Dropdown title
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Select equipment:", dropdownX + 8, dropdownY + 4)

        -- Item list
        local itemY = dropdownY + 22
        for i, availItem in ipairs(equipDropdownItems) do
            if itemY + itemHeight > dropdownY + dropdownH then break end

            local item = availItem.item
            local count = availItem.count

            -- Item row background (hover effect simulated)
            love.graphics.setColor(0.25, 0.3, 0.35)
            love.graphics.rectangle("fill", dropdownX + 4, itemY, dropdownW - 8, itemHeight - 2, 3, 3)

            -- Rank badge
            Components.drawRankBadge(item.rank, dropdownX + 8, itemY + 4, 22)

            -- Item name
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(item.name, dropdownX + 35, itemY + 4)

            -- Stats
            local statsStr = _Equipment and _Equipment.formatStats(item) or ""
            love.graphics.setColor(Components.colors.success)
            love.graphics.print(statsStr, dropdownX + 35, itemY + 17)

            -- Count
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.printf("x" .. count, dropdownX + dropdownW - 40, itemY + 8, 30, "right")

            itemY = itemY + itemHeight
        end
    end

    -- Hint text
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("[+] Equip  [X] Unequip  |  Click outside to close", popupX, popupY + popupH - 25, popupW, "center")
end

-- Draw roster tab with rest status
-- Helper function to draw a single hero card in roster
local function drawRosterHeroCard(hero, x, y, cardWidth, cardHeight, Heroes, TimeSystem, indented)
    local indent = indented and 20 or 0
    local isSelected = selectedHeroDetail and selectedHeroDetail.id == hero.id

    -- Card background color based on status (highlight if selected)
    local bgColor = Components.colors.panelLight
    if isSelected then
        bgColor = {0.35, 0.45, 0.55}
    elseif hero.status == "idle" then
        bgColor = {0.25, 0.35, 0.25}
    elseif hero.status == "resting" then
        bgColor = {0.3, 0.25, 0.35}
    else
        bgColor = {0.35, 0.3, 0.2}
    end
    Components.drawPanel(x + indent, y, cardWidth - indent, cardHeight, {color = bgColor, cornerRadius = 5})

    -- Hero sprite portrait (smaller)
    local spriteX = x + indent + 35
    local spriteY = y + cardHeight / 2
    SpriteSystem.drawCentered(hero, spriteX, spriteY, 180, 180, "Idle")

    -- Hero name
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(hero.name, x + indent + 75, y + 8)

    -- Class and level (compact)
    local maxLevelForRank = Heroes.getMaxLevelForRank(hero.rank)
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print(hero.class .. " Lv." .. hero.level .. "/" .. maxLevelForRank, x + indent + 75, y + 26)

    -- Rank badge (small)
    Components.drawRankBadge(hero.rank, x + indent + 75, y + 44, 20)

    -- Status indicator (right side of card)
    local statusX = x + indent + 200
    if cardWidth > 350 then
        statusX = x + indent + 280
    end

    if hero.status == "idle" then
        love.graphics.setColor(Components.colors.success)
        love.graphics.print("AVAILABLE", statusX, y + 15)

        -- Fire button (only for unassigned idle heroes)
        if not indented and cardWidth > 400 then
            local fireBtnX = x + cardWidth - 55
            local fireBtnY = y + 10
            local fireBtnW = 45
            local fireBtnH = 22

            if heroToFire == hero.id then
                love.graphics.setColor(0.7, 0.2, 0.2)
                love.graphics.rectangle("fill", fireBtnX, fireBtnY, fireBtnW, fireBtnH, 3, 3)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("Sure?", fireBtnX, fireBtnY + 4, fireBtnW, "center")
            else
                love.graphics.setColor(0.5, 0.3, 0.3)
                love.graphics.rectangle("fill", fireBtnX, fireBtnY, fireBtnW, fireBtnH, 3, 3)
                love.graphics.setColor(0.9, 0.6, 0.6)
                love.graphics.printf("Fire", fireBtnX, fireBtnY + 4, fireBtnW, "center")
            end
        end
    elseif hero.status == "resting" then
        love.graphics.setColor(0.6, 0.4, 0.7)
        love.graphics.print("RESTING", statusX, y + 8)
        local restPercent = Heroes.getRestPercent(hero)
        local timeLeft = math.max(0, (hero.restTimeMax or 0) - (hero.restProgress or 0))
        local barW = math.min(120, cardWidth - statusX + x - 20)
        Components.drawProgressBar(statusX, y + 28, barW, 12, restPercent, {
            fgColor = {0.6, 0.4, 0.7},
            text = TimeSystem.formatDuration(timeLeft)
        })
    else
        love.graphics.setColor(Components.colors.warning)
        local phaseText = (hero.questPhase or ""):upper()
        love.graphics.print(phaseText, statusX, y + 8)
        local phaseMax = hero.questPhaseMax or 1
        local progress = (hero.questProgress or 0) / phaseMax
        local timeLeft = math.max(0, phaseMax - (hero.questProgress or 0))
        local barW = math.min(120, cardWidth - statusX + x - 20)
        Components.drawProgressBar(statusX, y + 28, barW, 12, progress, {
            fgColor = Components.colors.warning,
            text = TimeSystem.formatDuration(timeLeft)
        })
    end

    -- Injury indicator (bottom right, compact)
    if hero.injuryState and Heroes and Heroes.getInjuryInfo then
        local injuryInfo = Heroes.getInjuryInfo(hero)
        local injuryColor = Components.getInjuryColor(hero.injuryState)
        love.graphics.setColor(injuryColor)
        love.graphics.print(injuryInfo.name:upper(), statusX, y + 48)
    end
end

-- Draw hero detail panel (right side of roster tab)
local function drawHeroDetailPanel(hero, panelX, panelY, panelW, panelH, Heroes)
    -- Panel background
    Components.drawPanel(panelX, panelY, panelW, panelH, {
        color = {0.15, 0.17, 0.2},
        cornerRadius = 5
    })

    -- Hero name
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf(hero.name, panelX + 10, panelY + 10, panelW - 20, "center")

    -- Large sprite portrait
    local spritePortraitX = panelX + 55
    local spritePortraitY = panelY + 70
    love.graphics.setColor(0.12, 0.12, 0.15)
    love.graphics.rectangle("fill", spritePortraitX - 35, spritePortraitY - 35, 70, 70, 5, 5)
    love.graphics.setColor(0.35, 0.35, 0.4)
    love.graphics.rectangle("line", spritePortraitX - 35, spritePortraitY - 35, 70, 70, 5, 5)
    SpriteSystem.drawCentered(hero, spritePortraitX, spritePortraitY, 180, 180, "Idle")

    -- Rank badge
    Components.drawRankBadge(hero.rank, panelX + 100, panelY + 35, 28)

    -- Race, Class, Level
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print(hero.race or "Human", panelX + 135, panelY + 35)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(hero.class .. " - Lv." .. hero.level, panelX + 135, panelY + 52)

    -- XP bar
    local xpPercent = hero.xpToLevel > 0 and (hero.xp / hero.xpToLevel) or 1
    Components.drawProgressBar(panelX + 135, panelY + 72, panelW - 155, 14, xpPercent, {
        fgColor = {0.5, 0.3, 0.7},
        text = hero.xp .. "/" .. hero.xpToLevel .. " XP"
    })

    -- Stats section
    local statY = panelY + 115
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("STATS", panelX + 10, statY)

    -- Bars/Graph toggle
    local toggleBtnX = panelX + panelW - 80
    local toggleBtnY = statY - 2
    local toggleBtnW = 70
    local toggleBtnH = 18

    love.graphics.setColor(0.25, 0.3, 0.35)
    love.graphics.rectangle("fill", toggleBtnX, toggleBtnY, toggleBtnW, toggleBtnH, 3, 3)

    local barsSelected = statDisplayMode == "bars"
    if barsSelected then
        love.graphics.setColor(0.4, 0.5, 0.6)
    else
        love.graphics.setColor(0.2, 0.25, 0.3)
    end
    love.graphics.rectangle("fill", toggleBtnX + 2, toggleBtnY + 2, toggleBtnW/2 - 4, toggleBtnH - 4, 2, 2)
    love.graphics.setColor(barsSelected and Components.colors.text or Components.colors.textDim)
    love.graphics.printf("Bars", toggleBtnX + 2, toggleBtnY + 3, toggleBtnW/2 - 4, "center")

    if not barsSelected then
        love.graphics.setColor(0.4, 0.5, 0.6)
    else
        love.graphics.setColor(0.2, 0.25, 0.3)
    end
    love.graphics.rectangle("fill", toggleBtnX + toggleBtnW/2, toggleBtnY + 2, toggleBtnW/2 - 2, toggleBtnH - 4, 2, 2)
    love.graphics.setColor(not barsSelected and Components.colors.text or Components.colors.textDim)
    love.graphics.printf("Graph", toggleBtnX + toggleBtnW/2, toggleBtnY + 3, toggleBtnW/2 - 2, "center")

    _toggleBtnPos = {x = toggleBtnX, y = toggleBtnY, w = toggleBtnW, h = toggleBtnH}

    statY = statY + 20
    local statData = {
        {name = "STR", key = "str", color = {0.8, 0.4, 0.4}},
        {name = "DEX", key = "dex", color = {0.4, 0.8, 0.4}},
        {name = "INT", key = "int", color = {0.4, 0.4, 0.8}},
        {name = "VIT", key = "vit", color = {0.8, 0.6, 0.3}},
        {name = "LCK", key = "luck", color = {0.7, 0.5, 0.8}}
    }

    local injuryPenalty = 1.0
    if Heroes and Heroes.getInjuryInfo then
        local injuryInfo = Heroes.getInjuryInfo(hero)
        injuryPenalty = injuryInfo.statPenalty or 1.0
    end

    if statDisplayMode == "bars" then
        for _, stat in ipairs(statData) do
            local baseValue = hero.stats[stat.key] or 0
            local effectiveValue = math.floor(baseValue * injuryPenalty)
            local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat.key) or 0

            love.graphics.setColor(stat.color)
            love.graphics.print(stat.name, panelX + 15, statY)

            local barW = panelW - 100
            local barH = 12
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", panelX + 50, statY + 2, barW, barH)

            love.graphics.setColor(stat.color[1] * 0.7, stat.color[2] * 0.7, stat.color[3] * 0.7)
            love.graphics.rectangle("fill", panelX + 50, statY + 2, barW * math.min(effectiveValue / 20, 1), barH)

            if equipBonus > 0 then
                love.graphics.setColor(stat.color)
                love.graphics.rectangle("fill", panelX + 50 + barW * (effectiveValue / 20), statY + 2,
                    barW * math.min(equipBonus / 20, 1 - effectiveValue / 20), barH)
            end

            love.graphics.setColor(Components.colors.text)
            love.graphics.print(baseValue + equipBonus, panelX + panelW - 40, statY)

            statY = statY + 18
        end
    else
        -- Graph mode - center the graph horizontally in the panel
        local graphCenterX = panelX + panelW / 2
        local graphCenterY = statY + 60
        local effectiveStats = {}
        for _, stat in ipairs(statData) do
            local base = hero.stats[stat.key] or 0
            local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat.key) or 0
            effectiveStats[stat.key] = base + equipBonus
        end
        Components.drawPentagonChart(effectiveStats, graphCenterX, graphCenterY, 55, {
            showLabels = true,
            fillColor = {0.8, 0.7, 0.2, 0.5},
            lineColor = {1, 0.9, 0.3, 1}
        })
        statY = statY + 130  -- Skip past the graph
    end

    -- Status section
    statY = statY + 5
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("STATUS", panelX + 10, statY)
    statY = statY + 18

    local statusColor = Components.getStatusColor(hero.status)
    love.graphics.setColor(statusColor)
    love.graphics.print("Status: " .. (hero.status or "unknown"):upper(), panelX + 15, statY)

    if Heroes and Heroes.getInjuryInfo then
        local injuryInfo = Heroes.getInjuryInfo(hero)
        local injuryColor = Components.getInjuryColor(hero.injuryState)
        love.graphics.setColor(injuryColor)
        love.graphics.print("Health: " .. injuryInfo.name, panelX + 130, statY)
    end
    statY = statY + 16

    -- Passive
    if hero.passive then
        local catColors = {
            OFFENSE = {0.9, 0.4, 0.3},
            DEFENSE = {0.3, 0.6, 0.9},
            WEALTH = {1, 0.85, 0.2},
            SPEED = {0.4, 0.9, 0.5}
        }
        if hero.partyId then
            local catColor = catColors[hero.passive.category] or Components.colors.text
            love.graphics.setColor(catColor)
            love.graphics.print("Passive: " .. hero.passive.name, panelX + 15, statY)
        else
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Passive: [Locked]", panelX + 15, statY)
        end
        statY = statY + 14
        love.graphics.setColor(Components.colors.textDim)
        if hero.partyId then
            love.graphics.print(hero.passive.description, panelX + 15, statY)
        else
            love.graphics.print("Complete 3 quests as party to unlock", panelX + 15, statY)
        end
        statY = statY + 14
    end

    local failures = hero.failureCount or 0
    local failColor = failures >= 2 and Components.colors.danger or Components.colors.textDim
    love.graphics.setColor(failColor)
    love.graphics.print("Failures: " .. failures .. "/3", panelX + 15, statY)

    -- Equipment section
    statY = statY + 22
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("EQUIPMENT", panelX + 10, statY)
    statY = statY + 18

    local equipSlots = {
        {key = "weapon", label = "Weapon", icon = "[W]"},
        {key = "armor", label = "Armor", icon = "[A]"},
        {key = "accessory", label = "Accessory", icon = "[C]"},
        {key = "mount", label = "Mount", icon = "[M]"}
    }

    _equipSlotPositions = {}

    for _, slot in ipairs(equipSlots) do
        local equippedId = hero.equipment and hero.equipment[slot.key]

        Components.drawPanel(panelX + 10, statY, panelW - 20, 24, {
            color = equippedId and {0.25, 0.35, 0.3} or {0.18, 0.18, 0.2},
            cornerRadius = 3
        })

        table.insert(_equipSlotPositions, {
            key = slot.key,
            x = panelX + 10,
            y = statY,
            width = panelW - 20,
            height = 24,
            equipped = equippedId
        })

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(slot.icon, panelX + 15, statY + 5)

        if equippedId and _Equipment then
            local item = _Equipment.get(equippedId)
            if item then
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(item.name, panelX + 45, statY + 5)

                love.graphics.setColor(Components.colors.danger)
                love.graphics.rectangle("fill", panelX + panelW - 32, statY + 2, 20, 20, 3, 3)
                love.graphics.setColor(Components.colors.text)
                love.graphics.printf("X", panelX + panelW - 32, statY + 4, 20, "center")
            else
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print("(unknown)", panelX + 45, statY + 5)
            end
        else
            local hasAvailable = false
            if _EquipmentSystem and _gameData then
                local available = _EquipmentSystem.getAvailableForSlot(_gameData, slot.key, hero.rank)
                hasAvailable = #available > 0
            end

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("(empty)", panelX + 45, statY + 5)

            if hasAvailable then
                love.graphics.setColor(Components.colors.success)
                love.graphics.rectangle("fill", panelX + panelW - 32, statY + 2, 20, 20, 3, 3)
                love.graphics.setColor(Components.colors.text)
                love.graphics.printf("+", panelX + panelW - 32, statY + 3, 20, "center")
            end
        end

        statY = statY + 26
    end

    -- Hint
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("[+] Equip  [X] Unequip", panelX, panelY + panelH - 18, panelW, "center")
end

function drawRosterTab(gameData, startY, height, Heroes, TimeSystem, GuildSystem)
    -- Layout: 60-40 split (60% hero list, 40% detail panel)
    local detailPanelWidth = selectedHeroDetail and math.floor(MENU_DESIGN_WIDTH * 0.4) or 0  -- 40% = 440px
    local listWidth = MENU_DESIGN_WIDTH - 40 - detailPanelWidth - (selectedHeroDetail and 10 or 0)

    -- Hero slots info
    local heroSlots = GuildSystem and GuildSystem.getHeroSlots(gameData) or 4
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Your Heroes (" .. #gameData.heroes .. "/" .. heroSlots .. ")", 20, startY)

    -- Status summary (compact)
    local idleCount = 0
    local busyCount = 0
    local restingCount = 0
    local injuredCount = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "idle" then idleCount = idleCount + 1
        elseif hero.status == "resting" then restingCount = restingCount + 1
        else busyCount = busyCount + 1
        end
        if hero.injuryState then injuredCount = injuredCount + 1 end
    end

    love.graphics.setColor(Components.colors.success)
    love.graphics.print("Idle: " .. idleCount, 200, startY)
    love.graphics.setColor(Components.colors.warning)
    love.graphics.print("Busy: " .. busyCount, 270, startY)
    love.graphics.setColor(0.6, 0.4, 0.7)
    love.graphics.print("Resting: " .. restingCount, 340, startY)
    if injuredCount > 0 then
        love.graphics.setColor(Components.colors.injured)
        love.graphics.print("Injured: " .. injuredCount, 430, startY)
    end

    if #gameData.heroes == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No heroes yet! Visit the Tavern to hire some.",
            0, startY + 50, MENU_DESIGN_WIDTH, "center")
        return
    end

    local cardHeight = 70  -- Smaller cards for side-by-side layout
    local partyHeaderHeight = 40
    local scrollbarWidth = 12

    -- Calculate content dimensions
    local listStartY = startY + 25
    local listHeight = MENU_DESIGN_HEIGHT - 20 - listStartY
    local listX = 20
    -- Narrower list when detail panel is showing (60% of width)
    local actualListWidth = selectedHeroDetail and math.floor(MENU_DESIGN_WIDTH * 0.6) - 30 or (MENU_DESIGN_WIDTH - 40)
    local cardWidth = actualListWidth - 30

    -- Build content layout to calculate total height
    PartySystem.initGameData(gameData)
    local contentItems = {}  -- {type, data, height}

    -- Add formed parties
    if gameData.parties and #gameData.parties > 0 then
        for _, party in ipairs(gameData.parties) do
            local members = PartySystem.getPartyMembers(party, gameData)
            local isExpanded = expandedParties[party.id]

            -- Party header
            table.insert(contentItems, {type = "party_header", party = party, members = members, height = partyHeaderHeight})

            -- If expanded, add member hero cards
            if isExpanded then
                for _, member in ipairs(members) do
                    table.insert(contentItems, {type = "party_member", hero = member, height = cardHeight + 5})
                end
            end
        end
    end

    -- Add unassigned heroes section header
    local unassignedHeroes = {}
    for _, hero in ipairs(gameData.heroes) do
        if not hero.partyId then
            table.insert(unassignedHeroes, hero)
        end
    end

    if #unassignedHeroes > 0 or #contentItems == 0 then
        table.insert(contentItems, {type = "section_header", text = "Unassigned Heroes", height = 25})
        for _, hero in ipairs(unassignedHeroes) do
            table.insert(contentItems, {type = "hero", hero = hero, height = cardHeight + 5})
        end
    end

    -- Calculate total content height
    local totalContentHeight = 0
    for _, item in ipairs(contentItems) do
        totalContentHeight = totalContentHeight + item.height
    end
    local maxScroll = math.max(0, totalContentHeight - listHeight)

    -- Store bounds for scroll detection
    rosterListBounds = {
        x = listX,
        y = listStartY,
        w = actualListWidth,
        h = listHeight,
        maxScroll = maxScroll
    }

    -- Clamp scroll offset
    rosterScrollOffset = math.max(0, math.min(rosterScrollOffset, maxScroll))

    -- Set up scissor for clipping (use helper for screen coords)
    setScissorDesign(listX, listStartY, actualListWidth, listHeight)

    -- Draw content with scroll offset
    local y = listStartY - rosterScrollOffset
    for _, item in ipairs(contentItems) do
        local itemBottom = y + item.height

        -- Only draw if visible
        if itemBottom >= listStartY and y < listStartY + listHeight then
            if item.type == "party_header" then
                local party = item.party
                local members = item.members
                local isExpanded = expandedParties[party.id]

                -- Party card background
                Components.drawPanel(listX, y, cardWidth, partyHeaderHeight, {
                    color = {0.25, 0.3, 0.4},
                    cornerRadius = 5
                })

                -- Expand/collapse indicator
                local arrowText = isExpanded and "v" or ">"
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(arrowText, listX + 10, y + 18)

                -- Party name
                love.graphics.setColor(1, 0.9, 0.5)
                love.graphics.print(party.name, listX + 30, y + 5)

                -- Party status
                local statusText = PartySystem.getStatusText(party, gameData)
                local statusColor = party.isFormed and PartySystem.allMembersQualified(party) and Components.colors.success or Components.colors.warning
                love.graphics.setColor(statusColor)
                love.graphics.print(statusText, listX + 30, y + 22)

                -- Member portraits in a row
                local portraitX = listX + 200
                local portraitSize = 40
                for j, member in ipairs(members) do
                    SpriteSystem.drawCentered(member, portraitX + (j-1) * 45 + portraitSize/2, y + 25, portraitSize + 30, portraitSize + 30, "Idle")
                end

                -- Party synergy (if formed) - only show if there's room
                if not selectedHeroDetail and party.isFormed and #members >= 4 then
                    local synergyInfo = Heroes.getSynergyInfo(members)
                    if synergyInfo and synergyInfo.name ~= "No Synergy" then
                        love.graphics.setColor(Components.colors.synergy or {0.8, 0.6, 1})
                        love.graphics.print(synergyInfo.name, listX + 410, y + 5)
                        local catColors = {
                            OFFENSE = {0.9, 0.4, 0.3},
                            DEFENSE = {0.3, 0.6, 0.9},
                            WEALTH = {1, 0.85, 0.2},
                            SPEED = {0.4, 0.9, 0.5}
                        }
                        local badgeX = listX + 410
                        if synergyInfo.categoryCounts then
                            for cat, count in pairs(synergyInfo.categoryCounts) do
                                if count > 0 then
                                    love.graphics.setColor(catColors[cat] or {0.5, 0.5, 0.5})
                                    love.graphics.print(cat:sub(1,1) .. count, badgeX, y + 22)
                                    badgeX = badgeX + 25
                                end
                            end
                        end
                    end
                end

                -- Quests completed
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print("Quests: " .. (party.totalQuestsCompleted or 0), listX + cardWidth - 80, y + 15)

            elseif item.type == "party_member" then
                drawRosterHeroCard(item.hero, listX, y, cardWidth, cardHeight, Heroes, TimeSystem, true)

            elseif item.type == "section_header" then
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(item.text, listX, y + 5)

            elseif item.type == "hero" then
                drawRosterHeroCard(item.hero, listX, y, cardWidth, cardHeight, Heroes, TimeSystem, false)
            end
        end

        y = y + item.height
    end

    -- Reset scissor
    love.graphics.setScissor()

    -- Draw scrollbar if needed
    if maxScroll > 0 then
        local scrollbarX = listX + actualListWidth - scrollbarWidth
        local scrollbarHeight = listHeight

        -- Scrollbar track
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, listStartY, scrollbarWidth, scrollbarHeight, 3, 3)

        -- Scrollbar thumb
        local thumbHeight = math.max(30, scrollbarHeight * (listHeight / totalContentHeight))
        local thumbY = listStartY + (rosterScrollOffset / maxScroll) * (scrollbarHeight - thumbHeight)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX + 2, thumbY, scrollbarWidth - 4, thumbHeight, 3, 3)
    end

    -- Draw detail panel on right side if a hero is selected (40% of width)
    if selectedHeroDetail then
        local panelW = math.floor(MENU_DESIGN_WIDTH * 0.4) - 10  -- 40% minus padding
        local panelX = MENU_DESIGN_WIDTH - panelW - 10
        local panelY = listStartY
        local panelH = listHeight
        drawHeroDetailPanel(selectedHeroDetail, panelX, panelY, panelW, panelH, Heroes)
    end
end

-- Draw quests tab with party selection
function drawQuestsTab(gameData, startY, height, QuestSystem, Quests, TimeSystem, GuildSystem)
    -- Left side: Quest list
    local questListWidth = 350
    local questSlots = GuildSystem and GuildSystem.getQuestSlots(gameData) or 2
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Available Quests", 20, startY)

    -- Active quest slots display
    local activeColor = #gameData.activeQuests >= questSlots and Components.colors.danger or Components.colors.textDim
    love.graphics.setColor(activeColor)
    love.graphics.print("Active: " .. #gameData.activeQuests .. "/" .. questSlots, 200, startY)

    if #gameData.availableQuests == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("No quests available. Wait for new ones!", 20, startY + 30)
    else
        local y = startY + 25
        for i, quest in ipairs(gameData.availableQuests) do
            if y + 70 > MENU_DESIGN_HEIGHT - 20 then break end

            local isSelected = selectedQuest and selectedQuest.id == quest.id

            -- Quest card
            local bgColor = isSelected and {0.3, 0.4, 0.5} or Components.colors.panelLight
            Components.drawPanel(20, y, questListWidth - 10, 65, {
                color = bgColor,
                cornerRadius = 5
            })

            -- Rank badge
            Components.drawRankBadge(quest.rank, 30, y + 18, 28)

            -- Quest info
            love.graphics.setColor(Components.colors.text)
            local questName = quest.name
            love.graphics.print(questName, 65, y + 8)

            -- Faction badge (colored dot with name)
            if quest.faction and GuildSystem then
                local faction = GuildSystem.factions[quest.faction]
                if faction then
                    love.graphics.setColor(faction.color)
                    love.graphics.circle("fill", 65, y + 52, 5)
                    love.graphics.setColor(Components.colors.textDim)
                    love.graphics.print(faction.name, 75, y + 45)
                end
            end

            -- Required stat indicator (primary + secondary)
            local statNames = {str = "STR", dex = "DEX", int = "INT", vit = "VIT", luck = "LCK"}
            local statColors = {
                str = {0.8, 0.4, 0.4},
                dex = {0.4, 0.8, 0.4},
                int = {0.4, 0.4, 0.8},
                vit = {0.8, 0.6, 0.3},
                luck = {0.7, 0.5, 0.8}
            }
            local reqStat = quest.requiredStat or "str"

            -- Build stat requirement string (shorter format)
            local statStr = statNames[reqStat] or "STR"
            if quest.secondaryStats and #quest.secondaryStats > 0 then
                for _, secStat in ipairs(quest.secondaryStats) do
                    statStr = statStr .. "+" .. (statNames[secStat.stat] or "?")
                end
            end

            -- Right side info column (rewards)
            love.graphics.setColor(Components.colors.gold)
            love.graphics.print(quest.reward .. "g", questListWidth - 65, y + 8)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("+" .. quest.xpReward .. " XP", questListWidth - 65, y + 24)

            local totalTime = Quests.getTotalTime(quest)
            love.graphics.print(TimeSystem.formatDuration(totalTime), questListWidth - 65, y + 40)

            -- Left side second line: stat requirement
            love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
            love.graphics.print(statStr, 65, y + 26)

            y = y + 70
        end
    end

    -- Right side: Party selection
    local partyX = questListWidth + 20
    local partyWidth = MENU_DESIGN_WIDTH - questListWidth - 50

    if selectedQuest then
        love.graphics.setColor(Components.colors.text)
        love.graphics.print("Party for: " .. selectedQuest.name, partyX, startY)

        -- Mode toggle buttons (Heroes / Parties)
        local toggleY = startY - 5
        local toggleBtnWidth = 80
        local heroesActive = questSelectionMode == "heroes"
        local partiesActive = questSelectionMode == "parties"

        -- Mode label
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Select:", partyX + partyWidth - 210, toggleY + 4)

        -- Heroes toggle (individual selection)
        Components.drawButton("Individual", partyX + partyWidth - 165, toggleY, toggleBtnWidth, 22, {
            color = heroesActive and Components.colors.buttonActive or Components.colors.button
        })
        -- Parties toggle (whole party selection)
        Components.drawButton("Party", partyX + partyWidth - 80, toggleY, 70, 22, {
            color = partiesActive and Components.colors.buttonActive or Components.colors.button
        })

        -- Gather selected heroes
        local partyHeroes = {}

        -- Only count heroes that are actually selected AND still exist in roster
        for heroId, isSelected in pairs(selectedHeroes) do
            if isSelected == true then
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId and hero.status == "idle" then
                        table.insert(partyHeroes, hero)
                        break
                    end
                end
            end
        end

        -- Show hero count with limit
        local maxHeroes = selectedQuest.maxHeroes or 6
        local heroCountColor = #partyHeroes >= maxHeroes and Components.colors.warning or Components.colors.textDim
        love.graphics.setColor(heroCountColor)
        love.graphics.print(string.format("Heroes: %d/%d", #partyHeroes, maxHeroes), partyX, startY + 18)

        -- Party stat totals for required stats (primary + secondary)
        local reqStat = selectedQuest.requiredStat or "str"
        local statNames = {str = "STR", dex = "DEX", int = "INT", vit = "VIT", luck = "LCK"}
        local statColors = {
            str = {0.8, 0.4, 0.4},
            dex = {0.4, 0.8, 0.4},
            int = {0.4, 0.4, 0.8},
            vit = {0.8, 0.6, 0.3},
            luck = {0.7, 0.5, 0.8}
        }

        -- Build list of all required stats (primary + secondary)
        local allReqStats = {{stat = reqStat, weight = 1.0}}
        if selectedQuest.secondaryStats then
            for _, secStat in ipairs(selectedQuest.secondaryStats) do
                table.insert(allReqStats, secStat)
            end
        end

        -- Display stats inline (compact format)
        local statDisplayX = partyX
        local statDisplayY = startY + 34
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Stats:", statDisplayX, statDisplayY)

        local xOffset = 45
        for i, statInfo in ipairs(allReqStats) do
            if i > 3 then break end  -- Limit to 3 stats displayed

            local stat = statInfo.stat
            local totalStat = 0
            local totalEquip = 0
            for _, hero in ipairs(partyHeroes) do
                totalStat = totalStat + (hero.stats[stat] or 0)
                if _EquipmentSystem then
                    totalEquip = totalEquip + _EquipmentSystem.getStatBonus(hero, stat)
                end
            end

            -- Primary stat shown in full, secondary stats show weight indicator
            local label = statNames[stat] or "?"
            if statInfo.weight < 1 then
                -- Secondary stat - show with weight indicator
                love.graphics.setColor(statColors[stat] or Components.colors.textDim)
                love.graphics.print(label .. ":" .. totalStat, statDisplayX + xOffset, statDisplayY)
            else
                -- Primary stat
                love.graphics.setColor(statColors[stat] or Components.colors.textDim)
                love.graphics.print(label .. ":" .. totalStat, statDisplayX + xOffset, statDisplayY)
            end

            if totalEquip > 0 then
                love.graphics.setColor(Components.colors.success)
                love.graphics.print("+" .. totalEquip, statDisplayX + xOffset + 50, statDisplayY)
                xOffset = xOffset + 70
            else
                xOffset = xOffset + 55
            end
        end

        -- Pentagon stat comparison chart (quest requirements vs party stats)
        local pentagonX = partyX + partyWidth - 120
        local pentagonY = startY + 110
        local pentagonRadius = 50

        -- Get quest requirements and party stats (summed across all heroes)
        local questReqs = getQuestStatRequirements(selectedQuest, Quests)
        local partyStats = getPartyStats(partyHeroes, _EquipmentSystem)

        -- Fixed max scale that allows pentagon to GROW as you add heroes
        -- Quest reqs are for 1 hero, party stats are summed - pentagon shows growth!
        local maxStatForChart = 30  -- Allows room to show combined stats

        -- Draw pentagon: quest requirements as outline, party stats as filled
        if #partyHeroes > 0 then
            -- Party stats filled (green), quest requirements as white outline
            -- The pentagon GROWS as you add more heroes since stats are summed!
            Components.drawPentagonChart(partyStats, pentagonX, pentagonY, pentagonRadius, {
                showLabels = true,
                fillColor = {0.3, 0.7, 0.3, 0.5},   -- Green when party has stats
                lineColor = {0.4, 0.9, 0.4, 1},     -- Bright green outline
                maxStat = maxStatForChart,
                overlayStats = questReqs,
                overlayColor = {1, 1, 1, 0.7}       -- White outline for requirements
            })
        else
            -- No party selected: just show quest requirements
            Components.drawPentagonChart(questReqs, pentagonX, pentagonY, pentagonRadius, {
                showLabels = true,
                fillColor = {0.5, 0.5, 0.5, 0.3},   -- Gray fill
                lineColor = {0.7, 0.7, 0.7, 0.8},   -- Gray outline
                maxStat = maxStatForChart
            })
        end

        -- Chart legend and combined stats display
        love.graphics.setColor(Components.colors.textDim)
        local combinedStatsText = "Combined Stats"
        local font = love.graphics.getFont()
        local textWidth = font:getWidth(combinedStatsText)
        love.graphics.print(combinedStatsText, pentagonX - textWidth / 2, pentagonY + pentagonRadius + 22)
        if #partyHeroes > 0 then
            -- Show hero count (centered)
            local heroCountText = #partyHeroes .. " hero" .. (#partyHeroes > 1 and "es" or "")
            local heroCountWidth = font:getWidth(heroCountText)
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.print(heroCountText, pentagonX - heroCountWidth / 2, pentagonY + pentagonRadius + 38)

            -- Legend (centered below)
            local legendY = pentagonY + pentagonRadius + 56
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.rectangle("fill", pentagonX - 45, legendY, 10, 10)
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Party", pentagonX - 32, legendY - 2)

            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.rectangle("line", pentagonX + 10, legendY, 10, 10)
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Quest", pentagonX + 24, legendY - 2)
        end

        -- Success chance (color coded, includes equipment bonuses)
        local successY = startY + 68
        if #partyHeroes > 0 then
            local chance = Quests.calculateSuccessChance(selectedQuest, partyHeroes, _EquipmentSystem)
            local chancePercent = chance * 100

            -- Color based on chance: red < 40%, yellow 40-70%, green > 70%
            local chanceColor
            if chancePercent < 40 then
                chanceColor = {0.8, 0.3, 0.3}  -- Red
            elseif chancePercent < 70 then
                chanceColor = {0.8, 0.7, 0.3}  -- Yellow
            else
                chanceColor = {0.3, 0.8, 0.3}  -- Green
            end

            love.graphics.setColor(chanceColor)
            love.graphics.print(string.format("Success: %.0f%%", chancePercent), partyX, successY)
        else
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Select heroes to see success chance", partyX, successY)
        end

        -- Active synergies display with hover tooltips
        local synergyY = successY + 18
        hoveredSynergy = nil  -- Reset hover state each frame
        synergyHelpHovered = false

        -- Store synergy positions for hover detection
        local synergyPositions = {}

        if #partyHeroes > 0 then
            local synergyBonuses = Quests.getSynergyBonuses(partyHeroes, selectedQuest)
            local activeSynergies = synergyBonuses.activeSynergies or {}

            -- Draw synergy label with help icon
            love.graphics.setColor(Components.colors.synergy)
            love.graphics.print("Synergies:", partyX, synergyY)

            -- Help icon (?)
            local helpX = partyX + 60
            Components.drawHelpIcon(helpX, synergyY - 2, 16)
            if Components.isPointInRect(mouseX, mouseY, helpX, synergyY - 2, 16, 16) then
                synergyHelpHovered = true
            end

            if #activeSynergies > 0 then
                local synX = partyX + 85
                local maxDisplay = 3
                for i, synergy in ipairs(activeSynergies) do
                    if i > maxDisplay then
                        love.graphics.setColor(Components.colors.textDim)
                        love.graphics.print("+" .. (#activeSynergies - maxDisplay) .. " more", synX, synergyY)
                        break
                    end

                    -- Synergy name with hover effect
                    local font = love.graphics.getFont()
                    local nameWidth = font:getWidth(synergy.name)
                    local isHovered = Components.isPointInRect(mouseX, mouseY, synX, synergyY, nameWidth, 16)

                    if isHovered then
                        love.graphics.setColor(1, 1, 1)  -- Bright white on hover
                        hoveredSynergy = synergy
                        hoveredSynergyPos = {x = synX, y = synergyY + 20}
                    else
                        love.graphics.setColor(Components.colors.synergyLight)
                    end
                    love.graphics.print(synergy.name, synX, synergyY)

                    -- Store position for click detection if needed
                    table.insert(synergyPositions, {
                        synergy = synergy,
                        x = synX, y = synergyY,
                        width = nameWidth, height = 16
                    })

                    synX = synX + nameWidth + 10
                end
                synergyY = synergyY + 18
            else
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print("(none active)", partyX + 85, synergyY)
                synergyY = synergyY + 18
            end
        end

        -- Death warning for A/S rank combat quests
        local deathWarningOffset = synergyY - (successY + 18)
        if selectedQuest.combat and (selectedQuest.rank == "A" or selectedQuest.rank == "S") then
            deathWarningOffset = deathWarningOffset + 18
            -- Check if party has a priest for protection
            local hasPriest = Quests.partyHasCleric(partyHeroes)
            if hasPriest then
                love.graphics.setColor(0.3, 0.7, 0.3)  -- Green - protected
                love.graphics.print("Priest provides death protection!", partyX, synergyY)
            else
                love.graphics.setColor(0.9, 0.3, 0.3)  -- Red - danger
                local deathChance = selectedQuest.rank == "S" and "50%" or "30%"
                love.graphics.print("DANGER: " .. deathChance .. " death on fail! Bring a Priest!", partyX, synergyY)
            end
            synergyY = synergyY + 16
        end

        -- Possible rewards display
        if selectedQuest.possibleRewards and #selectedQuest.possibleRewards > 0 then
            love.graphics.setColor(Components.colors.text)
            love.graphics.print("Possible Drops:", partyX, synergyY + 2)
            synergyY = synergyY + 16
            for _, reward in ipairs(selectedQuest.possibleRewards) do
                local dropPercent = math.floor((reward.dropChance or 0) * 100)
                local rewardName = reward.id or reward.type
                -- Capitalize first letter
                rewardName = rewardName:gsub("_", " "):gsub("^%l", string.upper)
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print(string.format("  %s x%d (%d%%)", rewardName, reward.amount or 1, dropPercent), partyX, synergyY)
                synergyY = synergyY + 14
                if synergyY > startY + 140 then break end  -- Limit display
            end
        end

        -- Selection list area (positioned below the pentagon chart area)
        local heroCardHeight = 70
        local heroCardSpacing = 75
        local listStartY = math.max(synergyY + 8, startY + 210)
        local listHeight = MENU_DESIGN_HEIGHT - 65 - listStartY  -- Available height for list
        local scrollbarWidth = 12

        if questSelectionMode == "heroes" then
            -- HEROES MODE: Available heroes list with scrolling
            -- Count idle heroes and calculate total content height
            local idleHeroCount = 0
            for _, hero in ipairs(gameData.heroes) do
                if hero.status == "idle" then
                    idleHeroCount = idleHeroCount + 1
                end
            end
            local totalContentHeight = idleHeroCount * heroCardSpacing
            local maxScroll = math.max(0, totalContentHeight - listHeight)

            -- Store bounds for scroll detection
            questHeroListBounds = {
                x = partyX,
                y = listStartY,
                w = partyWidth,
                h = listHeight,
                maxScroll = maxScroll
            }

            -- Clamp scroll offset
            questHeroScrollOffset = math.max(0, math.min(questHeroScrollOffset, maxScroll))

            -- Set up scissor for clipping (use helper for screen coords)
            setScissorDesign(partyX, listStartY, partyWidth, listHeight)

            -- Draw heroes with scroll offset
            local y = listStartY - questHeroScrollOffset
            for i, hero in ipairs(gameData.heroes) do
                if hero.status == "idle" then
                    -- Only draw if visible (with some margin for partial visibility)
                    if y + heroCardHeight >= listStartY and y < listStartY + listHeight then
                        local isSelected = selectedHeroes[hero.id] == true

                        local bgColor = isSelected and {0.3, 0.5, 0.3} or Components.colors.panelLight
                        Components.drawPanel(partyX, y, partyWidth - scrollbarWidth - 5, heroCardHeight, {
                            color = bgColor,
                            cornerRadius = 5
                        })

                        -- Larger sprite portrait (120x120 for better visibility)
                        SpriteSystem.drawCentered(hero, partyX + 40, y + heroCardHeight / 2, 140, 140, "Idle")

                        -- Rank badge (next to sprite)
                        Components.drawRankBadge(hero.rank, partyX + 75, y + 8, 24)

                        -- Hero name
                        love.graphics.setColor(Components.colors.text)
                        love.graphics.print(hero.name, partyX + 105, y + 8)

                        -- Race, class and level on second line
                        love.graphics.setColor(Components.colors.textDim)
                        love.graphics.print((hero.race or "Human") .. " " .. hero.class .. " Lv." .. hero.level, partyX + 105, y + 26)

                        -- Show hero's relevant stat for this quest (next to hero info)
                        local heroStat = hero.stats[reqStat] or 0
                        local heroEquipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, reqStat) or 0
                        love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
                        if heroEquipBonus > 0 then
                            love.graphics.print(statNames[reqStat] .. ":" .. heroStat .. "(+" .. heroEquipBonus .. ")", partyX + 105, y + 44)
                        else
                            love.graphics.print(statNames[reqStat] .. ":" .. heroStat, partyX + 105, y + 44)
                        end

                        -- Party indicator (show party name if hero is in a party)
                        if hero.partyId then
                            local party = PartySystem.getParty(hero.partyId, gameData)
                            if party then
                                love.graphics.setColor(0.6, 0.5, 0.8)
                                love.graphics.print("[" .. (party.name or "Party") .. "]", partyX + partyWidth - 130, y + 8)
                            end
                        end

                        -- Selection indicator (right side)
                        if isSelected then
                            love.graphics.setColor(0.3, 0.8, 0.3)
                            love.graphics.print("SELECTED", partyX + 230, y + 44)
                        end
                    end

                    y = y + heroCardSpacing
                end
            end

            -- Reset scissor
            love.graphics.setScissor()

            -- Draw scrollbar if needed
            if maxScroll > 0 then
                local scrollbarX = partyX + partyWidth - scrollbarWidth
                local scrollbarHeight = listHeight

                -- Scrollbar track
                love.graphics.setColor(0.2, 0.2, 0.25)
                love.graphics.rectangle("fill", scrollbarX, listStartY, scrollbarWidth, scrollbarHeight, 3, 3)

                -- Scrollbar thumb
                local thumbHeight = math.max(30, scrollbarHeight * (listHeight / totalContentHeight))
                local thumbY = listStartY + (questHeroScrollOffset / maxScroll) * (scrollbarHeight - thumbHeight)
                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.rectangle("fill", scrollbarX + 2, thumbY, scrollbarWidth - 4, thumbHeight, 3, 3)
            end

        else
            -- PARTIES MODE: Show formed parties with all members idle
            gameData.parties = gameData.parties or {}

            -- Filter to parties where all members are idle
            local availableParties = {}
            for _, party in ipairs(gameData.parties) do
                if party.isFormed then
                    local allIdle = true
                    local members = PartySystem.getPartyMembers(party, gameData)
                    if #members == PartySystem.config.requiredMembers then
                        for _, member in ipairs(members) do
                            if member.status ~= "idle" then
                                allIdle = false
                                break
                            end
                        end
                        if allIdle then
                            table.insert(availableParties, {party = party, members = members})
                        end
                    end
                end
            end

            -- Calculate scroll for parties
            local partyCardHeight = 90
            local partyCardSpacing = 95
            local totalContentHeight = #availableParties * partyCardSpacing
            local maxScroll = math.max(0, totalContentHeight - listHeight)

            questHeroListBounds = {
                x = partyX,
                y = listStartY,
                w = partyWidth,
                h = listHeight,
                maxScroll = maxScroll
            }

            questHeroScrollOffset = math.max(0, math.min(questHeroScrollOffset, maxScroll))

            love.graphics.setScissor(partyX, listStartY, partyWidth, listHeight)

            -- Hint about individual selection
            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.printf("Tip: Use 'Heroes' mode to select individuals", partyX, listStartY - 15, partyWidth - 10, "center")

            if #availableParties == 0 then
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.printf("No formed parties available.\nForm a party by completing 3 quests\nwith 4 unique-class heroes!\n\nSwitch to 'Heroes' to select individually.", partyX, listStartY + 20, partyWidth - scrollbarWidth - 10, "center")
            else
                local y = listStartY - questHeroScrollOffset
                for i, partyData in ipairs(availableParties) do
                    if y + partyCardHeight >= listStartY and y < listStartY + listHeight then
                        local party = partyData.party
                        local members = partyData.members
                        local isSelected = selectedPartyId == party.id

                        local bgColor = isSelected and {0.3, 0.5, 0.3} or Components.colors.panelLight
                        Components.drawPanel(partyX, y, partyWidth - scrollbarWidth - 5, partyCardHeight, {
                            color = bgColor,
                            cornerRadius = 5
                        })

                        -- Party name
                        love.graphics.setColor(Components.colors.synergy)
                        love.graphics.print(party.name, partyX + 10, y + 8)

                        -- Party stats
                        love.graphics.setColor(Components.colors.textDim)
                        love.graphics.print("Quests: " .. (party.totalQuestsCompleted or 0), partyX + 10, y + 26)

                        -- Draw member portraits in a row
                        local portraitX = partyX + 10
                        local portraitY = y + 45
                        local portraitSize = 50
                        for j, member in ipairs(members) do
                            -- Small portrait
                            SpriteSystem.drawCentered(member, portraitX + (j-1) * 55 + portraitSize/2, portraitY + portraitSize/2, portraitSize + 20, portraitSize + 20, "Idle")

                            -- Class initial below portrait
                            love.graphics.setColor(Components.colors.textDim)
                            local classInitial = member.class:sub(1, 1)
                            love.graphics.printf(classInitial, portraitX + (j-1) * 55, portraitY + portraitSize - 5, portraitSize, "center")
                        end

                        -- Selection indicator
                        if isSelected then
                            love.graphics.setColor(0.3, 0.8, 0.3)
                            love.graphics.printf("SELECTED", partyX + partyWidth - scrollbarWidth - 85, y + 35, 75, "right")
                        end
                    end

                    y = y + partyCardSpacing
                end
            end

            love.graphics.setScissor()

            -- Draw scrollbar if needed
            if maxScroll > 0 then
                local scrollbarX = partyX + partyWidth - scrollbarWidth
                local scrollbarHeight = listHeight

                love.graphics.setColor(0.2, 0.2, 0.25)
                love.graphics.rectangle("fill", scrollbarX, listStartY, scrollbarWidth, scrollbarHeight, 3, 3)

                local thumbHeight = math.max(30, scrollbarHeight * (listHeight / totalContentHeight))
                local thumbY = listStartY + (questHeroScrollOffset / maxScroll) * (scrollbarHeight - thumbHeight)
                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.rectangle("fill", scrollbarX + 2, thumbY, scrollbarWidth - 4, thumbHeight, 3, 3)
            end
        end

        -- Send Party button
        local btnY = MENU_DESIGN_HEIGHT - 55
        local hasQuestSlot = not GuildSystem or GuildSystem.canStartQuest(gameData)
        local canSend = #partyHeroes > 0 and hasQuestSlot

        local btnText = hasQuestSlot and "Send Party" or "Quest Slots Full"
        Components.drawButton(btnText, partyX, btnY, partyWidth, 35, {
            disabled = not canSend,
            color = canSend and Components.colors.buttonActive or Components.colors.buttonDisabled
        })

        -- Clear button (moved below toggle buttons)
        Components.drawButton("Clear", partyX + partyWidth - 230, startY - 5, 50, 22, {
            color = Components.colors.button
        })
    else
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("Select a quest", partyX, startY + 50, partyWidth, "center")
    end
end

-- Draw active quests tab with real-time progress
function drawActiveTab(gameData, startY, height, QuestSystem, Quests, TimeSystem)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Active Quests (" .. #gameData.activeQuests .. ")", 20, startY)

    if #gameData.activeQuests == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No active quests. Assign heroes to quests!",
            0, startY + 50, MENU_DESIGN_WIDTH, "center")
        return
    end

    local y = startY + 30
    local cardWidth = MENU_DESIGN_WIDTH - 40

    for i, quest in ipairs(gameData.activeQuests) do
        if y + 85 > MENU_DESIGN_HEIGHT - 20 then break end

        -- Quest card
        Components.drawPanel(20, y, cardWidth, 80, {
            color = Components.colors.panelLight,
            cornerRadius = 5
        })

        -- Rank and name
        Components.drawRankBadge(quest.rank, 30, y + 10, 30)
        love.graphics.setColor(Components.colors.text)
        love.graphics.print(quest.name, 70, y + 10)

        -- Current phase
        local phase = quest.currentPhase or "travel"
        local phaseColors = {
            travel = {0.5, 0.7, 0.9},
            execute = {0.9, 0.6, 0.3},
            awaiting_claim = {0.3, 0.9, 0.3},
            ["return"] = {0.6, 0.9, 0.6}
        }

        if phase == "awaiting_claim" then
            -- Quest complete - show claim button instead of progress
            love.graphics.setColor(phaseColors[phase])
            love.graphics.print("QUEST COMPLETE!", 70, y + 30)

            -- Claim button
            local claimBtnX = 200
            local claimBtnY = y + 25
            local claimBtnW = 120
            local claimBtnH = 28

            -- Store button position for click detection
            quest._claimBtnPos = {x = claimBtnX, y = claimBtnY, w = claimBtnW, h = claimBtnH}

            Components.drawButton("CLAIM REWARDS", claimBtnX, claimBtnY, claimBtnW, claimBtnH, {
                bgColor = {0.2, 0.7, 0.3},
                hoverColor = {0.3, 0.8, 0.4}
            })
        else
            love.graphics.setColor(phaseColors[phase] or Components.colors.text)
            love.graphics.print("Phase: " .. phase:upper(), 70, y + 30)

            -- Phase progress bar
            local phasePercent = Quests.getPhasePercent(quest)
            local timeRemaining = Quests.getPhaseTimeRemaining(quest)
            Components.drawProgressBar(200, y + 28, 200, 18, phasePercent, {
                fgColor = phaseColors[phase] or Components.colors.progress,
                text = TimeSystem.formatDuration(timeRemaining) .. " left"
            })
        end

        -- Dungeon-specific display
        if quest.isDungeon then
            -- Floor progress indicator
            local floorX = 420
            love.graphics.setColor(Components.colors.text)
            love.graphics.print("Floor: " .. (quest.currentFloor or 0) .. "/" .. quest.floorCount, floorX, y + 10)

            -- Floor status dots
            for f = 1, quest.floorCount do
                local dotX = floorX + (f - 1) * 18
                if f <= #(quest.floorsCleared or {}) then
                    local floorResult = quest.floorsCleared[f]
                    if floorResult and floorResult.success then
                        love.graphics.setColor(Components.colors.success)
                    else
                        love.graphics.setColor(Components.colors.danger)
                    end
                elseif f == (quest.currentFloor or 0) + 1 then
                    love.graphics.setColor(Components.colors.warning)
                else
                    love.graphics.setColor(0.3, 0.3, 0.3)
                end
                love.graphics.circle("fill", dotX + 6, y + 35, 5)
            end

            -- Fatigue indicator
            local fatiguePercent = (quest.partyFatigue or 0) * 100
            if fatiguePercent > 0 then
                love.graphics.setColor(Components.colors.danger)
                love.graphics.print(string.format("Fatigue: -%.0f%%", fatiguePercent), floorX, y + 48)
            end

            -- Dungeon label
            love.graphics.setColor(0.8, 0.5, 0.9)
            love.graphics.print("[DUNGEON]", 70, y + 48)

            -- Retreat button (only during execute phase with at least 1 floor cleared)
            if phase == "execute" and #(quest.floorsCleared or {}) >= 1 and not quest.hasRetreated then
                local retreatBtnX = floorX + 120
                local retreatBtnY = y + 44
                local retreatBtnW = 70
                local retreatBtnH = 24

                -- Store button position for click detection
                quest._retreatBtnPos = {x = retreatBtnX, y = retreatBtnY, w = retreatBtnW, h = retreatBtnH}

                Components.drawButton("Retreat", retreatBtnX, retreatBtnY, retreatBtnW, retreatBtnH, {
                    bgColor = {0.7, 0.3, 0.3},
                    hoverColor = {0.8, 0.4, 0.4}
                })
            end
        end

        -- Assigned heroes with sprites
        local heroX = 70
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Party:", heroX, y + 62)
        heroX = heroX + 45
        for _, heroId in ipairs(quest.assignedHeroes) do
            -- Check heroesOnQuest first (heroes physically on quest)
            local heroFound = false
            if quest.heroesOnQuest then
                for _, hero in ipairs(quest.heroesOnQuest) do
                    if hero.id == heroId then
                        SpriteSystem.drawCentered(hero, heroX + 15, y + 70, 40, 40, "Idle")
                        heroX = heroX + 30
                        heroFound = true
                        break
                    end
                end
            end
            -- Fallback to guild roster
            if not heroFound then
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId then
                        SpriteSystem.drawCentered(hero, heroX + 15, y + 70, 40, 40, "Idle")
                        heroX = heroX + 30
                        break
                    end
                end
            end
        end

        -- Reward preview
        love.graphics.setColor(Components.colors.gold)
        love.graphics.printf(quest.reward .. "g", cardWidth - 80, y + 10, 70, "right")
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("+" .. quest.xpReward .. " XP", cardWidth - 80, y + 28, 70, "right")

        -- Dungeon XP bonus indicator
        if quest.isDungeon then
            love.graphics.setColor(0.6, 0.9, 0.6)
            love.graphics.printf("+50% XP", cardWidth - 80, y + 45, 70, "right")
        end

        y = y + 85
    end
end

-- Draw reputation tab
function drawReputationTab(gameData, startY, height, GuildSystem)
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

-- Handle click in guild menu
function GuildMenu.handleClick(x, y, gameData, QuestSystem, Quests, Heroes, GuildSystem)
    -- Update menu position for current window size
    updateMenuRect()
    local windowW, windowH = love.graphics.getDimensions()
    local scale = MENU.scale or 1

    -- Transform screen coordinates to design coordinates for menu clicks
    local designX = (x - MENU.x) / scale
    local designY = (y - MENU.y) / scale

    -- Hero detail popup handling - only for non-roster tabs (roster uses side panel)
    if selectedHeroDetail and currentTab ~= "roster" then
        local popupW, popupH = 580, 560
        local popupX = (windowW - popupW) / 2
        local popupY = (windowH - popupH) / 2

        -- Close button on popup
        if Components.isPointInRect(x, y, popupX + popupW - 40, popupY + 10, 30, 30) then
            selectedHeroDetail = nil
            equipDropdownSlot = nil
            equipDropdownItems = {}
            return nil
        end

        -- Bars/Graph toggle button
        if _toggleBtnPos and Components.isPointInRect(x, y, _toggleBtnPos.x, _toggleBtnPos.y, _toggleBtnPos.w, _toggleBtnPos.h) then
            statDisplayMode = (statDisplayMode == "bars") and "graph" or "bars"
            return nil
        end

        -- Handle dropdown item selection first (if dropdown is open)
        if equipDropdownSlot and #equipDropdownItems > 0 then
            local dropdownX, dropdownY = popupX + 30, popupY + 250
            for _, slotPos in ipairs(_equipSlotPositions) do
                if slotPos.key == equipDropdownSlot then
                    dropdownX = slotPos.x
                    dropdownY = slotPos.y + slotPos.height + 2
                    break
                end
            end

            local dropdownW = popupW - 60
            local itemHeight = 32
            local dropdownH = math.min(#equipDropdownItems * itemHeight + 10, 150)

            if Components.isPointInRect(x, y, dropdownX, dropdownY, dropdownW, dropdownH) then
                local itemY = dropdownY + 22
                for i, availItem in ipairs(equipDropdownItems) do
                    if Components.isPointInRect(x, y, dropdownX + 4, itemY, dropdownW - 8, itemHeight - 2) then
                        local success, msg = _EquipmentSystem.equip(selectedHeroDetail, availItem.item.id, gameData)
                        equipDropdownSlot = nil
                        equipDropdownItems = {}
                        if success then
                            return "equip_changed", selectedHeroDetail.name .. " equipped " .. availItem.item.name
                        end
                        return nil
                    end
                    itemY = itemY + itemHeight
                end
                return nil
            else
                equipDropdownSlot = nil
                equipDropdownItems = {}
            end
        end

        -- Click outside popup closes it
        if not Components.isPointInRect(x, y, popupX, popupY, popupW, popupH) then
            selectedHeroDetail = nil
            equipDropdownSlot = nil
            equipDropdownItems = {}
            return nil
        end

        -- Equipment slot buttons
        if _equipSlotPositions and _EquipmentSystem then
            for _, slotInfo in ipairs(_equipSlotPositions) do
                local btnX = popupX + popupW - 55
                local btnY = slotInfo.y + 2
                local btnW, btnH = 24, 24

                if Components.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
                    if slotInfo.equipped then
                        local success, msg = _EquipmentSystem.unequip(selectedHeroDetail, slotInfo.key, gameData)
                        equipDropdownSlot = nil
                        equipDropdownItems = {}
                        if success then
                            return "equip_changed", selectedHeroDetail.name .. " unequipped item"
                        end
                    else
                        local available = _EquipmentSystem.getAvailableForSlot(gameData, slotInfo.key, selectedHeroDetail.rank)
                        if #available > 0 then
                            if #available == 1 then
                                local success, msg = _EquipmentSystem.equip(selectedHeroDetail, available[1].item.id, gameData)
                                if success then
                                    return "equip_changed", selectedHeroDetail.name .. " equipped " .. available[1].item.name
                                end
                            else
                                equipDropdownSlot = slotInfo.key
                                equipDropdownItems = available
                            end
                        end
                    end
                    return nil
                end
            end
        end

        return nil
    end

    -- Close button (design coordinates)
    if Components.isPointInRect(designX, designY, MENU_DESIGN_WIDTH - 40, 10, 30, 30) then
        GuildMenu.resetState()
        return "close"
    end

    -- Tab clicks (design coordinates)
    local tabY = 50
    local clickedTab = Components.getClickedTab(TABS, designX, designY, 20, tabY, 100, 30)
    if clickedTab then
        currentTab = clickedTab
        if clickedTab ~= "quests" then
            selectedQuest = nil
            selectedHeroes = {}
        end
        return nil
    end

    local contentY = tabY + 50

    -- Roster tab - click on hero to view details, fire, or expand/collapse parties
    if currentTab == "roster" then
        local cardHeight = 70  -- Match the compact layout
        local partyHeaderHeight = 40
        local listStartY = contentY + 25
        local listHeight = MENU_DESIGN_HEIGHT - 20 - listStartY
        local listX = 20

        -- Calculate actual list width based on whether detail panel is open (60-40 split)
        local actualListWidth = selectedHeroDetail and math.floor(MENU_DESIGN_WIDTH * 0.6) - 30 or (MENU_DESIGN_WIDTH - 40)
        local cardWidth = actualListWidth - 30

        -- Check for clicks in the detail panel area (right side, 40% width)
        if selectedHeroDetail then
            local panelW = math.floor(MENU_DESIGN_WIDTH * 0.4) - 10
            local panelX = MENU_DESIGN_WIDTH - panelW - 10
            local panelY = listStartY
            local panelH = listHeight

            -- Check if click is in panel area
            if Components.isPointInRect(designX, designY, panelX, panelY, panelW, panelH) then
                -- Handle toggle button clicks
                if _toggleBtnPos and Components.isPointInRect(designX, designY, _toggleBtnPos.x, _toggleBtnPos.y, _toggleBtnPos.w, _toggleBtnPos.h) then
                    statDisplayMode = (statDisplayMode == "bars") and "graph" or "bars"
                    return nil
                end

                -- Handle equipment slot clicks
                if _equipSlotPositions and _EquipmentSystem then
                    for _, slotInfo in ipairs(_equipSlotPositions) do
                        local btnX = slotInfo.x + slotInfo.width - 22
                        local btnY = slotInfo.y + 2
                        local btnW, btnH = 20, 20

                        if Components.isPointInRect(designX, designY, btnX, btnY, btnW, btnH) then
                            if slotInfo.equipped then
                                local success, msg = _EquipmentSystem.unequip(selectedHeroDetail, slotInfo.key, gameData)
                                if success then
                                    return "equip_changed", selectedHeroDetail.name .. " unequipped item"
                                end
                            else
                                local available = _EquipmentSystem.getAvailableForSlot(gameData, slotInfo.key, selectedHeroDetail.rank)
                                if #available > 0 then
                                    local success, msg = _EquipmentSystem.equip(selectedHeroDetail, available[1].item.id, gameData)
                                    if success then
                                        return "equip_changed", selectedHeroDetail.name .. " equipped " .. available[1].item.name
                                    end
                                end
                            end
                            return nil
                        end
                    end
                end

                return nil  -- Click in panel, don't propagate
            end
        end

        -- Only process clicks within the scroll area (use design coordinates)
        if not Components.isPointInRect(designX, designY, listX, listStartY, actualListWidth, listHeight) then
            heroToFire = nil
            return nil
        end

        -- Build the same content layout as drawing (matches drawRosterTab)
        PartySystem.initGameData(gameData)
        local contentItems = {}

        if gameData.parties and #gameData.parties > 0 then
            for _, party in ipairs(gameData.parties) do
                local members = PartySystem.getPartyMembers(party, gameData)
                local isExpanded = expandedParties[party.id]
                table.insert(contentItems, {type = "party_header", party = party, members = members, height = partyHeaderHeight, cardWidth = cardWidth})
                if isExpanded then
                    for _, member in ipairs(members) do
                        table.insert(contentItems, {type = "party_member", hero = member, height = cardHeight + 5, cardWidth = cardWidth})
                    end
                end
            end
        end

        local unassignedHeroes = {}
        for _, hero in ipairs(gameData.heroes) do
            if not hero.partyId then
                table.insert(unassignedHeroes, hero)
            end
        end

        if #unassignedHeroes > 0 or #contentItems == 0 then
            table.insert(contentItems, {type = "section_header", text = "Unassigned Heroes", height = 25})
            for _, hero in ipairs(unassignedHeroes) do
                table.insert(contentItems, {type = "hero", hero = hero, height = cardHeight + 5, cardWidth = cardWidth})
            end
        end

        -- Find which item was clicked
        local itemY = listStartY - rosterScrollOffset
        for _, item in ipairs(contentItems) do
            local itemBottom = itemY + item.height

            -- Check if click is on this item (and item is visible)
            if designY >= itemY and designY < itemBottom and itemBottom >= listStartY and itemY < listStartY + listHeight then
                if item.type == "party_header" then
                    -- Toggle party expansion
                    expandedParties[item.party.id] = not expandedParties[item.party.id]
                    heroToFire = nil
                    return nil

                elseif item.type == "party_member" or item.type == "hero" then
                    local hero = item.hero
                    local indent = item.type == "party_member" and 30 or 0

                    -- Check Fire button click (only for unassigned idle heroes when there's room)
                    if hero.status == "idle" and item.type == "hero" and cardWidth > 400 then
                        local fireBtnX = listX + cardWidth - 55
                        local fireBtnY = itemY + 10
                        local fireBtnW = 45
                        local fireBtnH = 22

                        if Components.isPointInRect(designX, designY, fireBtnX, fireBtnY, fireBtnW, fireBtnH) then
                            if heroToFire == hero.id then
                                -- Confirm fire
                                for j, h in ipairs(gameData.heroes) do
                                    if h.id == hero.id then
                                        -- Return equipment to inventory (use passed gameData, not cached _gameData)
                                        if hero.equipment and gameData.inventory and gameData.inventory.equipment then
                                            for slot, itemId in pairs(hero.equipment) do
                                                if itemId then
                                                    gameData.inventory.equipment[itemId] = (gameData.inventory.equipment[itemId] or 0) + 1
                                                end
                                            end
                                        end
                                        table.remove(gameData.heroes, j)
                                        break
                                    end
                                end
                                heroToFire = nil
                                return "fired", hero.name .. " has been dismissed from the guild."
                            else
                                heroToFire = hero.id
                            end
                            return nil
                        end
                    end

                    -- Click elsewhere on card opens details
                    heroToFire = nil
                    if hero.status == "idle" or hero.status == "resting" then
                        selectedHeroDetail = hero
                    end
                    return nil
                end
            end

            itemY = itemY + item.height
        end

        -- Clicking anywhere else resets fire confirmation
        heroToFire = nil
    end

    if currentTab == "quests" then
        -- Quest list clicks (design coordinates)
        local questListWidth = 350
        local questY = contentY + 25
        for i, quest in ipairs(gameData.availableQuests) do
            if Components.isPointInRect(designX, designY, 20, questY, questListWidth - 10, 65) then
                selectedQuest = quest
                selectedHeroes = {}
                return nil
            end
            questY = questY + 70
        end

        -- Party selection clicks
        if selectedQuest then
            local partyX = questListWidth + 20
            local partyWidth = MENU_DESIGN_WIDTH - questListWidth - 50

            -- Mode toggle buttons
            local toggleY = contentY - 5
            local toggleBtnWidth = 80

            -- Individual (heroes) toggle button (design coordinates)
            if Components.isPointInRect(designX, designY, partyX + partyWidth - 165, toggleY, toggleBtnWidth, 22) then
                questSelectionMode = "heroes"
                selectedPartyId = nil
                questHeroScrollOffset = 0
                return nil
            end

            -- Party toggle button (design coordinates)
            if Components.isPointInRect(designX, designY, partyX + partyWidth - 80, toggleY, 70, 22) then
                questSelectionMode = "parties"
                selectedHeroes = {}
                questHeroScrollOffset = 0
                return nil
            end

            -- Clear button (design coordinates)
            if Components.isPointInRect(designX, designY, partyX + partyWidth - 230, contentY - 5, 50, 22) then
                selectedHeroes = {}
                selectedPartyId = nil
                return nil
            end

            -- Hero/Party selection - with scroll offset support
            -- This matches the drawing code: math.max(synergyY + 8, startY + 210)
            local heroListStartY = contentY + 210
            local listHeight = MENU_DESIGN_HEIGHT - 65 - heroListStartY

            -- Only process clicks within the list bounds (design coordinates)
            if Components.isPointInRect(designX, designY, partyX, heroListStartY, partyWidth, listHeight) then
                if questSelectionMode == "heroes" then
                    -- HEROES MODE: Individual hero selection
                    local heroCardHeight = 70
                    local heroCardSpacing = 75

                    -- Count currently selected heroes
                    local currentCount = 0
                    for _, isSelected in pairs(selectedHeroes) do
                        if isSelected then currentCount = currentCount + 1 end
                    end
                    local maxHeroes = selectedQuest.maxHeroes or 6

                    -- Apply scroll offset to click position
                    local heroY = heroListStartY - questHeroScrollOffset
                    for i, hero in ipairs(gameData.heroes) do
                        if hero.status == "idle" then
                            -- Check if this hero card is at the clicked position (accounting for scroll)
                            local cardScreenY = heroY
                            if designY >= cardScreenY and designY < cardScreenY + heroCardHeight
                               and cardScreenY + heroCardHeight >= heroListStartY
                               and cardScreenY < heroListStartY + listHeight then
                                -- Check for double-click to show hero detail popup
                                local currentTime = love.timer.getTime()
                                if lastHeroClickId == hero.id and (currentTime - lastHeroClickTime) < 0.4 then
                                    -- Double-click: show hero detail popup
                                    selectedHeroDetail = hero
                                    lastHeroClickId = nil
                                    lastHeroClickTime = 0
                                    return nil
                                end
                                lastHeroClickId = hero.id
                                lastHeroClickTime = currentTime

                                -- Single click: toggle selection
                                if selectedHeroes[hero.id] then
                                    -- Always allow deselection
                                    selectedHeroes[hero.id] = nil
                                elseif currentCount < maxHeroes then
                                    -- Only allow selection if under limit
                                    selectedHeroes[hero.id] = true
                                end
                                -- If at limit and trying to select, do nothing (visual feedback via warning color)
                                return nil
                            end
                            heroY = heroY + heroCardSpacing
                        end
                    end
                else
                    -- PARTIES MODE: Select entire party
                    local partyCardHeight = 90
                    local partyCardSpacing = 95

                    -- Get available parties (same logic as drawing)
                    gameData.parties = gameData.parties or {}
                    local availableParties = {}
                    for _, party in ipairs(gameData.parties) do
                        if party.isFormed then
                            local allIdle = true
                            local members = PartySystem.getPartyMembers(party, gameData)
                            if #members == PartySystem.config.requiredMembers then
                                for _, member in ipairs(members) do
                                    if member.status ~= "idle" then
                                        allIdle = false
                                        break
                                    end
                                end
                                if allIdle then
                                    table.insert(availableParties, {party = party, members = members})
                                end
                            end
                        end
                    end

                    -- Apply scroll offset to click position
                    local partyY = heroListStartY - questHeroScrollOffset
                    for i, partyData in ipairs(availableParties) do
                        local cardScreenY = partyY
                        if designY >= cardScreenY and designY < cardScreenY + partyCardHeight
                           and cardScreenY + partyCardHeight >= heroListStartY
                           and cardScreenY < heroListStartY + listHeight then
                            -- Toggle party selection
                            if selectedPartyId == partyData.party.id then
                                -- Deselect party
                                selectedPartyId = nil
                                selectedHeroes = {}
                            else
                                -- Select party - populate selectedHeroes with all members
                                selectedPartyId = partyData.party.id
                                selectedHeroes = {}
                                for _, member in ipairs(partyData.members) do
                                    selectedHeroes[member.id] = true
                                end
                            end
                            return nil
                        end
                        partyY = partyY + partyCardSpacing
                    end
                end
            end

            -- Send Party button (design coordinates)
            local btnY = MENU_DESIGN_HEIGHT - 55
            if Components.isPointInRect(designX, designY, partyX, btnY, partyWidth, 35) then
                local partyHeroes = {}
                -- Only include heroes that are truly selected AND idle
                for heroId, isSelected in pairs(selectedHeroes) do
                    if isSelected == true then
                        for _, hero in ipairs(gameData.heroes) do
                            if hero.id == heroId and hero.status == "idle" then
                                table.insert(partyHeroes, hero)
                                break
                            end
                        end
                    end
                end

                if #partyHeroes > 0 then
                    -- Check quest slot availability
                    if GuildSystem and not GuildSystem.canStartQuest(gameData) then
                        return "error", "Quest slots full! Level up your guild."
                    end

                    local success, message = QuestSystem.assignParty(selectedQuest, partyHeroes, gameData)
                    if success then
                        selectedQuest = nil
                        selectedHeroes = {}
                        selectedPartyId = nil
                        return "assigned", message
                    else
                        return "error", message
                    end
                end
            end
        end
    end

    -- Active tab - click on claim button or retreat button
    if currentTab == "active" then
        local y = contentY + 30

        for i, quest in ipairs(gameData.activeQuests) do
            if y + 85 > MENU_DESIGN_HEIGHT - 20 then break end

            -- Check for claim button click on awaiting_claim quests
            if quest.currentPhase == "awaiting_claim" and quest._claimBtnPos then
                local btn = quest._claimBtnPos
                if Components.isPointInRect(designX, designY, btn.x, btn.y, btn.w, btn.h) then
                    -- Return "claim_quest" action with the quest
                    return "claim_quest", quest
                end
            end

            -- Check for retreat button click on dungeon quests
            if quest.isDungeon and quest._retreatBtnPos then
                local btn = quest._retreatBtnPos
                if Components.isPointInRect(designX, designY, btn.x, btn.y, btn.w, btn.h) then
                    -- Trigger retreat
                    if QuestSystem and QuestSystem.retreatFromDungeon then
                        local success, message = QuestSystem.retreatFromDungeon(quest, gameData)
                        if success then
                            return "retreat", message
                        else
                            return "error", message or "Cannot retreat from dungeon"
                        end
                    end
                end
            end

            y = y + 85
        end
    end

    return nil
end

return GuildMenu
