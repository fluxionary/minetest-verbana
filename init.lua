verbana = {}
local modname = minetest.get_current_modname()
verbana.modpath = minetest.get_modpath(modname)

function verbana.log(level, message, ...)
    minetest.log(level, ('[%s] %s'):format(modname, message:format(...)))
end

if not minetest.request_insecure_environment() then
	error('insecure environment inaccessible - make sure this mod has been added to minetest.conf!')
end

dofile(verbana.modpath .. '/settings.lua')
dofile(verbana.modpath .. '/privs.lua')

dofile(verbana.modpath .. '/ipmanip.lua')
dofile(verbana.modpath .. '/asn.lua')

dofile(verbana.modpath .. '/data.lua')

dofile(verbana.modpath .. '/commands.lua')
dofile(verbana.modpath .. '/login_handling.lua')
