verbana.chat = {}

function verbana.chat.tell_mods(message)
    if minetest.global_exists('irc') then irc:say(message) end
    if minetest.global_exists('irc2') then irc2:say(message) end

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local privs = minetest.get_player_privs(name)
        if privs[verbana.privs.moderator] or privs[verbana.privs.admin] then
            minetest.chat_send_player(name, message)
        end
    end
end

-- make this the first chat message handler
table.insert(minetest.registered_on_chat_messages, 1,
    function(name, message)
        if minetest.check_player_privs(name, {[verbana.privs.unverified]=true}) then
            local cmsg = ('[unverified] <%s> %s'):format(name, message)
            verbana.chat.tell_mods(cmsg)
            minetest.chat_send_player(name, cmsg)
            return true
        end
        return false
end)
