local db_class = verbana.db.sqlite.db_class

function data.register_ip(ipint)
    local code = ""
    return execute_bind_one(code, "register ip", ipint)
end

local ip_status_cache = {}
function data.get_ip_status(ipint, create_if_new)
    local cached_status = ip_status_cache[ipint]
    if cached_status then return cached_status end
    local code = [[

    ]]
    local table = get_full_ntable(code, "get ip status", ipint)
    if #table == 1 then
        ip_status_cache[ipint] = table[1]
        return table[1]
    elseif #table > 1 then
        log("error", "somehow got more than 1 result when getting current ip status for %s", ipint)
        return
    elseif not create_if_new then
        return
    end
    if not data.set_ip_status(ipint, data.verbana_player_id, data.ip_status.default.id, "creating initial ip status") then
        log("error", "failed to set initial ip status")
        return
    end
    return data.get_ip_status(ipint, false)
end

function data.set_ip_status(ipint, executor_id, status_id, reason, expires)
    ip_status_cache[ipint] = nil
    local code = [[

    ]]
    local now = os.time()
    if not execute_bind_one(code, "set ip status", ipint, executor_id, status_id, reason, expires, now) then return false end
    local last_id = db:last_insert_rowid()
    code = ""
    if not execute_bind_one(code, "update ip last status id", last_id, ipint) then return false end
    return true
end
