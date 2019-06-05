minetest.register_on_prejoinplayer(function(name, ip)
end)

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local ip = minetest.get_player_ip(name)
end)
