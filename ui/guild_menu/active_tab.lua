-- ui/guild_menu/active_tab.lua
-- Active quests tracking tab - Show and manage quests in progress

local Components = require("ui.components")
local SpriteSystem = require("systems.sprite_system")

local ActiveTab = {}

-- Main active tab draw function
function ActiveTab.draw(gameData, startY, height, QuestSystem, Quests, TimeSystem, State, Helpers)
    local MENU_DESIGN_WIDTH = Helpers.MENU_DESIGN_WIDTH
    local MENU_DESIGN_HEIGHT = Helpers.MENU_DESIGN_HEIGHT
    
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

        -- Quest card with paper texture (optional - currently using simple panel)
        local UIAssets = require("ui.ui_assets")
        -- UIAssets.drawPaper(20, y, cardWidth, 80, {
        --     special = false,
        --     color = {0.95, 0.95, 0.98, 1},  -- Slightly blue tint
        --     alpha = 0.9
        -- })
        
        -- Using simple panel for cleaner look (original design)
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
            awaiting_execute = {0.9, 0.7, 0.2},
            execute = {0.9, 0.6, 0.3},
            awaiting_return = {0.3, 0.8, 0.5},
            awaiting_claim = {0.3, 0.9, 0.3},
            ["return"] = {0.6, 0.9, 0.6}
        }

        if phase == "awaiting_execute" then
            -- Heroes arrived - show Execute Quest button
            love.graphics.setColor(phaseColors[phase])
            love.graphics.print("HEROES ARRIVED!", 70, y + 30)

            -- Execute Quest button
            local execBtnX = 200
            local execBtnY = y + 25
            local execBtnW = 130
            local execBtnH = 28

            -- Store button position for click detection
            quest._execBtnPos = {x = execBtnX, y = execBtnY, w = execBtnW, h = execBtnH}

            Components.drawButton("EXECUTE QUEST", execBtnX, execBtnY, execBtnW, execBtnH, {
                bgColor = {0.8, 0.5, 0.2},
                hoverColor = {0.9, 0.6, 0.3}
            })

        elseif phase == "awaiting_return" then
            -- Quest executed, waiting for player to start return
            love.graphics.setColor(phaseColors[phase])
            love.graphics.print("READY TO RETURN", 70, y + 30)

            -- Return button
            local returnBtnX = 200
            local returnBtnY = y + 25
            local returnBtnW = 100
            local returnBtnH = 28

            -- Store button position for click detection
            quest._returnBtnPos = {x = returnBtnX, y = returnBtnY, w = returnBtnW, h = returnBtnH}

            Components.drawButton("RETURN", returnBtnX, returnBtnY, returnBtnW, returnBtnH, {
                bgColor = {0.3, 0.6, 0.4},
                hoverColor = {0.4, 0.7, 0.5}
            })

        elseif phase == "awaiting_claim" then
            -- Quest complete - show claim button
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

return ActiveTab
