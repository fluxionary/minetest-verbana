verbana = {}
verbana.version = '0.1.0'
local modname = minetest.get_current_modname()
verbana.modname = modname
verbana.modpath = minetest.get_modpath(modname)

function verbana.log(level, message, ...)
    message = message:format(...)
    minetest.log(level, ('[%s] %s'):format(modname, message))
end

-- settings
dofile(verbana.modpath .. '/settings.lua')
dofile(verbana.modpath .. '/privs.lua')

if verbana.settings.debug_mode then
    verbana.log('warning', 'Verbana is running in debug mode.')
end

-- libraries
dofile(verbana.modpath .. '/util.lua')
dofile(verbana.modpath .. '/lib_ip.lua')
dofile(verbana.modpath .. '/lib_asn.lua')

-- connect to the DB - restrict access to full insecure environment to this point
local ie = minetest.request_insecure_environment()
if not ie then
	error('Verbana will not work unless it has been listed under secure.trusted_mods in minetest.conf')
end

local sql = ie.require('lsqlite3')
ie = nil -- nuke this as quickly as possible

if not sql then
    error('Verbana will not work unless lsqlite3 is installed. See README.txt')
end
verbana.sql = sql
local db_location = verbana.settings.db_path
local db, _, errmsg = sql.open(db_location)
if not db then
    error(('Verbana could not open its database @ %q: %q'):format(db_location, errmsg))
else
    verbana.db = db
end

minetest.register_on_shutdown(verbana.util.safe(function()
    local ret_code = db:close()
    if ret_code ~= sql.OK then
        verbana.log('error', 'Error closing DB: %s', db:error_message())
    end
end))


-- core
dofile(verbana.modpath .. '/data.lua') -- data must go first
dofile(verbana.modpath .. '/chat.lua') -- chat must go before login_handling
dofile(verbana.modpath .. '/login_handling.lua')
dofile(verbana.modpath .. '/imports/sban.lua') -- must go before commands
dofile(verbana.modpath .. '/imports/xban.lua') -- must go before commands
dofile(verbana.modpath .. '/commands.lua')

-- cleanup (prevent access to insecure environment from any outside mod, or in-game)
sqlite3 = nil
verbana.sql = nil
verbana.db = nil
