-- Time System Module
-- Real-time progression with day counter

local TimeSystem = {}

-- Time configuration
TimeSystem.config = {
    dayDuration = 360,  -- Real seconds per in-game day (6 minutes: 3 min day + 3 min night)
    timeScale = 1,      -- Speed multiplier (for testing: set higher)
}

-- Initialize time state
function TimeSystem.init()
    return {
        day = 1,
        dayProgress = 0,  -- 0 to 1 progress through current day
        totalTime = 0     -- Total elapsed time in seconds
    }
end

-- Update time (call every frame with dt)
function TimeSystem.update(gameData, dt)
    local scaledDt = dt * TimeSystem.config.timeScale

    gameData.totalTime = (gameData.totalTime or 0) + scaledDt
    gameData.dayProgress = (gameData.dayProgress or 0) + (scaledDt / TimeSystem.config.dayDuration)

    -- Day rollover
    if gameData.dayProgress >= 1 then
        gameData.dayProgress = gameData.dayProgress - 1
        gameData.day = gameData.day + 1
        return true  -- New day started
    end

    return false
end

-- Get time of day (0-1 maps to morning->night)
function TimeSystem.getTimeOfDay(gameData)
    return gameData.dayProgress or 0
end

-- Get formatted time string
function TimeSystem.getTimeString(gameData)
    local progress = gameData.dayProgress or 0
    local hour = math.floor(6 + progress * 18)  -- 6 AM to midnight
    local period = hour >= 12 and "PM" or "AM"
    local displayHour = hour > 12 and hour - 12 or hour
    if displayHour == 0 then displayHour = 12 end
    return string.format("%d:00 %s", displayHour, period)
end

-- Get day period name
function TimeSystem.getDayPeriod(gameData)
    local progress = gameData.dayProgress or 0
    if progress < 0.25 then return "Morning"
    elseif progress < 0.5 then return "Midday"
    elseif progress < 0.75 then return "Evening"
    else return "Night"
    end
end

-- Check if it's currently night (last 25% of day)
function TimeSystem.isNight(gameData)
    local progress = gameData.dayProgress or 0
    return progress >= 0.75
end

-- Check if it's daytime (first 75% of day)
function TimeSystem.isDay(gameData)
    local progress = gameData.dayProgress or 0
    return progress < 0.75
end

-- Format seconds into readable time
function TimeSystem.formatDuration(seconds)
    if seconds < 60 then
        return string.format("%.0fs", seconds)
    else
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%dm %ds", mins, secs)
    end
end

-- Set time scale (for testing/speed up)
function TimeSystem.setTimeScale(scale)
    TimeSystem.config.timeScale = scale
end

return TimeSystem
