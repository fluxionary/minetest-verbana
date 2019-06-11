if not verbana then verbana = {} end
if not verbana.modpath then verbana.modpath = '.' end
if not verbana.ip then dofile(verbana.modpath .. '/lib_ip.lua') end
if not verbana.log then function verbana.log(_, message, ...) print(message:format(...)) end end

local sql = verbana.sql
local db = verbana.db

local load_file = verbana.util.load_file

verbana.data.player_status_id = {
    unknown=0,
    default=1,
    unverified=2,
    banned=3,
    tempbanned=4,
    locked=5,
    whitelisted=6,
    suspicious=7,
}
verbana.data.player_status = verbana.util.table_invert(verbana.data.player_status_id)
verbana.data.ip_status_id = {
    default=0,
    trusted=1,
    suspicious=2,
    blocked=3,
    tempblocked=4,
}
verbana.data.ip_status = verbana.util.table_invert(verbana.data.ip_status_id)
verbana.data.asn_status_id = {
    default=0,
    suspicious=1,
    blocked=2,
    tempblocked=3,
}
verbana.data.asn_status = verbana.util.table_invert(verbana.data.asn_status_id)
verbana.data.verbana_player = '!verbana!'
verbana.data.verbana_player_id = 1

local function db_exec(stmt)
    local status = db:exec(stmt)
    if status ~= sql.OK then
        verbana.log('error', 'SQLite ERROR executing %q: %s', stmt, db:errmsg())
        return false
    end
    return true
end

local function get_full_table(query)
    local table = {}

    local function populate_table(udata, cols, values, names)
        local row = {}
        for col_id = 1,cols do
            row[names[col_id]] = values[col_id]
        end
        table.insert(row)
    end

    local status = db:exec(query, populate_table)

    if status ~= sql.OK then
        verbana.log('error', 'SQLite ERROR executing %q: %s', query, db:errmsg())
        return
    end

    return table
end

local function init_db()
    local schema = load_file(verbana.modpath .. '/schema.sql')
    local ret_code = db_exec(schema)
    if ret_code ~= sql.OK then
        error(('Verbana failed to initialize the database: %s'):format(db:error_message()))
    end
end -- init_db()

init_db()

function verbana.data.import_from_sban(filename)
    local sban_db, _, errormsg = sql.open(filename, sql.OPEN_READONLY)
    if not sban_db then
        return false, ('Error opening %s: %s'):format(filename, errormsg)
    end

    local player_data = get_full_table([[
        SELECT id, name, ip, created, last_login FROM playerdata
    ]])
    local bans_data = get_full_table([[
        SELECT id, name, source, created, reason, expires, u_source, u_reason, u_date, active, last_pos FROM bans
    ]])

    sban_db.close()
end

function verbana.data.get_player_id(name) end
function verbana.data.get_player_status(player_id) return {} end
function verbana.data.set_player_status(player_id, executod_id, status_name, reason, expires) end
function verbana.data.ban_player(player_id, executor_id, reason) end
function verbana.data.tempban_player(player_id, executor_id, reason, expires) end
function verbana.data.unban_player(player_id, executor_id, reason) end
function verbana.data.verify_player(player_id, executor_id, reason) end
function verbana.data.unverify_player(player_id, executor_id, reason) end
function verbana.data.lock_player(player_id, executor_id, reason) end
function verbana.data.unlock_player(player_id, executor_id, reason) end
function verbana.data.whitelist_player(player_id, executor_id, reason) end
function verbana.data.unwhitelist_player(player_id, executor_id, reason) end
function verbana.data.suspect_player(player_id, executor_id, reason) end
function verbana.data.unsuspect_player(player_id, executor_id, reason) end

function verbana.data.get_ip_status(ipint) return {} end
function verbana.data.set_ip_status(ipint, executor_id, status_name, reason, expires) end
function verbana.data.block_ip(ipint, executor_id, reason) end
function verbana.data.tempblock_ip(ipint, executor_id, reason, expires) end
function verbana.data.unblock_ip(ipint, executor_id, reason) end
function verbana.data.trust_ip(ipint, executor_id, reason) end
function verbana.data.untrust_ip(ipint, executor_id, reason) end
function verbana.data.suspect_ip(ipint, executor_id, reason) end
function verbana.data.unsuspect_ip(ipint, executor_id, reason) end

function verbana.data.get_asn_status(asn) return {} end
function verbana.data.set_asn_status(asn, executor_id, status_name, reason, expires) end
function verbana.data.block_asn(asn, executor_id, reason) end
function verbana.data.tempblock_asn(asn, executor_id, reason, expires) end
function verbana.data.unblock_asn(asn, executor_id, reason) end
function verbana.data.suspect_asn(asn, executor_id, reason) end
function verbana.data.unsuspect_asn(asn, executor_id, reason) end

function verbana.data.log(player_id, ipint, asn, success) end

function verbana.data.assoc(player_id, ipint, asn) end
function verbana.data.has_asn_assoc(player_id, asn) end
function verbana.data.has_ip_assoc(player_id, ipint) end

-- TODO: methods to get logs of player_status, ip_status, asn_status
-- TODO: methods to get connection logs by player, ip, asn
-- TODO: methods to get association logs by player, ip, asn
