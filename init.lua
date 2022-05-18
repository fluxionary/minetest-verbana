local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local S = minetest.get_translator(modname)

verbana = {
	version = os.time({year = 2022, month = 4, day = 18}),
	fork = "fluxionary",

    modname = modname,
    modpath = modpath,

	S = S,

    has = {
        irc = minetest.get_modpath("irc"),
        irc_commands = minetest.get_modpath("irc_commands"),
        -- irc2 is blocky survival's hacky way of connecting to two separate irc servers simultaneously
        irc2 = minetest.get_modpath("irc2"),
        irc_commands2 = minetest.get_modpath("irc_commands2"),
        sban = minetest.get_modpath("sban"),
        xban = minetest.get_modpath("xban"),
        xban2 = minetest.get_modpath("xban2"),
        verification = minetest.get_modpath("verification"),
    },

    log = function(level, message, ...)
        message = message:format(...)
        minetest.log(level, ("[%s] %s"):format(modname, message))
    end,

    assert_warn = function(value, message, ...)
        if not value then
            verbana.log("warning", message, ...)
        end
        return value
    end,

	dofile = function(...)
		dofile(table.concat({modpath, ...}, DIR_DELIM) .. ".lua")
	end,
}

-- settings
verbana.dofile("settings")
verbana.dofile("privs")

if verbana.settings.debug_mode then
    verbana.log("warning", "Verbana is running in debug mode.")
end

-- connect to the DB - restrict access to full insecure environment to this point
local ie = assert(
    minetest.request_insecure_environment(),
    "Verbana will not work unless it has been listed under secure.trusted_mods in minetest.conf"
)

verbana.ie = {
    lfs = assert(ie.require("lfs"), "Verbana will not function without lfs. See README.md"),
    imath = assert(ie.require("imath"), "Verbana will not function without limath. See README.md"),
    sqlite = ie.require("lsqlite3"),
    pgsql = assert(ie.require("pgsql"), "Verbana will not function without pgsql. See README.md"),
    http_api = verbana.assert_warn(minetest.request_http_api(),
        "Verbana cannot automatically update network information without http access. See README.md"),
    iconv = verbana.assert_warn(ie.require("liconv"),
        "Verbana cannot automatically update network information without iconv. See README.md"),
}

-- core
verbana.dofile("lib", "init") -- lib must go first
verbana.dofile("data", "init")
verbana.dofile("db", "init") -- db must go before chat
verbana.dofile("chat", "init") -- chat must go before callbacks
verbana.dofile("callbacks", "init")
verbana.dofile("imports", "init") -- must go before commands
verbana.dofile("commands", "init")

-- cleanup (prevent access to insecure environment from any outside mod, or in-game)
ie = nil
sqlite3 = nil
verbana.ie = nil
