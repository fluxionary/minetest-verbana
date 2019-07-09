verbana.settings = {}

local settings = minetest.settings

function verbana.settings.set_universal_verification(value)
    if type(value) == 'boolean' then
        settings:set_bool('verbana.universal_verification', value)
    else
        verbana.log('warning', 'tried to set universal verification to %q', value)
    end
end

local function get_setting(name, default)
    local setting = settings:get('verbana.db_path')
    if not setting or setting == '' then
        return default
    end
    return setting
end

local function get_jail_bounds()
    -- (x1,y1,z1),(x2,y2,z2)
    local bounds = settings:get('verbana.jail_bounds')
    if not bounds or bounds == '' then
        return nil
    end
    local x1, y1, z1, x2, y2, z2 = bounds:match(
        '^%s*%(%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)%s*%),%(%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)%s*%)%s*$'
    )
    if not x1 then
        verbana.log('warning', 'The setting of verbana.jail_bounds %q is invalid, ignoring.', bounds)
        return nil
    end
    x1 = tonumber(x1)
    y1 = tonumber(y1)
    z1 = tonumber(z1)
    x2 = tonumber(x2)
    y2 = tonumber(y2)
    z2 = tonubmer(z2)
    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    if z1 > z2 then z1, z2 = z2, z1 end
    return {vector.new(x1, y1, z1), vector.new(x2, y2, z2)}
end

verbana.settings.db_path = get_setting('verbana.db_path', ('%s/verbana.sqlite'):format(minetest.get_worldpath()))
verbana.settings.asn_description_path = get_setting('verbana.asn_description_path', ('%s/%s'):format(verbana.modpath, 'data-used-autnums'))
verbana.settings.asn_data_path = get_setting('verbana.asn_data_path', ('%s/%s'):format(verbana.modpath, 'data-raw-table'))

verbana.settings.admin_priv = get_setting('verbana.admin_priv', 'ban_admin')
verbana.settings.moderator_priv = get_setting('verbana.moderator_priv', 'basic_privs')

verbana.settings.verified_privs = minetest.string_to_privs(get_setting('default_privs', 'shout,interact'))
verbana.settings.unverified_privs = minetest.string_to_privs(get_setting('verbana.unverified_privs', 'shout'))
verbana.settings.whitelisted_privs = minetest.string_to_privs(get_setting('verbana.whitelisted_privs', ''))
if #verbana.settings.whitelisted_privs == 0 then verbana.settings.whitelisted_privs = nil end

verbana.settings.spawn_pos = minetest.string_to_pos(get_setting('static_spawnpoint', '(0,0,0)'))
verbana.settings.unverified_spawn_pos = minetest.string_to_pos(get_setting('verbana.unverified_spawn_pos', '(0,0,0)'))

verbana.settings.universal_verification = settings:get_bool('verbana.universal_verification', false)
verbana.settings.jail_bounds = get_jail_bounds()
verbana.settings.jail_check_period = get_setting('verbana.jail_check_period')

-- TODO: remove the default 'true' setting when we are ready
verbana.settings.debug_mode = get_setting('verbana.debug_mode', 'true') == 'true'

