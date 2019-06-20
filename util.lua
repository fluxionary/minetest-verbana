verbana.util = {}

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

