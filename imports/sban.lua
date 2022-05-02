verbana.import = verbana.import or {}
verbana.import.sban = {}
local _sban = {}

local db = verbana.db
local lib_asn = verbana.lib.asn
local lib_ip = verbana.lib.ip
local util = verbana.util
local log = verbana.log

local sql = verbana.sql
local db = verbana.db

-- initialize DB after registering

function _sban.import(filename)
    -- apologies for the very long method
    local start = os.clock()
    local now = os.time()
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
        else
            log('error', 'An error occurred while importing from sban')
        end
        execute('ROLLBACK', 'sban import rollback')
        if sban_db:close() ~= sql.OK then
            log('error', 'Error closing sban DB %s', sban_db:errmsg())
        else
            log('error', 'closed sban DB')
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
    for name, ipstr, created in sban_db:urows('SELECT name, ip, created FROM playerdata') do
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
    local default_player_status_id = db.player_status.default.id
    local banned_player_status_id = db.player_status.banned.id
    local insert_player_status_sql = [[
        INSERT OR IGNORE
          INTO player_status_log (executor_id, player_id, status_id, timestamp, reason, expires)
        VALUES                   (?,           ?,         ?,         ?,         ?,      ?)
    ]]
    local insert_player_status_statement = prepare(insert_player_status_sql, 'insert player status')
    if not insert_player_status_statement then return _error() end
    local flag_player_sql = [[
        UPDATE player
           SET flagged = 1
         WHERE id == ?
    ]]
    local flag_player_statement = prepare(flag_player_sql, 'flag player')
    if not flag_player_statement then return _error() end
    local select_bans_sql = [[
        SELECT name, source, created, reason, expires, u_source, u_reason, u_date
          FROM bans
      ORDER BY created
    ]]
    for name, source, created, reason, expires, u_source, u_reason, u_date in sban_db:urows(select_bans_sql) do
        local player_id = player_id_by_name[name]
        local source_id = player_id_by_name[source]
        if not bind_and_step(flag_player_statement, 'flag player', player_id) then return _error() end
        local unban_source_id
        if u_source and u_source == 'sban' then
            unban_source_id = source_id -- if a temp ban expired, mark it as unban by the original banner
        else
            unban_source_id = player_id_by_name[u_source]
        end
        local status_id = banned_player_status_id
        if expires == '' then expires = nil end
        -- BAN
        if not bind_and_step(insert_player_status_statement,     'insert player status (ban)',   source_id,       player_id, status_id,                created, reason,   expires) then return _error() end
        -- UNBAN
        if unban_source_id and (not expires or expires <= now) then
            if not bind_and_step(insert_player_status_statement, 'insert player status (unban)', unban_source_id, player_id, default_player_status_id, u_date,  u_reason, nil) then return _error() end
        end
    end
    if not finalize(insert_player_status_statement, 'insert player status') then return _error() end
    if not finalize(flag_player_statement, 'flag player') then return _error() end
    -- SET LAST ACTION --
    local set_current_status_id_sql = [[
        UPDATE player
           SET current_status_id = (SELECT MAX(player_status_log.id)
                                      FROM player_status_log
                                     WHERE player_status_log.player_id == player.id);
    ]]
    if not execute(set_current_status_id_sql, 'set last status') then return _error() end
    -- SET LAST LOGIN --
    local set_last_login_id_sql = [[
        UPDATE player
           SET last_login_id = (SELECT MAX(connection_log.id)
                                  FROM connection_log
                                 WHERE connection_log.player_id == player.id);
    ]]
    if not execute(set_last_login_id_sql, 'set last login') then return _error() end
    -- CLEANUP --
    if not execute('COMMIT', 'commit sban import') then
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
end -- import_from_sban
