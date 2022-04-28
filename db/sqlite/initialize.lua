
data.version = 2

-- SCHEMA INITIALIZATION
local function get_current_schema_version()
    local code = [[
    ]]
    local rows = get_full_ntable(code, "does version table exist?", "version")
    if not rows or #rows > 1 then
        log("error", "error checking if version table exists")
        return
    end -- ERROR
    if #rows == 0 then return 0 end -- if version table doesn't exist, assume DB is version 1
    code = [[]]
    rows = get_full_ntable(code, "get current version")
    if not rows or #rows ~= 1 then
        log("error", "error querying version table")
        return
    end -- ERROR
    return rows[1].version
end

local function set_current_schema_version(version)
    local code = [[]]
    execute_bind_one(code, "set current schema version", version)
end

local function init_status_table(table_name, status_table)
    local status_sql = (""):format(table_name)
    local status_statement = prepare(status_sql, ("initialize %s_status"):format(table_name))
    if not status_statement then return false end
    for _, status in ipairs(sort_status_table(status_table)) do
        if not bind_and_step(status_statement, "insert status", status.id, status.name) then
            return false
        end
    end
    if not finalize(status_statement, "insert status") then
        return false
    end
    return true
end

local function intialize_schema()
    verbana.log("action", "initializing schema")
    local schema = util.load_file(verbana.modpath .. "/schema.sql")
    if not schema then
        error(("[Verbana] Could not find Verbana schema at %q"):format(verbana.modpath .. "/schema.sql"))
    end
    if db:exec(schema) ~= sql.OK then
        error(("[Verbana] failed to initialize the database: %s"):format(db:error_message()))
    end
end

local function migrate_db(version)
    verbana.log("action", "migrating DB to version %s", version)
    local filename = ("%s/migrations/%s.sql"):format(verbana.modpath, version)
    local schema = util.load_file(filename)
    if not schema then
        error(("[Verbana] Could not find Verbana migration schema at %q"):format(filename))
    end
    if db:exec(schema) ~= sql.OK then
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
