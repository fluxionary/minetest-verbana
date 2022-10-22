std = "lua51+luajit+minetest+verbana"
unused_args = false
max_line_length = 120

stds.minetest = {
	read_globals = {
		"DIR_DELIM",
		"minetest",
		"core",
		"dump",
		"vector",
		"nodeupdate",
		"VoxelManip",
		"VoxelArea",
		"PseudoRandom",
		"ItemStack",
		"default",
		"table",
		"math",
		"string",
	}
}

stds.verbana = {
	globals = {
		"verbana",
  		"minetest",
	},
	read_globals = {
		"irc",
		"irc2",
		"vector",
		"os",
		"sqlite3",
		"DIR_DELIM"
	},
}
