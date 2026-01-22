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
    -- Normalize to forward slashes for LÖVE
    filepath = filepath:gsub("\\", "/")
    local contents, err = love.filesystem.read(filepath)
    if not contents then
        return nil, "Could not read file: " .. (err or filepath)
    end
    return json.decode(contents)
end

-- Encode Lua table to JSON string
function json.encode(value, indent, currentIndent)
    indent = indent or nil  -- nil = compact, number = pretty with that many spaces
    currentIndent = currentIndent or 0

    local function encodeString(s)
        s = s:gsub('\\', '\\\\')
        s = s:gsub('"', '\\"')
        s = s:gsub('\n', '\\n')
        s = s:gsub('\r', '\\r')
        s = s:gsub('\t', '\\t')
        return '"' .. s .. '"'
    end

    local function isArray(t)
        if type(t) ~= "table" then return false end
        local count = 0
        for k, _ in pairs(t) do
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                return false
            end
            count = count + 1
        end
        -- Check for sequential keys starting at 1
        for i = 1, count do
            if t[i] == nil then return false end
        end
        return true
    end

    local function sortedKeys(t)
        local keys = {}
        for k in pairs(t) do
            table.insert(keys, k)
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        return keys
    end

    local newline = indent and "\n" or ""
    local space = indent and " " or ""
    local nextIndent = indent and (currentIndent + indent) or 0
    local indentStr = indent and string.rep(" ", currentIndent) or ""
    local nextIndentStr = indent and string.rep(" ", nextIndent) or ""

    if value == nil then
        return "null"
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    elseif type(value) == "number" then
        if value ~= value then  -- NaN check
            return "null"
        elseif value == math.huge or value == -math.huge then
            return "null"
        elseif math.floor(value) == value then
            return string.format("%d", value)
        else
            return string.format("%.10g", value)
        end
    elseif type(value) == "string" then
        return encodeString(value)
    elseif type(value) == "table" then
        if isArray(value) then
            if #value == 0 then
                return "[]"
            end
            local parts = {}
            for i, v in ipairs(value) do
                table.insert(parts, nextIndentStr .. json.encode(v, indent, nextIndent))
            end
            return "[" .. newline .. table.concat(parts, "," .. newline) .. newline .. indentStr .. "]"
        else
            local keys = sortedKeys(value)
            if #keys == 0 then
                return "{}"
            end
            local parts = {}
            for _, k in ipairs(keys) do
                local v = value[k]
                -- Skip functions and other non-serializable types
                if type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
                    local encodedKey = encodeString(tostring(k))
                    local encodedValue = json.encode(v, indent, nextIndent)
                    table.insert(parts, nextIndentStr .. encodedKey .. ":" .. space .. encodedValue)
                end
            end
            return "{" .. newline .. table.concat(parts, "," .. newline) .. newline .. indentStr .. "}"
        end
    else
        return "null"  -- Fallback for unsupported types
    end
end

-- Save table to JSON file
-- Uses native Lua io to write to source directory (not LÖVE save directory)
function json.saveFile(filepath, data, prettyPrint)
    local indent = prettyPrint and 2 or nil
    local jsonStr = json.encode(data, indent)

    -- Normalize filepath
    filepath = filepath:gsub("\\", "/")

    -- Get the source directory (where the game files are)
    local sourceDir = love.filesystem.getSource()
    local fullPath = sourceDir .. "/" .. filepath

    -- Convert forward slashes to backslashes on Windows for io.open
    if love.system.getOS() == "Windows" then
        fullPath = fullPath:gsub("/", "\\")
    end

    print("[JSON] Writing to source: " .. fullPath)

    -- Use native Lua io to write to the actual source directory
    local file, err = io.open(fullPath, "w")
    if not file then
        print("[JSON] Failed to open file: " .. (err or "unknown error"))
        return false, "Could not open file for writing: " .. (err or filepath)
    end

    local success, writeErr = file:write(jsonStr)
    file:close()

    if not success then
        print("[JSON] Failed to write: " .. (writeErr or "unknown error"))
        return false, "Could not write file: " .. (writeErr or filepath)
    end

    print("[JSON] Write successful to source directory")
    return true
end

return json
