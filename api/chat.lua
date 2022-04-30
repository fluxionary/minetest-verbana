
verbana.api.chat = {}

verbana.api.chat.registered_on_send_players = {}
function verbana.api.chat.register_on_send_player(func)
    table.insert(verbana.api.chat.registered_on_send_players, func)
end

function verbana.api.chat.do_send_player(player, message)
    for _, func in ipairs(verbana.api.chat.registered_on_send_players) do
        if func(player, message) then
            return true
        end
    end
end

verbana.api.chat.registered_on_send_mods = {}
function verbana.api.chat.register_on_send_mods(func)
    table.insert(verbana.api.chat.registered_on_send_mods, func)
end

function verbana.api.chat.do_send_mods(message)
    for _, func in ipairs(verbana.api.chat.registered_on_send_players) do
        if func(message) then
            return true
        end
    end
end
