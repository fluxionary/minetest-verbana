if not verbana then verbana = {} end
if not verbana.modpath then verbana.modpath = '.' end
if not verbana.ip then dofile(verbana.modpath .. '/lib_ip.lua') end
if not verbana.log then function verbana.log(_, message, ...) print(message:format(...)) end end

local sql = verbana.sql
local db = verbana.db

local load_file = verbana.util.load_file

verbana.data = {}
verbana.data.player_status_id = {
    unknown=1,
    default=2,
    unverified=3,
    banned=4,
    tempbanned=5,
    locked=6,
    whitelisted=7,
    suspicious=8,
}
verbana.data.player_status = verbana.util.table_invert(verbana.data.player_status_id)
verbana.data.ip_status_id = {
    default=1,
    trusted=2,
    suspicious=3,
    blocked=4,
    tempblocked=5,
}
verbana.data.ip_status = verbana.util.table_invert(verbana.data.ip_status_id)
verbana.data.asn_status_id = {
    default=1,
    suspicious=2,
    blocked=3,
    tempblocked=4,
}
verbana.data.asn_status = verbana.util.table_invert(verbana.data.asn_status_id)
verbana.data.verbana_player = '!verbana!'
verbana.data.verbana_player_id = 1

local function init_db()
    local schema = load_file(verbana.modpath .. '/schema.sql')
    if not schema then
        error(('Could not find Verbana schema at %q'):format(verbana.modpath .. '/schema.sql'))
    end
    if db:exec(schema) ~= sql.OK then
        error(('Verbana failed to initialize the database: %s'):format(db:error_message()))
    end
end

init_db()

local function execute(code, description)
    if db:exec(code) ~= sql.OK then
        verbana.log('error', 'executing %s %q: %s', description, code, db:errmsg())
        return false
    end
    return true
end

local function prepare(code, description)
    local statement = db:prepare(code)
    if not statement then
        verbana.log('error', 'preparing %s %q: %s', description, code, db:errmsg())
        return nil
    end
    return statement
end

local function bind(statement, description, ...)
    if statement:bind_values(...) ~= sql.OK then
        verbana.log('error', 'binding %s: %s', description, db:errmsg())
        return false
    end
    return true
end

local function bind_and_step(statement, description, ...)
    if not bind(...) then return false end
    if statement:step() ~= sql.DONE then
        verbana.log('unbans: stepping %s: %s', description, db:errmsg())
        return false
    end
    statement:reset()
    return true
end

local function finalize(statement, description)
    if statement:finalize() ~= sql.OK then
        verbana.log('unbans: finalizing %s: %s', description, db:errmsg())
        return false
    end
    return true
end

local function execute_bind_one(code, description, ...)
    local statement = prepare(code)
    if not statement then return false end
    if not bind_and_step(statement, description, ...) then return false end
    if not finalize(statement, description) then return false end
    return true
end

local function get_full_table(code, description, ...)
    local statement = prepare(code, description)
    if not statement then return nil end
    if not bind(statement, ...) then return nil end
    local rows = {}
    for row in statement:rows() do
        table.insert(rows, row)
    end
    if not finalize(statement, description) then return nil end
    return rows
end

function verbana.data.import_from_sban(filename)
    local start = os.clock()
    -- this method isn't as complicated as it looks; 90% of it is repetative error handling
    if not execute('BEGIN TRANSACTION', 'sban import transaction') then
        return false
    end

    local sban_db, _, errormsg = sql.open(filename, sql.OPEN_READONLY)
    if not sban_db then
        verbana.log('error', 'Error opening %s: %s', filename, errormsg)
        return false
    end

    local function _error(message, ...)
        if message then
            verbana.log('error', message, ...)
        end
        execute('ROLLBACK', 'sban import rollback')
        if sban_db:close() ~= sql.OK then
            verbana.log('error', 'closing sban DB %s', sban_db:errmsg())
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
    -- associations --
    local insert_ip_statement = prepare('INSERT OR IGNORE INTO ip (ip) VALUES (?)', 'insert IP')
    if not insert_ip_statement then return _error() end
    local insert_asn_statement = prepare('INSERT OR IGNORE INTO asn (asn) VALUES (?)', 'insert ASN')
    if not insert_asn_statement then return _error() end
    local insert_assoc_statement = prepare('INSERT OR IGNORE INTO assoc (player_id, ip, asn) VALUES (?, ?, ?)', 'insert assoc')
    if not insert_assoc_statement then return _error() end
    local insert_log_statement = prepare('INSERT OR IGNORE INTO log (player_id, ip, asn, success, timestamp) VALUES (?, ?, ?, ?, ?)', 'insert log')
    if not insert_log_statement then return _error() end
    for name, ipstr, created, last_login in sban_db:urows('SELECT name, ip, created, last_login FROM playerdata') do
        local player_id = player_id_by_name[name]
        if not verbana.ip.is_valid_ip(ipstr) then
            return _error('%s is not a valid IPv4 address', ipstr)
        end
        local ipint = verbana.ip.ipstr_to_number(ipstr)
        local asn = verbana.asn.lookup(ipint)
        if not bind_and_step(insert_ip_statement, 'insert IP', ipint) then return _error() end
        if not bind_and_step(insert_asn_statement, 'insert ASN', asn) then return _error() end
        if not bind_and_step(insert_assoc_statement, 'insert assoc', player_id, ipint, asn) then return _error() end
        if not bind_and_step(insert_log_statement, 'insert log', player_id, ipint, asn, true, created) then return _error() end
    end
    if not finalize(insert_ip_statement, 'insert IP') then return _error() end
    if not finalize(insert_asn_statement, 'insert ASN') then return _error() end
    if not finalize(insert_assoc_statement, 'insert assoc') then return _error() end
    if not finalize(insert_log_statement, 'insert log') then return _error() end
    -- player status --
    local default_player_status_id = verbana.data.player_status_id.default
    local banned_player_status_id = verbana.data.player_status_id.banned
    local tempbanned_player_status_id = verbana.data.player_status_id.tempbanned
    local insert_player_status_sql = [[
        INSERT OR IGNORE
          INTO player_status_log (executor_id, player_id, status_id, timestamp, reason, expires)
        VALUES                   (?,           ?,         ?,         ?,         ?,      ?)
    ]]
    local insert_player_status_statement = prepare(insert_player_status_sql, 'insert player status')
    if not insert_player_status_statement then return _error() end
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
        local status_id
        if expires and type(expires) == 'number' then
            status_id = tempbanned_player_status_id
        else
            status_id = banned_player_status_id
            expires = nil
        end
        -- BAN
        if not bind_and_step(insert_player_status_statement, 'insert player status (ban)', source_id, player_id, status_id, created, reason, expires) then return _error() end
        -- UNBAN
        if unban_source_id then
            if not bind_and_step(insert_player_status_statement, 'insert player status (unban)', unban_source_id, player_id, default_player_status_id, u_date, u_reason, nil) then return _error() end
        end
    end
    if not finalize(insert_player_status_statement, 'insert player status') then return _error() end
    -- SET LAST ACTION --
    local set_last_status_id_sql = [[
        UPDATE player
           SET last_status_id = (SELECT MAX(player_status_log.id)
                                   FROM player_status_log
                                  WHERE player_status_log.player_id == player.id);
    ]]
    if not execute(set_last_status_id_sql, 'set last status') then return _error() end
    -- CLEANUP --
    if not execute('COMMIT') then
        if sban_db:close() ~= sql.OK then
            verbana.log('error', 'closing sban DB %s', sban_db:errmsg())
        end
        return false
    end
    if sban_db:close() ~= sql.OK then
        verbana.log('error', 'closing sban DB %s', sban_db:errmsg())
        return false
    end
    verbana.log('action', 'imported from SBAN in %s seconds', os.clock() - start)
    return true
end -- verbana.data.import_from_sban


function verbana.data.get_player_id(name, create_if_new)
    if create_if_new then
        if not execute_bind_one('INSERT OR IGNORE INTO player (name) VALUES (?)', 'insert player', name) then return nil end
    end
    local table = get_full_table('SELECT id FROM player WHERE name = ? LIMIT 1', 'get player id')
    if not (table and table[1]) then return nil end
    return table[1][1]
end
function verbana.data.get_player_status(player_id) return {} end
function verbana.data.set_player_status(player_id, executor_id, status_id, reason, expires) end

function verbana.data.get_ip_status(ipint) return {} end
function verbana.data.set_ip_status(ipint, executor_id, status_name, reason, expires) end

function verbana.data.get_asn_status(asn) return {} end
function verbana.data.set_asn_status(asn, executor_id, status_name, reason, expires) end

function verbana.data.log(player_id, ipint, asn, success) end

function verbana.data.assoc(player_id, ipint, asn) end
function verbana.data.has_asn_assoc(player_id, asn) end
function verbana.data.has_ip_assoc(player_id, ipint) end

function verbana.data.get_ban_record(player_name)
    local ban_record_sql = [[
        SELECT executor.name
             , player_status.name
             , player_status_log.timestamp
             , player_status_log.reason
             , player_status_log.expires
          FROM player_status_log
          JOIN player          ON player_status_log.player_id   == player.id
          JOIN player executor ON player_status_log.executor_id == executor.id
          JOIN player_status   ON player_status_log.status_id   == player_status.id
         WHERE LOWER(player.name) == LOWER(?)
      ORDER BY player_status_log.timestamp
    ]]
    return get_full_table(ban_record_sql, 'ban record')
end
-- TODO: methods to get logs of player_status, ip_status, asn_status
-- TODO: methods to get connection logs by player, ip, asn
-- TODO: methods to get association logs by player, ip, asn
