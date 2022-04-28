local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

verbana = {
    version = "20220418.0",
    modname = modname,
    modpath = modpath,

    has = {
        irc = minetest.get_modpath("irc"),
        irc2 = minetest.get_modpath("irc2"),
        sban = minetest.get_modpath("sban"),
        xban = minetest.get_modpath("xban"),
        xban2 = minetest.get_modpath("xban2"),
        verification = minetest.get_modpath("verification"),
    },

    log = function(level, message, ...)
        message = message:format(...)
        minetest.log(level, ("[%s] %s"):format(modname, message))
    end,

    chat_send_player = function(player, message, ...)
        message = message:format(...)
        if type(player) ~= "string" then
            player = player:get_player_name()
        end
        minetest.chat_send_player(player, message)
        local irc_message = minetest.strip_colors(message)
        if verbana.has.irc and irc.joined_players[player] then
            irc.say(player, irc_message)
        end
        if verbana.has.irc2 and irc2.joined_players[player] then
            irc2.say(player, irc_message)
        end
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

if verbana.settings.debug_mode then
    verbana.log("warning", "Verbana is running in debug mode.")
end

-- libraries
verbana.dofile("util")
verbana.dofile("lib", "init")

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
    http_api = verbana.assert_warn(minetest.request_http_api(), "Verbana will automatically update network information without http access. See README.md"),
}

ie = nil -- nuke this as quickly as possible

-- core
verbana.dofile("privs")  -- must go before chat
verbana.dofile("data", "init") -- must go before chat
verbana.dofile("chat", "init") -- chat must go before login_handling
verbana.dofile("login_handling")
verbana.dofile("imports", "init") -- must go before commands
verbana.dofile("commands", "init")

-- cleanup (prevent access to insecure environment from any outside mod, or in-game)
sqlite3 = nil
verbana.ie = nil
