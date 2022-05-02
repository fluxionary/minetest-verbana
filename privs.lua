verbana.privs = {
    admin = verbana.settings.admin_priv,
    moderator = verbana.settings.moderator_priv,
    kick = verbana.settings.kick_priv,

    is_admin = function(name)
        name = type(name) == "string" and name or name:get_player_name()
        return minetest.check_player_privs(name, {[verbana.privs.admin] = true})
    end,

    is_moderator = function(name)
        name = type(name) == "string" and name or name:get_player_name()
        return minetest.check_player_privs(name, {[verbana.privs.moderator] = true})
    end,

    is_privileged = function(name)
        name = type(name) == "string" and name or name:get_player_name()
        return verbana.privs.is_admin(name) or verbana.privs.is_moderator(name)
    end,
}

if not minetest.registered_privileges[verbana.privs.admin] then
    minetest.register_privilege(verbana.privs.admin, "Verbana administrator")
end

if not minetest.registered_privileges[verbana.privs.moderator] then
    minetest.register_privilege(verbana.privs.moderator, "Verbana moderator")
end

minetest.registered_privileges["kick"] = nil

if verbana.privs.kick then
    if not minetest.registered_privileges[verbana.privs.kick] then
        minetest.register_privilege(verbana.privs.kick, "Verbana kicker")
    end
end
