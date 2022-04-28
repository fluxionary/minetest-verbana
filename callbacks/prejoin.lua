local data                    = verbana.data
local lib_asn                 = verbana.lib.asn
local lib_ip                  = verbana.lib.ip
local log                     = verbana.log
local settings                = verbana.settings
local util                    = verbana.util

local safe                    = util.safe
local iso_date                = util.iso_date

local whitelisted_privs = settings.whitelisted_privs

local function get_player_status(player_id, name, now)
    local player_status, is_new_player = data.get_player_status(player_id, true)

    if player_status.expires and now >= player_status.expires then
        local prev_status_name = data.player_status_name[player_status.id]
        log("action", "[prejoin] expiring temp %s of %s", prev_status_name, name)
        local new_status_id
        if player_status.id == data.player_status.suspicious.id then
            new_status_id = data.player_status.default.id
        else
            new_status_id = data.player_status.suspicious.id
        end
        data.set_player_status(player_id, player_status.executor_id, new_status_id, ("temp %s expired"):format(prev_status_name))
        player_status = data.get_player_status(player_id) -- refresh player status
    end

    return player_status, is_new_player
end

local function get_ip_status(ipint, ipstr, now)
    data.register_ip(ipint)
    local ip_status = data.get_ip_status(ipint, true) -- will create one if none exists

    if ip_status.expires and now >= ip_status.expires then
        local prev_status_name = data.ip_status_name[ip_status.id]
        log("action", "[prejoin] expiring temp %s of %s", prev_status_name, ipstr)
        local new_status_id
        if ip_status.id == data.ip_status.suspicious.id then
            new_status_id = data.ip_status.default.id
        else
            new_status_id = data.ip_status.suspicious.id
        end
        data.set_ip_status(ipint, ip_status.executor_id, new_status_id, ("temp %s expired"):format(prev_status_name))
        ip_status = data.get_ip_status(ipint) -- refresh ip status
    end

    return ip_status
end

local function get_asn_status(asn, now)
    data.register_asn(asn)
    local asn_status = data.get_asn_status(asn, true) -- will create one if none exists

    if asn_status.expires and now >= asn_status.expires then
        local prev_status_name = data.asn_status_name[asn_status.id]
        log("action", "[prejoin] expiring temp %s of A%s", prev_status_name, asn)
        local new_status_id
        if asn_status.id == data.asn_status.suspicious.id then
            new_status_id = data.asn_status.default.id
        else
            new_status_id = data.asn_status.suspicious.id
        end
        data.set_asn_status(asn, asn_status.executor_id, new_status_id, ("temp %s expired"):format(prev_status_name))
        asn_status = data.get_asn_status(asn) -- refresh asn status
    end

    return asn_status
end

local function reason_player_banned(player_status, name, now)
    local reason = player_status.reason
    if player_status.expires then
        local expires = iso_date(player_status.expires or now)
        if reason and reason ~= "" then
            return ("Account %q is banned until %s because %q."):format(name, expires, reason)
        else
            return ("Account %q is banned until %s."):format(name, expires)
        end
    else
        if reason and reason ~= "" then
            return ("Account %q is banned because %q."):format(name, reason)
        else
            return ("Account %q is banned."):format(name)
        end
    end
end

local function reason_ip_blocked(ip_status, ipstr, now)
    local reason = ip_status.reason
    if ip_status.expires then
        local expires = iso_date(ip_status.expires or now)
        if reason and reason ~= "" then
            return ("IP %q is blocked until %s because %q."):format(ipstr, expires, reason)
        else
            return ("IP %q is blocked until %s."):format(ipstr, expires)
        end
    else
        if reason and reason ~= "" then
            return ("IP %q is blocked because %q."):format(ipstr, reason)
        else
            return ("IP %q is blocked."):format(ipstr)
        end
    end
end

local function reason_asn_blocked(asn_status, asn, now)
    local reason = asn_status.reason
    if asn_status.expires then
    local expires = iso_date(asn_status.expires or now)
        if reason and reason ~= "" then
            return ("Network %s (%s) is blocked until %s because %q."):format(asn, asn_description, expires, reason)
        else
            return ("Network %s (%s) is blocked until %s."):format(asn, asn_description, expires)
        end
    else
        if reason and reason ~= "" then
            return ("Network %s (%s) is blocked because %q."):format(asn, asn_description, reason)
        else
            return ("Network %s (%s) is blocked."):format(asn, asn_description)
        end
    end
end

local function is_player_banned(player_status)
    return player_status.id == data.player_status.banned.id
end

local function is_player_whitelisted(player_status)
    return player_status.id == data.player_status.whitelisted.id
end

local function is_player_whitelisted_privs(name)
    return whitelisted_privs and minetest.check_player_privs(name, settings)
end

local function is_ip_trusted(ip_status)
    return ip_status.id == data.ip_status.trusted.id
end

local function is_ip_suspicious(ip_status)
    return ip_status.id == data.ip_status.suspicious.id
end

local function is_ip_blocked(ip_status)
    return ip_status.id == data.ip_status.blocked.id
end

local function is_asn_suspicious(asn_status)
    return asn_status.id == data.asn_status.suspicious.id
end

local function is_asn_blocked(asn_status)
    return asn_status.id == data.asn_status.blocked.id
end

local function check_status(player_id, name, ipint, ipstr, asn)
    --check and clear temporary statuses
    local now = os.time()
    local player_status, is_new_player = get_player_status(player_id, name, now)
    local ip_status = get_ip_status(ipint, ipstr, now)
    local asn_status = get_asn_status(asn, now)

    -- figure out if the player is suspicious or should be outright rejected
    local suspicious = false
    local return_value

    if is_player_banned(player_status) then
        return_value = reason_player_banned(player_status, name, now)

    elseif is_player_whitelisted(player_status) then
        -- if the player is whitelisted, let them in.
        log("action", "[prejoin] %s is whitelisted", name)

    elseif is_player_whitelisted_privs(name) then
        -- if the player has a whitelisted priv, let them in.
        log("action", "[prejoin] %s whitelisted by privs", name)

    elseif is_ip_trusted(ip_status) then
        -- let them in
        log("action", "[prejoin] %s is trusted", ipstr)

    elseif is_ip_suspicious(ip_status) then
        suspicious = true
        log("action", "[prejoin] %s is suspicious", ipstr)

    elseif is_ip_blocked(ip_status) then
        return_value = reason_ip_blocked(ip_status, ipstr, now)

    elseif is_asn_suspicious(asn_status) then
        suspicious = true
        log("action", "[prejoin] A%s is suspicious", asn)

    elseif is_asn_blocked(asn_status) then
        return_value = reason_asn_blocked(asn_status, asn, now)
    end

    if suspicious and not return_value and not is_new_player then
        -- note: if "suspicious" is true, then "return_value" should be nil before this

        -- if the player is new, let them in, where they will end up in verification jail
        -- else if the player has never connected from this ip/asn, prevent them from connecting (possible hacking)
        -- else let them in (probably nothing bad; mods will get an alert about possible hacking)
        local has_assoc = data.has_asn_assoc(player_id, asn) or data.has_ip_assoc(player_id, ipint)
        if not has_assoc then
            return_value = "Suspicious activity detected."
        end
    end

    return return_value
end

minetest.register_on_prejoinplayer(safe(function(name, ipstr)
    -- return a string w/ the reason for refusal; otherwise return nothing
    local ipint = lib_ip.ipstr_to_ipint(ipstr)
    local asn, asn_description = lib_asn.lookup(ipint)
    log("action", "[prejoin] %s %s A%s (%s)", name, ipstr, asn, asn_description)

    local player_id = data.get_player_id(name, true) -- will create one if none exists
    if not player_id then
        log("error", "[prejoin] could not retrieve or create id for player %s", name)
        return  -- let them in... it's not their fault :\
    end

    local return_value = check_status(player_id, name, ipint, ipstr, asn)

    if return_value then
        data.log(player_id, ipint, asn, false)
        log("action", "Connection of %s from %s (A%s) denied because %q", name, ipstr, asn, return_value)
        if not settings.debug_mode then
            return return_value
        end
    else
        log("action", "Connection of %s from %s (A%s) allowed", name, ipstr, asn)
        data.log(player_id, ipint, asn, true)
        -- don't log associations here, because the login may still fail due to an invalid password
    end
end))
