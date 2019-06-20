verbana.settings = {}
-- config: privs_to_whitelist: if a player has this/these privs, they are treated as whitelisted
local function settings_get_set(name, default)
    -- "set" here is as in a "set of items"
    local value = minetest.settings:get(name)
    if value then
        local set = {}
        -- TODO split the value on commas etc
    else
        return default
    end
end

-- TODO load priv settings

verbana.settings.verified_privs = ...
verbana.settings.unverified_privs = settings_get_set('...', {unverified = true, shout = true})
verbana.settings.privs_to_whitelist = nil
verbana.settings.universal_verification = false -- TODO this should be loaded from mod_storage?

verbana.settings.spawn_pos = {x = 111, y = 13, z = -507} -- TODO this should be grabbed from the spawn mod
verbana.settings.verification_pos = {x = 172, y = 29, z = -477} -- TODO load from config
verbana.settings.verification_jail = {x={159, 184}, y={27, 36}, z={-493, -472}}
verbana.settings.verification_jail_period = nil
