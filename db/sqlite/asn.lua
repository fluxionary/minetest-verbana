
function data.register_asn(asn)
    local code = ""
    return execute_bind_one(code, "register asn", asn)
end

local asn_status_cache = {}
function data.get_asn_status(asn, create_if_new)
    local cached_status = asn_status_cache[asn]
    if cached_status then return cached_status end
    local code = [[

    ]]
    local table = get_full_ntable(code, "get asn status", asn)
    if #table == 1 then
        asn_status_cache[asn] = table[1]
        return table[1]
    elseif #table > 1 then
        log("error", "somehow got more than 1 result when getting current asn status for %s", asn)
        return
    elseif not create_if_new then
        return
    end
    if not data.set_asn_status(asn, data.verbana_player_id, data.asn_status.default.id, "creating initial asn status") then
        log("error", "failed to set initial asn status")
        return
    end
    return data.get_asn_status(asn, false)
end
function data.set_asn_status(asn, executor_id, status_id, reason, expires)
    asn_status_cache[asn] = nil
    local code = [[

    ]]
    local now = os.time()
    if not execute_bind_one(code, "set asn status", asn, executor_id, status_id, reason, expires, now) then return false end
    local last_id = db:last_insert_rowid()
    code = ""
    if not execute_bind_one(code, "update asn last status id", last_id, asn) then return false end
    return true
end

function data.get_asn_stats(asn)
    local code = [[

    ]]
    return get_full_ntable(code, "asn stats",
        data.player_status.default.id,
        data.player_status.default.id,
        asn,
        data.player_status.default.id,
        data.player_status.default.id
    )
end
