verbana.settings = {}
-- config: privs_to_whitelist: if a player has this/these privs, they are treated as whitelisted
local function settings_get_set(name, default)
    -- "set" here is as in a "set of items"
    local value = minetest.settings:get(name)
    if value then
        local set = {}
    else
        return default
    end
end

verbana.settings.unverified_privs = {unverified = true, shout = true}

verbana.settings.universal_verification = false


verbana.settings.spawn_pos = {x = 111, y = 13, z = -507}
verbana.settings.verification_pos = {x = 172, y = 29, z = -477}
