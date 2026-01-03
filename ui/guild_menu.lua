-- Guild Menu Module
-- UI for managing heroes and assigning quests

local Components = require("ui.components")

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

-- Reset selection state
function GuildMenu.resetState()
    currentTab = "roster"
    selectedQuest = nil
    selectedHeroes = {}
    selectedHeroDetail = nil
    equipDropdownSlot = nil
    equipDropdownItems = {}
end

-- Store module references for use in local functions
local _Equipment = nil
local _EquipmentSystem = nil
local _equipSlotPositions = {}
local _gameData = nil

-- Draw the guild menu
function GuildMenu.draw(gameData, QuestSystem, Quests, Heroes, TimeSystem, GuildSystem, Equipment, EquipmentSystem)
    -- Store references for popup
    _Equipment = Equipment
    _EquipmentSystem = EquipmentSystem
    _gameData = gameData
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
end

-- Draw hero detail popup
function drawHeroDetailPopup(hero, Heroes)
    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Popup dimensions (increased height for equipment)
    local popupW, popupH = 450, 500
    local popupX = (1280 - popupW) / 2
    local popupY = (720 - popupH) / 2

    -- Popup background
    Components.drawPanel(popupX, popupY, popupW, popupH)

    -- Close button
    Components.drawCloseButton(popupX + popupW - 40, popupY + 10)

    -- Hero name and class
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf(hero.name, popupX, popupY + 15, popupW, "center")

    -- Rank badge
    Components.drawRankBadge(hero.rank, popupX + 20, popupY + 50, 40)

    -- Race, Class and level
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print(hero.race or "Human", popupX + 70, popupY + 50)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(hero.class .. " - Level " .. hero.level, popupX + 70, popupY + 70)

    -- Power
    love.graphics.setColor(Components.colors.warning)
    love.graphics.print("Power: " .. hero.power, popupX + 250, popupY + 50)

    -- XP bar
    local xpPercent = hero.xp / hero.xpToLevel
    Components.drawProgressBar(popupX + 200, popupY + 72, 150, 16, xpPercent, {
        fgColor = {0.5, 0.3, 0.7},
        text = hero.xp .. "/" .. hero.xpToLevel .. " XP"
    })

    -- Stats section
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("STATS", popupX + 20, popupY + 110)

    local statY = popupY + 135
    local statData = {
        {name = "Strength", key = "str", color = {0.8, 0.4, 0.4}},
        {name = "Dexterity", key = "dex", color = {0.4, 0.8, 0.4}},
        {name = "Intelligence", key = "int", color = {0.4, 0.4, 0.8}},
        {name = "Vitality", key = "vit", color = {0.8, 0.6, 0.3}},
        {name = "Luck", key = "luck", color = {0.7, 0.5, 0.8}}
    }

    for _, stat in ipairs(statData) do
        local value = hero.stats[stat.key] or 0
        local equipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, stat.key) or 0
        local totalValue = value + equipBonus

        love.graphics.setColor(stat.color)
        love.graphics.print(stat.name, popupX + 30, statY)

        -- Stat bar (max 20, but show total including equipment)
        local barW = 150
        local barH = 14
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", popupX + 150, statY + 2, barW, barH)
        -- Base stat portion
        love.graphics.setColor(stat.color[1] * 0.7, stat.color[2] * 0.7, stat.color[3] * 0.7)
        love.graphics.rectangle("fill", popupX + 150, statY + 2, barW * math.min(value / 20, 1), barH)
        -- Equipment bonus portion (brighter)
        if equipBonus > 0 then
            love.graphics.setColor(stat.color)
            love.graphics.rectangle("fill", popupX + 150 + barW * (value / 20), statY + 2,
                barW * math.min(equipBonus / 20, 1 - value / 20), barH)
        end

        -- Show value with bonus
        love.graphics.setColor(Components.colors.text)
        if equipBonus > 0 then
            love.graphics.print(value, popupX + 310, statY)
            love.graphics.setColor(Components.colors.success)
            love.graphics.print("+" .. equipBonus, popupX + 335, statY)
        else
            love.graphics.print(value, popupX + 310, statY)
        end

        statY = statY + 28
    end

    -- Status section
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("STATUS", popupX + 20, statY + 10)

    statY = statY + 35
    love.graphics.setColor(Components.colors.textDim)

    -- Current status
    local statusColors = {
        idle = Components.colors.success,
        resting = {0.6, 0.4, 0.7},
        traveling = Components.colors.warning,
        questing = Components.colors.warning,
        returning = {0.6, 0.9, 0.6}
    }
    love.graphics.setColor(statusColors[hero.status] or Components.colors.text)
    love.graphics.print("Status: " .. (hero.status or "unknown"):upper(), popupX + 30, statY)

    -- Failure count
    local failures = hero.failureCount or 0
    local failColor = failures >= 2 and Components.colors.danger or Components.colors.textDim
    love.graphics.setColor(failColor)
    love.graphics.print("Failures: " .. failures .. "/3", popupX + 200, statY)

    -- Equipment section
    statY = statY + 30
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("EQUIPMENT", popupX + 20, statY)

    statY = statY + 25
    local equipSlots = {
        {key = "weapon", label = "Weapon", icon = "[W]"},
        {key = "armor", label = "Armor", icon = "[A]"},
        {key = "accessory", label = "Accessory", icon = "[C]"}
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

    -- Status summary
    local idleCount = 0
    local busyCount = 0
    local restingCount = 0
    for _, hero in ipairs(gameData.heroes) do
        if hero.status == "idle" then idleCount = idleCount + 1
        elseif hero.status == "resting" then restingCount = restingCount + 1
        else busyCount = busyCount + 1
        end
    end

    love.graphics.setColor(Components.colors.success)
    love.graphics.print("Idle: " .. idleCount, MENU.x + 200, startY)
    love.graphics.setColor(Components.colors.warning)
    love.graphics.print("Busy: " .. busyCount, MENU.x + 280, startY)
    love.graphics.setColor(0.6, 0.4, 0.7)
    love.graphics.print("Resting: " .. restingCount, MENU.x + 360, startY)

    if #gameData.heroes == 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("No heroes yet! Visit the Tavern to hire some.",
            MENU.x, startY + 50, MENU.width, "center")
        return
    end

    local cardHeight = 55
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

        -- Rank badge
        Components.drawRankBadge(hero.rank, MENU.x + 30, y + 12, 30)

        -- Hero info
        love.graphics.setColor(Components.colors.text)
        love.graphics.print(hero.name, MENU.x + 70, y + 8)

        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print((hero.race or "Human") .. " " .. hero.class .. " Lv." .. hero.level .. " | Power: " .. hero.power, MENU.x + 70, y + 28)

        -- Status with progress
        local statusX = MENU.x + 350
        if hero.status == "idle" then
            love.graphics.setColor(Components.colors.success)
            love.graphics.print("AVAILABLE", statusX, y + 18)
        elseif hero.status == "resting" then
            love.graphics.setColor(0.6, 0.4, 0.7)
            love.graphics.print("RESTING", statusX, y + 8)
            -- Rest progress bar
            local restPercent = Heroes.getRestPercent(hero)
            local timeLeft = math.max(0, (hero.restTimeMax or 0) - (hero.restProgress or 0))
            Components.drawProgressBar(statusX, y + 28, 150, 14, restPercent, {
                fgColor = {0.6, 0.4, 0.7},
                text = TimeSystem.formatDuration(timeLeft)
            })
        else
            -- On quest
            love.graphics.setColor(Components.colors.warning)
            local phaseText = (hero.questPhase or ""):upper()
            love.graphics.print(phaseText, statusX, y + 8)
            -- Quest progress bar
            local phaseMax = hero.questPhaseMax or 1
            local progress = (hero.questProgress or 0) / phaseMax
            local timeLeft = math.max(0, phaseMax - (hero.questProgress or 0))
            Components.drawProgressBar(statusX, y + 28, 150, 14, progress, {
                fgColor = Components.colors.warning,
                text = TimeSystem.formatDuration(timeLeft)
            })
        end

        -- XP bar
        local xpPercent = hero.xp / hero.xpToLevel
        Components.drawProgressBar(MENU.x + cardWidth - 80, y + 18, 70, 18, xpPercent, {
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

            -- Required stat indicator
            local statNames = {str = "STR", dex = "DEX", int = "INT"}
            local statColors = {str = {0.8, 0.4, 0.4}, dex = {0.4, 0.8, 0.4}, int = {0.4, 0.4, 0.8}}
            local reqStat = quest.requiredStat or "str"
            love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
            love.graphics.print("Needs: " .. (statNames[reqStat] or "STR"), MENU.x + 65, y + 26)

            love.graphics.setColor(Components.colors.textDim)
            local totalTime = Quests.getTotalTime(quest)
            love.graphics.print("Time: " .. TimeSystem.formatDuration(totalTime), MENU.x + 160, y + 26)

            love.graphics.setColor(Components.colors.gold)
            love.graphics.print(quest.reward .. "g", MENU.x + questListWidth - 70, y + 8)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print("+" .. quest.xpReward .. " XP", MENU.x + questListWidth - 70, y + 26)

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

        -- Show hero count AND power
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print(string.format("Heroes: %d selected", #partyHeroes), partyX, startY + 18)

        local powerColor = partyPower >= selectedQuest.requiredPower and Components.colors.success or Components.colors.danger
        love.graphics.setColor(powerColor)
        love.graphics.print(string.format("Power: %d / %d needed", partyPower, selectedQuest.requiredPower),
            partyX, startY + 34)

        -- Party stat total for required stat (base + equipment)
        local reqStat = selectedQuest.requiredStat or "str"
        local statNames = {str = "STR", dex = "DEX", int = "INT"}
        local statColors = {str = {0.8, 0.4, 0.4}, dex = {0.4, 0.8, 0.4}, int = {0.4, 0.4, 0.8}}
        local totalReqStat = 0
        local totalEquipBonus = 0
        for _, hero in ipairs(partyHeroes) do
            totalReqStat = totalReqStat + (hero.stats[reqStat] or 0)
            if _EquipmentSystem then
                totalEquipBonus = totalEquipBonus + _EquipmentSystem.getStatBonus(hero, reqStat)
            end
        end

        love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
        if totalEquipBonus > 0 then
            love.graphics.print(string.format("Party %s: %d", statNames[reqStat] or "STR", totalReqStat), partyX + 150, startY + 34)
            love.graphics.setColor(Components.colors.success)
            love.graphics.print(string.format("+%d", totalEquipBonus), partyX + 260, startY + 34)
        else
            love.graphics.print(string.format("Party %s: %d", statNames[reqStat] or "STR", totalReqStat), partyX + 150, startY + 34)
        end

        -- Success chance (color coded, includes equipment bonuses)
        local successY = startY + 52
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

        -- Active synergies display
        local synergyY = successY + 18
        if #partyHeroes > 0 then
            local synergyBonuses = Quests.getSynergyBonuses(partyHeroes, selectedQuest)
            local activeSynergies = synergyBonuses.activeSynergies or {}

            if #activeSynergies > 0 then
                love.graphics.setColor(0.6, 0.5, 0.8)  -- Purple for synergies
                love.graphics.print("Synergies:", partyX, synergyY)

                local synX = partyX + 70
                local maxDisplay = 3
                for i, synergy in ipairs(activeSynergies) do
                    if i > maxDisplay then
                        love.graphics.setColor(Components.colors.textDim)
                        love.graphics.print("+" .. (#activeSynergies - maxDisplay) .. " more", synX, synergyY)
                        break
                    end
                    -- Synergy name with bonus indicator
                    love.graphics.setColor(0.7, 0.6, 0.9)
                    love.graphics.print(synergy.name, synX, synergyY)
                    synX = synX + love.graphics.getFont():getWidth(synergy.name) + 8
                end
                synergyY = synergyY + 16
            end
        end

        -- Death warning for A/S rank combat quests
        local deathWarningOffset = synergyY - (successY + 18)
        if selectedQuest.combat and (selectedQuest.rank == "A" or selectedQuest.rank == "S") then
            deathWarningOffset = deathWarningOffset + 18
            -- Check if party has a cleric for protection
            local hasCleric = Quests.partyHasCleric(partyHeroes)
            if hasCleric then
                love.graphics.setColor(0.3, 0.7, 0.3)  -- Green - protected
                love.graphics.print("Cleric provides death protection!", partyX, synergyY)
            else
                love.graphics.setColor(0.9, 0.3, 0.3)  -- Red - danger
                local deathChance = selectedQuest.rank == "S" and "50%" or "30%"
                love.graphics.print("DANGER: " .. deathChance .. " death on fail! Bring a Cleric!", partyX, synergyY)
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

        -- Available heroes list
        local y = math.max(synergyY + 8, startY + 90)
        for i, hero in ipairs(gameData.heroes) do
            if y + 32 > MENU.y + MENU.height - 60 then break end

            if hero.status == "idle" then
                local isSelected = selectedHeroes[hero.id] == true

                local bgColor = isSelected and {0.3, 0.5, 0.3} or Components.colors.panelLight
                Components.drawPanel(partyX, y, partyWidth, 28, {
                    color = bgColor,
                    cornerRadius = 3
                })

                Components.drawRankBadge(hero.rank, partyX + 5, y + 2, 24)
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(hero.name, partyX + 35, y + 6)
                -- Show race and class
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.print((hero.race or "Human") .. " " .. hero.class, partyX + 150, y + 6)
                -- Show hero's relevant stat for this quest (with equipment bonus)
                local heroStat = hero.stats[reqStat] or 0
                local heroEquipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, reqStat) or 0
                love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
                if heroEquipBonus > 0 then
                    love.graphics.printf(statNames[reqStat] .. ":" .. heroStat, partyX + partyWidth - 70, y + 6, 35, "right")
                    love.graphics.setColor(Components.colors.success)
                    love.graphics.printf("+" .. heroEquipBonus, partyX + partyWidth - 30, y + 6, 25, "right")
                else
                    love.graphics.printf(statNames[reqStat] .. ":" .. heroStat, partyX + partyWidth - 50, y + 6, 45, "right")
                end

                y = y + 32
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

        -- Assigned heroes
        local heroNames = {}
        for _, heroId in ipairs(quest.assignedHeroes) do
            for _, hero in ipairs(gameData.heroes) do
                if hero.id == heroId then
                    table.insert(heroNames, hero.name)
                    break
                end
            end
        end
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Party: " .. table.concat(heroNames, ", "), MENU.x + 70, y + 55)

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
        local popupW, popupH = 450, 500
        local popupX = (1280 - popupW) / 2
        local popupY = (720 - popupH) / 2

        -- Close button on popup
        if Components.isPointInRect(x, y, popupX + popupW - 40, popupY + 10, 30, 30) then
            selectedHeroDetail = nil
            equipDropdownSlot = nil
            equipDropdownItems = {}
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

    -- Roster tab - click on hero to view details
    if currentTab == "roster" then
        local cardHeight = 55
        local cardWidth = MENU.width - 40
        local heroY = contentY + 25

        for i, hero in ipairs(gameData.heroes) do
            if heroY + cardHeight > MENU.y + MENU.height - 20 then break end

            if Components.isPointInRect(x, y, MENU.x + 20, heroY, cardWidth, cardHeight) then
                -- Only allow viewing details if not on active quest
                if hero.status == "idle" or hero.status == "resting" then
                    selectedHeroDetail = hero
                end
                return nil
            end
            heroY = heroY + cardHeight + 5
        end
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

            -- Hero selection - calculate dynamic Y position based on content
            -- Start after base info (52) + synergies + death warning + possible rewards
            local heroListStartY = contentY + 90  -- Base minimum position

            -- Account for selected heroes having synergies
            local partyHeroes = {}
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

            -- Adjust Y based on synergies display
            if #partyHeroes > 0 then
                local synergyBonuses = Quests.getSynergyBonuses(partyHeroes, selectedQuest)
                local activeSynergies = synergyBonuses.activeSynergies or {}
                if #activeSynergies > 0 then
                    heroListStartY = heroListStartY + 16
                end
            end

            -- Adjust for death warning
            if selectedQuest.combat and (selectedQuest.rank == "A" or selectedQuest.rank == "S") then
                heroListStartY = heroListStartY + 18
            end

            -- Adjust for possible rewards
            if selectedQuest.possibleRewards then
                local rewardCount = math.min(#selectedQuest.possibleRewards, 3)
                heroListStartY = heroListStartY + 18 + (rewardCount * 14)
            end

            local heroY = heroListStartY
            for i, hero in ipairs(gameData.heroes) do
                if hero.status == "idle" then
                    if Components.isPointInRect(x, y, partyX, heroY, partyWidth, 28) then
                        if selectedHeroes[hero.id] then
                            selectedHeroes[hero.id] = nil
                        else
                            selectedHeroes[hero.id] = true
                        end
                        return nil
                    end
                    heroY = heroY + 32
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
