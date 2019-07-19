PRAGMA foreign_keys = OFF;
-- PLAYER
CREATE TABLE IF NOT EXISTS player_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX IF NOT EXISTS player_status_name ON player_status(name);

CREATE TABLE IF NOT EXISTS player (
    id                INTEGER PRIMARY KEY AUTOINCREMENT
  , name              TEXT NOT NULL
  , master_id         INTEGER
  , current_status_id INTEGER
  , FOREIGN KEY (master_id)         REFERENCES player(id)
  , FOREIGN KEY (current_status_id) REFERENCES player_status_log(id)
);
  CREATE UNIQUE INDEX IF NOT EXISTS player_name              ON player(LOWER(name));
  CREATE        INDEX IF NOT EXISTS player_master_id         ON player(master_id);
  CREATE        INDEX IF NOT EXISTS player_current_status_id ON player(current_status_id);

CREATE TABLE IF NOT EXISTS player_status_log (
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

CREATE TABLE IF NOT EXISTS ip (
    ip             INTEGER PRIMARY KEY
  , current_status_id INTEGER
  , FOREIGN KEY (current_status_id) REFERENCES ip_status_log(id)
);
  CREATE INDEX IF NOT EXISTS ip_current_status_id ON ip(current_status_id);

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

CREATE TABLE IF NOT EXISTS asn (
    asn       INTEGER PRIMARY KEY
  , current_status_id INTEGER
  , FOREIGN KEY (current_status_id) REFERENCES asn_status_log(id)
);
  CREATE INDEX IF NOT EXISTS asn_current_status_id ON asn(current_status_id);

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
-- LOGS AND ASSOCIATIONS
CREATE TABLE IF NOT EXISTS connection_log (
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
  CREATE INDEX IF NOT EXISTS log_player    ON connection_log(player_id);
  CREATE INDEX IF NOT EXISTS log_ip        ON connection_log(ip);
  CREATE INDEX IF NOT EXISTS log_asn       ON connection_log(asn);
  CREATE INDEX IF NOT EXISTS log_timestamp ON connection_log(timestamp);

CREATE TABLE IF NOT EXISTS assoc (
    player_id  INTEGER NOT NULL
  , ip         INTEGER NOT NULL
  , asn        INTEGER NOT NULL
  , first_seen INTEGER NOT NULL
  , last_seen  INTEGER NOT NULL
  , PRIMARY KEY (player_id, ip, asn)
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (ip)        REFERENCES ip(ip)
  , FOREIGN KEY (asn)       REFERENCES asn(asn)
);
  CREATE INDEX IF NOT EXISTS assoc_player ON assoc(player_id);
  CREATE INDEX IF NOT EXISTS assoc_ip     ON assoc(ip);
  CREATE INDEX IF NOT EXISTS assoc_asn    ON assoc(asn);
-- END LOGS AND ASSOCIATIONS
-- REPORTS
CREATE TABLE IF NOT EXISTS report (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
  , reporter_id INTEGER NOT NULL
  , report      TEXT    NOT NULL
  , timestamp   INTEGER NOT NULL
  , FOREIGN KEY (reporter_id) REFERENCES player(id)
);
  CREATE INDEX IF NOT EXISTS report_reporter ON report(reporter_id);
-- END REPORTS
PRAGMA foreign_keys = ON;
