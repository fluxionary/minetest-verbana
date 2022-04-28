

local function register_chatcommand(name, def)
    if debug_mode then name = ("v_%s"):format(name) end
    def.func = safe(def.func)
    minetest.register_chatcommand(name, def)
end

local function override_chatcommand(name, def)
    def.func = safe(def.func)
    if debug_mode then
        name = ("v_%s"):format(name)
        minetest.register_chatcommand(name, def)
    else
        minetest.override_chatcommand(name, def)
    end
end

local function alias_chatcommand(name, existing_name)
    if debug_mode then
        name = ("v_%s"):format(name)
        existing_name = ("v_%s"):format(existing_name)
    end
    local existing_def = minetest.registered_chatcommands[existing_name]
    if not existing_def then
        log("error", "Could not alias command %q to %q, because %q doesn't exist", name, existing_name, existing_name)
    else
        minetest.register_chatcommand(name, existing_def)
    end

end
