local sqlite = verbana.ie.sqlite
local log = verbana.log

local sql = verbana.sql.sqlite.initialize

local db_class = verbana.db.sqlite.db_class

local version = 2

-- SCHEMA INITIALIZATION
function db_class:_get_current_schema_version()
    local rows = self:_get_full_ntable(sql.does_version_table_exist, "does version table exist?", "version")
    if not rows or #rows > 1 then
        log("error", "error checking if version table exists")
        return
    end -- ERROR

    if #rows == 0 then
        return 0
    end -- if version table doesn't exist, assume DB is version 1

    rows = self:_get_full_ntable(sql.get_current_version, "get current version")
    if not rows or #rows ~= 1 then
        log("error", "error querying version table")
        return
    end -- ERROR

    return rows[1].version
end

function db_class:_set_current_schema_version(version)
    self._execute_bind_one(
        sql.set_current_schema_version,
        "set current schema version",
        version
    )
end



local function sort_status_table(status_table)
    local sortable = {}
    for _, value in pairs(status_table) do
        table.insert(sortable, value)
    end
    table.sort(sortable, function (a, b) return a.id < b.id end)
    return sortable
end

function db_class:_init_status_table(table_name, status_table)
    local status_sql = sql[("initialize_%s_status"):format(table_name)]
    local status_statement = self._prepare(status_sql, ("initialize %s_status"):format(table_name))

    if not status_statement then
        return false
    end

    for _, status in ipairs(sort_status_table(status_table)) do
        if not self:_bind_and_step(status_statement, "insert status", status.id, status.name) then
            return false
        end
    end

    if not self._finalize(status_statement, "insert status") then
        return false
    end

    return true
end

function db_class:_intialize_schema()
    -- TODO where is the schema and migrations?
    log("action", "initializing schema")
    if self._db:exec(verbana.sql.sqlite.schema) ~= sqlite.OK then
        error(("[Verbana] failed to initialize the database: %s"):format(self._db:error_message()))
    end
end

local function migrate_db(version)
    log("action", "migrating DB to version %s", version)
    local filename = ("%s/migrations/%s.sql"):format(verbana.modpath, version)
    local schema = util.load_file(filename)
    if not schema then
        error(("[Verbana] Could not find Verbana migration schema at %q"):format(filename))
    end
    if db:exec(schema) ~= sqlite.OK then
        error(("[Verbana] failed to migrate the database to version %s: %s"):format(version, db:error_message()))
    end
end

local function initialize_static_data()
    verbana.log("action", "initializing static data")
    if not init_status_table("player", data.player_status) then
        error("[Verbana] error initializing player_status: see server log")
    end
    if not init_status_table("ip", data.ip_status) then
        error("[Verbana] error initializing ip_status: see server log")
    end
    if not init_status_table("asn", data.asn_status) then
        error("[Verbana] error initializing asn_status: see server log")
    end
    local verbana_player_sql = ""
    if not execute_bind_one(verbana_player_sql, "create verbana player", data.verbana_player) then
        error("[Verbana] error initializing verbana internal player: see server log")
    end
end

local function clean_db()
    local code = [[

    ]]
    return execute(code, "erase current DB")
end

local function init_db()
    local initialized = false
    local current_version = get_current_schema_version()
    if not current_version then
        error("[Verbana] error getting current DB version; aborting.")
    elseif current_version > data.version then
        error("[Verbana] database version is more recent than code version; please upgrade code.")
    elseif current_version == 0 or verbana.settings.debug_mode then
        -- wipe any pre-existing copies of the schema
        if not clean_db() then
            error("[Verbana] error wiping existing DB")
        end
        intialize_schema()
        current_version = 1
        initialized = true
    elseif current_version == data.version then
        return -- everything is up to date
    end
    for i = current_version + 1, data.version do
        migrate_db(i)
        set_current_schema_version(i)
    end
    initialize_static_data()

    if current_version == 0 or verbana.settings.debug_mode then
        -- auto import sban on first boot or in debug mode
        local sban_path = minetest.get_worldpath() .. "/sban.sqlite"
        if util.file_exists(sban_path) then
            log("action", "automatically importing existing sban DB")
            if not imports.sban.import(sban_path) then
                log("error", "failed to import existing sban DB")
            end
        end
    end
end

init_db() -- initialize DB after registering import_from_sban
