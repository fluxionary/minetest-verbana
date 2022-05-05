-- wrap sqllite API to make error reporting less messy

local sqlite = verbana.ie.sqlite

local log = verbana.log

-------------------------------

local db_class = verbana.lib.make_class(verbana.db.db_class)
verbana.db.sqlite.db_class = db_class

function db_class:__init()
    error()
end


function db_class:_check_description(description)
    return (
        type(description) == "string" and
        description ~= ""
    )
end

function db_class:_execute(code, description)
    if not self:_check_description(description) then
        log("error", "bad description for execute: %q", tostring(description))
        return false
    end

    if self._db:exec(code) ~= sqlite.OK then
        log("error", "executing %s %q: %s", description, code, self._db:errmsg())
        return false
    end

    return true
end

function db_class:_prepare(code, description)
    if not self:_check_description(description) then
        log("error", "bad description for prepare: %q", tostring(description))
        return
    end

    local statement = self._db:prepare(code)
    if not statement then
        log("error", "preparing %s %q: %s", description, code, self._db:errmsg())
        return
    end

    return statement
end

function db_class:_bind(statement, description, ...)
    if not self:_check_description(description) then
        log("error", "bad description for bind: %q", tostring(description))
        return false
    end

    if statement:bind_values(...) ~= sqlite.OK then
        log("error", "binding %s: %s; args=%q", description, self._db:errmsg(), minetest.serialize({...}))
        return false
    end

    return true
end

function db_class:_bind_and_step(statement, description, ...)
    if not self:_check_description(description) then
        log("error", "bad description for bind_and_step: %q", tostring(description))
        return false
    end

    if not self:_bind(statement, description, ...) then
        return false
    end

    if statement:step() ~= sqlite.DONE then
        log("error", "stepping %s: %s %q", description, self._db:errmsg(), minetest.serialize({...}))
        return false
    end

    statement:reset()
    return true
end

function db_class:_finalize(statement, description)
    if not self:_check_description(description) then
        log("error", "bad description for finalize: %q", tostring(description))
        return false
    end

    if statement:finalize() ~= sqlite.OK then
        log("error", "finalizing %s: %s", description, self._db:errmsg())
        return false
    end

    return true
end

function db_class:_execute_bind_one(code, description, ...)
    if not self:_check_description(description) then
        log("error", "bad description for execute_bind_one: %q", tostring(description))
        return false
    end

    local statement = self:_prepare(code, description)
    if not statement then
        return false
    end

    if not self:_bind_and_step(statement, description, ...) then
        return false
    end

    if not self:_finalize(statement, description) then
        return false
    end

    return true
end

function db_class:_get_full_table(code, description, ...)
    if not self:_check_description(description) then
        log("error", "bad description for get_full_table: %q", tostring(description))
        return false
    end

    local statement = self:_prepare(code, description)
    if not statement then
        return
    end

    if not self:_bind(statement, description, ...) then
        return
    end

    local rows = {}
    for row in statement:rows() do
        table.insert(rows, row)
    end

    if not self:_finalize(statement, description) then
        return
    end

    return rows
end

function db_class:_get_full_ntable(code, description, ...)
    if not self:_check_description(description) then
        log("error", "bad description for get_full_ntable: %q", tostring(description))
        return
    end

    local statement = self:_prepare(code, description)
    if not statement then
        return
    end

    if not self:_bind(statement, description, ...) then
        return
    end

    local rows = {}
    for row in statement:nrows() do
        table.insert(rows, row)
    end

    if not self:_finalize(statement, description) then
        return
    end

    return rows
end
