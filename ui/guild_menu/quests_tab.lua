-- ui/guild_menu/quests_tab.lua
-- Quest assignment tab - Quest selection and party formation

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")
local PartySystem = require("systems.party_system")
local UIAssets = require("ui.ui_assets")

local QuestsTab = {}

-- Store references for equipment system
local _EquipmentSystem = nil

-- Set equipment system references (called before draw)
function QuestsTab.setReferences(EquipmentSystem)
    _EquipmentSystem = EquipmentSystem
end

-- Main quests tab draw function
function QuestsTab.draw(gameData, startY, height, QuestSystem, Quests, TimeSystem, GuildSystem, State, Helpers)
    local MENU_DESIGN_WIDTH = Helpers.MENU_DESIGN_WIDTH
    
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
            if y + 70 > MENU_DESIGN_WIDTH - 20 then break end

            local isSelected = State.selectedQuest and State.selectedQuest.id == quest.id

            -- Quest card with paper texture
            if isSelected then
                UIAssets.drawPaper(20, y, questListWidth - 10, 65, {
                    special = false,
                    color = {0.8, 0.9, 0.95, 1},  -- Light blue tint for selected
                    alpha = 0.9
                })
            else
                UIAssets.drawPaper(20, y, questListWidth - 10, 65, {
                    special = false,
                    color = {0.98, 0.96, 0.92, 1},  -- Warm paper color
                    alpha = 0.85
                })
            end

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

    if State.selectedQuest then
        love.graphics.setColor(Components.colors.text)
        love.graphics.print("Party for: " .. State.selectedQuest.name, partyX, startY)

        -- Mode toggle buttons (Heroes / Parties)
        local toggleY = startY - 5
        local toggleBtnWidth = 80
        local heroesActive = State.questSelectionMode == "heroes"
        local partiesActive = State.questSelectionMode == "parties"

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
        for heroId, isSelected in pairs(State.selectedHeroes) do
            if isSelected == true then
                for _, hero in ipairs(gameData.heroes) do
                    if hero.id == heroId and hero.status == "idle" then
                        table.insert(partyHeroes, hero)
                        break
                    end
                end
            end
        end

        -- Compact header: hero count + stats on same line
        local maxHeroes = State.selectedQuest.maxHeroes or 6
        local heroCountColor = #partyHeroes >= maxHeroes and Components.colors.warning or Components.colors.textDim
        love.graphics.setColor(heroCountColor)
        love.graphics.print(string.format("%d/%d", #partyHeroes, maxHeroes), partyX, startY + 18)
        
        -- Party stat totals for required stats (primary + secondary)
        local reqStat = State.selectedQuest.requiredStat or "str"
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
        if State.selectedQuest.secondaryStats then
            for _, secStat in ipairs(State.selectedQuest.secondaryStats) do
                table.insert(allReqStats, secStat)
            end
        end

        -- Display stats inline next to hero count (more compact)
        local statDisplayX = partyX + 40
        local statDisplayY = startY + 18
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("│", statDisplayX - 5, statDisplayY)

        local xOffset = 0
        for i, statInfo in ipairs(allReqStats) do
            if i > 2 then break end  -- Limit to 2 stats displayed for compactness

            local stat = statInfo.stat
            local totalStat = 0
            local totalEquip = 0
            for _, hero in ipairs(partyHeroes) do
                totalStat = totalStat + (hero.stats[stat] or 0)
                if _EquipmentSystem then
                    totalEquip = totalEquip + _EquipmentSystem.getStatBonus(hero, stat)
                end
            end

            -- Compact stat display
            local label = statNames[stat] or "?"
            love.graphics.setColor(statColors[stat] or Components.colors.textDim)
            love.graphics.print(label .. ":" .. totalStat, statDisplayX + xOffset, statDisplayY)

            if totalEquip > 0 then
                love.graphics.setColor(Components.colors.success)
                love.graphics.print("+" .. totalEquip, statDisplayX + xOffset + 46, statDisplayY)
                xOffset = xOffset + 70
            else
                xOffset = xOffset + 50
            end
        end

        -- Pentagon stat comparison chart (quest requirements vs party stats)
        local pentagonX = partyX + partyWidth - 120
        local pentagonY = startY + 110
        local pentagonRadius = 50

        -- Get quest requirements and party stats (summed across all heroes)
        local questReqs = Helpers.getQuestStatRequirements(State.selectedQuest, Quests)
        local partyStats = Helpers.getPartyStats(partyHeroes, _EquipmentSystem)

        -- Fixed max scale that allows pentagon to GROW as you add heroes
        local maxStatForChart = 30  -- Allows room to show combined stats

        -- Draw pentagon: quest requirements as outline, party stats as filled
        if #partyHeroes > 0 then
            -- Party stats filled (green), quest requirements as white outline
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

        -- Success chance (color coded, includes equipment bonuses and party trait bonuses)
        local successY = startY + 36
        if #partyHeroes > 0 then
            local chance = Quests.calculateSuccessChance(State.selectedQuest, partyHeroes, _EquipmentSystem, gameData)
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
            love.graphics.print("Select heroes...", partyX, successY)
        end

        -- Active synergies display with hover tooltips (more compact)
        local synergyY = successY + 16
        State.hoveredSynergy = nil  -- Reset hover state each frame
        State.synergyHelpHovered = false

        if #partyHeroes > 0 then
            local synergyBonuses = Quests.getSynergyBonuses(partyHeroes, State.selectedQuest)
            local activeSynergies = synergyBonuses.activeSynergies or {}

            -- Draw synergy label with help icon
            love.graphics.setColor(Components.colors.synergy)
            love.graphics.print("Synergies:", partyX, synergyY)

            -- Help icon (?)
            local helpX = partyX + 60
            Components.drawHelpIcon(helpX, synergyY - 2, 16)
            if Components.isPointInRect(State.mouseX, State.mouseY, helpX, synergyY - 2, 16, 16) then
                State.synergyHelpHovered = true
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
                    local isHovered = Components.isPointInRect(State.mouseX, State.mouseY, synX, synergyY, nameWidth, 16)

                    if isHovered then
                        love.graphics.setColor(1, 1, 1)  -- Bright white on hover
                        State.hoveredSynergy = synergy
                        State.hoveredSynergyPos = {x = synX, y = synergyY + 20}
                    else
                        love.graphics.setColor(Components.colors.synergyLight)
                    end
                    love.graphics.print(synergy.name, synX, synergyY)

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
        if State.selectedQuest.combat and (State.selectedQuest.rank == "A" or State.selectedQuest.rank == "S") then
            -- Check if party has a priest for protection
            local hasPriest = Quests.partyHasCleric(partyHeroes)
            if hasPriest then
                love.graphics.setColor(0.3, 0.7, 0.3)  -- Green - protected
                love.graphics.print("Priest provides death protection!", partyX, synergyY)
            else
                love.graphics.setColor(0.9, 0.3, 0.3)  -- Red - danger
                local deathChance = State.selectedQuest.rank == "S" and "50%" or "30%"
                love.graphics.print("DANGER: " .. deathChance .. " death on fail! Bring a Priest!", partyX, synergyY)
            end
            synergyY = synergyY + 16
        end

        -- Possible rewards display
        if State.selectedQuest.possibleRewards and #State.selectedQuest.possibleRewards > 0 then
            love.graphics.setColor(Components.colors.text)
            love.graphics.print("Possible Drops:", partyX, synergyY + 2)
            synergyY = synergyY + 16
            for _, reward in ipairs(State.selectedQuest.possibleRewards) do
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
        local listHeight = Helpers.MENU_DESIGN_HEIGHT - 65 - listStartY  -- Available height for list
        local scrollbarWidth = 12

        if State.questSelectionMode == "heroes" then
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
            State.questHeroListBounds = {
                x = partyX,
                y = listStartY,
                w = partyWidth,
                h = listHeight,
                maxScroll = maxScroll
            }

            -- Clamp scroll offset
            State.questHeroScrollOffset = math.max(0, math.min(State.questHeroScrollOffset, maxScroll))

            -- Set up scissor for clipping
            Helpers.setScissorDesign(State, partyX, listStartY, partyWidth, listHeight)

            -- Draw heroes with scroll offset
            local y = listStartY - State.questHeroScrollOffset
            for i, hero in ipairs(gameData.heroes) do
                if hero.status == "idle" then
                    -- Only draw if visible
                    if y + heroCardHeight >= listStartY and y < listStartY + listHeight then
                        local isSelected = State.selectedHeroes[hero.id] == true

                        -- Hero card with paper texture
                        if isSelected then
                            UIAssets.drawPaper(partyX, y, partyWidth - scrollbarWidth - 5, heroCardHeight, {
                                special = false,
                                color = {0.7, 0.95, 0.75, 1},  -- Light green for selected
                                alpha = 0.9
                            })
                        else
                            UIAssets.drawPaper(partyX, y, partyWidth - scrollbarWidth - 5, heroCardHeight, {
                                special = false,
                                color = {0.96, 0.94, 0.90, 1},
                                alpha = 0.85
                            })
                        end

                        -- Larger sprite portrait
                        SpriteSystem.drawCentered(hero, partyX + 40, y + heroCardHeight / 2, 140, 140, "Idle")

                        -- Rank badge
                        Components.drawRankBadge(hero.rank, partyX + 75, y + 8, 24)

                        -- Hero name
                        love.graphics.setColor(Components.colors.text)
                        love.graphics.print(hero.name, partyX + 105, y + 8)

                        -- Race, class and level
                        love.graphics.setColor(Components.colors.textDim)
                        love.graphics.print((hero.race or "Human") .. " " .. hero.class .. " Lv." .. hero.level, partyX + 105, y + 26)

                        -- Show hero's relevant stat for this quest
                        local heroStat = hero.stats[reqStat] or 0
                        local heroEquipBonus = _EquipmentSystem and _EquipmentSystem.getStatBonus(hero, reqStat) or 0
                        love.graphics.setColor(statColors[reqStat] or Components.colors.textDim)
                        if heroEquipBonus > 0 then
                            love.graphics.print(statNames[reqStat] .. ":" .. heroStat .. "(+" .. heroEquipBonus .. ")", partyX + 105, y + 44)
                        else
                            love.graphics.print(statNames[reqStat] .. ":" .. heroStat, partyX + 105, y + 44)
                        end

                        -- Party indicator
                        if hero.partyId then
                            local party = PartySystem.getParty(hero.partyId, gameData)
                            if party then
                                love.graphics.setColor(0.6, 0.5, 0.8)
                                love.graphics.print("[" .. (party.name or "Party") .. "]", partyX + partyWidth - 130, y + 8)
                            end
                        end

                        -- Selection indicator
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
                local thumbY = listStartY + (State.questHeroScrollOffset / maxScroll) * (scrollbarHeight - thumbHeight)
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

            State.questHeroListBounds = {
                x = partyX,
                y = listStartY,
                w = partyWidth,
                h = listHeight,
                maxScroll = maxScroll
            }

            State.questHeroScrollOffset = math.max(0, math.min(State.questHeroScrollOffset, maxScroll))

            love.graphics.setScissor(partyX, listStartY, partyWidth, listHeight)

            -- Hint about individual selection
            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.printf("Tip: Use 'Heroes' mode to select individuals", partyX, listStartY - 15, partyWidth - 10, "center")

            if #availableParties == 0 then
                love.graphics.setColor(Components.colors.textDim)
                love.graphics.printf("No formed parties available.\nForm a party by completing 3 quests\nwith 4 unique-class heroes!\n\nSwitch to 'Heroes' to select individually.", partyX, listStartY + 20, partyWidth - scrollbarWidth - 10, "center")
            else
                local y = listStartY - State.questHeroScrollOffset
                for i, partyData in ipairs(availableParties) do
                    if y + partyCardHeight >= listStartY and y < listStartY + listHeight then
                        local party = partyData.party
                        local members = partyData.members
                        local isSelected = State.selectedPartyId == party.id

                        -- Party card with paper texture
                        if isSelected then
                            UIAssets.drawPaper(partyX, y, partyWidth - scrollbarWidth - 5, partyCardHeight, {
                                special = false,
                                color = {0.7, 0.95, 0.75, 1},  -- Light green for selected
                                alpha = 0.9
                            })
                        else
                            UIAssets.drawPaper(partyX, y, partyWidth - scrollbarWidth - 5, partyCardHeight, {
                                special = false,
                                color = {0.96, 0.94, 0.90, 1},
                                alpha = 0.85
                            })
                        end

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
                local thumbY = listStartY + (State.questHeroScrollOffset / maxScroll) * (scrollbarHeight - thumbHeight)
                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.rectangle("fill", scrollbarX + 2, thumbY, scrollbarWidth - 4, thumbHeight, 3, 3)
            end
        end

        -- Send Party button
        local btnY = Helpers.MENU_DESIGN_HEIGHT - 55
        local hasQuestSlot = not GuildSystem or GuildSystem.canStartQuest(gameData)
        local canSend = #partyHeroes > 0 and hasQuestSlot

        local btnText = hasQuestSlot and "Send Party" or "Quest Slots Full"
        Components.drawButton(btnText, partyX, btnY, partyWidth, 35, {
            disabled = not canSend,
            color = canSend and Components.colors.buttonActive or Components.colors.buttonDisabled
        })

        -- Clear button
        Components.drawButton("Clear", partyX + partyWidth - 230, startY - 5, 50, 22, {
            color = Components.colors.button
        })
    else
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("Select a quest", partyX, startY + 50, partyWidth, "center")
    end
end

return QuestsTab
