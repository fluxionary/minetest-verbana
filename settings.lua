verbana.settings = {}

local settings = minetest.settings

local function get_jail_bounds()
    local bounds = settings:get('verbana.jail_bounds')
    if not bounds or bounds == '' then
        return nil
    end

end

verbana.settings.verified_privs = minetest.string_to_privs(settings:get('default_privs') or '')
verbana.settings.unverified_privs = minetest.string_to_privs(settings:get('verbana.unverified_privs') or '')
verbana.settings.privs_to_whitelist = minetest.string_to_privs(settings:get('verbana.privs_to_whitelist') or '')
verbana.settings.universal_verification = settings:get_bool('verbana.universal_verification', false)

verbana.settings.spawn_pos = minetest.string_to_pos(settings:get('static_spawnpoint') or '(0,0,0)')
verbana.settings.unverified_spawn_pos = minetest.string_to_pos(settings:get('verbana.unverified_spawn_pos') or '(0,0,0)')
verbana.settings.jail_bounds = get_jail_bounds()
verbana.settings.jail_check_period = settings:get('static_spawnpoint')
