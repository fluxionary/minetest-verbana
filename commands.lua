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
    if debug_mode then name = ('v_%s'):format(name) end

end

register_chatcommand('sban_import', {
    params='<filename>',
    description='import records from sban',
    privs={[admin_priv]=true},
    func=function (caller, filename)
        if not filename or filename == '' then
            filename = minetest.get_worldpath() .. '/sban.sqlite'
        end
        if not io.open(filename, 'r') then
            return false, ('Could not open file %q.'):format(filename)
        end
        minetest.chat_send_player(caller, 'Importing SBAN. This can take a while...')
        if data.import_from_sban(filename) then
            return true, 'Successfully imported.'
        else
            return false, 'Error importing SBAN db (see server log)'
        end
    end
})

register_chatcommand('asn', {
    params='<name> | <IP>',
    description='get the ASN associated with an IP or player name',
    privs={[mod_priv]=true},
    func = function(_, name_or_ipstr)
        local ipstr

        if lib_ip.is_valid_ip(name_or_ipstr) then
            ipstr = name_or_ipstr
        else
            ipstr = data.fumble_about_for_an_ip(name_or_ipstr)
        end

        if not ipstr or ipstr == '' then
            return false, ('"%s" is not a valid ip nor a connected player'):format(name_or_ipstr)
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
    params='<name> [reason]',
    description='verify a player',
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
    params='<name> [reason]',
    description='unverify a player, revoking privs and putting them back in jail.',
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
    params='<name> [reason]',
    description='kick a player',
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
    params='<name> [timespan] [reason]',
    description='ban a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local player_id, player_name, player_status, reason = parse_player_status_params(params)
        if not player_id then
            return false, reason
        end
        local expires
        if reason then
            local first = reason:match('^(%S+)')
            expires = parse_time(first)
            if expires then
                reason = reason:sub(first:len() + 2)
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
        if reason then
            log('action', '%s banned %s because %s', caller, player_name, reason)
        else
            log('action', '%s banned %s', caller, player_name)
        end
        return true, ('Banned %s'):format(player_name)
    end
})

override_chatcommand('unban', {
    params='<name> [reason]',
    description='unban a player',
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
    params='<name> [reason]',
    description='whitelist a player',
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
    params='<name> [reason]',
    description='whitelist a player',
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
    params='<name> [reason]',
    description='mark a player as suspicious',
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
    params='<name> [reason]',
    description='unmark a player as suspicious',
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

register_chatcommand('trust_ip', {
    params='<ip> [reason]',
    description='Mark an IP as trusted - connections will bypass suspicious network checks',
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

register_chatcommand('untrust_ip', {
    params='<ip> [reason]',
    description='Remove trusted status from an IP',
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

register_chatcommand('suspect_ip', {
    params='<ip> [reason]',
    description='Mark an IP as suspicious.',
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

register_chatcommand('unsuspect_ip', {
    params='<ip> [reason]',
    description='Unmark an IP as suspcious',
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

register_chatcommand('block_ip', {
    params='<ip> [reason]',
    description='Block an IP from connecting.',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        local expires
        if reason then
            local first = reason:match('^(%S+)')
            expires = parse_time(first)
            if expires then
                reason = reason:sub(first:len() + 2)
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
        -- TODO: kick all connected players
        if reason then
            log('action', '%s blocked %s because %s', caller, ipstr, reason)
        else
            log('action', '%s blocked %s', caller, ipstr)
        end
        return true, ('Blocked %s'):format(ipstr)
    end
})

register_chatcommand('unblock_ip', {
    params='<ip> [reason]',
    description='Unblock an IP',
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

register_chatcommand('suspect_asn', {
    params='<asn> [reason]',
    description='Mark an ASN as suspicious.',
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

register_chatcommand('unsuspect_asn', {
    params='<asn> [reason]',
    description='Unmark an ASN as suspcious.',
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

register_chatcommand('block_asn', {
    params='<asn> [duration] [reason]',
    description='Block an ASN. Duration and reason optional.',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        local expires
        if reason then
            local first = reason:match('^(%S+)')
            expires = parse_time(first)
            if expires then
                reason = reason:sub(first:len() + 2)
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
        -- TODO: kick all connected players
        if reason then
            log('action', '%s blocked A%s because %s', caller, asn, reason)
        else
            log('action', '%s blocked A%s', caller, asn)
        end
        return true, ('Blocked A%s'):format(asn)
    end
})

register_chatcommand('unblock_asn', {
    params='<asn> [reason]',
    description='Unblock an ASN.',
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
    params='<name> [number]',
    description='shows the status log of a player',
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
            local message = ('%s: %s set status to %s.'):format(os.date("%c", row.timestamp), row.executor, row.status)
            local reason = row.reason
            if reason and reason ~= '' then
                message = ('%s Reason: %s'):format(message, reason)
            end
            local expires = row.expires
            if expires then
                message = ('%s Expires: %s'):format(message, os.date("%c", expires))
            end
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('ip_status_log', {
    params='<IP> [number]',
    description='shows the status log of an IP',
    privs={[admin_priv]=true},
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
            local message = ('%s: %s set status to %s.'):format(os.date("%c", row.timestamp), row.executor, row.status)
            local reason = row.reason
            if reason and reason ~= '' then
                message = ('%s Reason: %s'):format(message, reason)
            end
            local expires = row.expires
            if expires then
                message = ('%s Expires: %s'):format(message, os.date("%c", expires))
            end
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('asn_status_log', {
    params='<ASN> [number]',
    description='shows the status log of an ASN',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local asnstr, numberstr = string.match(params, '^A?(%d+)%s+(%d+)$')
        if not asnstr then
            asnstr = string.match(params, '^A?(%d+)$')
        end
        if not asnstr then
            return false, 'invalid arguments'
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
            local message = ('%s: %s set status to %s.'):format(os.date("%c", row.timestamp), row.executor, row.status)
            local reason = row.reason
            if reason and reason ~= '' then
                message = ('%s Reason: %s'):format(message, reason)
            end
            local expires = row.expires
            if expires then
                message = ('%s Expires: %s'):format(message, os.date("%c", expires))
            end
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('logins', {
    params='<name> [number]',
    description='shows the login record of a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local name, limit = params:match('^([a-zA-Z0-9_-]+)%s+(%d+)$')
        if not name then
            name = params:match('^([a-zA-Z0-9_-]+)$')
        end
        if not name then
            return false, 'invalid arguments'
        end
        if not limit then
            limit = 20
        end
        local player_id = data.get_player_id(name)
        if not player_id then
            return false, 'unknown player'
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
                os.date("%c", row.timestamp),
                (rows.success and ' failed!') or '',
                lib_ip.ipint_to_ipstr(row.ipint),
                row.ip_status_name or data.ip_status.default.name,
                row.asn,
                row.asn_status_name or data.asn_status.default.name,
                lib_asn.get_description(row.asn)
            )
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('inspect', {
    params='<name>',
    description='list ips, asns and statuses associated with a player',
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
        minetest.chat_send_player(caller, ('Records for %s'):format(name))
        for _, row in ipairs(rows) do
            local ipstr = lib_ip.ipint_to_ipstr(row.ipint)
            local asn_description = lib_asn.get_description(row.asn)
            local message = ('%s<%s> A%s (%s) <%s>'):format(
                ipstr,
                row.ip_status or data.ip_status.default.name,
                row.asn,
                asn_description,
                row.asn_status or data.asn_status.default.name
            )
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('inspect_ip', {
    params='<IP>',
    description='list player accounts and statuses associated with an IP',
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipstr = params:match('^(%d+%.%d+%.%d+%.%d+)$')
        if not ipstr or not lib_ip.is_valid_ip(ipstr) then
            return false, 'Invalid argument'
        end
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local rows = data.get_ip_associations(ipint)
        if not rows then
            return false, 'An error occurred (see server logs)'
        end
        if #rows == 0 then
            return true, 'No records found.'
        end
        minetest.chat_send_player(caller, ('Records for %s'):format(ipstr))
        for _, row in ipairs(rows) do
            local message = ('% 20s: %s'):format(
                row.player_name,
                row.player_status_name or data.player_status.default.name
            )
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})

--register_chatcommand('inspect_asn', {
--    params='<asn>',
--    description='list player accounts and statuses associated with an ASN',
--    privs={[admin_priv]=true},
--    func=function(caller, params)
--        -- TODO: this generates a ton of output. need a way to page through it, or ignore most of it
--        local asn = params:match('^A?(%d+)$')
--        if not asn then
--            return false, 'Invalid argument'
--        end
--        asn = tonumber(asn)
--        local description = lib_asn.get_description(asn)
--        local rows = data.get_asn_associations(asn)
--        if not rows then
--            return false, 'An error occurred (see server logs)'
--        end
--        if #rows == 0 then
--            return true, 'No records found.'
--        end
--        minetest.chat_send_player(caller, ('Records for A%s : %s'):format(asn, description))
--        for _, row in ipairs(rows) do
--            local message = ('% 20s: %s'):format(
--                row.player_name,
--                row.player_status_name or data.player_status.default.name
--            )
--            minetest.chat_send_player(caller, message)
--        end
--        return true
--    end
--})

register_chatcommand('cluster', {
    params='<player_name>',
    description='Get a list of other players who have ever shared an IP w/ the given player',
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
                row.player_status_name or data.player_status.default.name
            )
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})
--
register_chatcommand('who2', {
    description='Show current connected players, statuses, and sources',
    privs={[mod_priv]=true},
    func=function(caller, params)
        for _, player in ipairs(minetest.get_connected_players()) do
            local name = player:get_player_name()
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
            minetest.chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand('banlog', {
    params='[number]',
    description='Get a list of recent player status changes',
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
            local message = ('% 20s: %s'):format(
                row.player_name,
                row.player_status_name or data.player_status.default.name
            )
            minetest.chat_send_player(caller, message)
        end
    end
})
