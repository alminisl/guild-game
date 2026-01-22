-- Time System Module
-- Simple day counter for progression tracking

local TimeSystem = {}

-- Time configuration
TimeSystem.config = {
    dayDuration = 360,  -- Real seconds per in-game day (6 minutes)
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

-- Legacy compatibility stubs (return false/neutral values)
function TimeSystem.isNight(gameData)
    return false
end

function TimeSystem.isDay(gameData)
    return true
end

function TimeSystem.getDayPeriod(gameData)
    return "Day"
end

function TimeSystem.getTimeString(gameData)
    return "Day " .. (gameData.day or 1)
end

function TimeSystem.toggleDayNight(gameData)
    return false, "day"
end

return TimeSystem
