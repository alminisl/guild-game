-- Quest Result Modal Module
-- Displays detailed quest completion results (Dispatch-style)

local Components = require("ui.components")

local QuestResultModal = {}

-- Modal state
local resultQueue = {}  -- Queue of results waiting to be shown
local currentResult = nil  -- Currently displayed result
local isOpen = false

-- Speed settings for animation
local SPEED_SETTINGS = {
    {label = "1x", delay = 0.6},   -- Slow
    {label = "2x", delay = 0.3},   -- Normal
    {label = "3x", delay = 0.1}    -- Fast
}

-- Animation state for combat log
local animState = {
    visibleEntries = 0,      -- Number of log entries currently visible
    timer = 0,               -- Time accumulator
    speedIndex = 2,          -- Current speed (1=slow, 2=normal, 3=fast)
    isAnimating = false,     -- Whether animation is in progress
    autoScroll = true        -- Whether to auto-scroll to latest entry
}

-- Get current entry delay based on speed setting
local function getEntryDelay()
    return SPEED_SETTINGS[animState.speedIndex].delay
end

-- Modal dimensions (base, can be extended for dungeons/combat)
local MODAL = {
    width = 550,
    height = 480,
    dungeonExtraHeight = 120,  -- Extra height per 3 floors
    combatLogHeight = 200,     -- Extra height for combat log
    narrativeHeight = 80       -- Extra height for narrative
}

-- Reset modal state
function QuestResultModal.reset()
    resultQueue = {}
    currentResult = nil
    isOpen = false
    animState.visibleEntries = 0
    animState.timer = 0
    animState.isAnimating = false
end

-- Add a quest result to the queue
function QuestResultModal.push(result)
    table.insert(resultQueue, result)
    -- If no modal currently showing, show this one
    if not isOpen then
        QuestResultModal.showNext()
    end
end

-- Show the next result in queue
function QuestResultModal.showNext()
    if #resultQueue > 0 then
        currentResult = table.remove(resultQueue, 1)
        isOpen = true

        -- Reset animation state for combat log
        animState.timer = 0
        animState.visibleEntries = 0
        animState.autoScroll = true

        -- Start animating if this result has a combat log
        if currentResult.combatLog and #currentResult.combatLog > 0 then
            animState.isAnimating = true
        else
            animState.isAnimating = false
        end
    else
        currentResult = nil
        isOpen = false
        animState.isAnimating = false
    end
end

-- Close the current modal
function QuestResultModal.close()
    QuestResultModal.showNext()
end

-- Check if modal is open
function QuestResultModal.isOpen()
    return isOpen
end

-- Handle mouse wheel scroll for combat log
function QuestResultModal.handleScroll(direction)
    if not isOpen or not currentResult then return false end
    if not currentResult.combatLog then return false end

    -- Disable auto-scroll when user manually scrolls
    animState.autoScroll = false

    local lineHeight = 14
    local logAreaH = MODAL.combatLogHeight - 80
    local maxVisibleLines = math.floor(logAreaH / lineHeight)

    -- During animation, only allow scrolling within visible entries
    local totalEntries = animState.isAnimating and animState.visibleEntries or #currentResult.combatLog
    local maxOffset = math.max(0, totalEntries - maxVisibleLines)

    currentResult._logScrollOffset = currentResult._logScrollOffset or 0

    if direction > 0 then  -- Scroll up
        currentResult._logScrollOffset = math.max(0, currentResult._logScrollOffset - 3)
    else  -- Scroll down
        currentResult._logScrollOffset = math.min(maxOffset, currentResult._logScrollOffset + 3)
    end

    return true
end

-- Get remaining results count
function QuestResultModal.getQueueCount()
    return #resultQueue
end

-- Update animation (call from main update loop)
function QuestResultModal.update(dt)
    if not isOpen or not currentResult then return end
    if not animState.isAnimating then return end
    if not currentResult.combatLog then return end

    local totalEntries = #currentResult.combatLog

    -- Advance timer
    animState.timer = animState.timer + dt

    -- Calculate how many entries should be visible based on time and current speed
    local shouldBeVisible = math.floor(animState.timer / getEntryDelay())

    if shouldBeVisible > animState.visibleEntries then
        animState.visibleEntries = math.min(shouldBeVisible, totalEntries)

        -- Auto-scroll to follow new entries
        if animState.autoScroll then
            local lineHeight = 14
            local logAreaH = MODAL.combatLogHeight - 80
            local maxVisibleLines = math.floor(logAreaH / lineHeight)

            -- Keep the newest entry in view
            if animState.visibleEntries > maxVisibleLines then
                currentResult._logScrollOffset = animState.visibleEntries - maxVisibleLines
            end
        end
    end

    -- Check if animation is complete
    if animState.visibleEntries >= totalEntries then
        animState.isAnimating = false
    end
end

-- Skip animation and show all entries
function QuestResultModal.skipAnimation()
    if not isOpen or not currentResult then return end
    if not currentResult.combatLog then return end

    animState.visibleEntries = #currentResult.combatLog
    animState.isAnimating = false

    -- Scroll to bottom
    local lineHeight = 14
    local logAreaH = MODAL.combatLogHeight - 80
    local maxVisibleLines = math.floor(logAreaH / lineHeight)
    local maxOffset = math.max(0, #currentResult.combatLog - maxVisibleLines)
    currentResult._logScrollOffset = maxOffset
end

-- Check if animation is in progress
function QuestResultModal.isAnimating()
    return animState.isAnimating
end

-- Draw the modal
function QuestResultModal.draw(Heroes)
    if not isOpen or not currentResult then return end

    local result = currentResult

    -- Calculate modal height (extra for dungeons, combat, narratives)
    local modalHeight = MODAL.height
    if result.isDungeon and result.floorResults then
        local floorRows = math.ceil(#result.floorResults / 3)
        modalHeight = modalHeight + floorRows * 40 + 50
    end
    if result.combatLog and #result.combatLog > 0 then
        modalHeight = modalHeight + MODAL.combatLogHeight
    elseif result.narrative and #result.narrative > 0 then
        modalHeight = modalHeight + MODAL.narrativeHeight
    end

    -- Get actual screen dimensions for responsive layout
    local screenW, screenH = love.graphics.getDimensions()

    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Center modal
    local modalX = (screenW - MODAL.width) / 2
    local modalY = (screenH - modalHeight) / 2

    -- Modal background
    local bgColor = result.success and {0.15, 0.2, 0.15, 0.98} or {0.2, 0.15, 0.15, 0.98}
    Components.drawPanel(modalX, modalY, MODAL.width, modalHeight, {
        color = bgColor,
        border = true,
        borderColor = result.success and {0.3, 0.7, 0.3} or {0.7, 0.3, 0.3}
    })

    -- Title bar
    local titleColor = result.success and Components.colors.success or Components.colors.danger
    love.graphics.setColor(titleColor)
    local titleText
    if result.isExecutionResult then
        -- Execution phase - show battle outcome
        titleText = result.success and "VICTORY!" or "DEFEAT!"
    else
        titleText = result.success and "QUEST COMPLETE!" or "QUEST FAILED"
    end
    love.graphics.printf(titleText, modalX, modalY + 15, MODAL.width, "center")

    -- Quest name and rank
    local quest = result.quest
    if quest then
        love.graphics.setColor(Components.colors.text)
        love.graphics.printf(quest.name, modalX, modalY + 40, MODAL.width, "center")

        -- Rank badge
        Components.drawRankBadge(quest.rank, modalX + MODAL.width / 2 - 15, modalY + 60, 30)
    end

    local contentY = modalY + 100

    -- Skip rewards section for execution results (rewards come after return)
    if not result.isExecutionResult then
        -- Rewards section
        love.graphics.setColor(Components.colors.text)
        love.graphics.print("REWARDS", modalX + 20, contentY)
        contentY = contentY + 22

        -- Gold
        love.graphics.setColor(Components.colors.gold)
        love.graphics.print("Gold: " .. (result.goldReward or 0), modalX + 30, contentY)
        contentY = contentY + 18

        -- XP
        love.graphics.setColor({0.5, 0.3, 0.7})
        love.graphics.print("XP: " .. (result.xpReward or 0) .. " per hero", modalX + 30, contentY)
        contentY = contentY + 18

        -- Material drops
        if result.materialDrops and #result.materialDrops > 0 then
            love.graphics.setColor(Components.colors.textDim)
            local dropStr = "Materials: "
            for i, drop in ipairs(result.materialDrops) do
                if i > 1 then dropStr = dropStr .. ", " end
                dropStr = dropStr .. (drop.name or drop.id or "item") .. " x" .. (drop.amount or 1)
            end
            love.graphics.print(dropStr, modalX + 30, contentY)
            contentY = contentY + 18
        end

        -- Guild XP
        if result.guildXP and result.guildXP > 0 then
            love.graphics.setColor({0.4, 0.6, 0.8})
            local guildStr = "Guild XP: +" .. result.guildXP
            if result.guildLevelUp then
                guildStr = guildStr .. " (LEVEL UP!)"
            end
            love.graphics.print(guildStr, modalX + 30, contentY)
            contentY = contentY + 18
        end
    else
        -- Execution result - show message about rewards coming later
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.print("Rewards will be given when heroes return.", modalX + 20, contentY)
        contentY = contentY + 20
    end

    -- ═══════════════════════════════════════════════════════════════════
    -- COMBAT LOG (for combat quests)
    -- ═══════════════════════════════════════════════════════════════════
    if result.combatLog and #result.combatLog > 0 then
        contentY = contentY + 15

        -- Battle Report header
        love.graphics.setColor(0.9, 0.6, 0.2)
        love.graphics.print("[BATTLE REPORT]", modalX + 20, contentY)
        contentY = contentY + 22

        -- Combat summary
        if result.combatSummary then
            local summary = result.combatSummary
            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(string.format("Rounds: %d | Enemies Defeated: %d | Crits: %d",
                summary.rounds or 0,
                summary.enemiesDefeated or 0,
                summary.critCount or 0
            ), modalX + 30, contentY)
            contentY = contentY + 16

            -- MVP
            if summary.mvp then
                love.graphics.setColor(Components.colors.gold)
                love.graphics.print("MVP: " .. summary.mvp.name .. " (" .. summary.mvp.damage .. " damage)",
                    modalX + 30, contentY)
                contentY = contentY + 18
            end
        end

        -- Battle log entries (scrollable area)
        contentY = contentY + 8
        local logAreaX = modalX + 25
        local logAreaY = contentY
        local logAreaW = MODAL.width - 50
        local logAreaH = MODAL.combatLogHeight - 80
        local lineHeight = 14

        -- Draw log background
        love.graphics.setColor(0.1, 0.1, 0.12, 0.8)
        love.graphics.rectangle("fill", logAreaX, logAreaY, logAreaW, logAreaH, 5, 5)

        -- Set scissor for scrolling
        love.graphics.setScissor(logAreaX, logAreaY, logAreaW, logAreaH)

        local logY = logAreaY + 5
        local scrollOffset = result._logScrollOffset or 0
        local maxVisibleLines = math.floor(logAreaH / lineHeight)

        -- Determine how many entries to show (animated vs all)
        local entriesToShow = animState.isAnimating and animState.visibleEntries or #result.combatLog

        -- Find log entries to display
        local displayedLines = 0
        local skippedLines = 0
        local entryIndex = 0

        for _, entry in ipairs(result.combatLog) do
            entryIndex = entryIndex + 1

            -- Stop if we've reached the animation limit
            if entryIndex > entriesToShow then
                break
            end

            -- Skip entries based on scroll
            if skippedLines < scrollOffset then
                skippedLines = skippedLines + 1
            elseif displayedLines < maxVisibleLines then
                -- Color based on entry type
                if entry.type == "round_start" then
                    love.graphics.setColor(0.7, 0.7, 0.3)
                elseif entry.type == "death" then
                    love.graphics.setColor(0.8, 0.3, 0.3)
                elseif entry.type == "result" then
                    love.graphics.setColor(result.success and 0.3 or 0.8, result.success and 0.8 or 0.3, 0.3)
                elseif entry.type == "initiative" then
                    love.graphics.setColor(0.5, 0.7, 0.9)
                elseif entry.type == "poison" then
                    love.graphics.setColor(0.6, 0.3, 0.6)
                elseif entry.isCrit then
                    love.graphics.setColor(1, 0.8, 0.2)
                elseif entry.isHero then
                    love.graphics.setColor(0.6, 0.8, 0.6)
                else
                    love.graphics.setColor(0.8, 0.6, 0.6)
                end

                love.graphics.print(entry.message or "", logAreaX + 5, logY)
                logY = logY + lineHeight
                displayedLines = displayedLines + 1
            end
        end

        love.graphics.setScissor()

        -- Scroll indicator or animation status
        if animState.isAnimating then
            -- Show animation progress
            love.graphics.setColor(0.9, 0.7, 0.3)
            local progressText = string.format("Battle in progress... (%d/%d)",
                animState.visibleEntries, #result.combatLog)
            love.graphics.print(progressText, logAreaX, logAreaY + logAreaH + 2)

            -- Speed control buttons
            local speedBtnW = 30
            local speedBtnH = 18
            local speedBtnY = logAreaY + logAreaH + 1
            local speedBtnStartX = logAreaX + logAreaW - (speedBtnW * 3 + 10)

            -- Store speed button positions for click handling
            result._speedBtns = {}

            for i, speed in ipairs(SPEED_SETTINGS) do
                local btnX = speedBtnStartX + (i - 1) * (speedBtnW + 5)
                local isActive = (i == animState.speedIndex)

                -- Button background
                if isActive then
                    love.graphics.setColor(0.4, 0.6, 0.4)
                else
                    love.graphics.setColor(0.3, 0.3, 0.35)
                end
                love.graphics.rectangle("fill", btnX, speedBtnY, speedBtnW, speedBtnH, 3, 3)

                -- Button border
                if isActive then
                    love.graphics.setColor(0.6, 0.9, 0.6)
                else
                    love.graphics.setColor(0.5, 0.5, 0.5)
                end
                love.graphics.rectangle("line", btnX, speedBtnY, speedBtnW, speedBtnH, 3, 3)

                -- Button text
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(speed.label, btnX, speedBtnY + 3, speedBtnW, "center")

                -- Store for click detection
                result._speedBtns[i] = {x = btnX, y = speedBtnY, w = speedBtnW, h = speedBtnH}
            end
        elseif #result.combatLog > maxVisibleLines then
            love.graphics.setColor(Components.colors.textDim)
            local scrollInfo = string.format("Scroll: %d/%d (mouse wheel)",
                scrollOffset + 1, math.max(1, #result.combatLog - maxVisibleLines + 1))
            love.graphics.print(scrollInfo, logAreaX, logAreaY + logAreaH + 2)
        end

        -- Store log area for Skip button
        result._logAreaX = logAreaX
        result._logAreaY = logAreaY
        result._logAreaW = logAreaW
        result._logAreaH = logAreaH

        contentY = logAreaY + logAreaH + 18

    -- ═══════════════════════════════════════════════════════════════════
    -- NARRATIVE (for non-combat quests)
    -- ═══════════════════════════════════════════════════════════════════
    elseif result.narrative and #result.narrative > 0 then
        contentY = contentY + 15

        -- Narrative header
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.print("[QUEST REPORT]", modalX + 20, contentY)
        contentY = contentY + 22

        -- Narrative entries
        for _, entry in ipairs(result.narrative) do
            love.graphics.setColor(Components.colors.textDim)
            local line = (entry.emoji or "") .. " " .. (entry.text or "")
            love.graphics.print(line, modalX + 30, contentY)
            contentY = contentY + 18
        end
    end

    -- Dungeon floor breakdown
    if result.isDungeon and result.floorResults then
        contentY = contentY + 15
        love.graphics.setColor(0.8, 0.5, 0.9)
        love.graphics.print("FLOOR BREAKDOWN", modalX + 20, contentY)
        contentY = contentY + 22

        -- Draw floor results in a grid (3 per row)
        local floorX = modalX + 30
        local floorStartX = floorX
        local floorW = 140
        local floorH = 35
        local floorSpacing = 5

        for i, floor in ipairs(result.floorResults) do
            -- Floor box
            local floorColor = floor.success and {0.2, 0.35, 0.2} or {0.35, 0.2, 0.2}
            Components.drawPanel(floorX, contentY, floorW, floorH, {
                color = floorColor,
                cornerRadius = 3
            })

            -- Floor number and status
            love.graphics.setColor(Components.colors.text)
            love.graphics.print("Floor " .. i, floorX + 5, contentY + 3)

            if floor.success then
                love.graphics.setColor(Components.colors.success)
                love.graphics.print("Cleared", floorX + 70, contentY + 3)
            else
                love.graphics.setColor(Components.colors.danger)
                love.graphics.print("Failed", floorX + 70, contentY + 3)
            end

            -- Floor loot (if any)
            if floor.gold and floor.gold > 0 then
                love.graphics.setColor(Components.colors.gold)
                love.graphics.print(floor.gold .. "g", floorX + 5, contentY + 18)
            end

            -- Move to next position
            floorX = floorX + floorW + floorSpacing
            if i % 3 == 0 then
                floorX = floorStartX
                contentY = contentY + floorH + floorSpacing
            end
        end

        -- Adjust contentY if last row wasn't full
        if #result.floorResults % 3 ~= 0 then
            contentY = contentY + floorH + floorSpacing
        end

        -- Retreat or completion status
        if result.hasRetreated then
            love.graphics.setColor(Components.colors.warning)
            love.graphics.print("RETREATED - Partial rewards only", modalX + 30, contentY)
            contentY = contentY + 18
        elseif result.success then
            love.graphics.setColor(Components.colors.success)
            love.graphics.print("DUNGEON CLEARED - Completion bonus awarded!", modalX + 30, contentY)
            contentY = contentY + 18
        end
    end

    contentY = contentY + 10

    -- Hero status section
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("HERO STATUS", modalX + 20, contentY)
    contentY = contentY + 22

    -- Show hero outcomes
    if result.heroOutcomes then
        for _, outcome in ipairs(result.heroOutcomes) do
            local hero = outcome.hero
            if hero then
                -- Hero name
                love.graphics.setColor(Components.colors.text)
                love.graphics.print(hero.name, modalX + 30, contentY)

                -- Status/injury
                local statusX = modalX + 180
                if outcome.died then
                    love.graphics.setColor(Components.colors.danger)
                    love.graphics.print("FALLEN", statusX, contentY)
                elseif outcome.revived then
                    love.graphics.setColor({0.8, 0.5, 0.2})
                    love.graphics.print("Revived (Phoenix Feather)", statusX, contentY)
                elseif outcome.injury then
                    local injuryColor = Components.getInjuryColor(outcome.injury)
                    love.graphics.setColor(injuryColor)
                    local injuryName = outcome.injury:sub(1,1):upper() .. outcome.injury:sub(2)
                    love.graphics.print(injuryName, statusX, contentY)
                else
                    love.graphics.setColor(Components.colors.success)
                    love.graphics.print("OK", statusX, contentY)
                end

                -- Rest time
                if outcome.restTime and outcome.restTime > 0 then
                    love.graphics.setColor(Components.colors.textDim)
                    local restMins = math.floor(outcome.restTime / 60)
                    local restSecs = math.floor(outcome.restTime % 60)
                    local restStr = restMins > 0 and (restMins .. "m " .. restSecs .. "s") or (restSecs .. "s")
                    love.graphics.print("Rest: " .. restStr, statusX + 130, contentY)
                end

                -- Level up indicator
                if outcome.leveledUp then
                    love.graphics.setColor({0.5, 0.3, 0.7})
                    love.graphics.print("LEVEL UP!", statusX + 210, contentY)
                end

                contentY = contentY + 20
            end
        end
    end

    -- Failure hints (only on failed quests)
    if not result.success and result.failureHints and #result.failureHints > 0 then
        contentY = contentY + 10
        love.graphics.setColor(Components.colors.warning)
        love.graphics.print("WHAT WENT WRONG:", modalX + 20, contentY)
        contentY = contentY + 20

        love.graphics.setColor(Components.colors.textDim)
        for _, hint in ipairs(result.failureHints) do
            love.graphics.print("- " .. hint, modalX + 30, contentY)
            contentY = contentY + 16
        end
    end

    -- Queue indicator
    if #resultQueue > 0 then
        love.graphics.setColor(Components.colors.textDim)
        love.graphics.printf("(" .. #resultQueue .. " more result" .. (#resultQueue > 1 and "s" or "") .. " waiting)",
            modalX, modalY + modalHeight - 55, MODAL.width, "center")
    end

    -- Button section
    local btnW, btnH = 150, 35
    local btnX = modalX + (MODAL.width - btnW) / 2
    local btnY = modalY + modalHeight - 50

    if animState.isAnimating and result.combatLog then
        -- Show Skip button during animation
        Components.drawButton("Skip >>", btnX, btnY, btnW, btnH, {
            color = {0.5, 0.5, 0.6}
        })
    else
        -- Show Continue button when done
        Components.drawButton("Continue", btnX, btnY, btnW, btnH, {
            color = result.success and Components.colors.success or Components.colors.danger
        })
    end

    -- Store current height and button position for click handling
    currentResult._modalHeight = modalHeight
    currentResult._btnX = btnX
    currentResult._btnY = btnY
    currentResult._btnW = btnW
    currentResult._btnH = btnH
end

-- Handle click
function QuestResultModal.handleClick(x, y)
    if not isOpen or not currentResult then return false end

    -- Get modal height (dynamic for dungeons)
    local modalHeight = currentResult._modalHeight or MODAL.height

    -- Get actual screen dimensions for responsive layout
    local screenW, screenH = love.graphics.getDimensions()
    local modalX = (screenW - MODAL.width) / 2
    local modalY = (screenH - modalHeight) / 2

    -- Check speed button clicks first (during animation)
    if animState.isAnimating and currentResult._speedBtns then
        for i, btn in ipairs(currentResult._speedBtns) do
            if Components.isPointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
                animState.speedIndex = i
                return true  -- Don't skip animation, just change speed
            end
        end
    end

    -- Button position
    local btnX = currentResult._btnX or (modalX + (MODAL.width - 150) / 2)
    local btnY = currentResult._btnY or (modalY + modalHeight - 50)
    local btnW = currentResult._btnW or 150
    local btnH = currentResult._btnH or 35

    -- Handle button click
    if Components.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
        if animState.isAnimating then
            -- Skip animation
            QuestResultModal.skipAnimation()
        else
            -- Close modal
            QuestResultModal.close()
        end
        return true
    end

    -- Click anywhere on modal
    if Components.isPointInRect(x, y, modalX, modalY, MODAL.width, modalHeight) then
        if animState.isAnimating then
            -- During animation, clicking modal body does nothing (use Skip button or speed buttons)
            return true
        else
            QuestResultModal.close()
        end
        return true
    end

    -- Click outside modal closes it
    if not animState.isAnimating then
        QuestResultModal.close()
    end
    return true
end

-- Build result data from quest completion
function QuestResultModal.buildResult(quest, questResult, heroList, materialDrops, guildResult, Heroes)
    local result = {
        quest = quest,
        success = questResult.success,
        goldReward = questResult.goldReward,
        xpReward = questResult.xpReward,
        message = questResult.message,
        materialDrops = materialDrops or {},
        guildXP = guildResult and guildResult.guildXP or 0,
        guildLevelUp = guildResult and guildResult.guildLevelUp or false,
        heroOutcomes = {},
        failureHints = {},
        -- Dungeon-specific fields
        isDungeon = quest.isDungeon or false,
        floorResults = questResult.floorResults or nil,
        hasRetreated = quest.hasRetreated or false,
        completionBonus = questResult.completionBonus or 0,
        -- Combat log (for combat quests)
        combatLog = questResult.combatLog or nil,
        combatSummary = questResult.combatSummary or nil,
        -- Narrative (for non-combat quests)
        narrative = questResult.narrative or nil,
        -- UI state
        _logScrollOffset = 0,
        _showFullLog = false
    }

    -- Build hero outcomes
    for _, hero in ipairs(heroList) do
        local outcome = {
            hero = hero,
            injury = hero.injuryState,
            restTime = hero.restTimeMax or 0,
            leveledUp = false,  -- Would need to track this separately
            died = false,
            revived = false
        }

        -- Check for death (hero no longer in list)
        if questResult.deadHeroes then
            for _, deadHero in ipairs(questResult.deadHeroes) do
                if deadHero.id == hero.id then
                    outcome.died = true
                    break
                end
            end
        end

        table.insert(result.heroOutcomes, outcome)
    end

    -- Generate failure hints
    if not questResult.success then
        -- Rank mismatch hint
        local rankValues = {D = 1, C = 2, B = 3, A = 4, S = 5}
        local questRankValue = rankValues[quest.rank] or 1
        local avgHeroRank = 0
        for _, hero in ipairs(heroList) do
            avgHeroRank = avgHeroRank + (rankValues[hero.rank] or 1)
        end
        if #heroList > 0 then
            avgHeroRank = avgHeroRank / #heroList
        end
        if avgHeroRank < questRankValue then
            table.insert(result.failureHints, "Party rank was below quest rank - risky but rewarding if successful!")
        end

        -- Stat hint
        local reqStat = quest.requiredStat or "str"
        local totalStat = 0
        for _, hero in ipairs(heroList) do
            totalStat = totalStat + (hero.stats[reqStat] or 0)
        end
        local expectedStat = {D = 5, C = 7, B = 10, A = 13, S = 16}
        if totalStat / #heroList < (expectedStat[quest.rank] or 8) then
            local statNames = {str = "STR", dex = "DEX", int = "INT"}
            table.insert(result.failureHints, "Average " .. (statNames[reqStat] or "stat") .. " was low for this quest rank")
        end

        -- Injury hint
        local injuredCount = 0
        for _, hero in ipairs(heroList) do
            if hero.injuryState then injuredCount = injuredCount + 1 end
        end
        if injuredCount > 0 then
            table.insert(result.failureHints, injuredCount .. " hero(es) were injured, reducing effectiveness")
        end

        -- Cleric hint for A/S rank
        if quest.combat and (quest.rank == "A" or quest.rank == "S") then
            local hasCleric = false
            for _, hero in ipairs(heroList) do
                if hero.class == "Cleric" or hero.class == "Saint" then
                    hasCleric = true
                    break
                end
            end
            if not hasCleric then
                table.insert(result.failureHints, "No Cleric for death protection on high-rank combat quest")
            end
        end
    end

    return result
end

return QuestResultModal
