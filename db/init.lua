verbana.db = {}
local db = verbana.db

verbana.dofile("db", "constants")
verbana.dofile("db", "sqlite", "init")
verbana.dofile("db", "postgres", "init")

local ipint_to_ipstr = verbana.lib.ipint_to_ipstr
local log = verbana.log

function verbana.db.fumble_about_for_an_ip(name, player_id)
    local ipstr = verbana.util.get_player_ip(name)

    if not ipstr then
        if not player_id then player_id = db.get_player_id(name) end
        local connection_log = db.get_player_connection_log(player_id, 1)
        if not connection_log or #connection_log ~= 1 then
            log("warning", "player %s exists but has no connection log?", player_id)
        else
            local last_login = connection_log[1]
            ipstr = ipint_to_ipstr(last_login.ipint)
        end
    end

    return ipstr
end

