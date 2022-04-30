verbana.chat = {}

local has = verbana.has
local privs = verbana.privs


function verbana.chat.send_player(player, message, ...)
    if #{...} > 0 then
        message = message:format(...)
    end

    if type(player) ~= "string" then
        player = player:get_player_name()
    end

    if not verbana.api.chat.do_send_player(player, message) then
        minetest.chat_send_player(player, message)
    end
end

function verbana.chat.send_mods(message, ...)
    if #{...} > 0 then
        message = message:format(...)
    end

    if not verbana.api.chat.do_send_mods(message) then
        for _, player in ipairs(minetest.get_connected_players()) do
            if privs.is_privileged(player) then  -- mods and admins
                verbana.chat.send_player(player, message)
            end
        end
    end
end
