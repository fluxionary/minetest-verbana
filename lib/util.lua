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
