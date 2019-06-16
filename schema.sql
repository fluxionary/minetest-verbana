PRAGMA foreign_keys = OFF;
-- PLAYER
CREATE TABLE IF NOT EXISTS player_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX IF NOT EXISTS player_status_name ON player_status(name);
  INSERT OR IGNORE INTO player_status
         (id, name)
  VALUES ( 1, 'unknown')
       , ( 2, 'default')
       , ( 3, 'unverified')
       , ( 4, 'banned')
       , ( 5, 'tempbanned')
       , ( 6, 'locked')
       , ( 7, 'whitelisted')
       , ( 8, 'suspicious');

CREATE TABLE IF NOT EXISTS player (
    id             INTEGER PRIMARY KEY AUTOINCREMENT
  , name           TEXT NOT NULL
  , main_player_id INTEGER
  , last_status_id INTEGER
  , FOREIGN KEY (main_player_id) REFERENCES player(id)
  , FOREIGN KEY (last_status_id) REFERENCES player_status_log(id)
);
  CREATE UNIQUE INDEX IF NOT EXISTS player_name ON player(name);
  CREATE INDEX IF NOT EXISTS player_main_player_id ON player(main_player_id);
  CREATE INDEX IF NOT EXISTS player_last_status_id ON player(last_status_id);
  INSERT OR IGNORE INTO player (name) VALUES ('!verbana!');

CREATE TABLE IF NOT EXISTS player_status_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
  , executor_id INTEGER NOT NULL
  , player_id   INTEGER NOT NULL
  , status_id   INTEGER NOT NULL
  , timestamp   INTEGER NOT NULL
  , reason      TEXT
  , expires     INTEGER  -- only meaningful for temp bans
  , FOREIGN KEY (executor_id) REFERENCES player(id)
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (status_id) REFERENCES player_status(id)
  , UNIQUE (player_id, status_id, timestamp)
);
  CREATE INDEX IF NOT EXISTS player_status_log_player_id ON player_status_log(player_id);
  CREATE INDEX IF NOT EXISTS player_status_log_timestamp ON player_status_log(timestamp);
  CREATE INDEX IF NOT EXISTS player_status_log_reason    ON player_status_log(reason);
-- END PLAYER
-- IP
CREATE TABLE IF NOT EXISTS ip_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX IF NOT EXISTS ip_status_name ON ip_status(name);
  INSERT OR IGNORE INTO ip_status
         (id, name)
  VALUES ( 1, 'default')
       , ( 2, 'trusted')
       , ( 3, 'suspicious')
       , ( 4, 'blocked')
       , ( 5, 'tempblocked');

CREATE TABLE IF NOT EXISTS ip (
    ip             INTEGER PRIMARY KEY
  , last_status_id INTEGER
  , FOREIGN KEY (last_status_id) REFERENCES ip_status_log(id)
);
  CREATE INDEX IF NOT EXISTS ip_last_status_id ON ip(last_status_id);

CREATE TABLE IF NOT EXISTS ip_status_log (
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
  CREATE INDEX IF NOT EXISTS ip_status_log_ip        ON ip_status_log(ip);
  CREATE INDEX IF NOT EXISTS ip_status_log_timestamp ON ip_status_log(timestamp);
  CREATE INDEX IF NOT EXISTS ip_status_log_reason    ON ip_status_log(reason);
-- END IP
-- ASN
CREATE TABLE IF NOT EXISTS asn_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX IF NOT EXISTS asn_status_name ON asn_status(name);
  INSERT OR IGNORE INTO asn_status
         (id, name)
  VALUES ( 1, 'default')
       , ( 2, 'suspicious')
       , ( 3, 'blocked')
       , ( 4, 'tempblocked');

CREATE TABLE IF NOT EXISTS asn (
    asn       INTEGER PRIMARY KEY
  , last_status_id INTEGER
  , FOREIGN KEY (last_status_id) REFERENCES asn_status_log(id)
);
  CREATE INDEX IF NOT EXISTS asn_last_status_id ON asn(last_status_id);

CREATE TABLE IF NOT EXISTS asn_status_log (
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
  CREATE INDEX IF NOT EXISTS asn_status_log_asn       ON asn_status_log(asn);
  CREATE INDEX IF NOT EXISTS asn_status_log_timestamp ON asn_status_log(timestamp);
  CREATE INDEX IF NOT EXISTS asn_status_log_reason    ON asn_status_log(reason);
-- END ASN
-- OTHER
CREATE TABLE IF NOT EXISTS log (
    player_id INTEGER NOT NULL
  , ip        INTEGER NOT NULL
  , asn       INTEGER NOT NULL
  , success   INTEGER NOT NULL
  , timestamp INTEGER NOT NULL
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (ip)        REFERENCES ip(ip)
  , FOREIGN KEY (asn)       REFERENCES asn(asn)
  , UNIQUE (player_id, ip, success, timestamp)
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
