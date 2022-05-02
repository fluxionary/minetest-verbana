local modpath = verbana.modpath
local worldpath = minetest.get_worldpath()

local settings = minetest.settings

local function get_setting(name, default)
    local setting = settings:get("verbana." .. name)
    return setting or default
end

local function get_bool(name, default)
    return settings:get_bool("verbana." .. name, default)
end

local function get_jail_bounds()
    -- (x1,y1,z1),(x2,y2,z2)
    local bounds = settings:get("verbana.jail_bounds")
    if not bounds or bounds == "" then
        return nil
    end
    local x1, y1, z1, x2, y2, z2 = bounds:match(
        "^%s*%(%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)%s*%),%(%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*(%-?%d+)%s*%)%s*$"
    )
    x1 = tonumber(x1)
    y1 = tonumber(y1)
    z1 = tonumber(z1)
    x2 = tonumber(x2)
    y2 = tonumber(y2)
    z2 = tonumber(z2)

    if not (x1 and y1 and z1 and x2 and y2 and z2) then
        verbana.log("warning", "The setting of verbana.jail_bounds (%q) is invalid, ignoring.", bounds)
        return nil
    end

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

verbana.settings = {
    universal_verification = get_bool("verbana.universal_verification", false),
    set_universal_verification = function(value)
        if type(value) == "boolean" then
            settings:set_bool("verbana.universal_verification", value)
            verbana.settings.universal_verification = value
        else
            verbana.log("error", "tried to set universal verification to %q", value)
        end
    end,

    backend = get_setting("backend", "postgres"),

    sqlite_path = get_setting("sqlite_path", ("%s/verbana.sqlite"):format(worldpath)),

    pg_host = get_setting("pg_host", "127.0.0.1"),
    pg_port = get_setting("pg_port", "5432"),
    pg_database = get_setting("pg_database", "verbana"),
    pg_user = get_setting("pg_user", "verbana"),
    pg_password = get_setting("pg_password", ""),

    used_autnums_url = get_setting("used_autnums_url", "http://thyme.apnic.net/current/data-used-autnums"),
    used_autnums_path = get_setting("used_autnums_path", ("%s/data/used-autnums"):format(modpath)),
    ipv4_raw_table_url = get_setting("ipv4_raw_table_url", "http://thyme.apnic.net/current/data-raw-table"),
    ipv4_raw_table_path = get_setting("ipv4_raw_table_path", ("%s/data/ipv4-raw-table"):format(modpath)),
    ipv6_raw_table_url = get_setting("ipv6_raw_table_url", "https://thyme.apnic.net/current/ipv6-raw-table"),
    ipv6_raw_table_path = get_setting("ipv6_raw_table_path", ("%s/data/ipv6-raw-table"):format(modpath)),
    asn_table_update_period = get_setting(),
    asn_table_update_on_start = get_bool(),

    admin_priv = get_setting("admin_priv", "ban_admin"),
    moderator_priv = get_setting("moderator_priv", "ban"),
    kick_priv = get_setting("kick_priv", "kick"),

    verified_privs = minetest.string_to_privs(settings:get("default_privs") or "shout,interact"),
    unverified_privs = minetest.string_to_privs(get_setting("unverified_privs", "shout")),
    whitelisted_privs = minetest.string_to_privs(get_setting("whitelisted_privs", "")),

    spawn_pos = minetest.string_to_pos(settings:get("static_spawnpoint") or "(0,0,0)"),

    jail_bounds = get_jail_bounds(),
    jail_check_period = tonumber(get_setting("jail_check_period")),

    debug_mode = get_setting("debug_mode", debug_is_default) == "true"
}

if #verbana.settings.whitelisted_privs == 0 then
    verbana.settings.whitelisted_privs = nil
end

verbana.settings.unverified_spawn_pos = minetest.string_to_pos(
    get_setting(
        "unverified_spawn_pos",
        minetest.pos_to_string(verbana.settings.spawn_pos)
    )
)


