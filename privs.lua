verbana.privs = {}

verbana.privs.admin = verbana.settings.admin_priv
verbana.privs.moderator = verbana.settings.moderator_priv
verbana.privs.kick = verbana.settings.kick_priv

if not minetest.registered_privileges[verbana.privs.admin] then
    minetest.register_privilege(verbana.privs.admin, 'Verbana administrator')
end

if not minetest.registered_privileges[verbana.privs.moderator] then
    minetest.register_privilege(verbana.privs.moderator, 'Verbana moderator')
end

minetest.registered_privileges['kick'] = nil

if verbana.privs.kick then
    if not minetest.registered_privileges[verbana.privs.kick] then
        minetest.register_privilege(verbana.privs.kick, 'Verbana kicker')
    end
end

function verbana.privs.is_admin(name)
    return minetest.check_player_privs(name, {[verbana.privs.admin] = true})
end

function verbana.privs.is_moderator(name)
    return minetest.check_player_privs(name, {[verbana.privs.moderator] = true})
end

function verbana.privs.is_privileged(name)
    return verbana.privs.is_admin(name) or verbana.privs.is_moderator(name)
end
