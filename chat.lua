verbana.chat = {}

local data = verbana.data
local privs = verbana.privs

local mod_priv = privs.moderator
local admin_priv = privs.admin

function verbana.chat.tell_mods(message, ...)
    message = message:format(...)
    if minetest.global_exists('irc') then irc:say(message) end
    if minetest.global_exists('irc2') then irc2:say(message) end

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        if privs.is_privileged(name) then
            minetest.chat_send_player(name, message)
        end
    end
end

-- make this the first chat message handler by inserting it at the start.
-- this has the effect of
--   (1) pre-empting irc (and irc2)
--   (2) disabling all server-side commands
table.insert(minetest.registered_on_chat_messages, 1,
    function(name, message)
        local player_id = data.get_player_id(name)
        local player_status = data.get_player_status(player_id)
        local is_unverified = player_status.status_id == data.player_status.unverified.id
        if is_unverified then
            local cmsg = ('[unverified] <%s> %s'):format(name, message)
            verbana.chat.tell_mods(cmsg)
            minetest.chat_send_player(name, cmsg)
            return true
        end
        return false
end)
