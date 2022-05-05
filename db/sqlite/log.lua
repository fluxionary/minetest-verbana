local db_class = verbana.db.sqlite.db_class

function data.log(player_id, ipint, asn, success)
    local code = [[

    ]]
    local now = os.time()
    if not execute_bind_one(code, "log connection", player_id, ipint, asn, success, now) then
        return false
    end
    if success then
        local last_login_id = db:last_insert_rowid()
        code = [[

        ]]
        if not execute_bind_one(code, "set last login", last_login_id, player_id) then
            return false
        end
    end
    return true
end

function data.get_player_status_log(player_id)
    player_id = data.get_master(player_id) or player_id
    local code = [[

    ]]
    return get_full_ntable(code, "player status log", player_id)
end

function data.get_ip_status_log(ipint)
    local code = [[

    ]]
    return get_full_ntable(code, "ip status log", ipint)
end

function data.get_asn_status_log(asn)
    local code = [[

    ]]
    return get_full_ntable(code, "asn status log", asn)
end

function data.get_first_login(player_id)
    local code = [[

    ]]
    return get_full_ntable(code, "first login", player_id)
end

function data.get_player_connection_log(player_id, limit)
    local code = [[

    ]]
    if not limit or type(limit) ~= "number" or limit < 0 then
        limit = 20
    end
    local t = get_full_ntable(code, "player connection log", player_id, limit)
    return util.table_reversed(t)
end

function data.get_ip_connection_log(ipint, limit)
    local code = [[

    ]]
    if not limit or type(limit) ~= "number" or limit < 0 then
        limit = 20
    end
    local t = get_full_ntable(code, "ip connection log", ipint, limit)
    return util.table_reversed(t)
end

function data.get_asn_connection_log(asn, limit)
    local code = [[

    ]]
    if not limit or type(limit) ~= "number" or limit < 0 then
        limit = 20
    end
    local t = get_full_ntable(code, "asn connection log", asn, limit)
    return util.table_reversed(t)
end
