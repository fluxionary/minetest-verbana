verbana = {}
verbana.version = '1.0.0'
local modname = minetest.get_current_modname()
verbana.modname = modname
verbana.modpath = minetest.get_modpath(modname)

function verbana.log(level, message, ...)
    minetest.log(level, ('[%s] %s'):format(modname, message:format(...)))
end

verbana.ie = minetest.request_insecure_environment()
if not verbana.ie then
	error('Verbana will not work unless it has been listed under secure.trusted_mods in minetest.conf')
end

-- settings
dofile(verbana.modpath .. '/settings.lua')
dofile(verbana.modpath .. '/privs.lua')

-- libraries
dofile(verbana.modpath .. '/util.lua')
dofile(verbana.modpath .. '/lib_ip.lua')
dofile(verbana.modpath .. '/asn.lua')

-- connect to the DB
local sql = verbana.ie.require("lsqlite3")
local db_location = ('%s/verbana.sqlite'):format(minetest.get_worldpath()) -- TODO get path from settings
local db, _, errmsg = sql.open(db_location)
if not db then
    error(('Verbana could not open its database @ %q: %q'):format(db_location, errmsg))
end
verbana.sql = sql
verbana.db = db

minetest.register_on_shutdown(function()
    local ret_code = db:close()
    if ret_code ~= sql.OK then
        verbana.log('error', 'Error closing DB: %s', db:error_message())
    end
end)

-- core
dofile(verbana.modpath .. '/chat.lua')
dofile(verbana.modpath .. '/data.lua')
dofile(verbana.modpath .. '/login_handling.lua')
dofile(verbana.modpath .. '/commands.lua')

-- cleanup (prevent access to insecure environment from any outside mod)
sqlite3 = nil
verbana.ie = nil
verbana.sql = nil
verbana.db = nil


