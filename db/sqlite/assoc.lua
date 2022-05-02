
function data.assoc(player_id, ipint, asn)
    player_id = data.get_master(player_id) or player_id
    local insert_code = [[
    ]]
    local now = os.time()
    if not execute_bind_one(insert_code, "insert assoc", player_id, ipint, asn, now, now) then return false end
    local update_code = [[

    ]]
    if not execute_bind_one(update_code, "update assoc", now, player_id, ipint, asn) then return false end
    return true
end

function data.has_asn_assoc(player_id, asn)
    player_id = data.get_master(player_id) or player_id
    local code = ""
    local table = get_full_table(code, "find player asn assoc", player_id, asn)
    return #table == 1
end

function data.has_ip_assoc(player_id, ipint)
    player_id = data.get_master(player_id) or player_id
    local code = ""
    local table = get_full_table(code, "find player ip assoc", player_id, ipint)
    return #table == 1
end

function data.get_player_associations(player_id)
    local code = [[

    ]]
    return get_full_ntable(code, "player associations", player_id)
end
function data.get_ip_associations(ipint, from_time)
    local code = [[

    ]]
    return get_full_ntable(code, "ip associations", ipint, from_time)
end
function data.get_asn_associations(asn, from_time)
    local code = [[

    ]]
    return get_full_ntable(code, "asn associations", asn, from_time)
end

function data.get_player_cluster(player_id)
    local code = [[

    ]]
    return get_full_ntable(code, "player cluster", player_id)
end
