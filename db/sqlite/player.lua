
local player_id_cache = {}
function data.get_player_id(name, create_if_new)
    local cached_id = player_id_cache[name]
    if cached_id then return unpack(cached_id) end
    if create_if_new then
        if not execute_bind_one("", "insert player", name) then
            log("warning", "data.get_player_id: failed to create ID for player %s", name)
            return nil, nil
        end
    end
    local table = get_full_table("", "get player id", name)
    if not (table and table[1]) then
        log("warning", "data.get_player_id: failed to retrieve ID for player %s; %s", name, create_if_new)
        return nil, nil
    end
    player_id_cache[name] = table[1]
    return unpack(table[1])
end

function data.flag_player(player_id, flag)
    local code = [[

    ]]
    if not flag then flag = true end
    return execute_bind_one(code, "flag player", flag, player_id)
end

local player_status_cache = {}
function data.get_player_status(player_id, create_if_new)
    player_id = data.get_master(player_id) or player_id
    local cached_status = player_status_cache[player_id]
    if cached_status then return cached_status, false end
    local code = [[

    ]]
    local table = get_full_ntable(code, "get player status", player_id)
    if #table == 1 then
        player_status_cache[player_id] = table[1]
        return table[1], false
    elseif #table > 1 then
        log("error", "somehow got more than 1 result when getting current player status for %s", player_id)
        return nil, false
    elseif not create_if_new then
        return nil, nil
    end
    if not data.set_player_status(player_id, data.verbana_player_id, data.player_status.default.id, "creating initial player status") then
        log("error", "failed to set initial player status")
        return nil, true
    end
    return data.get_player_status(player_id, false), true
end
function data.set_player_status(player_id, executor_id, status_id, reason, expires, no_update_current)
    player_id = data.get_master(player_id) or player_id
    player_status_cache[player_id] = nil
    local code = [[

    ]]
    local now = os.time()
    if not execute_bind_one(code, "set player status", player_id, executor_id, status_id, reason, expires, now) then return false end
    if not no_update_current then
        local last_id = db:last_insert_rowid()
        code = ""
        if not execute_bind_one(code, "update player last status id", last_id, player_id) then return false end
    end
    if status_id ~= data.player_status.default.id and status_id ~= data.player_status.whitelisted.id then
        return data.flag_player(player_id, true)
    end
    return true
end

function data.get_all_banned_players()
    local code = [[

    ]]
    return get_full_ntable(code, "get all banned",
        data.player_status.banned
    )
end

function data.get_ban_log(limit)
    local code = [[

    ]]
    if not limit or type(limit) ~= "number" or limit < 0 then limit = 20 end
    return get_full_ntable(code, "get ban log",
        data.verbana_player_id,
        limit
    )
end

function data.get_master(player_id)
    local code = [[

    ]]
    local rows = get_full_ntable(code, "get master", player_id)
    if rows and #rows > 0 then
        return rows[1].id, rows[1].name
    end
end

function data.set_master(player_id, master_id)
    --[[
        case 1: master has no master
                just set player's master
        case 2: master has a master
                subcase A: player and master's master are different
                    set player's master to master's master
                subcase B: player == master's master
                    swap player and master
        if other players have player as their master, update their master to player's new master.
        loops can not be created this way, because we've ensured that a "true" master can't have
        a master of its own.
    ]]
    local master_master_id = data.get_master(master_id)
    if master_master_id == player_id then
        return data.swap_master(player_id, master_id)
    elseif master_master_id then
        master_id = master_master_id
    end
    local code = [[

    ]]
    if not execute_bind_one(code, "set master 1", master_id, player_id) then
        return false, "error"
    end
    code = [[

    ]]
    if not execute_bind_one(code, "set master 2", master_id, player_id) then
        return false, "error"
    end
    return true
end

function data.swap_master(player_id, master_id)
    if data.get_master(player_id) ~= master_id then
        return false, "not player\"s master"
    end
    local code = [[

    ]]
    if not execute_bind_one(code, "swap master 1", nil, player_id) then
        return false, "error"
    end
    -- same code
    if not execute_bind_one(code, "swap master 2", player_id, master_id) then
        return false, "error"
    end
    code = [[

    ]]
    if not execute_bind_one(code, "swap master 3", player_id, master_id) then
        return false, "error"
    end
    return true
end

function data.unset_master(player_id)
    local code = [[

    ]]
    return execute_bind_one(code, "unset master", player_id)
end

function data.get_alts(player_id)
    local code = [[

    ]]
    local master_id = data.get_master(player_id) or player_id
    local rows = get_full_ntable(code, "get alts", master_id, master_id)
    if rows then
        local alts = {}
        for _, row in ipairs(rows) do
            table.insert(alts, row.name)
        end
        return alts
    end
end

function data.grep_player(pattern, limit)
    local code = [[

    ]]
    return get_full_ntable(code, "grep player", pattern, limit)
end
