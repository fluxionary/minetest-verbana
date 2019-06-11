verbana.commands = {}

local mod_priv = verbana.privs.moderator
local admin_priv = verbana.privs.admin

function verbana.commands.import_sban(filename)
    verbana.data.import_from_sban(filename)
    return false, 'TODO: implement'
end

minetest.register_chatcommand('import_sban', {
    params='<filename>',
    description='import records from sban',
    privs={[admin_priv]=true},
    func=import_sban
})

minetest.register_chatcommand('get_asn', {
    params='<name> | <IP>',
    description='get the ASN associated with an IP or player name',
    privs={[mod_priv]=true},
    func = function(caller, name_or_ipstr)
        local ipstr

        if verbana.ip.is_valid_ip(name_or_ipstr) then
            ipstr = name_or_ipstr
        else
            ipstr = minetest.get_player_ip(name_or_ipstr)
        end

        if not ipstr then
            return false, ('"%s" is not a valid ip nor a connected player'):format(name_or_ipstr)
        end

        local asn, description = verbana.asn.lookup(ipstr)
        if not asn then
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
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('unverify', {
    params='<name>',
    description='unverify a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.override_chatcommand('kick', {
    params='<name> [<reason>]',
    description='kick a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('lock', {
    params='<name> [<reason>]',
    description='lock a player\'s account',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('unlock', {
    params='<name> [<reason>]',
    description='unlock a player\'s account',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.override_chatcommand('ban', {
    params='<name> [<reason>]',
    description='ban a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        -- todo: make sure that the begining of 'reason' doesn't look like a timespan =b
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('tempban', {
    params='<name> <timespan> [<reason>]',
    description='ban a player for a length of time',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.override_chatcommand('unban', {
    params='<name> [<reason>]',
    description='unban a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('whitelist', {
    params='<name> [<reason>]',
    description='whitelist a player',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('unwhitelist', {
    params='<name> [<reason>]',
    description='whitelist a player',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('suspect', {
    params='<name> [<reason>]',
    description='mark a player as suspicious',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('unsuspect', {
    params='<name> [<reason>]',
    description='unmark a player as suspicious',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('ban_record', {
    params='<name> [<number>]',
    description='shows the ban record of a player',
    privs={[mod_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('login_record', {
    params='<name> [<number>]',
    description='shows the login record of a player',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('inspect', {
    params='<name> | <IP>',
    description='list data associated with a player or IP',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('inspect_asn', {
    params='<asn>',
    description='list player accounts and statuses associated with an ASN',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('set_ip_status', {
    params='<asn> <status>',
    description='set the status of an IP (default, dangerous, blocked)',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

minetest.register_chatcommand('set_asn_status', {
    params='<asn> <status>',
    description='set the status of an ASN (default, dangerous, blocked)',
    privs={[admin_priv]=true},
    func=function(caller, params)
        return false, 'TODO: implement'
    end
})

-- alias (for listing an account's primary, cascade status)
-- list recent bans/kicks/locks/etc
-- first_login (=b) for all players
-- asn statistics
