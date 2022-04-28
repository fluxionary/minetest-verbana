
local function get_setting(name, default)
    local setting = minetest.settings:get(name)
    if not setting or setting == "" then
        return default
    end
    return setting
end

local function get_jail_bounds()
    -- (x1,y1,z1),(x2,y2,z2)
    local bounds = minetest.settings:get("verbana.jail_bounds")
    if not bounds or bounds == "" then
        return nil
    end
    local x1, y1, z1, x2, y2, z2 = bounds:match(
        "^%s*%(%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)%s*%),%(%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)%s*%)%s*$"
    )
    if not x1 then
        verbana.log("warning", "The setting of verbana.jail_bounds %q is invalid, ignoring.", bounds)
        return nil
    end
    x1 = tonumber(x1)
    y1 = tonumber(y1)
    z1 = tonumber(z1)
    x2 = tonumber(x2)
    y2 = tonumber(y2)
    z2 = tonumber(z2)
    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    if z1 > z2 then z1, z2 = z2, z1 end
    return {vector.new(x1, y1, z1), vector.new(x2, y2, z2)}
end

-- we revert to debug mode if verification, sban, or xban is enabled
local debug_is_default = (
    verbana.has.sban or
    verbana.has.xban or
    verbana.has.xban2 or
    verbana.has.verification
) and "true" or "false"

local world_path = minetest.get_worldpath()

verbana.settings = {
    universal_verification = minetest.settings:get_bool("verbana.universal_verification", false),
    set_universal_verification = function(value)
        if type(value) == "boolean" then
            minetest.settings:set_bool("verbana.universal_verification", value)
            verbana.settings.universal_verification = value
        else
            verbana.log("error", "tried to set universal verification to %q", value)
        end
    end,

    pg_host = get_setting("verbana.pg_host", "127.0.0.1"),
    pg_port = get_setting("verbana.pg_port", "5432"),
    pg_database = get_setting("verbana.pg_database", "verbana"),
    pg_user = get_setting("verbana.pg_user", "verbana"),
    pg_password = get_setting("verbana.pg_password", ""),

    -- TODO: handle migration from sqlite
    --db_path = get_setting("verbana.db_path", ("%s/verbana.sqlite"):format(world_path)),
    asn_description_path = get_setting("verbana.asn_description_path", ("%s/data-used-autnums"):format(verbana.modpath)),
    asn_data_path = get_setting("verbana.asn_data_path", ("%s/data-raw-table"):format(verbana.modpath)),
    ipv6_data_path = get_setting("verbana.asn_data_path", ("%s/ipv6-raw-table"):format(verbana.modpath)),

    admin_priv = get_setting("verbana.admin_priv", "ban_admin"),
    moderator_priv = get_setting("verbana.moderator_priv", "ban"),
    kick_priv = get_setting("verbana.kick_priv", nil),

    verified_privs = minetest.string_to_privs(get_setting("default_privs", "shout,interact")),
    unverified_privs = minetest.string_to_privs(get_setting("verbana.unverified_privs", "shout")),
    whitelisted_privs = minetest.string_to_privs(get_setting("verbana.whitelisted_privs", "")),

    spawn_pos = minetest.string_to_pos(get_setting("static_spawnpoint", "(0,0,0)")),

    jail_bounds = get_jail_bounds(),
    jail_check_period = tonumber(get_setting("verbana.jail_check_period")),

    debug_mode = get_setting("verbana.debug_mode", debug_is_default) == "true"
}

if #verbana.settings.whitelisted_privs == 0 then verbana.settings.whitelisted_privs = nil end

verbana.settings.unverified_spawn_pos = minetest.string_to_pos(
    get_setting(
        "verbana.unverified_spawn_pos",
        minetest.pos_to_string(verbana.settings.spawn_pos)
    )
)


