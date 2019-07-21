verbana.commands = {}

local data = verbana.data
local lib_asn = verbana.lib_asn
local lib_ip = verbana.lib_ip
local log = verbana.log
local settings = verbana.settings
local util = verbana.util

local mod_priv = verbana.privs.moderator
local admin_priv = verbana.privs.admin
local debug_mode = settings.debug_mode

local parse_time = util.parse_time
local safe = util.safe
local safe_kick_player = util.safe_kick_player
local table_contains = util.table_contains
local iso_date = util.iso_date

local function chat_send_player(name, message, ...)
    message = message:format(...)
    minetest.chat_send_player(name, message)
end

local function register_chatcommand(name, def)
    if debug_mode then name = ('v_%s'):format(name) end
    def.func = safe(def.func)
    minetest.register_chatcommand(name, def)
end

local function override_chatcommand(name, def)
    def.func = safe(def.func)
    if debug_mode then
        name = ('v_%s'):format(name)
        minetest.register_chatcommand(name, def)
    else
        minetest.override_chatcommand(name, def)
    end
end

local function alias_chatcommand(name, existing_name)
    if debug_mode then
        name = ('v_%s'):format(name)
        existing_name = ('v_%s'):format(existing_name)
    end
    local existing_def = minetest.registered_chatcommands[existing_name]
    if not existing_def then
        verbana.log('error', 'Could not alias command %q to %q, because %q doesn\'t exist', name, existing_name, existing_name)
    else
        minetest.register_chatcommand(name, existing_def)
    end

end

register_chatcommand('sban_import', {
    description='Import records from sban',
    params='[<filename>]',
    privs={[admin_priv]=true},
    func=function (caller, filename)
        if not filename or filename == '' then
            filename = minetest.get_worldpath() .. '/sban.sqlite'
        end
        if not io.open(filename, 'r') then
            return false, ('Could not open file %q.'):format(filename)
        end
        chat_send_player(caller, 'Importing SBAN. This can take a while...')
        if data.import_from_sban(filename) then
            return true, 'Successfully imported.'
        else
            return false, 'Error importing SBAN db (see server log)'
        end
    end
})

register_chatcommand('verification', {
    description='Turn universal verification on or off',
    params='on | off',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local value
        if params == 'on' then
            value = true
        elseif params == 'off' then
            value = false
        else
            return false, 'Invalid paramters'
        end
        if verbana.settings.universal_verification == value then
            return true, ('Universal verification is already %s'):format(params)
        end
        verbana.settings.set_universal_verification(value)
        return true, ('Turned universal verification %s'):format(params)
    end
})

register_chatcommand('asn', {
    description='Get the ASN associated with an IP or player name',
    params='<player_name> | <IP>',
    privs={[mod_priv]=true},
    func = function(_, name_or_ipstr)
        local ipstr

        if lib_ip.is_valid_ip(name_or_ipstr) then
            ipstr = name_or_ipstr
        else
            ipstr = data.fumble_about_for_an_ip(name_or_ipstr)
        end

        if not ipstr or ipstr == '' then
            return false, ('"%s" is not a valid ip nor a known player'):format(name_or_ipstr)
        end

        local asn, description = lib_asn.lookup(ipstr)
        if not asn or asn == 0 then
            return false, ('could not find ASN for "%s"'):format(ipstr)
        end

        description = description or ''

        return true, ('A%u (%s)'):format(asn, description)
    end
})
----------------- SET PLAYER STATUS COMMANDS -----------------
local function parse_player_status_params(params)
    local name, reason = params:match('^([a-zA-Z0-9_-]+)%s+(.*)$')
    if not name then
        name = params:match('^([a-zA-Z0-9_-]+)$')
    end
    if not name or name:len() > 20 then
        return nil, nil, nil, ('Invalid argument(s): %q'):format(params)
    end
    local player_id = data.get_player_id(name)
    if not player_id then
        return nil, nil, nil, ('Unknown player: %s'):format(name)
    end
    local player_status = data.get_player_status(player_id, true)
    return player_id, name, player_status, reason
end

local function has_suspicious_connection(player_id)
    local connection_log = data.get_player_connection_log(player_id, 1)
    if not connection_log or #connection_log ~= 1 then
        log('warning', 'player %s exists but has no connection log?', player_id)
        return true
    end
    local last_login = connection_log[1]
    if last_login.ip_status_id == data.ip_status.trusted.id then
        return false
    elseif last_login.ip_status_id and last_login.ip_status_id ~= data.ip_status.default.id then
        return true
    elseif last_login.asn_status_id == data.asn_status.default.id then
        return false
    end
    return true
end

register_chatcommand('verify', {
    description='Verify a player',
    params='<player_name> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        if player_status.id ~= data.player_status.unverified.id then
            return false, ('Player %s is not unverified'):format(player_name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        local status_id
        if has_suspicious_connection(player_id) then
            status_id = data.player_status.suspicious.id
        else
            status_id = data.player_status.default.id
        end
        if not data.set_player_status(player_id, executor_id, status_id, reason) then
            return false, 'ERROR setting player status'
        end
        log('action', 'setting verified privs for %s', player_name)
        if not debug_mode then
            minetest.set_player_privs(player_name, settings.verified_privs)
        end
        local player = minetest.get_player_by_name(player_name)
        if player then
            log('action', 'moving %s to spawn', player_name)
            if not debug_mode then
                player:set_pos(settings.spawn_pos)
            end
        end
        if reason then
            log('action', '%s verified %s because %s', caller, player_name, reason)
        else
            log('action', '%s verified %s', caller, player_name)
        end
        return true, ('Verified %s'):format(player_name)
    end
})

register_chatcommand('unverify', {
    description='Unverify a player, revoking privs and putting them back in jail.',
    params='<player_name> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        if not table_contains({
                data.player_status.default.id,
                data.player_status.suspicious.id,
            }, player_status.id) then
            return false, ('Cannot unverify %s w/ status %s'):format(player_name, player_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_player_status(player_id, executor_id, data.player_status.unverified.id, reason) then
            return false, 'ERROR setting player status'
        end
        log('action', 'setting unverified privs for %s', player_name)
        if not debug_mode then
            minetest.set_player_privs(player_name, settings.unverified_privs)
        end
        local player = minetest.get_player_by_name(player_name)
        if player then
            log('action', 'moving %s to unverified area', player_name)
            if not debug_mode then
                player:set_pos(settings.unverified_spawn_pos)
            end
        end
        if reason then
            log('action', '%s unverified %s because %s', caller, player_name, reason)
        else
            log('action', '%s unverified %s', caller, player_name)
        end
        return true, ('Unverified %s'):format(player_name)
    end
})

override_chatcommand('kick', {
    description='Kick a player',
    params='<player_name> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, _, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
		local player = minetest.get_player_by_name(player_name)
		if not player then
			return false, ("Player %s not in game!"):format(player_name)
        end
        safe_kick_player(caller, player, reason)
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_player_status(player_id, executor_id, data.player_status.kicked.id, reason, nil, true) then
            return false, 'ERROR logging player status'
        end
        if reason then
            log('action', '%s kicked %s because %s', caller, player_name, reason)
        else
            log('action', '%s kicked %s', caller, player_name)
        end
        return true, ('Kicked %s'):format(player_name)
    end
})

override_chatcommand('ban', {
    description='Ban a player. Timespan and reason are optional.',
    params='<player_name> [<timespan>] [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        local timespan
        local expires
        if reason then
            local first = reason:match('^(%S+)')
            timespan = parse_time(first)
            if timespan then
                reason = reason:sub(first:len() + 2)
                expires = os.time() + timespan
            end
        end
        if not table_contains({
                data.player_status.default.id,
                data.player_status.unverified.id,
                data.player_status.suspicious.id,
            }, player_status.id) then
            return false, ('Cannot ban %s w/ status %s'):format(player_name, player_status.name)
        end
		local player = minetest.get_player_by_name(player_name)
        if player then
            safe_kick_player(caller, player, reason)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_player_status(player_id, executor_id, data.player_status.banned.id, reason, expires) then
            return false, 'ERROR logging player status'
        end
        if expires then
            if reason then
                log('action', '%s banned %s until %s because %s', caller, player_name, iso_date(expires), reason)
            else
                log('action', '%s banned %s until %s', caller, player_name, iso_date(expires))
            end
        else
            if reason then
                log('action', '%s banned %s because %s', caller, player_name, reason)
            else
                log('action', '%s banned %s', caller, player_name)
            end
        end
        return true, ('Banned %s'):format(player_name)
    end
})

override_chatcommand('unban', {
    description='Unban a player',
    params='<player_name> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        if player_status.id ~= data.player_status.banned.id then
            return false, ('Player %s is not banned!'):format(player_name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        local status_id
        if has_suspicious_connection(player_id) then
            status_id = data.player_status.suspicious.id
        else
            status_id = data.player_status.default.id
        end
        if not data.set_player_status(player_id, executor_id, status_id, reason) then
            return false, 'ERROR setting player status'
        end
        if reason then
            log('action', '%s unbanned %s because %s', caller, player_name, reason)
        else
            log('action', '%s unbanned %s', caller, player_name)
        end
        return true, ('Unbanned %s'):format(player_name)
    end
})

register_chatcommand('whitelist', {
    description='Whitelist a player',
    params='<player_name> [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        if not table_contains({
                data.player_status.default.id,
                data.player_status.unverified.id,
                data.player_status.suspicious.id,
            }, player_status.id) then
            return false, ('Cannot whitelist %s w/ status %s'):format(player_name, player_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_player_status(player_id, executor_id, data.player_status.whitelisted.id, reason) then
            return false, 'ERROR setting player status'
        end
        if reason then
            log('action', '%s whitelisted %s because %s', caller, player_name, reason)
        else
            log('action', '%s whitelisted %s', caller, player_name)
        end
        return true, ('Whitelisted %s'):format(player_name)
    end
})

register_chatcommand('unwhitelist', {
    description='Remove whitelist status from a player',
    params='<player_name> [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        if player_status.id ~= data.player_status.whitelisted.id then
            return false, ('Player %s is not whitelisted!'):format(player_name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_player_status(player_id, executor_id, data.player_status.default.id, reason) then
            return false, 'ERROR setting player status'
        end
        if reason then
            log('action', '%s unwhitelisted %s because %s', caller, player_name, reason)
        else
            log('action', '%s unwhitelisted %s', caller, player_name)
        end
        return true, ('Unwhitelisted %s'):format(player_name)
    end
})

register_chatcommand('suspect', {
    description='Mark a player as suspicious',
    params='<player_name> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        if player_status.id ~= data.player_status.default.id then
            return false, ('Cannot whitelist %s w/ status %s'):format(player_name, player_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_player_status(player_id, executor_id, data.player_status.suspicious.id, reason) then
            return false, 'ERROR setting player status'
        end
        if reason then
            log('action', '%s suspected %s because %s', caller, player_name, reason)
        else
            log('action', '%s suspected %s', caller, player_name)
        end
        return true, ('Suspected %s'):format(player_name)
    end
})

register_chatcommand('unsuspect', {
    description='Unmark a player as suspicious',
    params='<player_name> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        if player_status.id ~= data.player_status.suspicious.id then
            return false, ('Player %s is not suspicious!'):format(player_name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_player_status(player_id, executor_id, data.player_status.default.id, reason) then
            return false, 'ERROR setting player status'
        end
        if reason then
            log('action', '%s unsuspected %s because %s', caller, player_name, reason)
        else
            log('action', '%s unsuspected %s', caller, player_name)
        end
        return true, ('Unsuspected %s'):format(player_name)
    end
})
----------------- SET IP STATUS COMMANDS -----------------
local function parse_ip_status_params(params)
    local ipstr, reason = params:match('^(%d+%.%d+%.%d+%.%d+)%s+(.*)$')
    if not ipstr then
        ipstr = params:match('^(%d+%.%d+%.%d+%.%d+)$')
    end
    if not ipstr or not lib_ip.is_valid_ip(ipstr) then
        return nil, nil, nil, ('Invalid argument(s): %q'):format(params)
    end
    local ipint = lib_ip.ipstr_to_ipint(ipstr)
    data.register_ip(ipint)
    local ip_status = data.get_ip_status(ipint, true)
    return ipint, ipstr, ip_status, reason
end

register_chatcommand('ip_trust', {
    description='Mark an IP as trusted - connections will bypass suspicious network checks',
    params='<IP> [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if not table_contains({
                data.ip_status.default.id,
                data.ip_status.suspicious.id,
            }, ip_status.id) then
            return false, ('Cannot trust IP w/ status %s'):format(ip_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.trusted.id, reason) then
            return false, 'ERROR setting IP status'
        end
        if reason then
            log('action', '%s trusted %s because %s', caller, ipstr, reason)
        else
            log('action', '%s trusted %s', caller, ipstr)
        end
        return true, ('Trusted %s'):format(ipstr)
    end
})

register_chatcommand('ip_untrust', {
    description='Remove trusted status from an IP',
    params='<IP> [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.player_status.trusted.id then
            return false, ('IP %s is not trusted!'):format(ipstr)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.default.id, reason) then
            return false, 'ERROR setting IP status'
        end
        if reason then
            log('action', '%s untrusted %s because %s', caller, ipstr, reason)
        else
            log('action', '%s untrusted %s', caller, ipstr)
        end
        return true, ('Untrusted %s'):format(ipstr)
    end
})

register_chatcommand('ip_suspect', {
    description='Mark an IP as suspicious.',
    params='<IP> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.ip_status.default.id then
            return false, ('Cannot suspect IP w/ status %s'):format(ip_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.suspicious.id, reason) then
            return false, 'ERROR setting IP status'
        end
        if reason then
            log('action', '%s suspected %s because %s', caller, ipstr, reason)
        else
            log('action', '%s suspected %s', caller, ipstr)
        end
        return true, ('Suspected %s'):format(ipstr)
    end
})

register_chatcommand('ip_unsuspect', {
    description='Unmark an IP as suspcious',
    params='<IP> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.player_status.suspicious.id then
            return false, ('IP %s is not suspicious!'):format(ipstr)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.default.id, reason) then
            return false, 'ERROR setting IP status'
        end
        if reason then
            log('action', '%s unsuspected %s because %s', caller, ipstr, reason)
        else
            log('action', '%s unsuspected %s', caller, ipstr)
        end
        return true, ('Unsuspected %s'):format(ipstr)
    end
})

register_chatcommand('ip_block', {
    description='Block an IP from connecting.',
    params='<IP> [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        local timespan
        local expires
        if reason then
            local first = reason:match('^(%S+)')
            timespan = parse_time(first)
            if timespan then
                reason = reason:sub(first:len() + 2)
                expires = os.time() + timespan
            end
        end
        if not table_contains({
                data.ip_status.default.id,
                data.ip_status.suspicious.id,
            }, ip_status.id) then
            return false, ('Cannot block IP w/ status %s'):format(ip_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.blocked.id, reason, expires) then
            return false, 'ERROR setting IP status'
        end
        util.safe_kick_ip(ipstr)
        if expires then
            if reason then
                log('action', '%s blocked %s until %s because %s', caller, ipstr, iso_date(expires), reason)
            else
                log('action', '%s blocked %s until %s', caller, ipstr, iso_date(expires))
            end
        else
            if reason then
                log('action', '%s blocked %s because %s', caller, ipstr, reason)
            else
                log('action', '%s blocked %s', caller, ipstr)
            end
        end
        return true, ('Blocked %s'):format(ipstr)
    end
})

register_chatcommand('ip_unblock', {
    description='Unblock an IP',
    params='<IP> [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.ip_status.blocked.id then
            return false, 'IP is not blocked!'
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.default.id, reason) then
            return false, 'ERROR setting IP status'
        end
        if reason then
            log('action', '%s unblocked %s because %s', caller, ipstr, reason)
        else
            log('action', '%s unblocked %s', caller, ipstr)
        end
        return true, ('Unblocked %s'):format(ipstr)
    end
})
----------------- SET ASN STATUS COMMANDS -----------------
local function parse_asn_status_params(params)
    local asnstr, reason = params:match('^A?(%d+)%s+(.*)$')
    if not asnstr then
        asnstr = params:match('^A?(%d+)$')
    end
    if not asnstr then
        return nil, nil, nil, ('Invalid argument(s): %q'):format(params)
    end
    local asn = tonumber(asnstr)
    local description = lib_asn.get_description(asn)
    if description == lib_asn.invalid_asn_description then
        return nil, nil, nil, ('Not a valid ASN: %q'):format(params)
    end
    data.register_asn(asn)
    local asn_status = data.get_asn_status(asn, true)
    return asn, description, asn_status, reason
end

register_chatcommand('asn_suspect', {
    description='Mark an ASN as suspicious.',
    params='<ASN> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        if asn_status.id ~= data.asn_status.default.id then
            return false, ('Cannot suspect ASN w/ status %s'):format(asn_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.suspicious.id, reason) then
            return false, 'ERROR setting ASN status'
        end
        if reason then
            log('action', '%s suspected A%s because %s', caller, asn, reason)
        else
            log('action', '%s suspected A%s', caller, asn)
        end
        return true, ('Suspected A%s'):format(asn)
    end
})

register_chatcommand('asn_unsuspect', {
    description='Unmark an ASN as suspcious.',
    params='<ASN> [<reason>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        if asn_status.id ~= data.asn_status.suspicious.id then
            return false, ('A%s is not suspicious!'):format(asn)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.default.id, reason) then
            return false, 'ERROR setting ASN status'
        end
        if reason then
            log('action', '%s unsuspected A%s because %s', caller, asn, reason)
        else
            log('action', '%s unsuspected A%s', caller, asn)
        end
        return true, ('Unsuspected A%s'):format(asn)
    end
})

register_chatcommand('asn_block', {
    description='Block an ASN. Duration and reason optional.',
    params='<ASN> [<duration>] [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        local timespan
        local expires
        if reason then
            local first = reason:match('^(%S+)')
            timespan = parse_time(first)
            if timespan then
                reason = reason:sub(first:len() + 2)
                expires = os.time() + timespan
            end
        end
        if not table_contains({
                data.asn_status.default.id,
                data.asn_status.suspicious.id,
            }, asn_status.id) then
            return false, ('Cannot block ASN w/ status %s'):format(asn_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.blocked.id, reason, expires) then
            return false, 'ERROR setting ASN status'
        end
        util.safe_kick_asn(asn)
        if expires then
            if reason then
                log('action', '%s blocked A%s until %s because %s', caller, asn, iso_date(expires), reason)
            else
                log('action', '%s blocked A%s until %s ', caller, asn, iso_date(expires))
            end
        else
            if reason then
                log('action', '%s blocked A%s because %s', caller, asn, reason)
            else
                log('action', '%s blocked A%s', caller, asn)
            end
        end
        return true, ('Blocked A%s'):format(asn)
    end
})

register_chatcommand('asn_unblock', {
    description='Unblock an ASN.',
    params='<ASN> [<reason>]',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        if asn_status.id ~= data.asn_status.blocked.id then
            return false, 'ASN is not blocked!'
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, 'ERROR: could not get executor ID?'
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.default.id, reason) then
            return false, 'ERROR setting IP status'
        end
        if reason then
            log('action', '%s unblocked A%s because %s', caller, asn, reason)
        else
            log('action', '%s unblocked A%s', caller, asn)
        end
        return true, ('Unblocked A%s'):format(asn)
    end
})
---------------- GET LOGS ---------------
register_chatcommand('ban_record', {
    description='shows the status log of a player',
    params='<player_name> [<number>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local name, numberstr = string.match(params, '^([%a%d_-]+)%s+(%d+)$')
        if not name then
            name = string.match(params, '^([%a%d_-]+)$')
        end
        if not name then
            return false, 'invalid arguments'
        end
        local player_id = data.get_player_id(name)
        if not player_id then
            return false, 'unknown player'
        end
        local rows = data.get_player_status_log(player_id)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        local starti
        if numberstr then
            local number = tonumber(numberstr)
            starti = math.max(1, #rows - number)
        else
            starti = 1
        end
        for index = starti,#rows do
            local row = rows[index]
            local message = ('%s: %s set status to %s.'):format(
                iso_date(row.timestamp),
                row.executor_name,
                row.status_name
            )
            local reason = row.reason
            if reason and reason ~= '' then
                message = ('%s Reason: %s'):format(message, reason)
            end
            local expires = row.expires
            if expires then
                message = ('%s Expires: %s'):format(message, iso_date(expires))
            end
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('ip_record', {
    description='shows the status log of an IP',
    params='<IP> [<number>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipstr, numberstr = string.match(params, '^(%d+%.%d+%.%d+%.%d+)%s+(%d+)$')
        if not ipstr then
            ipstr = string.match(params, '^(%d+%.%d+%.%d+%.%d+)$')
        end
        if not ipstr or not lib_ip.is_valid_ip(ipstr) then
            return false, 'invalid arguments'
        end
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local rows = data.get_ip_status_log(ipint)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        local starti
        if numberstr then
            local number = tonumber(numberstr)
            starti = math.max(1, #rows - number)
        else
            starti = 1
        end
        for index = starti,#rows do
            local row = rows[index]
            local message = ('%s: %s set status to %s.'):format(
                iso_date(row.timestamp),
                row.executor_name,
                row.status_name
            )
            local reason = row.reason
            if reason and reason ~= '' then
                message = ('%s Reason: %s'):format(message, reason)
            end
            local expires = row.expires
            if expires then
                message = ('%s Expires: %s'):format(message, iso_date(expires))
            end
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('asn_record', {
    description='shows the status log of an ASN',
    params='<ASN> [<number>]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asnstr, numberstr = string.match(params, '^A?(%d+)%s+(%d+)$')
        if not asnstr then
            asnstr = string.match(params, '^A?(%d+)$')
            if not asnstr then
                return false, 'invalid arguments'
            end
        end
        local asn = tonumber(asnstr)
        local rows = data.get_asn_status_log(asn)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        local starti
        if numberstr then
            local number = tonumber(numberstr)
            starti = math.max(1, #rows - number)
        else
            starti = 1
        end
        for index = starti,#rows do
            local row = rows[index]
            local message = ('%s: %s set status to %s.'):format(
                iso_date(row.timestamp),
                row.executor_name,
                row.status_name
            )
            local reason = row.reason
            if reason and reason ~= '' then
                message = ('%s Reason: %s'):format(message, reason)
            end
            local expires = row.expires
            if expires then
                message = ('%s Expires: %s'):format(message, iso_date(expires))
            end
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('logins', {
    description='shows the login record of a player',
    params='<player_name> [<number>=20]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local name, limit = params:match('^([a-zA-Z0-9_-]+)%s+(%d+)$')
        limit = tonumber(limit)
        if not name then
            name = params:match('^([a-zA-Z0-9_-]+)$')
            limit = 20
        end
        if not name or not limit then
            return false, 'Invalid arguments'
        end
        local player_id = data.get_player_id(name)
        if not player_id then
            return false, 'Unknown player'
        end
        local rows = data.get_player_connection_log(player_id, limit)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        for _, row in ipairs(rows) do
            local message = ('%s:%s from %s<%s> A%s<%s> (%s)'):format(
                iso_date(row.timestamp),
                (rows.success and ' failed!') or '',
                lib_ip.ipint_to_ipstr(row.ipint),
                data.ip_status_name[row.ip_status_id or data.ip_status.default.id],
                row.asn,
                data.asn_status_name[row.asn_status_id or data.asn_status.default.id],
                lib_asn.get_description(row.asn)
            )
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('inspect', {
    description='List IPs and ASNs associated with a player',
    params='<player_name>',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local name = params:match('^([a-zA-Z0-9_-]+)$')
        if not name or name:len() > 20 then
            return false, 'Invalid argument'
        end
        local player_id = data.get_player_id(name)
        if not player_id then
            return false, 'Unknown player'
        end
        local rows = data.get_player_associations(player_id)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        chat_send_player(caller, ('Records for %s'):format(name))
        for _, row in ipairs(rows) do
            local ipstr = lib_ip.ipint_to_ipstr(row.ipint)
            local asn_description = lib_asn.get_description(row.asn)
            local message = ('%s<%s> A%s (%s) <%s>'):format(
                ipstr,
                data.ip_status_name[row.ip_status_id or data.ip_status.default.id],
                row.asn,
                asn_description,
                data.asn_status_name[row.asn_status_id or data.asn_status.default.id]
            )
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('ip_inspect', {
    description='list player accounts and statuses associated with an IP',
    params='<IP> [<timespan>=1w]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipstr, timespan_str = params:match('^(%d+%.%d+%.%d+%.%d+)%s+(%w+)$')
        if not lib_ip.is_valid_ip(ipstr) then
            ipstr = params:match('^%s*(%d+%.%d+%.%d+%.%d+)%s*$')
            if not lib_ip.is_valid_ip(ipstr) then
                return false, 'Invalid arguments'
            end
        end
        local timespan
        if timespan_str then
            timespan = parse_time(timespan_str)
            if not timespan then
                return false, 'Invalid timespan'
            end
        else
            timespan = 60*60*24*7
        end
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local start_time = os.time() - timespan
        local rows = data.get_ip_associations(ipint, timespan)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        chat_send_player(caller, ('Records for %s'):format(ipstr))
        for _, row in ipairs(rows) do
            local message = ('% 20s: %s'):format(
                row.player_name,
                data.player_status_name[row.player_status_id or data.player_status.default.id]
            )
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('asn_inspect', {
    description='list player accounts and statuses associated with an ASN',
    params='<ASN> [<timespan>=1w]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asn, timespan_str = params:match('^A?(%d+)%s+(%w+)$')
        if not asn then
            asn = params:match('^A?(%d+)$')
            if not asn then
                return false, 'Invalid argument'
            end
        end
        local timespan
        if timespan_str then
            timespan = parse_time(timespan_str)
            if not timespan then
                return false, 'Invalid timespan'
            end
        else
            timespan = 60*60*24*7
        end
        asn = tonumber(asn)
        local description = lib_asn.get_description(asn)
        local start_time = os.time() - timespan
        local rows = data.get_asn_associations(asn, start_time)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        chat_send_player(caller, ('Records for A%s : %s'):format(asn, description))
        for _, row in ipairs(rows) do
            local message = ('% 20s: %s'):format(
                row.player_name,
                data.player_status_name[row.player_status_id or data.player_status.default.id]
            )
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('asn_stats', {
    description='Get statistics for an ASN',
    params='<ASN>',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asnstr = params:match('^A?(%d+)$')
        if not asnstr then
            return false, 'Invalid argument'
        end
        local asn = tonumber(asnstr)
        local asn_description = lib_asn.get_description(asn)
        local rows = data.get_asn_stats(asn)
        if not rows then
            return false, 'Error: see server log'
        elseif #rows == 0 then
            return true, 'No data'
        end
        chat_send_player(caller, ('Statistics for %s:'):format(asn_description))
        for _, row in ipairs(rows) do
            chat_send_player(caller, ('%s %s'):format(
                data.player_status_name[row.player_status_id or data.player_status.default.id],
                row.count
            ))
        end
        return true
    end
})

register_chatcommand('cluster', {
    description='Get a list of other players who have ever shared an IP w/ the given player',
    params='<player_name>',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_name = params:match('^([a-zA-Z0-9_-]+)$')
        if not player_name or player_name:len() > 20 then
            return false, 'Invalid argument'
        end
        local player_id = data.get_player_id(player_name)
        if not player_id then
            return false, 'Unknown player'
        end
        local rows = data.get_player_cluster(player_id)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        for _, row in ipairs(rows) do
            local message = ('% 20s: %s'):format(
                row.player_name,
                data.player_status_name[row.player_status_id or data.player_status.default.id]
            )
            chat_send_player(caller, message)
        end
        return true
    end
})
--
register_chatcommand('who2', {
    description='Show current connected players, statuses, and sources',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local names = {}
        for _, player in ipairs(minetest.get_connected_players()) do
            table.insert(names, player:get_player_name())
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        for _, name in ipairs(names) do
            local player_id = data.get_player_id(name)
            local player_status = data.get_player_status(player_id)

            local ipstr = verbana.data.fumble_about_for_an_ip(name, player_id)
            local ipint = lib_ip.ipstr_to_ipint(ipstr)
            local ip_status = data.get_ip_status(ipint)

            local asn, asn_description = lib_asn.lookup(ipint)
            local asn_status = data.get_asn_status(asn)

            local message = ('% 20s (%s) %s (%s) A%s (%s) %s'):format(
                name,
                player_status.name,
                ipstr,
                ip_status.name,
                asn,
                asn_status.name,
                asn_description
            )
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('bans', {
    description='Get a list of recent player status changes',
    params='[<number>=20]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local limit
        if params and params ~= '' then
            limit = params:match('^%s*(%d+)%s*$')
            if limit then
                limit = tonumber(limit)
            else
                return false, 'Invalid argument'
            end
        else
            limit = 20
        end
        local rows = data.get_ban_log(limit)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        for _, row in ipairs(rows) do
            local message = ('%s: %s %s %s'):format(
                iso_date(row.timestamp),
                row.executor_name,
                row.status_name,
                row.player_name
            )
            if row.expires then
                message = message .. (' until %s'):format(iso_date(row.expires))
            end
            if row.reason then
                message = message .. (' because %s'):format(row.reason)
            end
            chat_send_player(caller, message)
        end
    end
})

--------------

-- prevent players from flooding reports
local report_times_by_player = {}

register_chatcommand('report', {
    description='Send a report to server staff',
    params='<report>',
    func=function(reporter, report)
        -- TODO make the hard-coded values here settings
        local now = os.time()
        local report_times = report_times_by_player[reporter]
        if not report_times then
            report_times_by_player[reporter] = {now}
        else
            while #report_times > 0 and (now - report_times[1]) > 3600 do
                table.remove(report_times, 1)
            end
            if #report_times >= 5 then
                return false, 'You may only issue 5 reports in an hour.'
            end
            table.insert(report_times, now)
        end
        if report == '' then
            return false, 'You must enter a report!'
        end
        local reporter_id = data.get_player_id(reporter)
        if not data.add_report(reporter_id, report) then
            return false, 'Error: check server log'
        end
        return true, 'Report sent.'
    end
})

register_chatcommand('reports', {
    description='View recent reports',
    params='[<timespan>=1w]',
    privs={[mod_priv]=true},
    func=function(caller, timespan_str)
        local timespan
        if timespan_str ~= '' then
            timespan = parse_time(timespan_str)
            if not timespan then
                return false, 'Invalid timespan'
            end
        else
            timespan = 60*60*24*7
        end
        local from_time = os.time() - timespan
        local rows = verbana.data.get_reports(from_time)
        if not rows then
            return false, 'An error occurred (see server logs)'
        elseif #rows == 0 then
            return true, 'No records found.'
        end
        for _, row in ipairs(rows) do
            local message = ('%s % 20s: %s'):format(
                iso_date(row.timestamp),
                row.reporter,
                row.report
            )
            chat_send_player(caller, message)
        end
    end
})

register_chatcommand('first-login', {
    description='Get the first login time of any player or yourself.',
    params='[<player_name>]',
    func=function(reporter, params)
        if params == '' then
            params = reporter
        end
        local player_id = data.get_player_id(params)
        if not player_id then
            return false, 'Unknown player'
        end
        local rows = data.get_first_login(player_id)
        if not rows then
            return false, 'An error occured. See server logs.'
        elseif #rows == 0 then
            return true, 'No record of player logging in'
        end
        return true, iso_date(rows[1].timestamp)
    end
})

register_chatcommand('master', {
    description='Set the master account of an alt account',
    params='<alt> <master>',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local alt_name, master_name = params:match('^%s*([a-zA-Z0-9_-]+)%s+([a-zA-Z0-9_-]+)%s*$')
        if not alt_name or not master_name or alt_name:len() > 20 or master_name:len() > 20 then
            return false, 'Invalid arguments'
        end
        local alt_id = data.get_player_id(alt_name)
        local master_id = data.get_player_id(master_name)
        if not alt_id then
            return false, ('Unknown player %s'):format(alt_name)
        elseif not master_id then
            return false, ('Unknown player %s'):format(master_name)
        end
        local status, message = data.set_master(alt_id, master_id)
        if not status then
            return false, ('An error occured (%s). Check logs.'):format(message)
        end
        local true_master_id, true_master_name = data.get_master(alt_id)
        local status = data.get_player_status(true_master_id)
        if status.id == data.player_status.banned.id then
            local alts = data.get_alts(true_master_id)
            for _, other_alt_name in ipairs(alts) do
                local player = minetest.get_player_by_name(other_alt_name)
                if player then
                    util.safe_kick_player(caller, player, status.reason)
                end
            end
        end
        return true, ('Set master of %s to %s'):format(alt_name, true_master_name)
    end
})

register_chatcommand('master_rm', {
    description='Remove the master from an alt account',
    params='<player_name>',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local alt_name = params:match('^%s*([a-zA-Z0-9_-]+)%s*$')
        if not alt_name or alt_name:len() > 20 then
            return false, 'Invalid argument'
        end
        local alt_id = data.get_player_id(alt_name)
        if not alt_id then
            return false, 'Unknown player'
        end
        local master_id = data.get_master_id(alt_id)
        if not master_id then
            return false, 'Player has no master ID'
        end
        if not data.unset_master(alt_id) then
            return false, 'Error (see logs)'
        end
        return true, 'Master removed'
    end
})

register_chatcommand('pgrep', {
    description='Search for players by name, using a SQLite GLOB expression (e.g. "*foo*")',
    params='<pattern> [<limit>=20]',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local pattern, limit = params:match('^%s*(%S+)%s+(%d+)%s*$')
        if not limit or not pattern then
            pattern = params:match('^%s*(%S+)%s*$')
            if not pattern then
                return false, 'Invalid arguments'
            end
            limit = 20
        end
        local rows = data.grep_player(pattern, limit)
        if not rows then
            return false, 'Error (probably a malformed regular expression)'
        elseif #rows == 0 then
            return true, 'No matches'
        end
        for _, row in ipairs(rows) do
            chat_send_player(caller, '%s %s',
                row.name,
                data.player_status_name[row.player_status_id or data.player_status.default.id]
            )
        end
        return true
    end
})
