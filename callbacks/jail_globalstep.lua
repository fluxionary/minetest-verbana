
local chat                    = verbana.chat
local data                    = verbana.data
local log                     = verbana.log
local privs                   = verbana.privs
local settings                = verbana.settings

local spawn_pos               = settings.spawn_pos
local unverified_spawn_pos    = settings.unverified_spawn_pos
local jail_bounds             = settings.jail_bounds
local jail_check_period       = settings.jail_check_period
local using_verification_jail = jail_bounds and jail_check_period

if not using_verification_jail then
    return
end

function verbana.callbacks.jail_globalstep()
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local player_id = data.get_player_id(name) -- cached, so not heavy
        local player_status = data.get_player_status(player_id) -- cached, so not heavy
        if should_rejail(player, player_status) then
            log("action", "rejailing %s", name)
            chat.send_mods("%s has escaped verification jail, and is being sent back", name)
            if not settings.debug_mode then
                player:set_pos(unverified_spawn_pos)
            end
        elseif should_unjail(player, player_status) then
            log("action", "unjailing %s", name)
            chat.send_mods("%s has been removed from verification jail", name)
            if not settings.debug_mode then
                player:set_pos(spawn_pos)
            end
        end
    end
end

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime;
    if timer < jail_check_period then
        return
    end
    timer = 0
    return verbana.callbacks.jail_globalstep()
end)
