if not verbana then verbana = {} end

verbana.ip = {}

function verbana.ip.is_valid_ip(ipstr)
    local a, b, c, d = ipstr:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')
    a = tonumber(a)
    b = tonumber(b)
    c = tonumber(c)
    d = tonumber(d)
    if not (a and b and c and d) then return false end
    return 0 <= a and a < 256 and 0 <= b and b < 256 and 0 <= c and c < 256 and 0 <= d and d < 256
end

function verbana.ip.ipstr_to_number(ipstr)
    local a, b, c, d = ipstr:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$')
    return (tonumber(a) * 16777216) + (tonumber(b) * 65536) + (tonumber(c) * 256) + tonumber(d)
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

