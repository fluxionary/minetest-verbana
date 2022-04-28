
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

local function should_rejail(player, player_status)
    if player_status.id ~= data.player_status.unverified.id then
        return false
    end
    local pos = player:get_pos()
    return not (
        jail_bounds[1].x - 1 <= pos.x and pos.x <= jail_bounds[2].x + 1 and
        jail_bounds[1].y - 1 <= pos.y and pos.y <= jail_bounds[2].y + 1 and
        jail_bounds[1].z - 1 <= pos.z and pos.z <= jail_bounds[2].z + 1
    )
end

local function should_unjail(player, player_status)
    if player_status.id == data.player_status.unverified.id then
        return false
    elseif privs.is_privileged(player:get_player_name()) then
        return false
    end

    local pos = player:get_pos()
    return (
        jail_bounds[1].x - 1 <= pos.x and pos.x <= jail_bounds[2].x + 1 and
        jail_bounds[1].y - 1 <= pos.y and pos.y <= jail_bounds[2].y + 1 and
        jail_bounds[1].z - 1 <= pos.z and pos.z <= jail_bounds[2].z + 1
    )
end


local timer = 0
log("action", "initializing rejail globalstep")
minetest.register_globalstep(function(dtime)
    timer = timer + dtime;
    if timer < jail_check_period then
        return
    end
    timer = 0
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
end)
