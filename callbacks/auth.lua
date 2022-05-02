local data                    = verbana.data
local lib_asn                 = verbana.lib.asn
local lib_ip                  = verbana.lib.ip
local log                     = verbana.log
local util                    = verbana.util

local safe                    = util.safe

if minetest.register_on_authplayer then
    function verbana.callbacks.on_authplayer(name, ipstr, is_success)
        if is_success then
            log("action", "auth success: %s %s", name, ipstr)
        else
            log("action", "auth failure: %s %s", name, ipstr)
        end
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local asn = lib_asn.lookup(ipint)
        local player_id = data.get_player_id(name, true) -- will create one if none exists

        data.register_ip(ipint)
        data.register_asn(asn)
        data.log(player_id, ipint, asn, false)
    end

    minetest.register_on_authplayer(safe(function(...)
        return verbana.callbacks.on_authplayer(...)
    end))

elseif minetest.register_on_auth_fail then
    function verbana.callbacks.on_auth_fail(name, ipstr)
        log("action", "auth failure: %s %s", name, ipstr)
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local asn = lib_asn.lookup(ipint)
        local player_id = data.get_player_id(name, true) -- will create one if none exists

        data.register_ip(ipint)
        data.register_asn(asn)
        data.log(player_id, ipint, asn, false)
    end

    minetest.register_on_auth_fail(safe(function(...)
        return verbana.callbacks.on_auth_fail(...)
    end))

end
