if not verbana then verbana = {} end
if not verbana.modpath then verbana.modpath = '.' end
if not verbana.ip then dofile(verbana.modpath .. '/lib_ip.lua') end
if not verbana.log then function verbana.log(_, message, ...) print(message:format(...)) end end
verbana.asn = {}

local ASN_DESCRIPTION_FILE = 'data-used-autnums'
local NETWORK_ASN_FILE = 'data-raw-table'

local load_file = verbana.util.load_file

local function refresh_asn_descriptions()
    local contents = load_file(('%s/%s'):format(verbana.modpath, ASN_DESCRIPTION_FILE))
    if not contents then return end
    local description = {}

    for line in contents:gmatch('[^\r\n]+') do
        local asn, desc = line:match('^%s*(%d+)%s+(.*)$')
        if not asn or not desc then
            verbana.log('warning', 'could not interpret description line "%s"', line)
        else
            asn = tonumber(asn)
            description[asn] = desc
        end
    end

    verbana.asn.description = description
    return true
end

local function refresh_asn_table()
    local contents = load_file(('%s/%s'):format(verbana.modpath, NETWORK_ASN_FILE))
    if not contents then return end

    local networks = {}
    for line in contents:gmatch('[^\r\n]+') do
        local net, asn = line:match('^%s*(%S*)%s+(%S*)%s*$')
        if not asn or not net then
            verbana.log('warning', 'could not interpret network line "%s"', line)
        else
            asn = tonumber(asn)
            local start, end_ = verbana.ip.netstr_to_bounds(net)

            if #networks == 0 then
                table.insert(networks, {start, end_, asn})
            else
                local prev_net = networks[#networks]
                local prev_start = prev_net[1]
                local prev_end = prev_net[2]
                local prev_asn = prev_net[3]

                if prev_start <= start and prev_end >= end_ and prev_asn == asn then
                    -- redundant data, skip
                elseif start <= prev_end then
                    -- subnet delegated to someone else; split the prev network
                    table.remove(networks)
                    if prev_start ~= (start - 1) then
                        table.insert(networks, {prev_start, start - 1, prev_asn })
                    end
                    table.insert(networks, {start, end_, asn })
                    if (end_ + 1) ~= prev_end then
                        table.insert(networks, {end_ + 1, prev_end, prev_asn })
                    end
                elseif (prev_end + 1) == start and prev_asn == asn then
                    -- adjacent networks belong to the same ASN; just extend the existing network
                    networks[#networks][2] = end_
                else
                    -- default case
                    table.insert(networks, {start, end_, asn})
                end
            end
        end
    end

    verbana.asn.network = networks
    return true
end

function verbana.asn.refresh()
    local start = os.clock()
    if not refresh_asn_descriptions() then return end
    if not refresh_asn_table() then return end

    verbana.log('action', 'refreshed ASN tables in %s seconds', os.clock() - start)
    return true
end

if not verbana.asn.refresh() then
    error('Verbana could not load ASN data')
end

local function find(ipint)
    local t = verbana.asn.network
    local low = 1
    local high = #t
    while low <= high do
        local mid = math.floor((low + high) / 2)
        -- verbana.log('action', '%s %s %s %s %s', ipint, low, mid, high, #t)
        local element = t[mid]
        local start = element[1]
        local end_ = element[2]

        if start <= ipint and ipint <= end_ then
            return element[3]
        elseif start > ipint then
            high = mid - 1
        else
            low = mid + 1
        end
    end
end

function verbana.asn.lookup(ipstr)
    local ipint
    if type(ipstr) == 'number' then
        ipint = ipstr
    else
        ipint = verbana.ip.ipstr_to_number(ipstr)
    end
    local asn = find(ipint)
    if asn then
        return asn, verbana.asn.description[asn]
    else
        return 0, 'IP not associated with a known ASN'
    end
end
