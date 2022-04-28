

-- make this the first chat message handler by inserting it at the start.
-- this has the effect of
--   (1) preempting irc (and irc2)
--   (2) disabling all server-side commands
table.insert(minetest.registered_on_chat_messages, 1,
    function(name, message)
        local player_id = data.get_player_id(name)
        local player_status = data.get_player_status(player_id)
        local is_unverified = player_status.id == data.player_status.unverified.id
        if is_unverified then
            local cmsg = ("[unverified] <%s> %s"):format(name, message)
            verbana.chat.send_mods(cmsg)
            verbana.chat_send_player(name, cmsg)
            return true
        end
        return false
    end
)
