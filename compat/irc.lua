if not verbana.has.irc then
    return
end

verbana.api.register_on_send_mods(function(message, ...)
    if #{...} > 0 then
        message = message:format(...)
    end

    local irc_message = minetest.strip_colors(message)

    irc.say(irc_message)
end)

if verbana.has.irc_commands then
    -- irc_commands doesn't publish the logged in user map, so we have to track it ourselves

    local irc_users = {}

    local old_irc_login = irc.bot_commands["login"]
    local old_irc_logout = irc.bot_commands["logout"]

    verbana.api.register_on_send_player(function(player, message, ...)
        if #{...} > 0 then
            message = message:format(...)
        end

        local irc_message = minetest.strip_colors(message)

        if type(player) ~= "string" then
            player = player:get_player_name()
        end

        -- TODO: this sends a message to the IRC user if their name matches. it doesn't mean it's actually
        -- TODO: the same person.
        --if irc.joined_players[player] then
        --    irc.say(player, irc_message)
        --end
    end)
end
