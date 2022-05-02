verbana.util = {}

local settings = verbana.settings

local jail_bounds = settings.jail_bounds

local time_units = {
    h = 60 * 60,
    d = 60 * 60 * 24,
    w = 60 * 60 * 24 * 7,
    m = 60 * 60 * 24 * 30,
    y = 60 * 60 * 24 * 365,
}

function verbana.util.is_u8(i)
    return (
        type(i) == "number" and
        math.round(i) == i and
        0 <= i and
        i <= 0xFF
    )
end

function verbana.util.is_u16(i)
    return (
        type(i) == "number" and
        math.round(i) == i and
        0 <= i and
        i <= 0xFFFF
    )
end

function verbana.util.parse_timespan(text)
    if type(text) ~= "string" then
        return nil
    end
    local n, unit = text:lower():match("^%s*(%d+)([hdwmy])%s*")
    n = tonumber(n)
    if not (n and unit) then
        return nil
    end
    return n * time_units[unit]
end

function verbana.util.file_exists(filename)
   local handle = io.open(filename,"r")
   if handle then
       io.close(handle)
       return true
   else
       return false
   end
end

function verbana.util.load_file(filename)
    local file = io.open(filename, "r")

    if not file then
        verbana.log("error", "error opening %q", filename)
        return
    end

    local contents = file:read("*a")
    file:close()
    return contents
end

function verbana.util.write_file(filename, contents)
    local file = io.open(filename, "w")

    if not file then
        verbana.log("error", "error opening %q for writing", filename)
        return false
    end

    file:write(contents)
    file:close()

    return true
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

function verbana.util.iso_date(timestamp)
    return os.date("%Y-%m-%dT%H:%M:%SZ", timestamp)
end

function verbana.util.safe(func, rv_on_fail)
    -- wrap a function w/ logic to avoid crashing the game
    return function(...)
        local rvs = {xpcall(func, debug.traceback, ...)}
        if rvs[1] then
            table.remove(rvs, 1)
            return unpack(rvs)
        else
            verbana.log("error", "Caught error: %s", rvs[2])
            return rv_on_fail
        end
    end
end

function verbana.util.get_player_ip(player_name)
    if type(player_name) ~= "string" then
        player_name = player_name:get_player_name()
    end

    local ipstr = minetest.get_player_ip(player_name)

    -- for some reason, get_player_ip is unreliable during register_on_newplayer
    if not ipstr then
        local info = minetest.get_player_information(player_name)
        if info then
            ipstr = info.address
        end
    end

    return ipstr
end

function verbana.util.safe_kick_player(caller, player, reason)
    local player_name = player:get_player_name()
    verbana.log("action", "kicking %s...", player_name)

    if verbana.settings.debug_mode then
        return

    elseif not minetest.kick_player(player_name, reason) then
        player:set_detach()
        if not minetest.kick_player(player_name, reason) then
            verbana.chat.send_player(caller, "Failed to kick player %s after detaching!", player_name)
            verbana.log("error", "Failed to kick player %s after detaching!", player_name)
        end
    end
end

function verbana.util.safe_kick_ip(caller, ipstr, reason)
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_name = player:get_player_name()
        if verbana.util.get_player_ip(player_name) == ipstr then
            verbana.util.safe_kick_player(caller, player, reason)
        end
    end
end

function verbana.util.safe_kick_asn(caller, asn, reason)
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_name = player:get_player_name()
        local ipstr = verbana.util.get_player_ip(player_name)
        local ipint = verbana.lib.ip.ipstr_to_ipint(ipstr)

        if verbana.lib.asn.lookup(ipint) == asn then
            verbana.util.safe_kick_player(caller, player, reason)
        end
    end
end

function verbana.util.should_rejail(player, player_status)
    if not jail_bounds then
        return false
    end

    if player_status.id ~= data.player_status.unverified.id then
        return false
    end

    local pos = player:get_pos()
    return not (
        jail_bounds[1].x - 1 <= pos.x and pos.x <= jail_bounds[2].x + 1 and
        jail_bounds[1].y - 1 <= pos.y and pos.y <= jail_bounds[2].y + 1 and
        jail_bounds[1].z - 1 <= pos.z and pos.z <= jail_bounds[2].z + 1
    )
end

function verbana.util.should_unjail(player, player_status)
    if not jail_bounds then
        return false
    end
    
    if player_status.id == data.player_status.unverified.id then
        return false

    elseif privs.is_privileged(player:get_player_name()) then
        return false
    end

    local pos = player:get_pos()
    return (
        jail_bounds[1].x - 1 <= pos.x and pos.x <= jail_bounds[2].x + 1 and
        jail_bounds[1].y - 1 <= pos.y and pos.y <= jail_bounds[2].y + 1 and
        jail_bounds[1].z - 1 <= pos.z and pos.z <= jail_bounds[2].z + 1
    )
end
