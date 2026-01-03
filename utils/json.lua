-- Simple JSON parser for LÖVE2D
-- Handles basic JSON parsing for game data files

local json = {}

-- Decode JSON string to Lua table
function json.decode(str)
    if not str or str == "" then
        return nil, "Empty string"
    end

    local pos = 1
    local len = #str

    local function skipWhitespace()
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end

    local function parseString()
        pos = pos + 1  -- Skip opening quote
        local start = pos
        local result = ""

        while pos <= len do
            local c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return result
            elseif c == '\\' then
                pos = pos + 1
                local escape = str:sub(pos, pos)
                if escape == 'n' then result = result .. '\n'
                elseif escape == 't' then result = result .. '\t'
                elseif escape == 'r' then result = result .. '\r'
                elseif escape == '"' then result = result .. '"'
                elseif escape == '\\' then result = result .. '\\'
                else result = result .. escape
                end
                pos = pos + 1
            else
                result = result .. c
                pos = pos + 1
            end
        end

        error("Unterminated string at position " .. start)
    end

    local function parseNumber()
        local start = pos
        while pos <= len do
            local c = str:sub(pos, pos)
            if c:match("[%d%.%-+eE]") then
                pos = pos + 1
            else
                break
            end
        end
        local numStr = str:sub(start, pos - 1)
        return tonumber(numStr)
    end

    local parseValue  -- Forward declaration

    local function parseArray()
        pos = pos + 1  -- Skip [
        local arr = {}
        skipWhitespace()

        if str:sub(pos, pos) == ']' then
            pos = pos + 1
            return arr
        end

        while true do
            skipWhitespace()
            table.insert(arr, parseValue())
            skipWhitespace()

            local c = str:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            elseif c == ',' then
                pos = pos + 1
            else
                error("Expected ',' or ']' at position " .. pos)
            end
        end
    end

    local function parseObject()
        pos = pos + 1  -- Skip {
        local obj = {}
        skipWhitespace()

        if str:sub(pos, pos) == '}' then
            pos = pos + 1
            return obj
        end

        while true do
            skipWhitespace()

            if str:sub(pos, pos) ~= '"' then
                error("Expected string key at position " .. pos)
            end

            local key = parseString()
            skipWhitespace()

            if str:sub(pos, pos) ~= ':' then
                error("Expected ':' at position " .. pos)
            end
            pos = pos + 1

            skipWhitespace()
            obj[key] = parseValue()
            skipWhitespace()

            local c = str:sub(pos, pos)
            if c == '}' then
                pos = pos + 1
                return obj
            elseif c == ',' then
                pos = pos + 1
            else
                error("Expected ',' or '}' at position " .. pos)
            end
        end
    end

    parseValue = function()
        skipWhitespace()
        local c = str:sub(pos, pos)

        if c == '"' then
            return parseString()
        elseif c == '{' then
            return parseObject()
        elseif c == '[' then
            return parseArray()
        elseif c == 't' then
            if str:sub(pos, pos + 3) == "true" then
                pos = pos + 4
                return true
            end
        elseif c == 'f' then
            if str:sub(pos, pos + 4) == "false" then
                pos = pos + 5
                return false
            end
        elseif c == 'n' then
            if str:sub(pos, pos + 3) == "null" then
                pos = pos + 4
                return nil
            end
        elseif c:match("[%d%-]") then
            return parseNumber()
        end

        error("Unexpected character '" .. c .. "' at position " .. pos)
    end

    local success, result = pcall(parseValue)
    if success then
        return result
    else
        return nil, result
    end
end

-- Load and parse a JSON file
function json.loadFile(filepath)
    local contents, err = love.filesystem.read(filepath)
    if not contents then
        return nil, "Could not read file: " .. (err or filepath)
    end
    return json.decode(contents)
end

return json
