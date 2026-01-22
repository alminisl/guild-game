-- Logger Utility
-- Saves error logs to files for debugging

local Logger = {}

-- Get current timestamp string
local function getTimestamp()
    local date = os.date("*t")
    return string.format("%04d-%02d-%02d %02d:%02d:%02d",
        date.year, date.month, date.day,
        date.hour, date.min, date.sec)
end

-- Get date string for filename
local function getDateString()
    local date = os.date("*t")
    return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

-- Ensure logs directory exists
local function ensureLogsDir()
    local info = love.filesystem.getInfo("logs")
    if not info then
        love.filesystem.createDirectory("logs")
    end
end

-- Log an error message
function Logger.error(source, message, details)
    ensureLogsDir()

    local timestamp = getTimestamp()
    local dateStr = getDateString()
    local logFile = "logs/error_" .. dateStr .. ".log"

    -- Format log entry
    local entry = string.format("[%s] ERROR in %s: %s\n", timestamp, source, message)
    if details then
        entry = entry .. "  Details: " .. tostring(details) .. "\n"
    end
    entry = entry .. "\n"

    -- Read existing content (if any)
    local existingContent = ""
    local existing = love.filesystem.read(logFile)
    if existing then
        existingContent = existing
    end

    -- Append new entry
    local success, err = love.filesystem.write(logFile, existingContent .. entry)

    -- Also print to console
    print("[LOG ERROR] " .. source .. ": " .. message)
    if details then
        print("  Details: " .. tostring(details))
    end

    return success
end

-- Log a warning message
function Logger.warn(source, message, details)
    ensureLogsDir()

    local timestamp = getTimestamp()
    local dateStr = getDateString()
    local logFile = "logs/warn_" .. dateStr .. ".log"

    local entry = string.format("[%s] WARN in %s: %s\n", timestamp, source, message)
    if details then
        entry = entry .. "  Details: " .. tostring(details) .. "\n"
    end
    entry = entry .. "\n"

    local existingContent = ""
    local existing = love.filesystem.read(logFile)
    if existing then
        existingContent = existing
    end

    love.filesystem.write(logFile, existingContent .. entry)

    print("[LOG WARN] " .. source .. ": " .. message)
end

-- Log an info message
function Logger.info(source, message)
    ensureLogsDir()

    local timestamp = getTimestamp()
    local dateStr = getDateString()
    local logFile = "logs/info_" .. dateStr .. ".log"

    local entry = string.format("[%s] INFO %s: %s\n", timestamp, source, message)

    local existingContent = ""
    local existing = love.filesystem.read(logFile)
    if existing then
        existingContent = existing
    end

    love.filesystem.write(logFile, existingContent .. entry)

    print("[LOG INFO] " .. source .. ": " .. message)
end

-- Get the save directory path (useful for finding logs)
function Logger.getSaveDirectory()
    return love.filesystem.getSaveDirectory()
end

return Logger
