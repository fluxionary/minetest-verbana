
-- wrap sqllite API to make error reporting less messy
local function check_description(description)
    return (
        type(description) == "string" and
        description ~= ""
    )
end

local function execute(code, description)
    if not check_description(description) then
        log("error", "bad description for execute: %q", tostring(description))
        return false
    end
    if db:exec(code) ~= sql.OK then
        log("error", "executing %s %q: %s", description, code, db:errmsg())
        return false
    end
    return true
end

local function prepare(code, description)
    if not check_description(description) then
        log("error", "bad description for prepare: %q", tostring(description))
        return
    end
    local statement = db:prepare(code)
    if not statement then
        log("error", "preparing %s %q: %s", description, code, db:errmsg())
        return
    end
    return statement
end

local function bind(statement, description, ...)
    if not check_description(description) then
        log("error", "bad description for bind: %q", tostring(description))
        return false
    end
    if statement:bind_values(...) ~= sql.OK then
        log("error", "binding %s: %s %q", description, db:errmsg(), minetest.serialize({...}))
        return false
    end
    return true
end

local function bind_and_step(statement, description, ...)
    if not check_description(description) then
        log("error", "bad description for bind_and_step: %q", tostring(description))
        return false
    end
    if not bind(statement, description, ...) then return false end
    if statement:step() ~= sql.DONE then
        log("error", "stepping %s: %s %q", description, db:errmsg(), minetest.serialize({...}))
        return false
    end
    statement:reset()
    return true
end

local function finalize(statement, description)
    if not check_description(description) then
        log("error", "bad description for finalize: %q", tostring(description))
        return false
    end
    if statement:finalize() ~= sql.OK then
        log("error", "finalizing %s: %s", description, db:errmsg())
        return false
    end
    return true
end

local function execute_bind_one(code, description, ...)
    if not check_description(description) then
        log("error", "bad description for execute_bind_one: %q", tostring(description))
        return false
    end
    local statement = prepare(code, description)
    if not statement then return false end
    if not bind_and_step(statement, description, ...) then return false end
    if not finalize(statement, description) then return false end
    return true
end

local function get_full_table(code, description, ...)
    if not check_description(description) then
        log("error", "bad description for get_full_table: %q", tostring(description))
        return false
    end
    local statement = prepare(code, description)
    if not statement then return end
    if not bind(statement, description, ...) then return end
    local rows = {}
    for row in statement:rows() do
        table.insert(rows, row)
    end
    if not finalize(statement, description) then return end
    return rows
end

local function get_full_ntable(code, description, ...)
    if not check_description(description) then
        log("error", "bad description for get_full_ntable: %q", tostring(description))
        return
    end
    local statement = prepare(code, description)
    if not statement then return end
    if not bind(statement, description, ...) then return end
    local rows = {}
    for row in statement:nrows() do
        table.insert(rows, row)
    end
    if not finalize(statement, description) then return end
    return rows
end

local function sort_status_table(status_table)
    local sortable = {}
    for _, value in pairs(status_table) do table.insert(sortable, value) end
    table.sort(sortable, function (a, b) return a.id < b.id end)
    return sortable
end
