#!/usr/bin/env lua5.1
-- this file is not intended to be loaded into minetest
-- it is provided to update the ASN DB lua scripts

local RAW_TABLE_URL = 'http://thyme.apnic.net/current/data-raw-table'  -- IP/mask\tASN
local NETWORK_ASN_FILE = 'network_asn.lua'
local ASN_DESCRIPTION_URL = 'http://thyme.apnic.net/current/data-used-autnums' -- ASN description
local ASN_DESCRIPTION_FILE = 'asn_descriptions.lua'

local http = require('socket.http')
require('DataDumper')
require('ipmanip')

local function download_page(url)
    local body, c, _, h = http.request(url)
    if c ~= 200 then
        print(('ERROR FETCHING "%s": "%s"'):format(url, h))
        return
    end
    return body
end

local function dump(table, varname, filename)
    local file = io.open(filename, 'w')
    if not file then
        print(('ERROR OPENING "%s" FOR WRITING'):format(filename))
        return
    end
    file:write('if not verbana then verbana = {} end\n')
    file:write(DataDumper(table, ('verbana.%s = '):format(varname), true))
    file:close()
end


local function update_descriptions()
    local body = download_page(ASN_DESCRIPTION_URL)
    if not body then return end

    local descriptions = {}

    for line in body:gmatch('[^\r\n]+') do
        local asn, desc = line:match('^%s*(%d+)%s+(%S*)%s*$')
        if not asn or not desc then
            print('could not interpret "' .. line .. '"')
        else
            asn = tonumber(asn)
            descriptions[asn] = desc
        end
    end

    dump(descriptions, 'asn_description', ASN_DESCRIPTION_FILE)
end

local function update_asn_look()
    local body = download_page(RAW_TABLE_URL)
    if not body then return end

    local networks = {}
    for line in body:gmatch('[^\r\n]+') do
        local net, asn = line:match('^%s*(%S*)%s+(%S*)%s*$')
        if not asn or not net then
            print('could not interpret "' .. line .. '"')
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

    dump(networks, 'network_asn', NETWORK_ASN_FILE)
end


-- #update_descriptions()
update_asn_look()
