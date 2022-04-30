verbana.lib.ip = {}

local imath = verbana.ie.imath

local function parse_ipv6(ipstr)
    if type(ipstr) ~= "string" then
        return
    end
    local before_gap = true
    local before_chunks = {}
    local after_chunks = {}
    local index = 1
    local chunks = before_chunks

    while index <= #ipstr do
        if ipstr:sub(index, index + 1) == "::" then
            if not before_gap then
                return -- invalid
            end
            before_gap = false
            chunks = after_chunks
            index = index + 2

        elseif ipstr:sub(index, index) == ":" then
            index = index + 1

        elseif ipstr:sub(index, #ipstr):match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$") then
            local a, b, c, d = ipstr:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
            a = tonumber(a)
            b = tonumber(b)
            c = tonumber(c)
            d = tonumber(d)
            if is_u8(a) and is_u8(b) and is_u8(c) and is_u8(d) then
                table.insert(chunks, (a * 256) + b)
                table.insert(chunks, (c * 256) + d)
                index = #ipstr + 1
            else
                return  -- invalid
            end

        else
            local chunk = ipstr:sub(index, #ipstr):match("^([^:]+):")
            if not chunk then
                chunk = ipstr:sub(index, #ipstr):match("^([^:]+)$")
            end
            local number = tonumber(chunk, 16)
            if not number then
                -- invalid
                return
            end
            table.insert(chunks, number)
            index = index + #chunk
        end
    end

    if #before_chunks ~= 8 then
        if #after_chunks > 0 then
            for _ = 1, 8 - (#before_chunks + #after_chunks) do
                table.insert(before_chunks, 0)
            end
            for _, chunk in ipairs(after_chunks) do
                table.insert(before_chunks, chunk)
            end
        end
    end

    if #before_chunks ~= 8 then
        return  -- something went wrong
    end

    local total = imath.new()
    for _, chunk in ipairs(before_chunks) do
        if not is_u16(chunk) then
            return
        end
        total = total * 0x10000
        total = total + chunk
    end
    return total
end

local function parse_ipv4(ipstr)
    if type(ipstr) ~= "string" then
        return
    end
    return parse_ipv6("::ffff:" .. ipstr)
end


function verbana.lib_ip.is_valid_ip(ipstr)
    return parse_ipv4(ipstr) or parse_ipv6(ipstr)
end

function verbana.lib_ip.ipstr_to_ipint(ipstr)
    return parse_ipv4(ipstr) or parse_ipv6(ipstr)
end

function verbana.lib_ip.ipint_to_ipstr(number)
    error("todo") -- TODO
end

function verbana.lib_ip.netstr_to_bounds(ipnet)
    local ip, net = ipnet:match("^(.*)/(%d+)$")
    local start = verbana.lib_ip.ipstr_to_ipint(ip)
    net = tonumber(net)
    local end_ = start + (2 ^ (32 - net)) - 1
    return start, end_
end

function data.fumble_about_for_an_ip(name, player_id)
    -- for some reason, get_player_ip is unreliable during register_on_newplayer
    local ipstr = minetest.get_player_ip(name)
    if not ipstr then
        local info = minetest.get_player_information(name)
        if info then
            ipstr = info.address
        end
    end

    if not ipstr then
        if not player_id then player_id = data.get_player_id(name) end
        local connection_log = data.get_player_connection_log(player_id, 1)
        if not connection_log or #connection_log ~= 1 then
            log("warning", "player %s exists but has no connection log?", player_id)
        else
            local last_login = connection_log[1]
            ipstr = lib_ip.ipint_to_ipstr(last_login.ipint)
        end
    end
    return ipstr
end


