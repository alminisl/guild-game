-- UI Components Module
-- Reusable UI elements for the game

local Components = {}

-- Color definitions
Components.colors = {
    -- Base colors
    background = {0.15, 0.15, 0.2},
    panel = {0.2, 0.2, 0.25, 0.95},
    panelLight = {0.25, 0.25, 0.3},

    -- Button states
    button = {0.3, 0.3, 0.4},
    buttonHover = {0.4, 0.4, 0.5},
    buttonActive = {0.2, 0.5, 0.3},
    buttonDisabled = {0.25, 0.25, 0.25},

    -- Text
    text = {1, 1, 1},
    textDim = {0.7, 0.7, 0.7},
    textDark = {0.3, 0.3, 0.3},

    -- Resources
    gold = {1, 0.85, 0},

    -- Status
    success = {0.3, 0.7, 0.3},
    warning = {0.8, 0.6, 0.2},
    danger = {0.7, 0.3, 0.3},

    -- Injury states
    healthy = {0.3, 0.7, 0.3},
    fatigued = {0.7, 0.7, 0.3},
    injured = {0.8, 0.5, 0.2},
    wounded = {0.7, 0.2, 0.2},

    -- Hero status
    idle = {0.3, 0.7, 0.3},
    traveling = {0.5, 0.6, 0.8},
    questing = {0.8, 0.6, 0.2},
    returning = {0.6, 0.5, 0.8},
    resting = {0.5, 0.4, 0.6},

    -- Synergy
    synergy = {0.6, 0.5, 0.8},
    synergyLight = {0.7, 0.6, 0.9},

    -- Tooltip
    tooltipBg = {0.1, 0.1, 0.15, 0.95},
    tooltipBorder = {0.5, 0.5, 0.6, 0.8},

    -- Ranks
    rankD = {0.5, 0.5, 0.5},
    rankC = {0.3, 0.7, 0.3},
    rankB = {0.3, 0.5, 0.8},
    rankA = {0.6, 0.3, 0.7},
    rankS = {1, 0.7, 0.2},
}

-- Get rank color
function Components.getRankColor(rank)
    local rankColors = {
        D = Components.colors.rankD,
        C = Components.colors.rankC,
        B = Components.colors.rankB,
        A = Components.colors.rankA,
        S = Components.colors.rankS,
    }
    return rankColors[rank] or Components.colors.text
end

-- Check if point is in rectangle
function Components.isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Draw a button and return if it was clicked
function Components.drawButton(text, x, y, w, h, options)
    options = options or {}
    local disabled = options.disabled or false
    local active = options.active or false
    local color = options.color

    -- Determine button color
    local btnColor
    if disabled then
        btnColor = Components.colors.buttonDisabled
    elseif active then
        btnColor = Components.colors.buttonActive
    elseif color then
        btnColor = color
    else
        btnColor = Components.colors.button
    end

    -- Draw button background
    love.graphics.setColor(btnColor)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)

    -- Draw border if active
    if active then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 5, 5)
        love.graphics.setLineWidth(1)
    end

    -- Draw text
    if disabled then
        love.graphics.setColor(Components.colors.textDim)
    else
        love.graphics.setColor(Components.colors.text)
    end
    love.graphics.printf(text, x, y + h/2 - 7, w, "center")

    return not disabled
end

-- Check if button was clicked (call in mousepressed)
function Components.buttonClicked(x, y, btnX, btnY, btnW, btnH, disabled)
    if disabled then return false end
    return Components.isPointInRect(x, y, btnX, btnY, btnW, btnH)
end

-- Draw a panel/card
function Components.drawPanel(x, y, w, h, options)
    options = options or {}
    local color = options.color or Components.colors.panel
    local cornerRadius = options.cornerRadius or 10

    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w, h, cornerRadius, cornerRadius)

    if options.border then
        love.graphics.setColor(options.borderColor or {1, 1, 1, 0.2})
        love.graphics.setLineWidth(options.borderWidth or 1)
        love.graphics.rectangle("line", x, y, w, h, cornerRadius, cornerRadius)
    end
end

-- Draw rank badge
function Components.drawRankBadge(rank, x, y, size)
    size = size or 24
    local color = Components.getRankColor(rank)

    -- Background circle
    love.graphics.setColor(color[1], color[2], color[3], 0.3)
    love.graphics.circle("fill", x + size/2, y + size/2, size/2)

    -- Border
    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x + size/2, y + size/2, size/2)
    love.graphics.setLineWidth(1)

    -- Rank letter
    love.graphics.setColor(color)
    love.graphics.printf(rank, x, y + size/2 - 7, size, "center")
end

-- Draw progress bar
function Components.drawProgressBar(x, y, w, h, progress, options)
    options = options or {}
    local bgColor = options.bgColor or {0.2, 0.2, 0.2}
    local fgColor = options.fgColor or Components.colors.success
    local text = options.text

    -- Background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)

    -- Progress fill
    love.graphics.setColor(fgColor)
    love.graphics.rectangle("fill", x, y, w * math.min(progress, 1), h, 3, 3)

    -- Text overlay
    if text then
        love.graphics.setColor(Components.colors.text)
        love.graphics.printf(text, x, y + h/2 - 7, w, "center")
    end
end

-- Draw stat bar (for hero stats)
function Components.drawStatBar(label, value, maxValue, x, y, w)
    local barHeight = 12
    local labelWidth = 40

    -- Label
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print(label, x, y)

    -- Bar background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x + labelWidth, y + 2, w - labelWidth - 30, barHeight, 2, 2)

    -- Bar fill
    local percent = value / maxValue
    local r = 0.3 + (1 - percent) * 0.4
    local g = 0.3 + percent * 0.4
    love.graphics.setColor(r, g, 0.3)
    love.graphics.rectangle("fill", x + labelWidth, y + 2, (w - labelWidth - 30) * percent, barHeight, 2, 2)

    -- Value text
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf(tostring(value), x + w - 25, y, 25, "right")
end

-- Draw close button (X)
function Components.drawCloseButton(x, y, size)
    size = size or 30
    love.graphics.setColor(0.6, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, size, size, 5, 5)
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("X", x, y + size/2 - 7, size, "center")
end

-- Draw gold display
function Components.drawGold(amount, x, y)
    love.graphics.setColor(Components.colors.gold)
    love.graphics.print("Gold: " .. amount, x, y)
end

-- Draw day display
function Components.drawDay(day, x, y)
    love.graphics.setColor(Components.colors.text)
    love.graphics.print("Day " .. day, x, y)
end

-- Draw a hero card (compact version for lists)
function Components.drawHeroCard(hero, x, y, w, h, options)
    options = options or {}
    local selected = options.selected or false
    local showStats = options.showStats or false

    -- Card background
    local bgColor = selected and {0.3, 0.4, 0.5} or Components.colors.panelLight
    Components.drawPanel(x, y, w, h, {color = bgColor, cornerRadius = 5})

    -- Rank badge
    Components.drawRankBadge(hero.rank, x + 10, y + 10, 30)

    -- Hero info
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(hero.name, x + 50, y + 10)

    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print(hero.class .. " Lv." .. hero.level, x + 50, y + 28)

    -- Status indicator
    if hero.status == "on_quest" then
        love.graphics.setColor(Components.colors.warning)
        love.graphics.print("On Quest", x + 50, y + 46)
    elseif hero.status == "idle" then
        love.graphics.setColor(Components.colors.success)
        love.graphics.print("Available", x + 50, y + 46)
    end

    -- Power display
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("Power: " .. hero.power, x + w - 80, y + 10, 70, "right")

    -- Stats if expanded
    if showStats and h > 70 then
        local statsY = y + 65
        local statsX = x + 10
        local statW = (w - 30) / 2

        Components.drawStatBar("STR", hero.stats.str, 20, statsX, statsY, statW)
        Components.drawStatBar("DEX", hero.stats.dex, 20, statsX + statW + 10, statsY, statW)
        Components.drawStatBar("INT", hero.stats.int, 20, statsX, statsY + 18, statW)
        Components.drawStatBar("VIT", hero.stats.vit, 20, statsX + statW + 10, statsY + 18, statW)
    end
end

-- Draw a quest card
function Components.drawQuestCard(quest, x, y, w, h, options)
    options = options or {}
    local selected = options.selected or false
    local showParty = options.showParty or false

    -- Card background
    local bgColor = selected and {0.3, 0.4, 0.5} or Components.colors.panelLight
    if quest.assignedHeroes and #quest.assignedHeroes > 0 then
        bgColor = {0.25, 0.25, 0.2}
    end
    Components.drawPanel(x, y, w, h, {color = bgColor, cornerRadius = 5})

    -- Rank badge
    Components.drawRankBadge(quest.rank, x + 10, y + 10, 30)

    -- Quest info
    love.graphics.setColor(Components.colors.text)
    love.graphics.print(quest.name, x + 50, y + 10)

    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print(quest.description, x + 50, y + 28)

    -- Duration and reward
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.print("Duration: " .. quest.duration .. " day(s)", x + 50, y + 46)

    love.graphics.setColor(Components.colors.gold)
    love.graphics.printf(quest.reward .. " gold", x + w - 100, y + 10, 90, "right")

    -- Power requirement
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("Req: " .. quest.requiredPower .. " power", x + w - 100, y + 28, 90, "right")

    -- XP reward
    love.graphics.setColor(Components.colors.textDim)
    love.graphics.printf("+" .. quest.xpReward .. " XP", x + w - 100, y + 46, 90, "right")
end

-- Draw tab buttons
function Components.drawTabs(tabs, currentTab, x, y, tabWidth, tabHeight)
    for i, tab in ipairs(tabs) do
        local tabX = x + (i - 1) * (tabWidth + 5)
        local isActive = currentTab == tab.id

        Components.drawButton(tab.label, tabX, y, tabWidth, tabHeight, {active = isActive})
    end
end

-- Check which tab was clicked
function Components.getClickedTab(tabs, mouseX, mouseY, x, y, tabWidth, tabHeight)
    for i, tab in ipairs(tabs) do
        local tabX = x + (i - 1) * (tabWidth + 5)
        if Components.isPointInRect(mouseX, mouseY, tabX, y, tabWidth, tabHeight) then
            return tab.id
        end
    end
    return nil
end

-- Draw notification/toast message
function Components.drawNotification(message, x, y, w, notificationType)
    local color
    if notificationType == "success" then
        color = {0.2, 0.5, 0.3, 0.9}
    elseif notificationType == "error" then
        color = {0.5, 0.2, 0.2, 0.9}
    else
        color = {0.3, 0.3, 0.4, 0.9}
    end

    Components.drawPanel(x, y, w, 40, {color = color, cornerRadius = 5})
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf(message, x + 10, y + 12, w - 20, "center")
end

-- Draw tooltip with auto-positioning to stay on screen
-- lines: array of strings or {text, color} tables
function Components.drawTooltip(lines, x, y, options)
    options = options or {}
    local maxWidth = options.maxWidth or 250
    local padding = options.padding or 10
    local font = love.graphics.getFont()

    -- Calculate tooltip dimensions
    local textWidth = 0
    local textHeight = 0
    local lineHeight = font:getHeight() + 4

    for _, line in ipairs(lines) do
        local text = type(line) == "table" and line.text or line
        local width = font:getWidth(text)
        if width > maxWidth then
            -- Wrap text
            local wrapped = {}
            local currentLine = ""
            for word in text:gmatch("%S+") do
                local testLine = currentLine == "" and word or (currentLine .. " " .. word)
                if font:getWidth(testLine) > maxWidth then
                    table.insert(wrapped, currentLine)
                    currentLine = word
                else
                    currentLine = testLine
                end
            end
            if currentLine ~= "" then
                table.insert(wrapped, currentLine)
            end
            textHeight = textHeight + lineHeight * #wrapped
            for _, wl in ipairs(wrapped) do
                textWidth = math.max(textWidth, font:getWidth(wl))
            end
        else
            textWidth = math.max(textWidth, width)
            textHeight = textHeight + lineHeight
        end
    end

    local tooltipW = textWidth + padding * 2
    local tooltipH = textHeight + padding * 2

    -- Adjust position to stay on screen
    local screenW, screenH = love.graphics.getDimensions()
    if x + tooltipW > screenW - 10 then
        x = screenW - tooltipW - 10
    end
    if y + tooltipH > screenH - 10 then
        y = y - tooltipH - 20  -- Show above cursor
    end
    if x < 10 then x = 10 end
    if y < 10 then y = 10 end

    -- Draw background
    love.graphics.setColor(Components.colors.tooltipBg)
    love.graphics.rectangle("fill", x, y, tooltipW, tooltipH, 5, 5)

    -- Draw border
    love.graphics.setColor(Components.colors.tooltipBorder)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, tooltipW, tooltipH, 5, 5)

    -- Draw text
    local textY = y + padding
    for _, line in ipairs(lines) do
        local text, color
        if type(line) == "table" then
            text = line.text
            color = line.color or Components.colors.text
        else
            text = line
            color = Components.colors.text
        end

        love.graphics.setColor(color)

        -- Handle text wrapping
        local width = font:getWidth(text)
        if width > maxWidth then
            local currentLine = ""
            for word in text:gmatch("%S+") do
                local testLine = currentLine == "" and word or (currentLine .. " " .. word)
                if font:getWidth(testLine) > maxWidth then
                    love.graphics.print(currentLine, x + padding, textY)
                    textY = textY + lineHeight
                    currentLine = word
                else
                    currentLine = testLine
                end
            end
            if currentLine ~= "" then
                love.graphics.print(currentLine, x + padding, textY)
                textY = textY + lineHeight
            end
        else
            love.graphics.print(text, x + padding, textY)
            textY = textY + lineHeight
        end
    end
end

-- Draw pentagon/radar stat chart (Dispatch-style)
-- stats: {str, dex, int, vit, luck} with values 0-20
-- options: {showLabels, showIcons, fillColor, lineColor, overlayStats, overlayColor}
function Components.drawPentagonChart(stats, x, y, radius, options)
    options = options or {}
    local showLabels = options.showLabels ~= false  -- Default true
    local fillColor = options.fillColor or {0.8, 0.7, 0.2, 0.4}  -- Gold fill
    local lineColor = options.lineColor or {0.9, 0.8, 0.3, 1}    -- Gold outline
    local maxStat = options.maxStat or 20
    local overlayStats = options.overlayStats  -- Optional second stat set for comparison
    local overlayColor = options.overlayColor or {1, 1, 1, 0.3}  -- White for requirements

    -- Stat order (clockwise from top): STR, DEX, LUCK, VIT, INT
    local statOrder = {"str", "dex", "luck", "vit", "int"}
    local statLabels = {str = "STR", dex = "DEX", luck = "LCK", vit = "VIT", int = "INT"}
    local statIcons = {str = "[S]", dex = "[D]", luck = "[L]", vit = "[V]", int = "[I]"}

    -- Calculate angles for 5 points (starting from top, going clockwise)
    local angles = {}
    for i = 1, 5 do
        angles[i] = (i - 1) * (2 * math.pi / 5) - math.pi / 2  -- Start from top
    end

    -- Draw background pentagon (max stat outline)
    love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
    local bgVertices = {}
    for i = 1, 5 do
        table.insert(bgVertices, x + math.cos(angles[i]) * radius)
        table.insert(bgVertices, y + math.sin(angles[i]) * radius)
    end
    love.graphics.polygon("fill", bgVertices)

    -- Draw grid lines (inner pentagons at 25%, 50%, 75%)
    love.graphics.setColor(0.4, 0.4, 0.45, 0.4)
    for scale = 0.25, 0.75, 0.25 do
        local gridVertices = {}
        for i = 1, 5 do
            table.insert(gridVertices, x + math.cos(angles[i]) * radius * scale)
            table.insert(gridVertices, y + math.sin(angles[i]) * radius * scale)
        end
        love.graphics.polygon("line", gridVertices)
    end

    -- Draw axis lines
    love.graphics.setColor(0.4, 0.4, 0.45, 0.5)
    for i = 1, 5 do
        love.graphics.line(x, y, x + math.cos(angles[i]) * radius, y + math.sin(angles[i]) * radius)
    end

    -- Draw overlay stats (requirements) if provided
    if overlayStats then
        local overlayVertices = {}
        for i, stat in ipairs(statOrder) do
            local value = overlayStats[stat] or 0
            local scale = math.min(value / maxStat, 1)
            table.insert(overlayVertices, x + math.cos(angles[i]) * radius * scale)
            table.insert(overlayVertices, y + math.sin(angles[i]) * radius * scale)
        end
        -- Draw dashed outline for requirements
        love.graphics.setColor(overlayColor)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", overlayVertices)
        love.graphics.setLineWidth(1)
    end

    -- Draw stat polygon (filled)
    local statVertices = {}
    for i, stat in ipairs(statOrder) do
        local value = stats[stat] or 0
        local scale = math.min(value / maxStat, 1)
        table.insert(statVertices, x + math.cos(angles[i]) * radius * scale)
        table.insert(statVertices, y + math.sin(angles[i]) * radius * scale)
    end

    -- Fill
    love.graphics.setColor(fillColor)
    love.graphics.polygon("fill", statVertices)

    -- Outline
    love.graphics.setColor(lineColor)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", statVertices)
    love.graphics.setLineWidth(1)

    -- Draw stat points
    for i, stat in ipairs(statOrder) do
        local value = stats[stat] or 0
        local scale = math.min(value / maxStat, 1)
        local px = x + math.cos(angles[i]) * radius * scale
        local py = y + math.sin(angles[i]) * radius * scale

        love.graphics.setColor(lineColor)
        love.graphics.circle("fill", px, py, 4)
    end

    -- Draw labels/icons at vertices
    if showLabels then
        local labelOffset = 18
        for i, stat in ipairs(statOrder) do
            local lx = x + math.cos(angles[i]) * (radius + labelOffset)
            local ly = y + math.sin(angles[i]) * (radius + labelOffset)

            local label = statLabels[stat]
            local value = stats[stat] or 0

            -- Center the label
            local font = love.graphics.getFont()
            local labelW = font:getWidth(label)

            love.graphics.setColor(Components.colors.textDim)
            love.graphics.print(label, lx - labelW/2, ly - 7)

            -- Show value below label
            local valueStr = tostring(math.floor(value))
            local valueW = font:getWidth(valueStr)
            love.graphics.setColor(Components.colors.text)
            love.graphics.print(valueStr, lx - valueW/2, ly + 7)
        end
    end

    -- Draw background pentagon outline
    love.graphics.setColor(0.5, 0.5, 0.55, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("line", bgVertices)
end

-- Get injury state color
function Components.getInjuryColor(injuryState)
    if injuryState == "wounded" then
        return Components.colors.wounded
    elseif injuryState == "injured" then
        return Components.colors.injured
    elseif injuryState == "fatigued" then
        return Components.colors.fatigued
    else
        return Components.colors.healthy
    end
end

-- Get hero status color
function Components.getStatusColor(status)
    local statusColors = {
        idle = Components.colors.idle,
        traveling = Components.colors.traveling,
        questing = Components.colors.questing,
        returning = Components.colors.returning,
        resting = Components.colors.resting,
    }
    return statusColors[status] or Components.colors.textDim
end

-- Draw help icon (?) that can show tooltip on hover
function Components.drawHelpIcon(x, y, size)
    size = size or 18
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.circle("fill", x + size/2, y + size/2, size/2)
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.circle("line", x + size/2, y + size/2, size/2)
    love.graphics.setColor(Components.colors.text)
    love.graphics.printf("?", x, y + size/2 - 7, size, "center")
end

return Components
