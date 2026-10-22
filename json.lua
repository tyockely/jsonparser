local json = {}

local function escape_str(s)
    local escape_map = {
        ['\\'] = '\\\\',
        ['"']  = '\\"',
        ['\b'] = '\\b',
        ['\f'] = '\\f',
        ['\n'] = '\\n',
        ['\r'] = '\\r',
        ['\t'] = '\\t'
    }
    return s:gsub('[\\"\b\f\n\r\t]', escape_map)
end

-- checks if a table is an array (sequential integer indices starting at 1)
local function is_array(t)
    local count = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
            return false
        end
        count = count + 1
    end
    return count == #t
end

--- encodes lua value into a json string.
-- @param val string|number|boolean|table the lua value to serialize
-- @return string json-formatted string
function json.encode(val)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" or t == "number" then
        return tostring(val)
    elseif t == "string" then
        return '"' .. escape_str(val) .. '"'
    elseif t == "table" then
        local parts = {}
        if is_array(val) then
            for i = 1, #val do
                table.insert(parts, json.encode(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                if type(k) == "string" then
                    table.insert(parts, json.encode(k) .. ":" .. json.encode(v))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        error("Unsupported data type for JSON encoding: " .. t)
    end
end

--- parses a json string into a Lua table or primitive.
-- @param str string json string to decode
-- @return table|string|number|boolean|nil lua representation of the json
function json.decode(str)
    local idx = 1

    local function skip_whitespace()
        idx = str:find("%S", idx) or (#str + 1)
    end

    local function parse_value()
        skip_whitespace()
        local char = str:sub(idx, idx)

        if char == "{" then
            idx = idx + 1
            local obj = {}
            skip_whitespace()
            if str:sub(idx, idx) == "}" then
                idx = idx + 1
                return obj
            end
            while true do
                skip_whitespace()
                if str:sub(idx, idx) ~= '"' then
                    error("Expected string key at position " .. idx)
                end
                local key = parse_value()
                skip_whitespace()
                if str:sub(idx, idx) ~= ":" then
                    error("Expected ':' at position " .. idx)
                end
                idx = idx + 1
                obj[key] = parse_value()
                skip_whitespace()
                local c = str:sub(idx, idx)
                if c == "}" then
                    idx = idx + 1
                    break
                elseif c == "," then
                    idx = idx + 1
                else
                    error("Expected ',' or '}' at position " .. idx)
                end
            end
            return obj
        elseif char == "[" then
            idx = idx + 1
            local arr = {}
            skip_whitespace()
            if str:sub(idx, idx) == "]" then
                idx = idx + 1
                return arr
            end
            while true do
                table.insert(arr, parse_value())
                skip_whitespace()
                local c = str:sub(idx, idx)
                if c == "]" then
                    idx = idx + 1
                    break
                elseif c == "," then
                    idx = idx + 1
                else
                    error("Expected ',' or ']' at position " .. idx)
                end
            end
            return arr
        elseif char == '"' then
            local end_idx = idx
            while true do
                end_idx = str:find('"', end_idx + 1)
                if not end_idx then error("Unterminated string starting at position " .. idx) end
                local backslashes = 0
                local check = end_idx - 1
                while str:sub(check, check) == "\\" do
                    backslashes = backslashes + 1
                    check = check - 1
                end
                if backslashes % 2 == 0 then break end
            end
            local s = str:sub(idx + 1, end_idx - 1)
            idx = end_idx + 1
            return s
        elseif char:match("[%d%-]") then
            local num_str = str:match("^-?%d+%.?%d*", idx)
            idx = idx + #num_str
            return tonumber(num_str)
        elseif str:sub(idx, idx + 3) == "true" then
            idx = idx + 4
            return true
        elseif str:sub(idx, idx + 4) == "false" then
            idx = idx + 5
            return false
        elseif str:sub(idx, idx + 3) == "null" then
            idx = idx + 4
            return nil
        else
            error("Unexpected character '" .. char .. "' at position " .. idx)
        end
    end

    local result = parse_value()
    return result
end

return json
