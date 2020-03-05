local data                    = verbana.data
local lib_asn                 = verbana.lib_asn
local lib_ip                  = verbana.lib_ip
local log                     = verbana.log
local privs                   = verbana.privs
local settings                = verbana.settings
local util                    = verbana.util

local safe                    = util.safe
local iso_date                = util.iso_date

local spawn_pos               = settings.spawn_pos
local unverified_spawn_pos    = settings.unverified_spawn_pos
local jail_bounds             = settings.jail_bounds
local jail_check_period       = settings.jail_check_period
local USING_VERIFICATION_JAIL = jail_bounds and jail_check_period

local function should_rejail(player, player_status)
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

local function should_unjail(player, player_status)
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


if USING_VERIFICATION_JAIL then
    local timer = 0
    log('action','initializing rejail globalstep')
    minetest.register_globalstep(function(dtime)
        timer = timer + dtime;
        if timer < jail_check_period then
            return
        end
        timer = 0
        for _, player in ipairs(minetest.get_connected_players()) do
            local name = player:get_player_name()
            local player_id = data.get_player_id(name) -- cached, so not heavy
            local player_status = data.get_player_status(player_id) -- cached, so not heavy
            if should_rejail(player, player_status) then
                log('action', 'rejailing %s', name)
                verbana.chat.tell_mods('%s has escaped verification jail, and is being sent back', name)
                if not settings.debug_mode then
                    player:set_pos(unverified_spawn_pos)
                end
            elseif should_unjail(player, player_status) then
                log('action', 'unjailing %s', name)
                verbana.chat.tell_mods('%s has been removed from verification jail', name)
                if not settings.debug_mode then
                    player:set_pos(spawn_pos)
                end
            end
        end
    end)
end

minetest.register_on_prejoinplayer(safe(function(name, ipstr)
    -- return a string w/ the reason for refusal; otherwise return nothing
    local ipint = lib_ip.ipstr_to_ipint(ipstr)
    local asn, asn_description = lib_asn.lookup(ipint)
    log('action', '[prejoin] %s %s A%s (%s)', name, ipstr, asn, asn_description)

    local player_id = data.get_player_id(name, true) -- will create one if none exists
    if not player_id then
        log('error', '[prejoin] could not retrieve or create id for player %s', name)
        return  -- let them in... it's not their fault :\
    end

    local player_status, is_new_player = data.get_player_status(player_id, true)
    data.register_ip(ipint)
    local ip_status = data.get_ip_status(ipint, true) -- will create one if none exists
    data.register_asn(asn)
    local asn_status = data.get_asn_status(asn, true) -- will create one if none exists

    -- check and clear temporary statuses
    local now = os.time()
    if player_status.expires and now >= player_status.expires then
        local prev_status_name = data.player_status_name[player_status.id]
        log('action', '[prejoin] expiring temp %s of %s', prev_status_name, name)
        local new_status_id
        if player_status.id == data.player_status.suspicious.id then
            new_status_id = data.player_status.default.id
        else
            new_status_id = data.player_status.suspicious.id
        end
        data.set_player_status(player_id, player_status.executor_id, new_status_id, ('temp %s expired'):format(prev_status_name))
        player_status = data.get_player_status(player_id) -- refresh player status
    end
    if ip_status.expires and now >= ip_status.expires then
        local prev_status_name = data.ip_status_name[ip_status.id]
        log('action', '[prejoin] expiring temp %s of %s', prev_status_name, ipstr)
        local new_status_id
        if ip_status.id == data.ip_status.suspicious.id then
            new_status_id = data.ip_status.default.id
        else
            new_status_id = data.ip_status.suspicious.id
        end
        data.set_ip_status(ipint, ip_status.executor_id, new_status_id, ('temp %s expired'):format(prev_status_name))
        ip_status = data.get_ip_status(ipint) -- refresh ip status
    end
    if asn_status.expires and now >= asn_status.expires then
        local prev_status_name = data.asn_status_name[asn_status.id]
        log('action', '[prejoin] expiring temp %s of A%s', prev_status_name, asn)
        local new_status_id
        if asn_status.id == data.asn_status.suspicious.id then
            new_status_id = data.asn_status.default.id
        else
            new_status_id = data.asn_status.suspicious.id
        end
        data.set_asn_status(asn, asn_status.executor_id, new_status_id, ('temp %s expired'):format(prev_status_name))
        asn_status = data.get_asn_status(asn) -- refresh asn status
    end

    -- figure out if the player is suspicious or should be outright rejected
    local suspicious = false
    local return_value

    if player_status.id == data.player_status.banned.id then
        local reason = player_status.reason
        if player_status.expires then
            local expires = iso_date(player_status.expires or now)
            if reason and reason ~= '' then
                return_value = ('Account %q is banned until %s because %q.'):format(name, expires, reason)
            else
                return_value = ('Account %q is banned until %s.'):format(name, expires)
            end
        else
            if reason and reason ~= '' then
                return_value = ('Account %q is banned because %q.'):format(name, reason)
            else
                return_value = ('Account %q is banned.'):format(name)
            end
        end
    elseif player_status.id == data.player_status.whitelisted.id then
        -- if the player is whitelisted, let them in.
        log('action', '[prejoin] %s is whitelisted', name)
    elseif settings.whitelisted_privs and minetest.check_player_privs(name, settings.whitelisted_privs) then
        -- if the player has a whitelisted priv, let them in.
        log('action', '[prejoin] %s whitelisted by privs', name)
    elseif ip_status.id == data.ip_status.trusted.id then
        -- let them in
        log('action', '[prejoin] %s is trusted', ipstr)
    elseif ip_status.id == data.ip_status.suspicious.id then
        suspicious = true
        log('action', '[prejoin] %s is suspicious', ipstr)
    elseif ip_status.id == data.ip_status.blocked.id then
        local reason = ip_status.reason
        if ip_status.expires then
            local expires = iso_date(ip_status.expires or now)
            if reason and reason ~= '' then
                return_value = ('IP %q is blocked until %s because %q.'):format(ipstr, expires, reason)
            else
                return_value = ('IP %q is blocked until %s.'):format(ipstr, expires)
            end
        else
            if reason and reason ~= '' then
                return_value = ('IP %q is blocked because %q.'):format(ipstr, reason)
            else
                return_value = ('IP %q is blocked.'):format(ipstr)
            end
        end
    elseif asn_status.id == data.asn_status.suspicious.id then
        suspicious = true
        log('action', '[prejoin] A%s is suspicious', asn)
    elseif asn_status.id == data.asn_status.blocked.id then
        local reason = asn_status.reason
        if asn_status.expires then
        local expires = iso_date(asn_status.expires or now)
            if reason and reason ~= '' then
                return_value = ('Network %s (%s) is blocked until %s because %q.'):format(asn, asn_description, expires, reason)
            else
                return_value = ('Network %s (%s) is blocked until %s.'):format(asn, asn_description, expires)
            end
        else
            if reason and reason ~= '' then
                return_value = ('Network %s (%s) is blocked because %q.'):format(asn, asn_description, reason)
            else
                return_value = ('Network %s (%s) is blocked.'):format(asn, asn_description)
            end
        end
    end

    if suspicious and not is_new_player then
        -- if the player is new, let them in (truly new players will require verification)
        -- else if the player has never connected from this ip/asn, prevent them from connecting
        -- else let them in (mods will get an alert)
        local has_assoc = data.has_asn_assoc(player_id, asn) or data.has_ip_assoc(player_id, ipint)
        if not has_assoc then
            -- note: if 'suspicious' is true, then 'return_value' should be nil before this
            return_value = 'Suspicious activity detected.'
        end
    end

    if return_value then
        data.log(player_id, ipint, asn, false)
        log('action', 'Connection of %s from %s (A%s) denied because %q', name, ipstr, asn, return_value)
        if not settings.debug_mode then
            return return_value
        end
    else
        log('action', 'Connection of %s from %s (A%s) allowed', name, ipstr, asn)
        data.log(player_id, ipint, asn, true)
        data.assoc(player_id, ipint, asn)
    end
end))

local function move_to(name, pos, max_tries)
    max_tries = max_tries or 5
    local tries = 0
    local function f()
        -- get the player again here, in case they have disconnected
        local player = minetest.get_player_by_name(name)
        if player then
            log('action', 'moving %s to %s', name, minetest.pos_to_string(pos))
            if not settings.debug_mode then
                player:set_pos(pos)
            end
        elseif tries < max_tries then
            tries = tries + 1
            minetest.after(1, f)
        end
    end
    f()
end

minetest.register_on_newplayer(safe(function(player)
    local name = player:get_player_name()
    local player_id = data.get_player_id(name)

    local ipstr = data.fumble_about_for_an_ip(name, player_id)
    local need_to_verify
    if not ipstr then
        -- if we can't figure out where they're coming from, force verification
        log('warning', 'could not discover an IP for new player %s; forcing verification', name)
        need_to_verify = true
    else
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local ip_status = data.get_ip_status(ipint)

        local asn = lib_asn.lookup(ipint)
        local asn_status = data.get_asn_status(asn)

        need_to_verify = (
            settings.universal_verification or
            ip_status.id == data.ip_status.suspicious.id or
            (asn_status.id == data.asn_status.suspicious.id and
             ip_status.id ~= data.ip_status.trusted.id)
        )
    end

    if need_to_verify then
        if not data.set_player_status(player_id, data.verbana_player_id, data.player_status.unverified.id, 'new player connected from suspicious network') then
            log('error', 'error setting unverified status on %s', name)
        end
        if not settings.debug_mode then
            minetest.set_player_privs(name, settings.unverified_privs)
        end
        -- wait a second before moving the player to the verification area
        -- because other mods sometimes try to move them around as well
        minetest.after(1, move_to, name, unverified_spawn_pos)
        log('action', 'new player %s sent to verification', name)
    else
        data.get_player_status(player_id, true) -- create a new status if they don't have one
        log('action', 'new player %s', name)
    end
end))

minetest.register_on_joinplayer(safe(function(player)
    local name = player:get_player_name()
    local player_id = data.get_player_id(name)
    local player_status = data.get_player_status(player_id)
    local is_unverified = player_status.id == data.player_status.unverified.id
    local ipstr = data.fumble_about_for_an_ip(name)
    if is_unverified then
        if ipstr then
            local ipint = lib_ip.ipstr_to_ipint(ipstr)
            local asn, asn_description = lib_asn.lookup(ipint)
            verbana.chat.tell_mods(('*** Player %s from A%s (%s) is unverified.'):format(name, asn, asn_description))
        else
            verbana.chat.tell_mods(('*** Player %s is unverified.'):format(name))
        end
    elseif player_status.id == data.player_status.suspicious.id then
        if ipstr then
            local ipint = lib_ip.ipstr_to_ipint(ipstr)
            local asn, asn_description = lib_asn.lookup(ipint)
            verbana.chat.tell_mods(('*** Player %s from A%s (%s) is suspicious.'):format(name, asn, asn_description))
        else
            verbana.chat.tell_mods(('*** Player %s is suspicious.'):format(name))
        end
    end

    if USING_VERIFICATION_JAIL then
        if should_rejail(player, player_status) then
            log('action', 'spawning %s in verification jail', name)
            if not settings.debug_mode then
                player:set_pos(unverified_spawn_pos)
            end
        elseif should_unjail(player, player_status) then
            log('action', 'removing %s from verification jail on spawn', name)
            if not settings.debug_mode then
                player:set_pos(spawn_pos)
            end
        end
    end
end))

minetest.register_on_auth_fail(safe(function(name, ipstr)
    log('action', 'auth failure: %s %s', name, ipstr)
    local ipint = lib_ip.ipstr_to_ipint(ipstr)
    local asn = lib_asn.lookup(ipint)
    local player_id = data.get_player_id(name, true) -- will create one if none exists

    data.register_ip(ipint)
    data.register_asn(asn)
    data.log(player_id, ipint, asn, false)
end))
