-- ui/guild_menu/roster_tab.lua
-- Roster tab - Hero display and management

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")
local PartySystem = require("systems.party_system")

local RosterTab = {}

-- Store module references for use in equipment UI
local _Equipment = nil
local _EquipmentSystem = nil
local _gameData = nil
local _equipSlotPositions = {}
local _toggleBtnPos = nil

-- Set equipment system references (called before draw)
function RosterTab.setReferences(Equipment, EquipmentSystem, gameData)
    _Equipment = Equipment
    _EquipmentSystem = EquipmentSystem
    _gameData = gameData
end

-- Draw individual hero card in roster list
local function drawRosterHeroCard(hero, x, y, cardWidth, cardHeight, Heroes, TimeSystem, indented, State)
    local indent = indented and 20 or 0
    local isSelected = State.selectedHeroDetail and State.selectedHeroDetail.id == hero.id

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

            if State.heroToFire == hero.id then
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
local function drawHeroDetailPanel(hero, panelX, panelY, panelW, panelH, Heroes, State)
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

    local barsSelected = State.statDisplayMode == "bars"
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

    if State.statDisplayMode == "bars" then
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

-- Main roster tab draw function
function RosterTab.draw(gameData, startY, height, Heroes, TimeSystem, GuildSystem, State, Helpers)
    local MENU_DESIGN_WIDTH = Helpers.MENU_DESIGN_WIDTH
    
    -- Layout: 60-40 split (60% hero list, 40% detail panel)
    local detailPanelWidth = State.selectedHeroDetail and math.floor(MENU_DESIGN_WIDTH * 0.4) or 0
    local listWidth = MENU_DESIGN_WIDTH - 40 - detailPanelWidth - (State.selectedHeroDetail and 10 or 0)

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

    local cardHeight = 70
    local partyHeaderHeight = 40
    local scrollbarWidth = 12

    -- Calculate content dimensions
    local listStartY = startY + 25
    local listHeight = height - (listStartY - startY)
    local listX = 20
    local actualListWidth = State.selectedHeroDetail and math.floor(MENU_DESIGN_WIDTH * 0.6) - 30 or (MENU_DESIGN_WIDTH - 40)
    local cardWidth = actualListWidth - 30

    -- Build content layout to calculate total height
    PartySystem.initGameData(gameData)
    local contentItems = {}

    -- Add formed parties
    if gameData.parties and #gameData.parties > 0 then
        for _, party in ipairs(gameData.parties) do
            local members = PartySystem.getPartyMembers(party, gameData)
            local isExpanded = State.expandedParties[party.id]

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
    State.rosterListBounds = {
        x = listX,
        y = listStartY,
        w = actualListWidth,
        h = listHeight,
        maxScroll = maxScroll
    }

    -- Clamp scroll offset
    State.rosterScrollOffset = math.max(0, math.min(State.rosterScrollOffset, maxScroll))

    -- Set up scissor for clipping
    Helpers.setScissorDesign(State, listX, listStartY, actualListWidth, listHeight)

    -- Draw content with scroll offset
    local y = listStartY - State.rosterScrollOffset
    for _, item in ipairs(contentItems) do
        local itemBottom = y + item.height

        -- Only draw if visible
        if itemBottom >= listStartY and y < listStartY + listHeight then
            if item.type == "party_header" then
                local party = item.party
                local members = item.members
                local isExpanded = State.expandedParties[party.id]

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

                -- Party synergy (if formed)
                if not State.selectedHeroDetail and party.isFormed and #members >= 4 then
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
                drawRosterHeroCard(item.hero, listX, y, cardWidth, cardHeight, Heroes, TimeSystem, true, State)

            elseif item.type == "section_header" then
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(item.text, listX, y + 5)

            elseif item.type == "hero" then
                drawRosterHeroCard(item.hero, listX, y, cardWidth, cardHeight, Heroes, TimeSystem, false, State)
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
        local thumbY = listStartY + (State.rosterScrollOffset / maxScroll) * (scrollbarHeight - thumbHeight)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX + 2, thumbY, scrollbarWidth - 4, thumbHeight, 3, 3)
    end

    -- Draw detail panel on right side if a hero is selected (40% of width)
    if State.selectedHeroDetail then
        local panelW = math.floor(MENU_DESIGN_WIDTH * 0.4) - 10
        local panelX = MENU_DESIGN_WIDTH - panelW - 10
        local panelY = listStartY
        local panelH = listHeight
        drawHeroDetailPanel(State.selectedHeroDetail, panelX, panelY, panelW, panelH, Heroes, State)
    end
end

-- Get equipment slot positions for click handling
function RosterTab.getEquipSlotPositions()
    return _equipSlotPositions
end

-- Get toggle button position for click handling
function RosterTab.getToggleButtonPos()
    return _toggleBtnPos
end

return RosterTab
