verbana.util = {}

local time_units = {
    h = 60 * 60,
    d = 60 * 60 * 24,
    w = 60 * 60 * 24 * 7,
    m = 60 * 60 * 24 * 30,
    y = 60 * 60 * 24 * 365,
}

function verbana.util.load_file(filename)
    local file = io.open(filename, 'r')
    if not file then
        verbana.log('error', 'error opening "%s"', filename)
        return
    end
    local contents = file:read('*a')
    file:close()
    return contents
end

function verbana.util.table_invert(t)
    local inverted = {}
    for k,v in pairs(t) do inverted[v] = k end
    return inverted
end

function verbana.util.table_reversed(t)
    local len = #t
    local reversed = {}
    for i = len,1,-1 do
        reversed[len - i + 1] = t[i]
    end
    return reversed
end

function verbana.util.table_contains(t, value)
    for _, v in ipairs(t) do
        if v == value then return true end
    end
    return false
end

function verbana.util.parse_time(text)
    if type(text) ~= 'string' then
        return nil
    end
    local n, unit = text:lower():match('^(\d+)([hdwmy])')
    if not (n and unit) then
        return nil
    end
    return n * time_units[unit]
end
