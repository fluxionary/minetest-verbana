if not verbana then verbana = {} end
if not verbana.modpath then verbana.modpath = '.' end
if not verbana.ip then dofile(verbana.modpath .. '/ipmanip.lua') end
if not verbana.log then function verbana.log(_, message, ...) print(message:format(...)) end end

local ie = minetest.request_insecure_environment()
if not ie then
	error('Verbana will not work unless it has been listed under secure.trusted_mods in minetest.conf')
end

local sql = ie.require("lsqlite3")
local db = sql.open(('%s/verbana.sqlite'):format(minetest.get_worldpath())) -- TODO get path from settings
sqlite3 = nil -- remove sqlite3 from the global (secure) namespace

minetest.register_on_shutdown(function()
	db:close()
end)

local function db_exec(stmt)
    local status = db:exec(stmt)
    if status ~= sql.OK then
        verbana.log('error', 'SQLite ERROR: %s', db:errmsg())
        return false
    end
    return true
end

local function init_db()
    db_exec([[
PRAGMA foreign_keys = OFF;
-- PLAYER
CREATE TABLE IF NOT EXISTS player_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX IF NOT EXISTS player_status_name ON player_status(name);
  INSERT OR IGNORE INTO player_status
         (id, name)
  VALUES ( 0, 'default')
       , ( 1, 'unverified')
       , ( 2, 'banned')
       , ( 3, 'tempbanned')
       , ( 4, 'locked')
       , ( 5, 'whitelisted')
       , ( 6, 'suspicious');

CREATE TABLE IF NOT EXISTS player (
    id             INTEGER PRIMARY KEY AUTOINCREMENT
  , name           TEXT NOT NULL
  , main_player_id INTEGER
  , last_action_id INTEGER
  , FOREIGN KEY (main_player_id) REFERENCES player(id)
  , FOREIGN KEY (last_action_id) REFERENCES player_action_log(id)
);
  CREATE UNIQUE INDEX IF NOT EXISTS player_name ON player(name);
  CREATE INDEX IF NOT EXISTS player_main_player_id ON player(main_player_id);
  CREATE INDEX IF NOT EXISTS player_last_action_id ON player(last_action_id);

CREATE TABLE IF NOT EXISTS player_action_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
  , executor_id INTEGER NOT NULL
  , player_id   INTEGER NOT NULL
  , status_id   INTEGER NOT NULL
  , timestamp   INTEGER NOT NULL
  , reason      TEXT
  , expires     INTEGER
  , FOREIGN KEY (executor_id) REFERENCES player(id)
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (status_id) REFERENCES player_status(id)
);
  CREATE INDEX IF NOT EXISTS player_action_log_player_id ON player_action_log(player_id);
  CREATE INDEX IF NOT EXISTS player_action_log_timestamp ON player_action_log(timestamp);
  CREATE INDEX IF NOT EXISTS player_action_log_reason    ON player_action_log(reason);
-- END PLAYER
-- IP
CREATE TABLE IF NOT EXISTS ip_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX IF NOT EXISTS ip_status_name ON ip_status(name);
  INSERT OR IGNORE INTO ip_status
         (id, name)
  VALUES ( 0, 'default')
       , ( 1, 'untrusted')
       , ( 2, 'blocked')
       , ( 3, 'tempblocked');

CREATE TABLE IF NOT EXISTS ip (
    ip             INTEGER PRIMARY KEY
  , last_action_id INTEGER
  , FOREIGN KEY (last_action_id) REFERENCES ip_action_log(id)
);
  CREATE INDEX IF NOT EXISTS ip_last_action_id ON ip(last_action_id);

CREATE TABLE IF NOT EXISTS ip_action_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
  , executor_id INTEGER NOT NULL
  , ip          INTEGER NOT NULL
  , status_id   INTEGER NOT NULL
  , timestamp   INTEGER NOT NULL
  , reason      TEXT
  , expires     INTEGER
  , FOREIGN KEY (executor_id) REFERENCES player(id)
  , FOREIGN KEY (ip) REFERENCES ip(ip)
  , FOREIGN KEY (status_id) REFERENCES ip_status(id)
);
  CREATE INDEX IF NOT EXISTS ip_action_log_ip        ON ip_action_log(ip);
  CREATE INDEX IF NOT EXISTS ip_action_log_timestamp ON ip_action_log(timestamp);
  CREATE INDEX IF NOT EXISTS ip_action_log_reason    ON ip_action_log(reason);
-- END IP
-- ASN
CREATE TABLE IF NOT EXISTS asn_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX IF NOT EXISTS asn_status_name ON asn_status(name);
  INSERT OR IGNORE INTO asn_status
         (id, name)
  VALUES ( 0, 'default')
       , ( 1, 'untrusted')
       , ( 2, 'blocked')
       , ( 3, 'tempblocked');

CREATE TABLE IF NOT EXISTS asn (
    asn       INTEGER PRIMARY KEY
  , last_action_id INTEGER
  , FOREIGN KEY (last_action_id) REFERENCES asn_action_log(id)
);
  CREATE INDEX IF NOT EXISTS asn_last_action_id ON asn(last_action_id);

CREATE TABLE IF NOT EXISTS asn_action_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
  , executor_id INTEGER NOT NULL
  , asn         INTEGER NOT NULL
  , status_id   INTEGER NOT NULL
  , timestamp   INTEGER NOT NULL
  , reason      TEXT
  , expires     INTEGER
  , FOREIGN KEY (executor_id) REFERENCES player(id)
  , FOREIGN KEY (asn) REFERENCES asn(asn)
  , FOREIGN KEY (status_id) REFERENCES asn_status(id)
);
  CREATE INDEX IF NOT EXISTS asn_action_log_asn       ON asn_action_log(asn);
  CREATE INDEX IF NOT EXISTS asn_action_log_timestamp ON asn_action_log(timestamp);
  CREATE INDEX IF NOT EXISTS asn_action_log_reason    ON asn_action_log(reason);
-- END ASN
-- OTHER
CREATE TABLE IF NOT EXISTS log (
    player_id INTEGER NOT NULL
  , ip        INTEGER NOT NULL
  , asn       INTEGER NOT NULL
  , timestamp INTEGER NOT NULL
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (ip)        REFERENCES ip(ip)
  , FOREIGN KEY (asn)       REFERENCES asn(asn)
);
  CREATE INDEX IF NOT EXISTS log_player    ON log(player_id);
  CREATE INDEX IF NOT EXISTS log_ip        ON log(ip);
  CREATE INDEX IF NOT EXISTS log_asn       ON log(asn);
  CREATE INDEX IF NOT EXISTS log_timestamp ON log(timestamp);

CREATE TABLE IF NOT EXISTS assoc (
    player_id INTEGER
  , ip        INTEGER
  , asn       INTEGER
  , PRIMARY KEY (player_id, ip, asn)
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (ip)        REFERENCES ip(ip)
  , FOREIGN KEY (asn)       REFERENCES asn(asn)
);
  CREATE        INDEX IF NOT EXISTS assoc_player ON assoc(player_id);
  CREATE        INDEX IF NOT EXISTS assoc_ip     ON assoc(ip);
  CREATE        INDEX IF NOT EXISTS assoc_asn    ON assoc(asn);
-- END OTHER
PRAGMA foreign_keys = ON;
    ]])
end -- init_db()

init_db()
