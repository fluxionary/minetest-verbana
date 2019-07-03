if not verbana then verbana = {} end
verbana.privs = {}

minetest.register_privilege('ban_admin', 'administrator for verification/bans')

verbana.privs.admin = 'ban_admin'  -- TODO load from settings
verbana.privs.moderator = 'basic_privs' -- TODO load from settings

function verbana.privs.is_admin(name)
    return minetest.check_player_privs(name, {[verbana.privs.admin] = true})
end

function verbana.privs.is_moderator(name)
    return minetest.check_player_privs(name, {[verbana.privs.moderator] = true})
end

function verbana.privs.is_privileged(name)
    return verbana.privs.is_admin(name) or verbana.privs.is_moderator(name)
end
