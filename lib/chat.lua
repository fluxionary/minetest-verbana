verbana.chat = {}

local data = verbana.data
local has = verbana.has
local privs = verbana.privs

function verbana.chat.send_mods(message, ...)
    message = message:format(...)
    local irc_message = "[verbana] " .. minetest.strip_colors(message)
    if has.irc then
        irc.say(irc_message)
    end
    if has.irc2 then
        irc2.say(irc_message)
    end

    for _, player in ipairs(minetest.get_connected_players()) do
        if privs.is_privileged(player) then
            verbana.chat_send_player(player, message)
        end
    end
end
