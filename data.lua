verbana.data = {}

local lib_asn = verbana.lib_asn
local lib_ip = verbana.lib_ip
local log = verbana.log

local sql = verbana.sql
local db = verbana.db

-- constants
verbana.data.player_status = {
    default={name='default', id=1},
    suspicious={name='suspicious', id=2},
    banned={name='banned', id=3},
    whitelisted={name='whitelisted', id=4},
    unverified={name='unverified', id=5},
    kicked={name='kicked', id=6},  -- for logging kicks
}
verbana.data.player_status_name = {}
for _, value in pairs(verbana.data.player_status) do verbana.data.player_status_name[value.id] = value.name end
verbana.data.ip_status = {
    default={name='default', id=1},
    suspicious={name='suspicious', id=2},
    blocked={name='blocked', id=3},
    trusted={name='trusted', id=4},
}
verbana.data.ip_status_name = {}
for _, value in pairs(verbana.data.ip_status) do verbana.data.ip_status_name[value.id] = value.name end
verbana.data.asn_status = {
    default={name='default', id=1},
    suspicious={name='suspicious', id=2},
    blocked={name='blocked', id=3},
}
verbana.data.asn_status_name = {}
for _, value in pairs(verbana.data.asn_status) do verbana.data.asn_status_name[value.id] = value.name end
verbana.data.verbana_player = '!verbana!'
verbana.data.verbana_player_id = 1
-- wrap sqllite API to make error reporting less messy
local function execute(code, description)
    if db:exec(code) ~= sql.OK then
        log('error', 'executing %s %q: %s', description, code, db:errmsg())
        return false
    end
    return true
end

local function prepare(code, description)
    local statement = db:prepare(code)
    if not statement then
        log('error', 'preparing %s %q: %s', description, code, db:errmsg())
        return nil
    end
    return statement
end

local function bind(statement, description, ...)
    if statement:bind_values(...) ~= sql.OK then
        log('error', 'binding %s: %s %q', description, db:errmsg(), minetest.serialize({...}))
        return false
    end
    return true
end

local function bind_and_step(statement, description, ...)
    if not bind(statement, description, ...) then return false end
    if statement:step() ~= sql.DONE then
        log('error', 'stepping %s: %s %q', description, db:errmsg(), minetest.serialize({...}))
        return false
    end
    statement:reset()
    return true
end

local function finalize(statement, description)
    if statement:finalize() ~= sql.OK then
        log('error', 'finalizing %s: %s', description, db:errmsg())
        return false
    end
    return true
end

local function execute_bind_one(code, description, ...)
    local statement = prepare(code, description)
    if not statement then return false end
    if not bind_and_step(statement, description, ...) then return false end
    if not finalize(statement, description) then return false end
    return true
end

local function get_full_table(code, description, ...)
    local statement = prepare(code, description)
    if not statement then return nil end
    if not bind(statement, description, ...) then return nil end
    local rows = {}
    for row in statement:rows() do
        table.insert(rows, row)
    end
    if not finalize(statement, description) then return nil end
    return rows
end

local function get_full_ntable(code, description, ...)
    local statement = prepare(code, description)
    if not statement then return nil end
    if not bind(statement, description, ...) then return nil end
    local rows = {}
    for row in statement:nrows() do
        table.insert(rows, row)
    end
    if not finalize(statement, description) then return nil end
    return rows
end

local function sort_status_table(data)
    local sortable = {}
    for _, value in pairs(data) do table.insert(sortable, value) end
    table.sort(sortable, function (a, b) return a.id < b.id end)
    return sortable
end

local function init_status_table(table_name, data)
    local status_sql = ('INSERT OR IGNORE INTO %s_status (id, name) VALUES (?, ?)'):format(table_name)
    local status_statement = prepare(status_sql, ('initialize %s_status'):format(table_name))
    if not status_statement then return false end
    for _, status in ipairs(sort_status_table(data)) do
        if not bind_and_step(status_statement, 'insert status', status.id, status.name) then
            return false
        end
    end
    if not finalize(status_statement, 'insert status') then
        return false
    end
    return true
end

local function init_db()
    local schema = verbana.util.load_file(verbana.modpath .. '/schema.sql')
    if not schema then
        error(('Could not find Verbana schema at %q'):format(verbana.modpath .. '/schema.sql'))
    end
    if db:exec(schema) ~= sql.OK then
        error(('Verbana failed to initialize the database: %s'):format(db:error_message()))
    end
    if not init_status_table('player', verbana.data.player_status) then
        error('error initializing player_status: see server log')
    end
    if not init_status_table('ip', verbana.data.ip_status) then
        error('error initializing ip_status: see server log')
    end
    if not init_status_table('asn', verbana.data.asn_status) then
        error('error initializing asn_status: see server log')
    end
    local verbana_player_sql = 'INSERT OR IGNORE INTO player (name) VALUES (?)'
    if not execute_bind_one(verbana_player_sql, 'verbana player', verbana.data.verbana_player) then
        error('error initializing verbana internal player: see server log')
    end
end

init_db()
---- data API -----
function verbana.data.reset_db()
    local code = [[
        PRAGMA writable_schema = 1;
        DELETE FROM sqlite_master WHERE type IN ('table', 'index', 'trigger');
        PRAGMA writable_schema = 0;
        VACUUM;
        PRAGMA INTEGRITY_CHECK;
    ]]
    if not execute(code, 'erase current DB') then
        return false
    end
    init_db()
end

function verbana.data.import_from_sban(filename)
    -- apologies for the very long method
    local start = os.clock()
    if not execute('BEGIN TRANSACTION', 'sban import transaction') then
        return false
    end

    local sban_db, _, errormsg = sql.open(filename, sql.OPEN_READONLY)
    if not sban_db then
        log('error', 'Error opening %s: %s', filename, errormsg)
        return false
    end

    local function _error(message, ...)
        if message then
            log('error', message, ...)
        end
        execute('ROLLBACK', 'sban import rollback')
        if sban_db:close() ~= sql.OK then
            log('error', 'closing sban DB %s', sban_db:errmsg())
        end
        return false
    end

    -- IMPORT INTO VERBANA --
    local insert_player_statement = prepare('INSERT OR IGNORE INTO player (name) VALUES (?)', 'insert player')
    if not insert_player_statement then return _error() end
    for name in sban_db:urows('SELECT DISTINCT name FROM playerdata') do
        if not bind_and_step(insert_player_statement, 'insert player', name) then
            return _error()
        end
    end
    if not finalize(insert_player_statement, 'insert player') then return _error() end
    -- GET VERBANA PLAYER IDS --
    local player_id_by_name = {}
    for id, name in db:urows('SELECT id, name FROM player') do
        player_id_by_name[name] = id
    end
    -- ips, asns, associations, and logs --
    local insert_ip_statement = prepare('INSERT OR IGNORE INTO ip (ip) VALUES (?)', 'insert IP')
    if not insert_ip_statement then return _error() end
    local insert_asn_statement = prepare('INSERT OR IGNORE INTO asn (asn) VALUES (?)', 'insert ASN')
    if not insert_asn_statement then return _error() end
    local insert_assoc_statement = prepare('INSERT OR IGNORE INTO assoc (player_id, ip, asn, first_seen, last_seen) VALUES (?, ?, ?, ?, ?)', 'insert assoc')
    if not insert_assoc_statement then return _error() end
    local insert_log_statement = prepare('INSERT OR IGNORE INTO connection_log (player_id, ip, asn, success, timestamp) VALUES (?, ?, ?, ?, ?)', 'insert connection log')
    if not insert_log_statement then return _error() end
    for name, ipstr, created, last_login in sban_db:urows('SELECT name, ip, created, last_login FROM playerdata') do
        local player_id = player_id_by_name[name]
        if not lib_ip.is_valid_ip(ipstr) then
            return _error('%s is not a valid IPv4 address', ipstr)
        end
        local ipint = lib_ip.ipstr_to_ipint(ipstr)
        local asn = lib_asn.lookup(ipint)
        if not bind_and_step(insert_ip_statement, 'insert IP', ipint) then return _error() end
        if not bind_and_step(insert_asn_statement, 'insert ASN', asn) then return _error() end
        if not bind_and_step(insert_assoc_statement, 'insert assoc', player_id, ipint, asn, created, created) then return _error() end
        if not bind_and_step(insert_log_statement, 'insert connection log', player_id, ipint, asn, true, created) then return _error() end
    end
    if not finalize(insert_ip_statement, 'insert IP') then return _error() end
    if not finalize(insert_asn_statement, 'insert ASN') then return _error() end
    if not finalize(insert_assoc_statement, 'insert assoc') then return _error() end
    if not finalize(insert_log_statement, 'insert connection log') then return _error() end
    -- player status --
    local default_player_status_id = verbana.data.player_status.default.id
    local banned_player_status_id = verbana.data.player_status.banned.id
    local insert_player_status_sql = [[
        INSERT OR IGNORE
          INTO player_status_log (executor_id, player_id, status_id, timestamp, reason, expires)
        VALUES                   (?,           ?,         ?,         ?,         ?,      ?)
    ]]
    local insert_player_status_statement = prepare(insert_player_status_sql, 'insert player status')
    if not insert_player_status_statement then return _error() end
--    local update_player_current_status_sql = [[
--        UPDATE player
--           SET current_status_id = ?
--         WHERE id = ?
--    ]]
--    local update_player_current_status_statement = prepare(update_player_current_status_sql, 'update player current status')
--    if not update_player_current_status_statement then return _error() end
    local select_bans_sql = [[
        SELECT name, source, created, reason, expires, u_source, u_reason, u_date
          FROM bans
      ORDER BY created
    ]]
    for name, source, created, reason, expires, u_source, u_reason, u_date in sban_db:urows(select_bans_sql) do
        local player_id = player_id_by_name[name]
        local source_id = player_id_by_name[source]
        local unban_source_id
        if u_source and u_source == 'sban' then
            unban_source_id = source_id
        else
            unban_source_id = player_id_by_name[u_source]
        end
        local status_id = banned_player_status_id
        if expires == '' then expires = nil end
        -- BAN
        if not bind_and_step(insert_player_status_statement,     'insert player status (ban)',   source_id,       player_id, status_id,                created, reason,   expires) then return _error() end
        -- UNBAN
        if unban_source_id then
            if not bind_and_step(insert_player_status_statement, 'insert player status (unban)', unban_source_id, player_id, default_player_status_id, u_date,  u_reason, nil) then return _error() end
        end
--        bind_and_step(update_player_current_status_statement, 'update player current status', ?, player_id)
    end
    if not finalize(insert_player_status_statement, 'insert player status') then return _error() end
--    if not finalize(update_player_current_status_statement, 'update player current status') then return _error() end
    -- SET LAST ACTION --
    local set_current_status_id_sql = [[
        UPDATE player
           SET current_status_id = (SELECT MAX(player_status_log.id)
                                      FROM player_status_log
                                     WHERE player_status_log.player_id == player.id);
    ]]
    if not execute(set_current_status_id_sql, 'set last status') then return _error() end
    -- CLEANUP --
    if not execute('COMMIT') then
        if sban_db:close() ~= sql.OK then
            log('error', 'closing sban DB %s', sban_db:errmsg())
        end
        return false
    end
    if sban_db:close() ~= sql.OK then
        log('error', 'closing sban DB %s', sban_db:errmsg())
        return false
    end
    log('action', 'imported from SBAN in %s seconds', os.clock() - start)
    return true
end -- verbana.data.import_from_sban


local player_id_cache = {}
function verbana.data.get_player_id(name, create_if_new)
    local cached_id = player_id_cache[name]
    if cached_id then return cached_id end
    if create_if_new then
        if not execute_bind_one('INSERT OR IGNORE INTO player (name) VALUES (?)', 'insert player', name) then
            log('warning', 'data.get_player_id: failed to create ID for player %s', name)
            return nil
        end
    end
    local table = get_full_table('SELECT id FROM player WHERE LOWER(name) == LOWER(?) LIMIT 1', 'get player id', name)
    if not (table and table[1]) then
        log('warning', 'data.get_player_id: failed to retrieve ID for player %s; %s', name, create_if_new)
        return nil
    end
    player_id_cache[name] = table[1][1]
    return table[1][1]
end

local player_status_cache = {}
function verbana.data.get_player_status(player_id, create_if_new)
    player_id = verbana.data.get_master(player_id) or player_id
    local cached_status = player_status_cache[player_id]
    if cached_status then return cached_status, false end
    local code = [[
        SELECT executor.id   executor_id
             , executor.name executor
             , status.id     id
             , status.name   name
             , log.timestamp timestamp
             , log.reason    reason
             , log.expires   expires
          FROM player
          JOIN player_status_log log      ON player.current_status_id == log.id
          JOIN player_status     status   ON log.status_id == status.id
          JOIN player            executor ON log.executor_id == executor.id
         WHERE player.id == ?
         LIMIT 1
    ]]
    local table = get_full_ntable(code, 'get player status', player_id)
    if #table == 1 then
        player_status_cache[player_id] = table[1]
        return table[1], false
    elseif #table > 1 then
        log('error', 'somehow got more than 1 result when getting current player status for %s', player_id)
        return nil, false
    elseif not create_if_new then
        return nil, nil
    end
    if not verbana.data.set_player_status(player_id, verbana.data.verbana_player_id, verbana.data.player_status.default.id, 'creating initial player status') then
        log('error', 'failed to set initial player status')
        return nil, true
    end
    return verbana.data.get_player_status(player_id, false), true
end
function verbana.data.set_player_status(player_id, executor_id, status_id, reason, expires, no_update_current)
    player_id = verbana.data.get_master(player_id) or player_id
    player_status_cache[player_id] = nil
    local code = [[
        INSERT INTO player_status_log (player_id, executor_id, status_id, reason, expires, timestamp)
             VALUES                   (?,         ?,           ?,         ?,      ?,       ?)
    ]]
    if not execute_bind_one(code, 'set player status', player_id, executor_id, status_id, reason, expires, os.time()) then return false end
    if not no_update_current then
        local last_id = db:last_insert_rowid()
        local code = 'UPDATE player SET current_status_id = ? WHERE id = ?'
        if not execute_bind_one(code, 'update player last status id', last_id, player_id) then return false end
    end
    return true
end

function verbana.data.register_ip(ipint)
    local code = 'INSERT OR IGNORE INTO ip (ip) VALUES (?)'
    return execute_bind_one(code, 'register ip', ipint)
end

local ip_status_cache = {}
function verbana.data.get_ip_status(ipint, create_if_new)
    local cached_status = ip_status_cache[ipint]
    if cached_status then return cached_status end
    local code = [[
        SELECT executor.id   executor_id
             , executor.name executor
             , status.id     id
             , status.name   name
             , log.timestamp timestamp
             , log.reason    reason
             , log.expires   expires
          FROM ip
          JOIN ip_status_log log      ON ip.current_status_id == log.id
          JOIN ip_status     status   ON log.status_id == status.id
          JOIN player        executor ON log.executor_id == executor.id
         WHERE ip.ip == ?
         LIMIT 1
    ]]
    local table = get_full_ntable(code, 'get ip status', ipint)
    if #table == 1 then
        ip_status_cache[ipint] = table[1]
        return table[1]
    elseif #table > 1 then
        log('error', 'somehow got more than 1 result when getting current ip status for %s', ipint)
        return nil
    elseif not create_if_new then
        return nil
    end
    if not verbana.data.set_ip_status(ipint, verbana.data.verbana_player_id, verbana.data.ip_status.default.id, 'creating initial ip status') then
        log('error', 'failed to set initial ip status')
        return nil
    end
    return verbana.data.get_ip_status(ipint, false)
end
function verbana.data.set_ip_status(ipint, executor_id, status_id, reason, expires)
    ip_status_cache[ipint] = nil
    local code = [[
        INSERT INTO ip_status_log (ip, executor_id, status_id, reason, expires, timestamp)
             VALUES               (?,  ?,           ?,         ?,      ?,       ?)
    ]]
    if not execute_bind_one(code, 'set ip status', ipint, executor_id, status_id, reason, expires, os.time()) then return false end
    local last_id = db:last_insert_rowid()
    local code = 'UPDATE ip SET current_status_id = ? WHERE ip = ?'
    if not execute_bind_one(code, 'update ip last status id', last_id, ipint) then return false end
    return true
end

function verbana.data.register_asn(asn)
    local code = 'INSERT OR IGNORE INTO asn (asn) VALUES (?)'
    return execute_bind_one(code, 'register asn', asn)
end

local asn_status_cache = {}
function verbana.data.get_asn_status(asn, create_if_new)
    local cached_status = asn_status_cache[asn]
    if cached_status then return cached_status end
    local code = [[
        SELECT executor.id   executor_id
             , executor.name executor
             , status.id     id
             , status.name   name
             , log.timestamp timestamp
             , log.reason    reason
             , log.expires   expires
          FROM asn
          JOIN asn_status_log log      ON asn.current_status_id == log.id
          JOIN asn_status     status   ON log.status_id == status.id
          JOIN player         executor ON log.executor_id == executor.id
         WHERE asn.asn == ?
         LIMIT 1
    ]]
    local table = get_full_ntable(code, 'get asn status', asn)
    if #table == 1 then
        asn_status_cache[asn] = table[1]
        return table[1]
    elseif #table > 1 then
        log('error', 'somehow got more than 1 result when getting current asn status for %s', asn)
        return nil
    elseif not create_if_new then
        return nil
    end
    if not verbana.data.set_asn_status(asn, verbana.data.verbana_player_id, verbana.data.asn_status.default.id, 'creating initial asn status') then
        log('error', 'failed to set initial asn status')
        return nil
    end
    return verbana.data.get_asn_status(asn, false)
end
function verbana.data.set_asn_status(asn, executor_id, status_id, reason, expires)
    asn_status_cache[asn] = nil
    local code = [[
        INSERT INTO asn_status_log (asn, executor_id, status_id, reason, expires, timestamp)
             VALUES                (?,   ?,           ?,         ?,      ?,       ?)
    ]]
    if not execute_bind_one(code, 'set asn status', asn, executor_id, status_id, reason, expires, os.time()) then return false end
    local last_id = db:last_insert_rowid()
    local code = 'UPDATE asn SET current_status_id = ? WHERE asn = ?'
    if not execute_bind_one(code, 'update asn last status id', last_id, asn) then return false end
    return true
end

function verbana.data.log(player_id, ipint, asn, success)
    local code = [[
        INSERT INTO connection_log (player_id, ip, asn, success, timestamp)
             VALUES                 (?,         ?,  ?,   ?,       ?)
    ]]
    if not execute_bind_one(code, 'log connection', player_id, ipint, asn, success, os.time()) then return false end
    return true
end

function verbana.data.assoc(player_id, ipint, asn)
    player_id = verbana.data.get_master(player_id) or player_id
    local insert_code = [[
        INSERT OR IGNORE INTO assoc (player_id, ip, asn, first_seen, last_seen)
                             VALUES (?,         ?,  ?,   ?,          ?)
    ]]
    if not execute_bind_one(insert_code, 'insert assoc', player_id, ipint, asn, os.time(), os.time()) then return false end
    local update_code = [[
        UPDATE assoc
           SET last_seen = ?
         WHERE player_id == ?
           AND ip == ?
           AND asn == ?
    ]]
    if not execute_bind_one(update_code, 'update assoc', os.time(), player_id, ipint, asn) then return false end
    return true
end
function verbana.data.has_asn_assoc(player_id, asn)
    player_id = verbana.data.get_master(player_id) or player_id
    local code = 'SELECT 1 FROM assoc WHERE player_id = ? AND asn == ? LIMIT 1'
    local table = get_full_table(code, 'find player asn assoc', player_id, asn)
    return #table == 1
end
function verbana.data.has_ip_assoc(player_id, ipint)
    player_id = verbana.data.get_master(player_id) or player_id
    local code = 'SELECT 1 FROM assoc WHERE player_id = ? AND ip == ? LIMIT 1'
    local table = get_full_table(code, 'find player asn assoc', player_id, ipint)
    return #table == 1
end

function verbana.data.get_player_status_log(player_id)
    player_id = verbana.data.get_master(player_id) or player_id
    local code = [[
        SELECT executor.name executor
             , status.name   status
             , log.timestamp timestamp
             , log.reason    reason
             , log.expires   expires
          FROM player_status_log log
          JOIN player                     ON log.player_id   == player.id
          JOIN player            executor ON log.executor_id == executor.id
          JOIN player_status     status   ON log.status_id   == status.id
         WHERE player.id == ?
      ORDER BY log.timestamp
    ]]
    return get_full_ntable(code, 'player status log', player_id)
end
function verbana.data.get_ip_status_log(ipint)
    local code = [[
        SELECT executor.name executor
             , status.name   status
             , log.timestamp timestamp
             , log.reason    reason
             , log.expires   expires
          FROM ip_status_log log
          JOIN player        executor ON log.executor_id == executor.id
          JOIN ip_status     status   ON log.status_id   == status.id
         WHERE log.ip == ?
      ORDER BY log.timestamp
    ]]
    return get_full_ntable(code, 'ip status log', ipint)
end
function verbana.data.get_asn_status_log(asn)
    local code = [[
        SELECT executor.name executor
             , status.name   status
             , log.timestamp timestamp
             , log.reason    reason
             , log.expires   expires
          FROM asn_status_log log
          JOIN player         executor ON log.executor_id == executor.id
          JOIN asn_status     status   ON log.status_id   == status.id
         WHERE log.asn == ?
      ORDER BY log.timestamp
    ]]
    return get_full_ntable(code, 'asn status log', asn)
end

function verbana.data.get_first_login(player_id)
    local code = [[
        SELECT timestamp
          FROM connection_log
         WHERE player_id == ?
      ORDER BY timestamp
         LIMIT 1
    ]]
    return get_full_ntable(code, 'first login', player_id)
end
function verbana.data.get_player_connection_log(player_id, limit)
    local code = [[
        SELECT log.ip                   ipint
             , log.asn                  asn
             , log.success              success
             , log.timestamp            timestamp
             , ip_status_log.status_id  ip_status_id
             , asn_status_log.status_id asn_status_id
          FROM connection_log log
          JOIN player         ON player.id         == log.player_id
          JOIN ip             ON ip.ip             == log.ip
     LEFT JOIN ip_status_log  ON ip_status_log.id  == ip.current_status_id
          JOIN asn            ON asn.asn           == log.asn
     LEFT JOIN asn_status_log ON asn_status_log.id == asn.current_status_id
         WHERE player.id == ?
      ORDER BY timestamp DESC
         LIMIT ?
    ]]
    if not limit or type(limit) ~= 'number' or limit < 0 then
        limit = 20
    end
    local t = get_full_ntable(code, 'player connection log', player_id, limit)
    return verbana.util.table_reversed(t)
end
function verbana.data.get_ip_connection_log(ipint, limit)
    local code = [[
        SELECT player.name                 player_name
             , player.id                   player_id
             , log.asn                     asn
             , log.success                 success
             , log.timestamp               timestamp
             , player_status_log.status_id player_status_id
             , asn_status_log.status_id    asn_status_id
          FROM connection_log log
          JOIN player            ON player.id == log.player_id
     LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
          JOIN asn               ON asn.asn == log.asn
     LEFT JOIN asn_status_log    ON asn.current_status_id == asn_status_log.id
         WHERE log.ip == ?
      ORDER BY timestamp DESC
         LIMIT ?
    ]]
    if not limit or type(limit) ~= 'number' or limit < 0 then
        limit = 20
    end
    local t = get_full_ntable(code, 'ip connection log', ipint, limit)
    return verbana.util.table_reversed(t)
end
function verbana.data.get_asn_connection_log(asn, limit)
    local code = [[
        SELECT player.name                 player_name
             , player.id                   player_id
             , log.ip                      ipint
             , log.success                 success
             , log.timestamp               timestamp
             , player_status_log.status_id player_status_id
             , ip.current_status_id        ip_status_id
          FROM connection_log log
          JOIN player            ON player.id == log.player_id
     LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
          JOIN ip                ON ip.ip == log.ip
     LEFT JOIN ip_status_log     ON ip.current_status_id == ip_status_log.id
         WHERE log.asn == ?
      ORDER BY timestamp DESC
         LIMIT ?
    ]]
    if not limit or type(limit) ~= 'number' or limit < 0 then
        limit = 20
    end
    local t = get_full_ntable(code, 'asn connection log', asn, limit)
    return verbana.util.table_reversed(t)
end

function verbana.data.get_player_associations(player_id)
    local code = [[
        SELECT assoc.ip          ipint
             , assoc.asn         asn
             , ip_status_log.id  ip_status_id
             , asn_status_log.id asn_status_id
          FROM assoc
          JOIN player         ON player.id == assoc.player_id
          JOIN ip             ON ip.ip == assoc.ip
     LEFT JOIN ip_status_log  ON ip.current_status_id == ip_status_log.id
          JOIN asn            ON asn.asn == assoc.asn
     LEFT JOIN asn_status_log ON asn.current_status_id == asn_status_log.id
         WHERE player.id == ?
      ORDER BY assoc.asn, assoc.ip
    ]]
    return get_full_ntable(code, 'player associations', player_id)
end
function verbana.data.get_ip_associations(ipint, from_time)
    local code = [[
        SELECT
      DISTINCT player.name                 player_name
             , player_status_log.status_id player_status_id
          FROM assoc
          JOIN player            ON player.id == assoc.player_id
     LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
          JOIN connection_log    ON connection_log.timestamp >= ? AND connection_log.ip == assoc.ip AND connection_log.asn == assoc.asn
         WHERE assoc.ip == ?
      ORDER BY LOWER(player.name)
    ]]
    return get_full_ntable(code, 'ip associations', from_time, ipint)
end
function verbana.data.get_asn_associations(asn, from_time)
    local code = [[
        SELECT
      DISTINCT player.name                 player_name
             , player_status_log.status_id player_status_id
          FROM assoc
          JOIN player            ON player.id                == assoc.player_id
     LEFT JOIN player_status_log ON player_status_log.id     == player.current_status_id
          JOIN connection_log    ON connection_log.timestamp >= ?
                                AND connection_log.ip == assoc.ip
                                AND connection_log.asn == assoc.asn
         WHERE assoc.asn == ?
      ORDER BY LOWER(player.name)
    ]]
    return get_full_ntable(code, 'asn associations', from_time, asn)
end

function verbana.data.get_player_cluster(player_id)
    local code = [[
        SELECT
      DISTINCT other.name         player_name
             , player_status_log.status_id player_status_id
          FROM player
          JOIN assoc player_assoc ON player_assoc.player_id == player.id
          JOIN assoc other_assoc  ON other_assoc.ip == player_assoc.ip
                                 AND player_assoc.player_id != other_assoc.player_id
          JOIN player other       ON other.id == other_assoc.player_id
     LEFT JOIN player_status_log  ON player_status_log.id == other.current_status_id
         WHERE player.id == ?
      ORDER BY LOWER(other.name)
    ]]
    return get_full_ntable(code, 'player cluster', player_id)
end

function verbana.data.get_all_banned_players()
    local code = [[
        SELECT player.name                 player_name
             , player_status_log.status_id player_status_id
             , player_status_log.reason    reason
             , player_status_log.expires   expires
          FROM player
     LEFT JOIN player_status_log ON player.id == player_status_log.player_id
         WHERE player_status_log.status_id == ?
    ]]
    return get_full_ntable(code, 'all banned',
        verbana.data.player_status.banned
    )
end

function verbana.data.fumble_about_for_an_ip(name, player_id)
    -- for some reason, get_player_ip is unreliable during register_on_newplayer
    local ipstr = minetest.get_player_ip(name)
    if not ipstr then
        local info = minetest.get_player_information(name)
        if info then
            ipstr = info.address
        end
    end
    if not ipstr then
        if not player_id then player_id = verbana.data.get_player_id(name) end
        local connection_log = verbana.data.get_player_connection_log(player_id, 1)
        if not connection_log or #connection_log ~= 1 then
            log('warning', 'player %s exists but has no connection log?', player_id)
        else
            local last_login = connection_log[1]
            ipstr = lib_ip.ipint_to_ipstr(last_login.ipint)
        end
    end
    return ipstr
end

function verbana.data.get_ban_log(limit)
    local code = [[
        SELECT player.name                 player
             , executor.name               executor
             , player_status.name          status
             , player_status_log.reason    timestamp
             , player_status_log.timestamp reason
             , player_status_log.expires   expires
          FROM player_status_log
          JOIN player          ON player.id        == player_status_log.player_id
          JOIN player executor ON executor.id      == player_status_log.executor_id
          JOIN player_status   ON player_status.id == player_status_log.status_id
         WHERE player_status_log.status_id IN (?, ?)
         ORDER BY player_status_log.timestamp DESC
         LIMIT ?
    ]]
    if not limit or type(limit) ~= 'number' or limit < 0 then limit = 20 end
    return get_full_ntable(code, 'ban log',
        verbana.data.player_status.banned.id,
        verbana.data.player_status.kicked.id,
        limit
    )
end

function verbana.data.add_report(reporter_id, report)
    local code = [[
        INSERT INTO report
                    (reporter_id, report, timestamp)
             VALUES (?          , ?     , ?        )
    ]]
    return execute_bind_one(code, 'add report', reporter_id, report, os.time())
end

function verbana.data.get_reports(from_time)
    local code = [[
        SELECT player.name      reporter
             , report.report    report
             , report.timestamp timestamp
          FROM report
          JOIN player ON player.id == report.reporter_id
         WHERE report.timestamp >= ?
    ]]
    return get_full_ntable(code, 'get reports', from_time)
end

function verbana.data.get_asn_stats(asn)
    local code = [[
        SELECT COALESCE(player_status_log.status_id, ?)        player_status_id
             , COUNT(COALESCE(player_status_log.status_id, ?)) count
          FROM (SELECT DISTINCT player_id id FROM assoc WHERE asn = ?) asn_player
          JOIN player            ON player.id            == asn_player.id
     LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
      GROUP BY COALESCE(player_status_log.status_id, ?)
      ORDER BY COALESCE(player_status_log.status_id, ?)
    ]]
    return get_full_ntable(code, 'asn stats',
        verbana.data.player_status.default.id,
        verbana.data.player_status.default.id,
        asn,
        verbana.data.player_status.default.id,
        verbana.data.player_status.default.id
    )
end

function verbana.data.get_master(player_id)
    local code = [[
        SELECT master.id   id
             , master.name name
          FROM player
     LEFT JOIN player master ON master.id == player.master_id
         WHERE player.id = ?
    ]]
    local rows = get_full_ntable(code, 'get_master', player_id)
    if rows and #rows > 0 then
        return rows[1].id, rows[1].name
    end
end

function verbana.data.set_master(player_id, master_id)
    --[[
        case 1: master has no master
                just set player's master
        case 2: master has a master
                subcase A: player and master's master are different
                    set player's master to master's master
                subcase B: player == master's master
                    swap player and master
        if other players have player as their master, update their master to player's new master.
        loops can not be created this way, because we've ensured that a "true" master can't have
        a master of its own.
    ]]
    local master_master_id = verbana.data.get_master(master_id)
    if master_master_id == player_id then
        return verbana.data.swap_master(player_id, master_id)
    elseif master_master_id then
        master_id = master_master_id
    end
    local code = [[
        UPDATE player
           SET master_id = ?
         WHERE id = ?
    ]]
    if not execute_bind_one(code, 'set master 1', master_id, player_id) then
        return false, 'error'
    end
    local code = [[
        UPDATE player
           SET master_id = ?
         WHERE master_id = ?
    ]]
    if not execute_bind_one(code, 'set master 2', master_id, player_id) then
        return false, 'error'
    end
    return true
end

function verbana.data.swap_master(player_id, master_id)
    if verbana.data.get_master(player_id) ~= master_id then
        return false, 'not player\'s master'
    end
    local code = [[
        UPDATE player
           SET master_id = ?
         WHERE id = ?
    ]]
    if not execute_bind_one(code, 'swap master 1', nil, player_id) then
        return false, 'error'
    end
    if not execute_bind_one(code, 'swap master 2', player_id, master_id) then
        return false, 'error'
    end
    local code = [[
        UPDATE player
           SET master_id = ?
         WHERE master_id = ?
    ]]
    if not execute_bind_one(code, 'swap master 3', player_id, master_id) then
        return false, 'error'
    end
    return true
end

function verbana.data.unset_master(player_id)
    local code = [[
        UPDATE player
           SET master_id = NULL
         WHERE id = ?
    ]]
    return execute_bind_one(code, 'unset master', player_id)
end

function verbana.data.get_alts(player_id)
    local code = [[
        SELECT master.name name
          FROM player master
         WHERE master.id == ?
         UNION
        SELECT alt.name
          FROM player master
          JOIN player alt    ON alt.master_id == master.id
         WHERE master.id == ?
    ]]
    local master_id = verbana.data.get_master() or player_id
    local rows = get_full_ntable(code, 'get alts', master_id)
    if rows then
        local alts = {}
        for _, row in ipairs(rows) do
            table.insert(alts, row.name)
        end
        return alts
    end
end

function verbana.data.grep_player(pattern, limit)
    local code = [[
        SELECT player.name                              name
             , COALESCE(player_status_log.status_id, ?) player_status_id
          FROM player
     LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
         WHERE LOWER(player.name) GLOB LOWER(?)
      ORDER BY LOWER(player.name)
         LIMIT ?
    ]]
    return get_full_ntable(code, 'grep player', verbana.data.player_status.default.id, pattern, limit)
end
