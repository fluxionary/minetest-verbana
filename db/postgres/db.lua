--[[
    https://lua.msys.ch/lua-module-reference.html#pgsql
    https://github.com/arcapos/luapgsql/blob/master/luapgsql.c
    https://www.postgresql.org/docs/current/libpq-exec.html
]]

local settings = verbana.settings
local pgsql = verbana.ie.pgsql

-------------

local function check_description(description)
    if type(description) ~= "string" or description == "" then
        error(("invalid query description: %s"):format(description))
    end
end

local function is_result_ok(result)
    if not result then
        return false
    end
    local status = result:status()
    return status ~= pgsql.PGRES_BAD_RESPONSE and status ~= pgsql.PGRES_FATAL_ERROR
end

local function check_connection(connection)
    if not connection then
        error("out-of-memory or inability to send the command at all")
    end
    assert(connection:status() == pgsql.CONNECTION_OK, connection:errorMessage())
    return connection
end

--------------

local db_class = verbana.lib.make_class()

function db_class:_init()
    self._connection = check_connection(
        pgsql.connectdb(
            ("postgres://%s:%s@%s:%s/%s"):format(
                settings.pg_user,
                settings.pg_password,
                settings.pg_host,
                settings.pg_port,
                settings.pg_database
            )
        )
    )
end

---------------------

function db_class:check_result(result, description)
    if not result then
        error(("%s: invalid result: %s"):format(description, self._connection:errorMessage()))
    end
    local status = result:status()
    if status == pgsql.PGRES_BAD_RESPONSE or status == pgsql.PGRES_FATAL_ERROR then
        error(("%s: %s %s"):format(description, result:resStatus(status), result:errorMessage()))
    end
    return result
end

---------------------

function db_class:exec(command, description, ...)
    check_description(description)

    local result
    if #{...} > 0 then
        result = self._connection:execParams(command, ...)
    else
        result = self._connection:exec(command)
    end

    return self:check_result(result, description)
end

--[[
luapgsql calls the first argument to `prepare` "command", and the second "name", but
that's backwards. they're passed to PQprepare in the same backwards order, so we can
just use the order that PQprepare expects (name first, query second)
...
	conn = pgsql_conn(L, 1);
	command = luaL_checkstring(L, 2);
	name = luaL_checkstring(L, 3);
...
	*res = PQprepare(conn, command, name, nParams, paramTypes);
...
PGresult *PQprepare(PGconn *conn,
                    const char *stmtName,
                    const char *query,
                    int nParams,
                    const Oid *paramTypes);
]]
function db_class:prepare(name, command, ...)
    local result = self._connection:prepare(name, command, ...)
    self:check_result(result, name)
    return result
end

function db_class:exec_prepared(name, ...)
    local result = self._connection:execPrepared(name, ...)
    self:check_result(result, name)
    return result
end

----------------------------

local db = db_class()
function verbana.data.get_db()
    return db
end

minetest.register_on_shutdown(verbana.util.safe(function()
    db._connection:finish()
end))
