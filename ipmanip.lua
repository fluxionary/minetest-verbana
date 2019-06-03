if not verbana then verbana = {} end

verbana.ip = {}

function verbana.ip.ipstr_to_number(ip)
    local a, b, c, d = ip:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')
    a = tonumber(a)
    b = tonumber(b)
    c = tonumber(c)
    d = tonumber(d)
    return (a * 16777216) + (b * 65536) + (c * 256) + d
end

function verbana.ip.number_to_ipstr(number)
    local d = number % 256
    number = math.floor(number / 256)
    local c = number % 256
    number = math.floor(number / 256)
    local b = number % 256
    local a = math.floor(number / 256)
    return ('%u.%u.%u.%u'):format(a, b, c, d)
end

function verbana.ip.netstr_to_bounds(ipnet)
    local ip, net = ipnet:match('^(.*)/(%d+)$')
    local start = verbana.ip.ipstr_to_number(ip)
    net = tonumber(net)
    local end_ = start + (2 ^ (32 - net)) - 1
    return start, end_
end

