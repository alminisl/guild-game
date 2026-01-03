-- Quest Result Modal Module
-- Displays detailed quest completion results (Dispatch-style)

local Components = require("ui.components")

local QuestResultModal = {}

-- Modal state
local resultQueue = {}  -- Queue of results waiting to be shown
local currentResult = nil  -- Currently displayed result
local isOpen = false

-- Modal dimensions
local MODAL = {
    width = 500,
    height = 450
}

-- Reset modal state
function QuestResultModal.reset()
    resultQueue = {}
    currentResult = nil
    isOpen = false
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
    else
        currentResult = nil
        isOpen = false
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

-- Get remaining results count
function QuestResultModal.getQueueCount()
    return #resultQueue
end

-- Draw the modal
function QuestResultModal.draw(Heroes)
    if not isOpen or not currentResult then return end

    local result = currentResult

    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    -- Center modal
    local modalX = (1280 - MODAL.width) / 2
    local modalY = (720 - MODAL.height) / 2

    -- Modal background
    local bgColor = result.success and {0.15, 0.2, 0.15, 0.98} or {0.2, 0.15, 0.15, 0.98}
    Components.drawPanel(modalX, modalY, MODAL.width, MODAL.height, {
        color = bgColor,
        border = true,
        borderColor = result.success and {0.3, 0.7, 0.3} or {0.7, 0.3, 0.3}
    })

    -- Title bar
    local titleColor = result.success and Components.colors.success or Components.colors.danger
    love.graphics.setColor(titleColor)
    local titleText = result.success and "QUEST COMPLETE!" or "QUEST FAILED"
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
            modalX, modalY + MODAL.height - 55, MODAL.width, "center")
    end

    -- Continue button
    local btnW, btnH = 150, 35
    local btnX = modalX + (MODAL.width - btnW) / 2
    local btnY = modalY + MODAL.height - 50
    Components.drawButton("Continue", btnX, btnY, btnW, btnH, {
        color = result.success and Components.colors.success or Components.colors.danger
    })
end

-- Handle click
function QuestResultModal.handleClick(x, y)
    if not isOpen then return false end

    local modalX = (1280 - MODAL.width) / 2
    local modalY = (720 - MODAL.height) / 2

    -- Continue button
    local btnW, btnH = 150, 35
    local btnX = modalX + (MODAL.width - btnW) / 2
    local btnY = modalY + MODAL.height - 50

    if Components.isPointInRect(x, y, btnX, btnY, btnW, btnH) then
        QuestResultModal.close()
        return true
    end

    -- Click anywhere on modal to continue
    if Components.isPointInRect(x, y, modalX, modalY, MODAL.width, MODAL.height) then
        QuestResultModal.close()
        return true
    end

    -- Click outside modal also closes
    QuestResultModal.close()
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
        failureHints = {}
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
        -- Power hint
        local totalPower = 0
        for _, hero in ipairs(heroList) do
            totalPower = totalPower + hero.power
        end
        if totalPower < quest.requiredPower then
            table.insert(result.failureHints, "Party power (" .. totalPower .. ") was below requirement (" .. quest.requiredPower .. ")")
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
