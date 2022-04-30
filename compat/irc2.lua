if not verbana.has.irc2 then
    return
end

verbana.api.register_on_send_mods(function(message, ...)
    if #{...} > 0 then
        message = message:format(...)
    end

    local irc_message = minetest.strip_colors(message)

    irc2.say(irc_message)
end)

if verbana.has.irc_commands2 then
    -- TODO
end
