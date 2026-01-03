-- Guild Menu Module
-- UI for managing heroes and assigning quests

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")

local GuildMenu = {}

-- Menu dimensions (scaled for 1280x720)
local MENU = {
    x = 90,
    y = 60,
    width = 1100,
    height = 600
}

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

-- Tooltip/hover state
local mouseX, mouseY = 0, 0
local hoveredSynergy = nil  -- Synergy currently being hovered
local hoveredSynergyPos = nil  -- Position for tooltip
local synergyHelpHovered = false  -- Is the synergy "?" icon hovered
local hoveredHeroId = nil  -- Hero card being hovered (for status bar)

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

-- Draw the guild menu
function GuildMenu.draw(gameData, QuestSystem, Quests, Heroes, TimeSystem, GuildSystem, Equipment, EquipmentSystem)
    -- Store references for popup and helpers
    _Equipment = Equipment
    _EquipmentSystem = EquipmentSystem
    _gameData = gameData
    _Quests = Quests
    -- Background panel
    Components.drawPanel(MENU.x, MENU.y, MENU.width, MENU.height)

    -- Title
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("GUILD HALL", MENU.x, MENU.y + 15, MENU.width, "center")

    -- Close button
    Components.drawCloseButton(MENU.x + MENU.width - 40, MENU.y + 10)

    -- Gold display
    Components.drawGold(gameData.gold, MENU.x + 20, MENU.y + 15)

    -- Tabs
    local tabY = MENU.y + 50
    Components.drawTabs(TABS, currentTab, MENU.x + 20, tabY, 100, 30)

    -- Active quests count badge
    if #gameData.activeQuests > 0 then
        love.graphics.setColor(Components.colors.warning)
        love.graphics.circle("fill", MENU.x + 320, tabY + 15, 10)
        love.graphics.setColor(Components.colors.text)
        love.graphics.printf(tostring(#gameData.activeQuests), MENU.x + 310, tabY + 8, 20, "center")
    end

    -- Content area
    local contentY = tabY + 50
    local contentHeight = MENU.height - 120

    if currentTab == "roster" then
        drawRosterTab(gameData, contentY, contentHeight, Heroes, TimeSystem, GuildSystem)
    elseif currentTab == "quests" then
        drawQuestsTab(gameData, contentY, contentHeight, QuestSystem, Quests, TimeSystem, GuildSystem)
    elseif currentTab == "active" then
        drawActiveTab(gameData, contentY, contentHeight, QuestSystem, Quests, TimeSystem)
    elseif currentTab == "reputation" then
        drawReputationTab(gameData, contentY, contentHeight, GuildSystem)
    end

    -- Hero detail popup (draws on top)
    if selectedHeroDetail then
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
    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Popup dimensions (increased width for pentagon chart)
    local popupW, popupH = 580, 520
    local popupX = (1280 - popupW) / 2
    local popupY = (720 - popupH) / 2

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

    -- Power
    love.graphics.setColor(Components.colors.warning)
    love.graphics.print("Power: " .. hero.power, popupX + 175, popupY + 82)

    -- XP bar
    local xpPercent = hero.xpToLevel > 0 and (hero.xp / hero.xpToLevel) or 1
    Components.drawProgressBar(popupX + 290, popupY + 82, 120, 16, xpPercent, {
        fgColor = {0.5, 0.3, 0.7},
        text = hero.xp .. "/" .. hero.xpToLevel .. " XP"
    })

    -- Pentagon stat chart (right side) - includes equipment bonuses
    local pentagonX = popupX + popupW - 130
    local pentagonY = popupY + 150

    -- Calculate effective stats (base + equipment + injury)
    local effectiveStats = {}
    local baseStats = {}
    for _, stat in ipairs({"str", "dex", "int", "vit", "luck"}) do
        local base = hero.stats[stat] or 0
        local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat) or 0
        baseStats[stat] = base
        effectiveStats[stat] = base + equipBonus
    end

    -- Draw effective stats (with equipment) as main, base stats as inner reference
    local hasEquipment = false
    for stat, val in pairs(effectiveStats) do
        if val > baseStats[stat] then hasEquipment = true break end
    end

    if hasEquipment then
        -- Show effective stats as main filled area, base stats as white inner line
        Components.drawPentagonChart(effectiveStats, pentagonX, pentagonY, 70, {
            showLabels = true,
            fillColor = {0.3, 0.7, 0.3, 0.5},   -- Green tint for equipped
            lineColor = {0.4, 0.9, 0.4, 1},     -- Bright green outline
            overlayStats = baseStats,
            overlayColor = {1, 0.9, 0.3, 0.6}   -- Gold line showing base stats
        })
        -- Equipment indicator below pentagon
        love.graphics.setColor(Components.colors.success)
        love.graphics.printf("+ Gear", pentagonX - 35, pentagonY + 75, 70, "center")
    else
        -- No equipment - just show base stats in gold
        Components.drawPentagonChart(effectiveStats, pentagonX, pentagonY, 70, {
            showLabels = true,
            fillColor = {0.8, 0.7, 0.2, 0.5},
            lineColor = {1, 0.9, 0.3, 1}
        })
    end

    -- Stats section (left side) with toggle button
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("STATS", popupX + 20, popupY + 115)

    -- Bars/Graph toggle button
    local toggleBtnX = popupX + 80
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

    -- Only show bars when in bars mode
    if statDisplayMode == "bars" then
        for _, stat in ipairs(statData) do
            local baseValue = hero.stats[stat.key] or 0
            local effectiveValue = math.floor(baseValue * injuryPenalty)
            local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat.key) or 0

            love.graphics.setColor(stat.color)
            love.graphics.print(stat.name, popupX + 30, statY)

            -- Stat bar
            local barW = 150
            local barH = 12
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", popupX + 70, statY + 2, barW, barH)

            -- Effective stat (with injury)
            love.graphics.setColor(stat.color[1] * 0.7, stat.color[2] * 0.7, stat.color[3] * 0.7)
            love.graphics.rectangle("fill", popupX + 70, statY + 2, barW * math.min(effectiveValue / 20, 1), barH)

            -- Equipment bonus
            if equipBonus > 0 then
                love.graphics.setColor(stat.color)
                love.graphics.rectangle("fill", popupX + 70 + barW * (effectiveValue / 20), statY + 2,
                    barW * math.min(equipBonus / 20, 1 - effectiveValue / 20), barH)
            end

            -- Value display
            love.graphics.setColor(Components.colors.text)
            if injuryPenalty < 1 then
                love.graphics.setColor(Components.colors.injured)
                love.graphics.print(effectiveValue, popupX + 230, statY)
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print("(" .. baseValue .. ")", popupX + 255, statY)
            else
                love.graphics.print(baseValue, popupX + 230, statY)
            end
            if equipBonus > 0 then
                love.graphics.setColor(Components.colors.success)
                love.graphics.print("+" .. equipBonus, popupX + 285, statY)
            end

            statY = statY + 22
        end
    else
        -- Graph mode: show larger pentagon in center of stat area
        local graphCenterX = popupX + 170
        local graphCenterY = popupY + 210

        -- Show numerical values next to the pentagon
        if hasEquipment then
            Components.drawPentagonChart(effectiveStats, graphCenterX, graphCenterY, 85, {
                showLabels = true,
                fillColor = {0.3, 0.7, 0.3, 0.5},
                lineColor = {0.4, 0.9, 0.4, 1},
                overlayStats = baseStats,
                overlayColor = {1, 0.9, 0.3, 0.6}
            })
        else
            Components.drawPentagonChart(effectiveStats, graphCenterX, graphCenterY, 85, {
                showLabels = true,
                fillColor = {0.8, 0.7, 0.2, 0.5},
                lineColor = {1, 0.9, 0.3, 1}
            })
        end

        -- Show stat values as compact list below pentagon
        local valueY = graphCenterY + 95
        love.graphics.setColor(Components.colors.textDim)
        local valueStr = ""
        for _, stat in ipairs(statData) do
            local baseValue = hero.stats[stat.key] or 0
            local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat.key) or 0
            local totalVal = baseValue + equipBonus
            valueStr = valueStr .. stat.name .. ":" .. totalVal .. "  "
        end
        love.graphics.printf(valueStr, popupX + 20, valueY, popupW - 40, "center")

        statY = valueY + 20
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
function drawRosterTab(gameData, startY, height, Heroes, TimeSystem, GuildSystem)
    -- Hero slots info
    local heroSlots = GuildSystem and GuildSystem.getHeroSlots(gameData) or 4
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Your Heroes (" .. #gameData.heroes .. "/" .. heroSlots .. ")", MENU.x + 20, startY)

    -- Status summary (include injury counts)
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
    love.graphics.print("Idle: " .. idleCount, MENU.x + 200, startY)
    love.graphics.setColor(Components.colors.warning)
    love.graphics.print("Busy: " .. busyCount, MENU.x + 280, startY)
    love.graphics.setColor(0.6, 0.4, 0.7)
    love.graphics.print("Resting: " .. restingCount, MENU.x + 360, startY)
    if injuredCount > 0 then
        love.graphics.setColor(Components.colors.injured)
        love.graphics.print("Injured: " .. injuredCount, MENU.x + 460, startY)
    end

    if #gameData.heroes == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No heroes yet! Visit the Tavern to hire some.",
            MENU.x, startY + 50, MENU.width, "center")
        return
    end

    local cardHeight = 100
    local cardWidth = MENU.width - 40
    local y = startY + 25

    for i, hero in ipairs(gameData.heroes) do
        if y + cardHeight > MENU.y + MENU.height - 20 then break end

        -- Card background color based on status
        local bgColor = Components.colors.panelLight
        if hero.status == "idle" then
            bgColor = {0.25, 0.35, 0.25}
        elseif hero.status == "resting" then
            bgColor = {0.3, 0.25, 0.35}
        else
            bgColor = {0.35, 0.3, 0.2}
        end
        Components.drawPanel(MENU.x + 20, y, cardWidth, cardHeight, {color = bgColor, cornerRadius = 5})

        -- Hero sprite portrait (much larger to compensate for sprite padding)
        local spriteX = MENU.x + 70
        local spriteY = y + cardHeight / 2
        SpriteSystem.drawCentered(hero, spriteX, spriteY, 240, 240, "Idle")

        -- Hero info (shifted right for bigger sprite)
        love.graphics.setColor(Components.colors.text)
        love.graphics.print(hero.name, MENU.x + 130, y + 15)

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print((hero.race or "Human") .. " " .. hero.class .. " Lv." .. hero.level, MENU.x + 130, y + 35)

        -- Rank and Power on third line
        love.graphics.setColor(Components.colors.warning)
        love.graphics.print("Rank: " .. hero.rank .. "  |  Power: " .. hero.power, MENU.x + 130, y + 55)

        -- Status with progress (centered vertically for taller card)
        local statusX = MENU.x + 380
        if hero.status == "idle" then
            love.graphics.setColor(Components.colors.success)
            love.graphics.print("AVAILABLE", statusX, y + 38)

            -- Fire button (only for idle heroes)
            local fireBtnX = MENU.x + 550
            local fireBtnY = y + 35
            local fireBtnW = 50
            local fireBtnH = 24

            if heroToFire == hero.id then
                -- Confirmation state - show "Sure?" button
                love.graphics.setColor(0.7, 0.2, 0.2)
                love.graphics.rectangle("fill", fireBtnX, fireBtnY, fireBtnW, fireBtnH, 3, 3)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("Sure?", fireBtnX, fireBtnY + 5, fireBtnW, "center")
            else
                -- Normal Fire button
                love.graphics.setColor(0.5, 0.3, 0.3)
                love.graphics.rectangle("fill", fireBtnX, fireBtnY, fireBtnW, fireBtnH, 3, 3)
                love.graphics.setColor(0.9, 0.6, 0.6)
                love.graphics.printf("Fire", fireBtnX, fireBtnY + 5, fireBtnW, "center")
            end
        elseif hero.status == "resting" then
            love.graphics.setColor(0.6, 0.4, 0.7)
            love.graphics.print("RESTING", statusX, y + 25)
            -- Rest progress bar
            local restPercent = Heroes.getRestPercent(hero)
            local timeLeft = math.max(0, (hero.restTimeMax or 0) - (hero.restProgress or 0))
            Components.drawProgressBar(statusX, y + 48, 150, 14, restPercent, {
                fgColor = {0.6, 0.4, 0.7},
                text = TimeSystem.formatDuration(timeLeft)
            })
        else
            -- On quest
            love.graphics.setColor(Components.colors.warning)
            local phaseText = (hero.questPhase or ""):upper()
            love.graphics.print(phaseText, statusX, y + 25)
            -- Quest progress bar
            local phaseMax = hero.questPhaseMax or 1
            local progress = (hero.questProgress or 0) / phaseMax
            local timeLeft = math.max(0, phaseMax - (hero.questProgress or 0))
            Components.drawProgressBar(statusX, y + 48, 150, 14, progress, {
                fgColor = Components.colors.warning,
                text = TimeSystem.formatDuration(timeLeft)
            })
        end

        -- Injury indicator (shows after status)
        if hero.injuryState and Heroes and Heroes.getInjuryInfo then
            local injuryInfo = Heroes.getInjuryInfo(hero)
            local injuryColor = Components.getInjuryColor(hero.injuryState)
            love.graphics.setColor(injuryColor)
            love.graphics.print(injuryInfo.name:upper(), MENU.x + cardWidth - 150, y + 38)
        end

        -- XP bar
        local xpPercent = hero.xp / hero.xpToLevel
        Components.drawProgressBar(MENU.x + cardWidth - 80, y + 38, 70, 18, xpPercent, {
            fgColor = {0.5, 0.3, 0.7},
            text = "XP"
        })

        y = y + cardHeight + 5
    end
end

-- Draw quests tab with party selection
function drawQuestsTab(gameData, startY, height, QuestSystem, Quests, TimeSystem, GuildSystem)
    -- Left side: Quest list
    local questListWidth = 350
    local questSlots = GuildSystem and GuildSystem.getQuestSlots(gameData) or 2
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Available Quests", MENU.x + 20, startY)

    -- Active quest slots display
    local activeColor = #gameData.activeQuests >= questSlots and Components.colors.danger or Components.colors.textDim
    love.graphics.setColor(activeColor)
    love.graphics.print("Active: " .. #gameData.activeQuests .. "/" .. questSlots, MENU.x + 200, startY)

    if #gameData.availableQuests == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("No quests available. Wait for new ones!", MENU.x + 20, startY + 30)
    else
        local y = startY + 25
        for i, quest in ipairs(gameData.availableQuests) do
            if y + 70 > MENU.y + MENU.height - 20 then break end

            local isSelected = selectedQuest and selectedQuest.id == quest.id

            -- Quest card
            local bgColor = isSelected and {0.3, 0.4, 0.5} or Components.colors.panelLight
            Components.drawPanel(MENU.x + 20, y, questListWidth - 10, 65, {
                color = bgColor,
                cornerRadius = 5
            })

            -- Rank badge
            Components.drawRankBadge(quest.rank, MENU.x + 30, y + 18, 28)

            -- Quest info
            love.graphics.setColor(Components.colors.text)
            local questName = quest.name
            local timeOfDay = quest.timeOfDay or "any"
            if timeOfDay == "night" then
                questName = questName .. " [Night]"
                love.graphics.setColor(0.6, 0.5, 0.8)  -- Purple tint for night quests
            elseif timeOfDay == "day" then
                questName = questName .. " [Day]"
                love.graphics.setColor(0.9, 0.7, 0.3)  -- Golden tint for day quests
            end
            love.graphics.print(questName, MENU.x + 65, y + 8)

            -- Faction badge (colored dot with name)
            if quest.faction and GuildSystem then
                local faction = GuildSystem.factions[quest.faction]
                if faction then
                    love.graphics.setColor(faction.color)
                    love.graphics.circle("fill", MENU.x + 65, y + 52, 5)
                    love.graphics.setColor(Components.colors.textDim)
                    love.graphics.print(faction.name, MENU.x + 75, y + 45)
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

            -- Build stat requirement string
            local statStr = statNames[reqStat] or "STR"
            if quest.secondaryStats and #quest.secondaryStats > 0 then
                for _, secStat in ipairs(quest.secondaryStats) do
                    statStr = statStr .. "+" .. (statNames[secStat.stat] or "?")
                end
            end

            love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
            love.graphics.print("Needs: " .. statStr, MENU.x + 65, y + 26)

            love.graphics.setColor(Components.colors.textDim)
            local totalTime = Quests.getTotalTime(quest)
            love.graphics.print("Time: " .. TimeSystem.formatDuration(totalTime), MENU.x + 160, y + 26)

            love.graphics.setColor(Components.colors.gold)
            love.graphics.print(quest.reward .. "g", MENU.x + questListWidth - 70, y + 8)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("+" .. quest.xpReward .. " XP", MENU.x + questListWidth - 70, y + 26)

            -- Mini pentagon showing quest stat requirements
            local miniPentagonX = MENU.x + questListWidth - 35
            local miniPentagonY = y + 50
            local questReqs = getQuestStatRequirements(quest, Quests)
            local statColor = statColors[reqStat] or {0.6, 0.6, 0.6}
            Components.drawPentagonChart(questReqs, miniPentagonX, miniPentagonY, 18, {
                showLabels = false,
                fillColor = {statColor[1], statColor[2], statColor[3], 0.4},
                lineColor = {statColor[1], statColor[2], statColor[3], 0.8},
                maxStat = 20
            })

            y = y + 70
        end
    end

    -- Right side: Party selection
    local partyX = MENU.x + questListWidth + 20
    local partyWidth = MENU.width - questListWidth - 50

    if selectedQuest then
        love.graphics.setColor(Components.colors.text)
        love.graphics.print("Party for: " .. selectedQuest.name, partyX, startY)

        -- Party power display - count selected heroes properly
        local partyPower = 0
        local partyHeroes = {}

        -- Only count heroes that are actually selected AND still exist in roster
        for heroId, isSelected in pairs(selectedHeroes) do
            if isSelected == true then
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId and hero.status == "idle" then
                        partyPower = partyPower + hero.power
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

        local powerColor = partyPower >= selectedQuest.requiredPower and Components.colors.success or Components.colors.danger
        love.graphics.setColor(powerColor)
        love.graphics.print(string.format("Power: %d / %d needed", partyPower, selectedQuest.requiredPower),
            partyX, startY + 34)

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
        local statDisplayY = startY + 50
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
        local pentagonX = partyX + partyWidth - 85
        local pentagonY = startY + 100
        local pentagonRadius = 55

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
        love.graphics.print("Combined Stats", pentagonX - 35, pentagonY + pentagonRadius + 8)
        if #partyHeroes > 0 then
            -- Show hero count
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.print(#partyHeroes .. " hero" .. (#partyHeroes > 1 and "es" or ""), pentagonX - 35, pentagonY + pentagonRadius + 24)

            -- Legend
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.rectangle("fill", pentagonX - 40, pentagonY + pentagonRadius + 42, 10, 10)
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Party", pentagonX - 25, pentagonY + pentagonRadius + 40)

            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.rectangle("line", pentagonX + 20, pentagonY + pentagonRadius + 42, 10, 10)
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("Quest", pentagonX + 35, pentagonY + pentagonRadius + 40)
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

        -- Available heroes list (positioned below the pentagon chart area)
        local y = math.max(synergyY + 8, startY + 210)
        for i, hero in ipairs(gameData.heroes) do
            if y + 38 > MENU.y + MENU.height - 60 then break end

            if hero.status == "idle" then
                local isSelected = selectedHeroes[hero.id] == true

                local bgColor = isSelected and {0.3, 0.5, 0.3} or Components.colors.panelLight
                Components.drawPanel(partyX, y, partyWidth, 34, {
                    color = bgColor,
                    cornerRadius = 3
                })

                -- Small sprite portrait
                SpriteSystem.drawCentered(hero, partyX + 20, y + 17, 60, 60, "Idle")

                Components.drawRankBadge(hero.rank, partyX + 38, y + 5, 24)
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(hero.name, partyX + 68, y + 9)
                -- Show race and class
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print((hero.race or "Human") .. " " .. hero.class, partyX + 180, y + 9)
                -- Show hero's relevant stat for this quest (with equipment bonus)
                local heroStat = hero.stats[reqStat] or 0
                local heroEquipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, reqStat) or 0
                love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
                if heroEquipBonus > 0 then
                    love.graphics.printf(statNames[reqStat] .. ":" .. heroStat, partyX + partyWidth - 70, y + 9, 35, "right")
                    love.graphics.setColor(Components.colors.success)
                    love.graphics.printf("+" .. heroEquipBonus, partyX + partyWidth - 30, y + 9, 25, "right")
                else
                    love.graphics.printf(statNames[reqStat] .. ":" .. heroStat, partyX + partyWidth - 50, y + 9, 45, "right")
                end

                y = y + 38
            end
        end

        -- Send Party button
        local btnY = MENU.y + MENU.height - 55
        local hasQuestSlot = not GuildSystem or GuildSystem.canStartQuest(gameData)
        local canSend = partyPower >= selectedQuest.requiredPower and #partyHeroes > 0 and hasQuestSlot

        local btnText = hasQuestSlot and "Send Party" or "Quest Slots Full"
        Components.drawButton(btnText, partyX, btnY, partyWidth, 35, {
            disabled = not canSend,
            color = canSend and Components.colors.buttonActive or Components.colors.buttonDisabled
        })

        -- Clear button
        Components.drawButton("Clear", partyX + partyWidth - 50, startY - 5, 50, 22, {
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
    love.graphics.print("Active Quests (" .. #gameData.activeQuests .. ")", MENU.x + 20, startY)

    if #gameData.activeQuests == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No active quests. Assign heroes to quests!",
            MENU.x, startY + 50, MENU.width, "center")
        return
    end

    local y = startY + 30
    local cardWidth = MENU.width - 40

    for i, quest in ipairs(gameData.activeQuests) do
        if y + 85 > MENU.y + MENU.height - 20 then break end

        -- Quest card
        Components.drawPanel(MENU.x + 20, y, cardWidth, 80, {
            color = Components.colors.panelLight,
            cornerRadius = 5
        })

        -- Rank and name
        Components.drawRankBadge(quest.rank, MENU.x + 30, y + 10, 30)
        love.graphics.setColor(Components.colors.text)
        love.graphics.print(quest.name, MENU.x + 70, y + 10)

        -- Current phase
        local phase = quest.currentPhase or "travel"
        local phaseColors = {
            travel = {0.5, 0.7, 0.9},
            execute = {0.9, 0.6, 0.3},
            ["return"] = {0.6, 0.9, 0.6}
        }
        love.graphics.setColor(phaseColors[phase] or Components.colors.text)
        love.graphics.print("Phase: " .. phase:upper(), MENU.x + 70, y + 30)

        -- Phase progress bar
        local phasePercent = Quests.getPhasePercent(quest)
        local timeRemaining = Quests.getPhaseTimeRemaining(quest)
        Components.drawProgressBar(MENU.x + 200, y + 28, 200, 18, phasePercent, {
            fgColor = phaseColors[phase] or Components.colors.progress,
            text = TimeSystem.formatDuration(timeRemaining) .. " left"
        })

        -- Assigned heroes with sprites
        local heroX = MENU.x + 70
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Party:", heroX, y + 52)
        heroX = heroX + 45
        for _, heroId in ipairs(quest.assignedHeroes) do
            for _, hero in ipairs(gameData.heroes) do
                if hero.id == heroId then
                    -- Draw small sprite
                    SpriteSystem.drawCentered(hero, heroX + 15, y + 60, 50, 50, "Idle")
                    heroX = heroX + 35
                    break
                end
            end
        end

        -- Reward preview
        love.graphics.setColor(Components.colors.gold)
        love.graphics.printf(quest.reward .. "g", MENU.x + cardWidth - 80, y + 10, 70, "right")
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("+" .. quest.xpReward .. " XP", MENU.x + cardWidth - 80, y + 28, 70, "right")

        y = y + 85
    end
end

-- Draw reputation tab
function drawReputationTab(gameData, startY, height, GuildSystem)
    if not GuildSystem then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("Guild system not available", MENU.x, startY + 50, MENU.width, "center")
        return
    end

    -- Guild level info
    local guildLevel = gameData.guild and gameData.guild.level or 1
    local progress, needed, percent = GuildSystem.getXPProgress(gameData)
    local currentXP = gameData.guild and gameData.guild.xp or 0

    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Guild Level " .. guildLevel, MENU.x + 20, startY)

    -- Guild XP bar
    local nextLevelXP = GuildSystem.getXPToNextLevel(gameData)
    if nextLevelXP > 0 then
        Components.drawProgressBar(MENU.x + 150, startY, 200, 18, percent, {
            fgColor = {0.4, 0.6, 0.8},
            text = progress .. "/" .. needed .. " XP"
        })
    else
        love.graphics.setColor(Components.colors.success)
        love.graphics.print("MAX LEVEL", MENU.x + 150, startY)
    end

    -- Slots info
    local slotsInfo = GuildSystem.getSlotsInfo(gameData)
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Heroes: " .. slotsInfo.heroesUsed .. "/" .. slotsInfo.heroSlots ..
        "  |  Quests: " .. slotsInfo.questsActive .. "/" .. slotsInfo.questSlots, MENU.x + 400, startY)

    -- Faction reputation section
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Faction Reputation", MENU.x + 20, startY + 40)

    local y = startY + 65
    local cardHeight = 70
    local cardWidth = MENU.width - 40

    for _, factionId in ipairs(GuildSystem.factionOrder) do
        local faction = GuildSystem.factions[factionId]
        local rep = GuildSystem.getReputation(gameData, factionId)
        local tier = GuildSystem.getReputationTier(gameData, factionId)

        -- Card background
        Components.drawPanel(MENU.x + 20, y, cardWidth, cardHeight, {
            color = Components.colors.panelLight,
            cornerRadius = 5
        })

        -- Faction color dot
        love.graphics.setColor(faction.color)
        love.graphics.circle("fill", MENU.x + 40, y + 25, 12)

        -- Faction name
        love.graphics.setColor(Components.colors.text)
        love.graphics.print(faction.name, MENU.x + 60, y + 10)

        -- Faction description
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(faction.description, MENU.x + 60, y + 30)

        -- Rival indicator
        if faction.rival then
            love.graphics.setColor(Components.colors.warning)
            love.graphics.print("Rival: " .. GuildSystem.factions[faction.rival].name, MENU.x + 60, y + 48)
        end

        -- Reputation value and tier
        love.graphics.setColor(tier.color)
        love.graphics.print(tier.name, MENU.x + 280, y + 10)

        -- Rep value (with sign)
        local repStr = rep >= 0 and ("+" .. rep) or tostring(rep)
        love.graphics.print("(" .. repStr .. ")", MENU.x + 380, y + 10)

        -- Reputation bar
        local repPercent = (rep + 100) / 200  -- -100 to 100 => 0 to 1
        Components.drawProgressBar(MENU.x + 280, y + 32, 200, 14, repPercent, {
            fgColor = tier.color,
            bgColor = {0.2, 0.2, 0.2}
        })

        -- Reward multiplier
        local multStr = tier.rewardMult == 0 and "No quests" or
            (tier.rewardMult < 1 and (math.floor(tier.rewardMult * 100) .. "% rewards") or
            (tier.rewardMult > 1 and ("+" .. math.floor((tier.rewardMult - 1) * 100) .. "% rewards") or "Normal"))
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(multStr, MENU.x + 500, y + 30)

        y = y + cardHeight + 8
    end

    -- Info text at bottom
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("Complete quests to gain reputation. Rival factions lose rep when you favor their enemies.",
        MENU.x + 20, y + 10, cardWidth, "center")
end

-- Handle click in guild menu
function GuildMenu.handleClick(x, y, gameData, QuestSystem, Quests, Heroes, GuildSystem)
    -- Hero detail popup handling (takes priority)
    if selectedHeroDetail then
        local popupW, popupH = 580, 520
        local popupX = (1280 - popupW) / 2
        local popupY = (720 - popupH) / 2

        -- Close button on popup
        if Components.isPointInRect(x, y, popupX + popupW - 40, popupY + 10, 30, 30) then
            selectedHeroDetail = nil
            equipDropdownSlot = nil
            equipDropdownItems = {}
            return nil
        end

        -- Bars/Graph toggle button
        if _toggleBtnPos and Components.isPointInRect(x, y, _toggleBtnPos.x, _toggleBtnPos.y, _toggleBtnPos.w, _toggleBtnPos.h) then
            -- Toggle between bars and graph mode
            if statDisplayMode == "bars" then
                statDisplayMode = "graph"
            else
                statDisplayMode = "bars"
            end
            return nil
        end

        -- Handle dropdown item selection first (if dropdown is open)
        if equipDropdownSlot and #equipDropdownItems > 0 then
            -- Find dropdown position
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

            -- Check if clicked inside dropdown
            if Components.isPointInRect(x, y, dropdownX, dropdownY, dropdownW, dropdownH) then
                -- Find which item was clicked
                local itemY = dropdownY + 22
                for i, availItem in ipairs(equipDropdownItems) do
                    if Components.isPointInRect(x, y, dropdownX + 4, itemY, dropdownW - 8, itemHeight - 2) then
                        -- Equip this item
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
                return nil  -- Clicked in dropdown but not on an item
            else
                -- Clicked outside dropdown - close it
                equipDropdownSlot = nil
                equipDropdownItems = {}
                -- Don't return, let click propagate to check other elements
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
                -- Check for button click (button is at right side of slot)
                local btnX = popupX + popupW - 55
                local btnY = slotInfo.y + 2
                local btnW, btnH = 24, 24

                if Components.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
                    if slotInfo.equipped then
                        -- Unequip button clicked
                        local success, msg = _EquipmentSystem.unequip(selectedHeroDetail, slotInfo.key, gameData)
                        equipDropdownSlot = nil
                        equipDropdownItems = {}
                        if success then
                            return "equip_changed", selectedHeroDetail.name .. " unequipped item"
                        end
                    else
                        -- Equip button clicked - open dropdown with available items
                        local available = _EquipmentSystem.getAvailableForSlot(gameData, slotInfo.key, selectedHeroDetail.rank)
                        if #available > 0 then
                            if #available == 1 then
                                -- Only one item, equip directly
                                local success, msg = _EquipmentSystem.equip(selectedHeroDetail, available[1].item.id, gameData)
                                if success then
                                    return "equip_changed", selectedHeroDetail.name .. " equipped " .. available[1].item.name
                                end
                            else
                                -- Multiple items, show dropdown
                                equipDropdownSlot = slotInfo.key
                                equipDropdownItems = available
                            end
                        end
                    end
                    return nil
                end
            end
        end

        -- Click inside popup (don't propagate)
        return nil
    end

    -- Close button
    if Components.isPointInRect(x, y, MENU.x + MENU.width - 40, MENU.y + 10, 30, 30) then
        GuildMenu.resetState()
        return "close"
    end

    -- Tab clicks
    local tabY = MENU.y + 50
    local clickedTab = Components.getClickedTab(TABS, x, y, MENU.x + 20, tabY, 100, 30)
    if clickedTab then
        currentTab = clickedTab
        if clickedTab ~= "quests" then
            selectedQuest = nil
            selectedHeroes = {}
        end
        return nil
    end

    local contentY = tabY + 50

    -- Roster tab - click on hero to view details or fire
    if currentTab == "roster" then
        local cardHeight = 100
        local cardWidth = MENU.width - 40
        local heroY = contentY + 25

        for i, hero in ipairs(gameData.heroes) do
            if heroY + cardHeight > MENU.y + MENU.height - 20 then break end

            -- Check Fire button click first (only for idle heroes)
            if hero.status == "idle" then
                local fireBtnX = MENU.x + 550
                local fireBtnY = heroY + 35
                local fireBtnW = 50
                local fireBtnH = 24

                if Components.isPointInRect(x, y, fireBtnX, fireBtnY, fireBtnW, fireBtnH) then
                    if heroToFire == hero.id then
                        -- Confirm fire - remove hero from roster
                        for j, h in ipairs(gameData.heroes) do
                            if h.id == hero.id then
                                -- Unequip all equipment first (return to inventory)
                                if hero.equipment then
                                    for slot, itemId in pairs(hero.equipment) do
                                        if itemId and _gameData then
                                            _gameData.inventory.equipment[itemId] = (_gameData.inventory.equipment[itemId] or 0) + 1
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
                        -- First click - set confirmation state
                        heroToFire = hero.id
                    end
                    return nil
                end
            end

            -- Click elsewhere on card opens details (only if not on active quest)
            if Components.isPointInRect(x, y, MENU.x + 20, heroY, cardWidth, cardHeight) then
                -- Reset fire confirmation if clicking elsewhere
                heroToFire = nil
                if hero.status == "idle" or hero.status == "resting" then
                    selectedHeroDetail = hero
                end
                return nil
            end
            heroY = heroY + cardHeight + 5
        end

        -- Clicking anywhere else resets fire confirmation
        heroToFire = nil
    end

    if currentTab == "quests" then
        -- Quest list clicks
        local questListWidth = 350
        local questY = contentY + 25
        for i, quest in ipairs(gameData.availableQuests) do
            if Components.isPointInRect(x, y, MENU.x + 20, questY, questListWidth - 10, 65) then
                selectedQuest = quest
                selectedHeroes = {}
                return nil
            end
            questY = questY + 70
        end

        -- Party selection clicks
        if selectedQuest then
            local partyX = MENU.x + questListWidth + 20
            local partyWidth = MENU.width - questListWidth - 50

            -- Clear button
            if Components.isPointInRect(x, y, partyX + partyWidth - 50, contentY - 5, 50, 22) then
                selectedHeroes = {}
                return nil
            end

            -- Hero selection - fixed position below pentagon chart
            -- This matches the drawing code: math.max(synergyY + 8, startY + 210)
            local heroListStartY = contentY + 210

            -- Count currently selected heroes
            local currentCount = 0
            for _, isSelected in pairs(selectedHeroes) do
                if isSelected then currentCount = currentCount + 1 end
            end
            local maxHeroes = selectedQuest.maxHeroes or 6

            local heroY = heroListStartY
            for i, hero in ipairs(gameData.heroes) do
                if hero.status == "idle" then
                    if Components.isPointInRect(x, y, partyX, heroY, partyWidth, 34) then
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
                    heroY = heroY + 38
                end
            end

            -- Send Party button
            local btnY = MENU.y + MENU.height - 55
            if Components.isPointInRect(x, y, partyX, btnY, partyWidth, 35) then
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
                        return "assigned", message
                    else
                        return "error", message
                    end
                end
            end
        end
    end

    return nil
end

return GuildMenu
