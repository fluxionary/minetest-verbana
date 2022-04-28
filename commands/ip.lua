
----------------- SET IP STATUS COMMANDS -----------------
local function parse_ip_status_params(params)
    local ipstr, reason = params:match("^(%d+%.%d+%.%d+%.%d+)%s+(.*)$")
    if not ipstr then
        ipstr = params:match("^(%d+%.%d+%.%d+%.%d+)$")
    end
    if not ipstr or not lib_ip.is_valid_ip(ipstr) then
        return nil, nil, nil, ("Invalid argument(s): %q"):format(params)
    end
    local ipint = lib_ip.ipstr_to_ipint(ipstr)
    data.register_ip(ipint)
    local ip_status = data.get_ip_status(ipint, true)
    return ipint, ipstr, ip_status, reason
end

register_chatcommand("ip_trust", {
    description="Mark an IP as trusted - connections will bypass suspicious network checks",
    params="<IP> [<reason>]",
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if not table_contains({
                data.ip_status.default.id,
                data.ip_status.suspicious.id,
            }, ip_status.id) then
            return false, ("Cannot trust IP w/ status %s"):format(ip_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.trusted.id, reason) then
            return false, "ERROR setting IP status"
        end
        if reason then
            log("action", "%s trusted %s because %s", caller, ipstr, reason)
        else
            log("action", "%s trusted %s", caller, ipstr)
        end
        return true, ("Trusted %s"):format(ipstr)
    end
})

register_chatcommand("ip_untrust", {
    description="Remove trusted status from an IP",
    params="<IP> [<reason>]",
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.player_status.trusted.id then
            return false, ("IP %s is not trusted!"):format(ipstr)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.default.id, reason) then
            return false, "ERROR setting IP status"
        end
        if reason then
            log("action", "%s untrusted %s because %s", caller, ipstr, reason)
        else
            log("action", "%s untrusted %s", caller, ipstr)
        end
        return true, ("Untrusted %s"):format(ipstr)
    end
})

register_chatcommand("ip_suspect", {
    description="Mark an IP as suspicious.",
    params="<IP> [<reason>]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.ip_status.default.id then
            return false, ("Cannot suspect IP w/ status %s"):format(ip_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.suspicious.id, reason) then
            return false, "ERROR setting IP status"
        end
        if reason then
            log("action", "%s suspected %s because %s", caller, ipstr, reason)
        else
            log("action", "%s suspected %s", caller, ipstr)
        end
        return true, ("Suspected %s"):format(ipstr)
    end
})

register_chatcommand("ip_unsuspect", {
    description="Unmark an IP as suspicious",
    params="<IP> [<reason>]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.player_status.suspicious.id then
            return false, ("IP %s is not suspicious!"):format(ipstr)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.default.id, reason) then
            return false, "ERROR setting IP status"
        end
        if reason then
            log("action", "%s unsuspected %s because %s", caller, ipstr, reason)
        else
            log("action", "%s unsuspected %s", caller, ipstr)
        end
        return true, ("Unsuspected %s"):format(ipstr)
    end
})

register_chatcommand("ip_block", {
    description="Block an IP from connecting.",
    params="<IP> [<reason>]",
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
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
                data.ip_status.default.id,
                data.ip_status.suspicious.id,
            }, ip_status.id) then
            return false, ("Cannot block IP w/ status %s"):format(ip_status.name)
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.blocked.id, reason, expires) then
            return false, "ERROR setting IP status"
        end
        util.safe_kick_ip(ipstr)
        if expires then
            if reason then
                log("action", "%s blocked %s until %s because %s", caller, ipstr, iso_date(expires), reason)
            else
                log("action", "%s blocked %s until %s", caller, ipstr, iso_date(expires))
            end
        else
            if reason then
                log("action", "%s blocked %s because %s", caller, ipstr, reason)
            else
                log("action", "%s blocked %s", caller, ipstr)
            end
        end
        return true, ("Blocked %s"):format(ipstr)
    end
})

register_chatcommand("ip_unblock", {
    description="Unblock an IP",
    params="<IP> [<reason>]",
    privs={[admin_priv]=true},
    func=function(caller, params)
        local ipint, ipstr, ip_status, reason = parse_ip_status_params(params)
        if not ipint then
            return false, reason
        end
        if ip_status.id ~= data.ip_status.blocked.id then
            return false, "IP is not blocked!"
        end
        local executor_id = data.get_player_id(caller)
        if not executor_id then
            return false, "ERROR: could not get executor ID?"
        end
        if not data.set_ip_status(ipint, executor_id, data.ip_status.default.id, reason) then
            return false, "ERROR setting IP status"
        end
        if reason then
            log("action", "%s unblocked %s because %s", caller, ipstr, reason)
        else
            log("action", "%s unblocked %s", caller, ipstr)
        end
        return true, ("Unblocked %s"):format(ipstr)
    end
})

register_chatcommand("ip_status", {
    description="shows the status log of an IP",
    params="<IP> [<number>]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipstr, numberstr = string.match(params, "^(%d+%.%d+%.%d+%.%d+)%s+(%d+)$")
        if not ipstr then
            ipstr = string.match(params, "^(%d+%.%d+%.%d+%.%d+)$")
        end
        if not ipstr or not lib_ip.is_valid_ip(ipstr) then
            return false, "invalid arguments"
        end
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local rows = data.get_ip_status_log(ipint)
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
            local status_name = data.ip_status_name[row.status_id] or data.ip_status.default.name
            local status_color = data.ip_status_color[row.status_id] or data.ip_status.default.color
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

register_chatcommand("ip_inspect", {
    description="list player accounts and statuses associated with an IP",
    params="<IP> [<timespan>=1m]",
    privs={[mod_priv]=true},
    func=function(caller, params)
        local ipstr, timespan_str = params:match("^(%d+%.%d+%.%d+%.%d+)%s+(%w+)$")
        if not lib_ip.is_valid_ip(ipstr) then
            ipstr = params:match("^%s*(%d+%.%d+%.%d+%.%d+)%s*$")
            if not lib_ip.is_valid_ip(ipstr) then
                return false, "Invalid arguments"
            end
        end
        local timespan
        if timespan_str then
            timespan = parse_timespan(timespan_str)
            if not timespan then
                return false, "Invalid timespan"
            end
        else
            timespan = parse_timespan("1m")
        end
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local rows = data.get_ip_associations(ipint, timespan)
        if not rows then
            return false, "An error occurred (see server logs)"
        end
        if #rows == 0 then
            return true, "No records found."
        end
        chat_send_player(caller, ("Records for %s"):format(ipstr))
        for _, row in ipairs(rows) do
            local status_name = data.player_status_name[row.player_status_id] or data.player_status.default.name
            local status_color = data.player_status_color[row.player_status_id] or data.player_status.default.color
            local message = ("% 20s: %s"):format(
                row.player_name,
                minetest.colorize(status_color, status_name)
            )
            chat_send_player(caller, message)
        end
        return true
    end
})
