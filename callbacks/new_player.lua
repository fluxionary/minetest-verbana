local data                    = verbana.data
local lib_asn                 = verbana.lib.asn
local lib_ip                  = verbana.lib.ip
local log                     = verbana.log
local settings                = verbana.settings
local util                    = verbana.util

local safe                    = util.safe

local unverified_spawn_pos    = settings.unverified_spawn_pos


local function move_to(name, pos, max_tries)
    -- sometimes we'll want to move a player, but they're not actually connected yet. give it a moment.
    max_tries = max_tries or 5
    local tries = 0
    local function f()
        -- get the player again here, in case they have disconnected
        local player = minetest.get_player_by_name(name)
        if player then
            log("action", "moving %s to %s", name, minetest.pos_to_string(pos))
            if not settings.debug_mode then
                if player:get_attach() then
                    player:set_detach()
                end
                player:set_pos(pos)
            end

        elseif tries < max_tries then
            tries = tries + 1
            minetest.after(1, f)
        end
    end
    f()
end

minetest.register_on_newplayer(safe(function(player)
    local name = player:get_player_name()
    local player_id = data.get_player_id(name)

    local ipstr = data.fumble_about_for_an_ip(name, player_id)
    local need_to_verify
    if not ipstr then
        -- if we can't figure out where they're coming from, force verification
        log("warning", "could not discover an IP for new player %s; forcing verification", name)
        need_to_verify = true
    else
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local ip_status = data.get_ip_status(ipint)

        local asn = lib_asn.lookup(ipint)
        local asn_status = data.get_asn_status(asn)

        need_to_verify = (
            settings.universal_verification or
            ip_status.id == data.ip_status.suspicious.id or
            (asn_status.id == data.asn_status.suspicious.id and
             ip_status.id ~= data.ip_status.trusted.id)
        )
    end

    if need_to_verify then
        if not data.set_player_status(
            player_id,
            data.verbana_player_id,
            data.player_status.unverified.id,
            "new player connected from suspicious network"
        ) then
            log("error", "error setting unverified status on %s", name)
        end
        if not settings.debug_mode then
            minetest.set_player_privs(name, settings.unverified_privs)
        end
        -- wait a second before moving the player to the verification area
        -- because other mods sometimes try to move them around as well
        minetest.after(1, move_to, name, unverified_spawn_pos)
        log("action", "new player %s sent to verification", name)
    else
        data.get_player_status(player_id, true) -- create a new status if they don't have one
        log("action", "new player %s", name)
    end
end))
