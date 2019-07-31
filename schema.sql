BEGIN EXCLUSIVE TRANSACTION;
CREATE TABLE version (version INTEGER);
INSERT INTO version (version) VALUES (1);

-- PLAYER
CREATE TABLE player_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX player_status_name ON player_status(name);

CREATE TABLE player (
    id                INTEGER PRIMARY KEY AUTOINCREMENT
  , name              TEXT NOT NULL
  , master_id         INTEGER
  , current_status_id INTEGER
  , last_login_id     INTEGER
  , flagged           BOOLEAN NOT NULL DEFAULT FALSE
  , FOREIGN KEY (master_id)         REFERENCES player(id)
  , FOREIGN KEY (current_status_id) REFERENCES player_status_log(id)
  , FOREIGN KEY (last_login_id)     REFERENCES connection_log(id)
);
  CREATE UNIQUE INDEX player_name              ON player(LOWER(name));
  CREATE        INDEX player_master_id         ON player(master_id);
  CREATE        INDEX player_current_status_id ON player(current_status_id);
  CREATE        INDEX player_last_login_id     ON player(last_login_id);

CREATE TABLE player_status_log (
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
  CREATE INDEX player_status_log_player_id ON player_status_log(player_id);
  CREATE INDEX player_status_log_timestamp ON player_status_log(timestamp);
  CREATE INDEX player_status_log_reason    ON player_status_log(reason);
-- END PLAYER
-- IP
CREATE TABLE ip_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX ip_status_name ON ip_status(name);

CREATE TABLE ip (
    ip             INTEGER PRIMARY KEY
  , current_status_id INTEGER
  , FOREIGN KEY (current_status_id) REFERENCES ip_status_log(id)
);
  CREATE INDEX ip_current_status_id ON ip(current_status_id);

CREATE TABLE ip_status_log (
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
  CREATE INDEX ip_status_log_ip        ON ip_status_log(ip);
  CREATE INDEX ip_status_log_timestamp ON ip_status_log(timestamp);
  CREATE INDEX ip_status_log_reason    ON ip_status_log(reason);
-- END IP
-- ASN
CREATE TABLE asn_status (
    id   INTEGER PRIMARY KEY
  , name TEXT NOT NULL
);
  CREATE INDEX asn_status_name ON asn_status(name);

CREATE TABLE asn (
    asn       INTEGER PRIMARY KEY
  , current_status_id INTEGER
  , FOREIGN KEY (current_status_id) REFERENCES asn_status_log(id)
);
  CREATE INDEX asn_current_status_id ON asn(current_status_id);

CREATE TABLE asn_status_log (
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
  CREATE INDEX asn_status_log_asn       ON asn_status_log(asn);
  CREATE INDEX asn_status_log_timestamp ON asn_status_log(timestamp);
  CREATE INDEX asn_status_log_reason    ON asn_status_log(reason);
-- END ASN
-- LOGS AND ASSOCIATIONS
CREATE TABLE connection_log (
    id        INTEGER PRIMARY KEY AUTOINCREMENT
  , player_id INTEGER NOT NULL
  , ip        INTEGER NOT NULL
  , asn       INTEGER NOT NULL
  , success   INTEGER NOT NULL
  , timestamp INTEGER NOT NULL
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (ip)        REFERENCES ip(ip)
  , FOREIGN KEY (asn)       REFERENCES asn(asn)
  , UNIQUE (player_id, ip, success, timestamp)
);
  CREATE INDEX log_player    ON connection_log(player_id);
  CREATE INDEX log_ip        ON connection_log(ip);
  CREATE INDEX log_asn       ON connection_log(asn);
  CREATE INDEX log_timestamp ON connection_log(timestamp);

CREATE TABLE assoc (
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
  CREATE INDEX assoc_player ON assoc(player_id);
  CREATE INDEX assoc_ip     ON assoc(ip);
  CREATE INDEX assoc_asn    ON assoc(asn);
-- END LOGS AND ASSOCIATIONS
-- REPORTS
CREATE TABLE report (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
  , reporter_id INTEGER NOT NULL
  , report      TEXT    NOT NULL
  , timestamp   INTEGER NOT NULL
  , FOREIGN KEY (reporter_id) REFERENCES player(id)
);
  CREATE INDEX report_reporter  ON report(reporter_id);
  CREATE INDEX report_timestamp ON report(timestamp);
-- END REPORTS
COMMIT TRANSACTION;
