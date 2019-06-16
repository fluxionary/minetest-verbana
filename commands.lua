verbana.commands = {}

local mod_priv = verbana.privs.moderator
local admin_priv = verbana.privs.admin

minetest.register_chatcommand('import_sban', {
    params='<filename>',
    description='import records from sban',
    privs={[admin_priv]=true},
    func=function (_, filename)
        if not filename or filename == '' then
            filename = minetest.get_worldpath() .. '/sban.sqlite'
        end
        if not io.open(filename, 'r') then
            return false, ('Could not open file %q.'):format(filename)
        elseif verbana.data.import_from_sban(filename) then
            return true, 'Successfully imported.'
        else
            return false, 'Error importing SBAN db (see server log)'
        end
    end
})

minetest.register_chatcommand('get_asn', {
    params='<name> | <IP>',
    description='get the ASN associated with an IP or player name',
    privs={[mod_priv]=true},
    func = function(_, name_or_ipstr)
        local ipstr

        if verbana.ip.is_valid_ip(name_or_ipstr) then
            ipstr = name_or_ipstr
        else
            ipstr = minetest.get_player_ip(name_or_ipstr)
        end

        if not ipstr or ipstr == '' then
            return false, ('"%s" is not a valid ip nor a connected player'):format(name_or_ipstr)
        end

        local asn, description = verbana.asn.lookup(ipstr)
        if not asn or asn == 0 then
            return false, ('could not find ASN for "%s"'):format(ipstr)
        end

        description = description or ''

        return true, ('A%u (%s)'):format(asn, description)
    end
})

minetest.register_chatcommand('verify', {
    params='<name>',
    description='verify a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('unverify', {
    params='<name>',
    description='unverify a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.override_chatcommand('kick', {
    params='<name> [<reason>]',
    description='kick a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('lock', {
    params='<name> [<reason>]',
    description='lock a player\'s account',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('unlock', {
    params='<name> [<reason>]',
    description='unlock a player\'s account',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.override_chatcommand('ban', {
    params='<name> [<reason>]',
    description='ban a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        -- todo: make sure that the begining of 'reason' doesn't look like a timespan =b
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('tempban', {
    params='<name> <timespan> [<reason>]',
    description='ban a player for a length of time',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.override_chatcommand('unban', {
    params='<name> [<reason>]',
    description='unban a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('whitelist', {
    params='<name> [<reason>]',
    description='whitelist a player',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('unwhitelist', {
    params='<name> [<reason>]',
    description='whitelist a player',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('suspect', {
    params='<name> [<reason>]',
    description='mark a player as suspicious',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('unsuspect', {
    params='<name> [<reason>]',
    description='unmark a player as suspicious',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('ban_record', {
    params='<name> [<number>]',
    description='shows the ban record of a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        local name, numberstr = string.match(params, '^([%a%d_-]+) +(%d+)$')
        if not name then
            name = string.match(params, '^([%a%d_-]+)$')
            if not name then
                return false, 'invalid arguments'
            end
        end

        local rows = verbana.data.get_ban_record(name)
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
            local executor = row[1]
            local status = row[2]
            local timestamp = os.date("%c", row[3])
            local reason = row[4]
            local expires
            if row[5] then
                expires = os.date("%c", row[5])
            end
            local message = ('%s: %s set status to %s.'):format(timestamp, executor, status)
            if reason and reason ~= '' then
                message = ('%s Reason: %s'):format(message, reason)
            end
            if expires then
                message = ('%s Expires: %s'):format(message, expires)
            end

            minetest.chat_send_player(caller, message)
        end

        return true
    end
})

minetest.register_chatcommand('login_record', {
    params='<name> [<number>]',
    description='shows the login record of a player',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('inspect', {
    params='<name> | <IP>',
    description='list data associated with a player or IP',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('inspect_asn', {
    params='<asn>',
    description='list player accounts and statuses associated with an ASN',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('set_ip_status', {
    params='<asn> <status>',
    description='set the status of an IP (default, dangerous, blocked)',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

minetest.register_chatcommand('set_asn_status', {
    params='<asn> <status>',
    description='set the status of an ASN (default, dangerous, blocked)',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'  -- TODO
    end
})

-- alias (for listing an account's primary, cascade status)
-- list recent bans/kicks/locks/etc
-- first_login (=b) for all players
-- asn statistics
