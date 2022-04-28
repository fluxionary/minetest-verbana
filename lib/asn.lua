verbana.lib_asn = {}

verbana.lib_asn.invalid_asn_description = "Invalid ASN"

local lib_ip = verbana.lib_ip
local settings = verbana.settings

local load_file = verbana.util.load_file

-- map from ASN (integer) to description (string)
verbana.lib_asn.description = {}

local function refresh_asn_descriptions()
    local contents = load_file(settings.asn_description_path)
    if not contents then return end
    local description = {}

    for line in contents:gmatch("[^\r\n]+") do
        local asn, desc = line:match("^%s*(%d+)%s+(.*)$")
        if not asn or not desc then
            verbana.log("warning", "could not interpret description line "%s"", line)
        else
            asn = tonumber(asn)
            description[asn] = desc
        end
    end

    verbana.lib_asn.description = description
    return true
end

-- array of values like {starting_ip (integer), ending_ip (integer), ASN (integer)}
-- ip ranges should be sorted and not overlap.
verbana.lib_asn.network = {}

local function refresh_asn_table()
    -- format of source file: IP/NET ASN
    -- source file is assumed to be sorted
    -- source file may have overlapping networks corresponding to subleases;
    --   extra logic is used to resolve these overlaps.
    local contents = load_file(settings.asn_data_path)
    if not contents then return end

    local networks = {}
    for line in contents:gmatch("[^\r\n]+") do
        local net, asn = line:match("^%s*(%S*)%s+(%S*)%s*$")
        if not asn or not net then
            verbana.log("warning", "could not interpret network line "%s"", line)
        else
            asn = tonumber(asn)
            local start, end_ = lib_ip.netstr_to_bounds(net)

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

    verbana.lib_asn.network = networks
    return true
end

function verbana.lib_asn.refresh()
    local start = os.clock()
    if not refresh_asn_descriptions() then return false end
    if not refresh_asn_table() then return false end

    verbana.log("action", "refreshed ASN tables in %s seconds", os.clock() - start)
    return true
end

if not verbana.lib_asn.refresh() then
    error("Verbana could not load ASN data. Please see README.md for instructions.")
end

local function find(ipint)
    -- binary search
    local t = verbana.lib_asn.network
    local low = 1
    local high = #t
    while low <= high do
        local mid = math.floor((low + high) / 2)
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
    -- not found, return nil
end

function verbana.lib_asn.lookup(ipstr)
    local ipint
    if type(ipstr) == "number" then
        ipint = ipstr
    else
        ipint = lib_ip.ipstr_to_ipint(ipstr)
    end
    local asn = find(ipint)
    if asn then
        return asn, (verbana.lib_asn.description[asn] or "UNKNOWN")
    else
        return 0, "Not part of a known ASN"
    end
end

function verbana.lib_asn.get_description(asn)
    if asn == 0 then
        return "Not part of a known ASN"
    else
        return verbana.lib_asn.description[asn] or verbana.lib_asn.invalid_asn_description
    end
end
