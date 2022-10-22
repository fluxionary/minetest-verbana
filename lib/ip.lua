verbana.lib.ip = {}
local ip = verbana.lib.ip

local imath = verbana.ie.imath

local util = verbana.util

local is_u8 = util.is_u8
local is_u16 = util.is_u16

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


function ip.is_valid_ip(ipstr)
    return parse_ipv4(ipstr) or parse_ipv6(ipstr)
end

function ip.ipstr_to_ipint(ipstr)
    return parse_ipv4(ipstr) or parse_ipv6(ipstr)
end

function ip.ipint_to_ipstr(ipint)
    error("todo") -- TODO
end

function ip.netstr_to_bounds(ipnet)
    local ip, net = ipnet:match("^(.*)/(%d+)$")
    local start = verbana.lib.ip.ipstr_to_ipint(ip)
    net = tonumber(net)
    local end_ = start + (2 ^ (32 - net)) - 1
    return start, end_
end
