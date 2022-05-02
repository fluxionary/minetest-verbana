local chat                    = verbana.chat
local data                    = verbana.data
local lib_asn                 = verbana.lib.asn
local lib_ip                  = verbana.lib.ip
local log                     = verbana.log
local settings                = verbana.settings
local util                    = verbana.util

local safe                    = util.safe

local spawn_pos               = settings.spawn_pos
local unverified_spawn_pos    = settings.unverified_spawn_pos
local jail_bounds             = settings.jail_bounds
local jail_check_period       = settings.jail_check_period
local using_verification_jail = jail_bounds and jail_check_period

function verbana.callbacks.on_joinplayer(player)
    local name = player:get_player_name()
    local player_id = data.get_player_id(name)
    local player_status = data.get_player_status(player_id)
    local is_unverified = player_status.id == data.player_status.unverified.id
    local ipstr = data.fumble_about_for_an_ip(name)

    local ipint = lib_ip.ipstr_to_ipint(ipstr)
    local asn, _ = lib_asn.lookup(ipint)
    data.assoc(player_id, ipint, asn)

    if is_unverified then
        if ipstr then
            local ipint = lib_ip.ipstr_to_ipint(ipstr)
            local asn, asn_description = lib_asn.lookup(ipint)
            chat.send_mods(("*** Player %s from A%s (%s) is unverified."):format(name, asn, asn_description))
        else
            chat.send_mods(("*** Player %s is unverified."):format(name))
        end
    elseif player_status.id == data.player_status.suspicious.id then
        if ipstr then
            local ipint = lib_ip.ipstr_to_ipint(ipstr)
            local asn, asn_description = lib_asn.lookup(ipint)
            chat.send_mods(("*** Player %s from A%s (%s) is suspicious."):format(name, asn, asn_description))
        else
            chat.send_mods(("*** Player %s is suspicious."):format(name))
        end
    end

    if using_verification_jail then
        if should_rejail(player, player_status) then
            log("action", "spawning %s in verification jail", name)
            if not settings.debug_mode then
                player:set_pos(unverified_spawn_pos)
            end
        elseif should_unjail(player, player_status) then
            log("action", "removing %s from verification jail on spawn", name)
            if not settings.debug_mode then
                player:set_pos(spawn_pos)
            end
        end
    end
end


minetest.register_on_joinplayer(safe(function(...)
    return verbana.callbacks.on_joinplayer(...)
end))
