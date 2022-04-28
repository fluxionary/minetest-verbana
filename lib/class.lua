

function verbana.lib.make_class(super)
    local class = {}
	class.__index = class

	local metatable = {}
	if super then
		metatable.__index = super
	end

    function metatable:__call(...)
        local obj = setmetatable({}, class)
        if obj._init then
            obj:_init(...)
        end
        return obj
    end

	setmetatable(class, metatable)

    return class
end
