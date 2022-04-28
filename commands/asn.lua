
register_chatcommand("asn", {
    description="Get the ASN associated with an IP or player name",
    params="<player_name> | <IP>",
    privs={[mod_priv]=true},
    func = function(_, name_or_ipstr)
        local ipstr

        if lib_ip.is_valid_ip(name_or_ipstr) then
            ipstr = name_or_ipstr
        else
            ipstr = data.fumble_about_for_an_ip(name_or_ipstr)
        end

        if not ipstr or ipstr == "" then
            return false, (""%s" is not a valid ip nor a known player"):format(name_or_ipstr)
        end

        local asn, description = lib_asn.lookup(ipstr)
        if not asn or asn == 0 then
            return false, ("could not find ASN for "%s""):format(ipstr)
        end

        description = description or ""

        return true, ("A%u (%s)"):format(asn, description)
    end
})


----------------- SET ASN STATUS COMMANDS -----------------
local function parse_asn_status_params(params)
    local asnstr, reason = params:match("^A?(%d+)%s+(.*)$")
    if not asnstr then
        asnstr = params:match("^A?(%d+)$")
    end
    if not asnstr then
        return nil, nil, nil, ("Invalid argument(s): %q"):format(params)
    end
    local asn = tonumber(asnstr)
    local description = lib_asn.get_description(asn)
    if description == lib_asn.invalid_asn_description then
        return nil, nil, nil, ("Not a valid ASN: %q"):format(params)
    end
    data.register_asn(asn)
    local asn_status = data.get_asn_status(asn, true)
    return asn, description, asn_status, reason
end

register_chatcommand("asn_suspect", {
    description="Mark an ASN as suspicious.",
    params="<ASN> [<reason>]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        if asn_status.id ~= data.asn_status.default.id then
            return false, ("Cannot suspect ASN w/ status %s"):format(asn_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.suspicious.id, reason) then
            return false, "ERROR setting ASN status"
        end
        if reason then
            log("action", "%s suspected A%s because %s", caller, asn, reason)
        else
            log("action", "%s suspected A%s", caller, asn)
        end
        return true, ("Suspected A%s (%s)"):format(asn, description)
    end
})

register_chatcommand("asn_unsuspect", {
    description="Unmark an ASN as suspicious.",
    params="<ASN> [<reason>]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        if asn_status.id ~= data.asn_status.suspicious.id then
            return false, ("A%s is not suspicious!"):format(asn)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.default.id, reason) then
            return false, "ERROR setting ASN status"
        end
        if reason then
            log("action", "%s unsuspected A%s because %s", caller, asn, reason)
        else
            log("action", "%s unsuspected A%s", caller, asn)
        end
        return true, ("Unsuspected A%s (%q)"):format(asn, description)
    end
})

register_chatcommand("asn_block", {
    description="Block an ASN. Duration and reason optional.",
    params="<ASN> [<duration>] [<reason>]",
    privs={[admin_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        local timespan
        local expires
        if reason then
            local first = reason:match("^(%S+)")
            timespan = parse_timespan(first)
            if timespan then
                reason = reason:sub(first:len() + 2)
                expires = os.time() + timespan
            end
        end
        if not table_contains({
                data.asn_status.default.id,
                data.asn_status.suspicious.id,
            }, asn_status.id) then
            return false, ("Cannot block ASN w/ status %s"):format(asn_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.blocked.id, reason, expires) then
            return false, "ERROR setting ASN status"
        end
        util.safe_kick_asn(asn)
        if expires then
            if reason then
                log("action", "%s blocked A%s until %s because %s", caller, asn, iso_date(expires), reason)
            else
                log("action", "%s blocked A%s until %s ", caller, asn, iso_date(expires))
            end
        else
            if reason then
                log("action", "%s blocked A%s because %s", caller, asn, reason)
            else
                log("action", "%s blocked A%s", caller, asn)
            end
        end
        return true, ("Blocked A%s (%q)"):format(asn, description)
    end
})

register_chatcommand("asn_unblock", {
    description="Unblock an ASN.",
    params="<ASN> [<reason>]",
    privs={[admin_priv]=true},
    func=function(caller, params)
        local asn, description, asn_status, reason = parse_asn_status_params(params)
        if not asn then
            return false, reason
        end
        if asn_status.id ~= data.asn_status.blocked.id then
            return false, "ASN is not blocked!"
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_asn_status(asn, executor_id, data.asn_status.default.id, reason) then
            return false, "ERROR setting IP status"
        end
        if reason then
            log("action", "%s unblocked A%s because %s", caller, asn, reason)
        else
            log("action", "%s unblocked A%s", caller, asn)
        end
        return true, ("Unblocked A%s (%q)"):format(asn, description)
    end
})

register_chatcommand("asn_status", {
    description="shows the status log of an ASN",
    params="<ASN> [<number>]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asnstr, numberstr = string.match(params, "^A?(%d+)%s+(%d+)$")
        if not asnstr then
            asnstr = string.match(params, "^A?(%d+)$")
            if not asnstr then
                return false, "invalid arguments"
            end
        end
        local asn = tonumber(asnstr)
        local rows = data.get_asn_status_log(asn)
        if not rows then
            return false, "An error occurred (see server logs)"
        end
        if #rows == 0 then
            return true, "No records found."
        end
        local starti
        if numberstr then
            local number = tonumber(numberstr)
            starti = math.max(1, #rows - number)
        else
            starti = 1
        end
        for index = starti,#rows do
            local row = rows[index]
            local status_name = data.asn_status_name[row.status_id] or data.asn_status.default.name
            local status_color = data.asn_status_color[row.status_id] or data.asn_status.default.color
            local message = ("%s: %s set status to %s."):format(
                iso_date(row.timestamp),
                row.executor_name,
                minetest.colorize(status_color, status_name)
            )
            local reason = row.reason
            if reason and reason ~= "" then
                message = ("%s Reason: %s"):format(message, reason)
            end
            local expires = row.expires
            if expires then
                message = ("%s Expires: %s"):format(message, iso_date(expires))
            end
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand("asn_inspect", {
    description="list *FLAGGED* player accounts and statuses associated with an ASN",
    params="<ASN> [<timespan>=1y]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asn, timespan_str = params:match("^A?(%d+)%s+(%w+)$")
        if not asn then
            asn = params:match("^A?(%d+)$")
            if not asn then
                return false, "Invalid argument"
            end
        end
        local timespan
        if timespan_str then
            timespan = parse_timespan(timespan_str)
            if not timespan then
                return false, "Invalid timespan"
            end
        else
            timespan = parse_timespan("1y")
        end
        asn = tonumber(asn)
        local description = lib_asn.get_description(asn)
        local start_time = os.time() - timespan
        local rows = data.get_asn_associations(asn, start_time)
        if not rows then
            return false, "An error occurred (see server logs)"
        end
        if #rows == 0 then
            return true, "No records found."
        end
        chat_send_player(caller, ("Records for A%s : %s"):format(asn, description))
        for _, row in ipairs(rows) do
            local status_name = data.player_status_name[row.player_status_id] or data.player_status.default.name
            local status_color = data.player_status_color[row.player_status_id] or data.player_status.default.color
            local message = ("% 20s: %s (last IP: %s)"):format(
                row.player_name,
                minetest.colorize(status_color, status_name),
                lib_ip.ipint_to_ipstr(row.ipint)
            )
            chat_send_player(caller, message)
        end
        return true
    end
})

register_chatcommand("asn_stats", {
    description="Get statistics for an ASN",
    params="<ASN>",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local asnstr = params:match("^A?(%d+)$")
        if not asnstr then
            return false, "Invalid argument"
        end
        local asn = tonumber(asnstr)
        local asn_description = lib_asn.get_description(asn)
        local rows = data.get_asn_stats(asn)
        if not rows then
            return false, "Error: see server log"
        elseif #rows == 0 then
            return true, "No data"
        end
        chat_send_player(caller, ("Statistics for %s:"):format(asn_description))
        for _, row in ipairs(rows) do
            local status_name = data.player_status_name[row.player_status_id] or data.player_status.default.name
            local status_color = data.player_status_color[row.player_status_id] or data.player_status.default.color
            chat_send_player(caller, ("%s %s"):format(
                minetest.colorize(status_color, status_name),
                row.count
            ))
        end
        return true
    end
})
