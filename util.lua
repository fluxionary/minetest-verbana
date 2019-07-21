verbana.util = {}

local time_units = {
    h = 60 * 60,
    d = 60 * 60 * 24,
    w = 60 * 60 * 24 * 7,
    m = 60 * 60 * 24 * 30,
    y = 60 * 60 * 24 * 365,
}

function verbana.util.parse_time(text)
    if type(text) ~= 'string' then
        return nil
    end
    local n, unit = text:lower():match('^%s*(%d+)([hdwmy])%s*')
    if not (n and unit) then
        return nil
    end
    return n * time_units[unit]
end

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

function verbana.util.table_is_empty(t)
    for _ in pairs(t) do return false end
    return true
end

function verbana.util.safe(func, rv_on_fail)
    -- wrap a function w/ logic to avoid crashing the game
    return function(...)
        local rvs = {xpcall(func, debug.traceback, ...)}
        if rvs[1] then
            table.remove(rvs, 1)
            return unpack(rvs)
        else
            verbana.log('error', 'Caught error: %s', rvs[2])
            return rv_on_fail
        end
    end
end

function verbana.util.safe_kick_player(caller, player, reason)
    local player_name = player:get_player_name()
    verbana.log('action', 'kicking %s...', player_name)
    if not verbana.settings.debug_mode then
        if not minetest.kick_player(player_name, reason) then
            player:set_detach()
            if not minetest.kick_player(player_name, reason) then
                minetest.chat_send_player(caller, ('Failed to kick player %s after detaching!'):format(player_name))
                verbana.log('warning', 'Failed to kick player %s after detaching!', player_name)
            end
        end
    end
end

function verbana.util.safe_kick_ip(caller, ipstr, reason)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        if minetest.get_player_ip(name) == ipstr then
            verbana.util.safe_kick_player(caller, player, reason)
        end
    end
end

function verbana.util.safe_kick_asn(caller, asn, reason)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local ipstr = minetest.get_player_ip(name)
        local ipint = verbana.lib_ip.ipstr_to_ipint(ipstr)
        if verbana.lib_asn.lookup(ipint) == asn then
            verbana.util.safe_kick_player(caller, player, reason)
        end
    end
end

function verbana.util.iso_date(timestamp)
    return os.date('%Y-%m-%dT%H:%M:%SZ', timestamp)
end

