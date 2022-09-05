BEGIN TRANSACTION;
SET CONSTRAINTS ALL DEFERRED;

CREATE TABLE version (version INTEGER NOT NULL);
INSERT INTO version (version) VALUES (1);

-- STATUSES (static data)

CREATE TABLE player_status (
    id   INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , name TEXT    NOT NULL
);
  CREATE INDEX player_status_name ON player_status USING HASH (name);

CREATE TABLE ip_status (
    id   INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , name TEXT    NOT NULL
);
  CREATE INDEX ip_status_name ON ip_status USING HASH (name);

CREATE TABLE asn_status (
    id   INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , name TEXT    NOT NULL
);
  CREATE INDEX asn_status_name ON asn_status USING HASH (name);

-- BASIC DATA RECORDS

CREATE TABLE player (
    id                INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , master_id         INTEGER          REFERENCES player            ON DELETE RESTRICT
  , current_status_id INTEGER          REFERENCES player_status_log ON DELETE RESTRICT
  , last_login_id     INTEGER          REFERENCES connection_log    ON DELETE RESTRICT
  , name              TEXT    NOT NULL
  , flagged           BOOLEAN NOT NULL DEFAULT FALSE
);
  CREATE UNIQUE INDEX player_name              ON player USING HASH (LOWER(name));
  CREATE        INDEX player_master_id         ON player(master_id);
  CREATE        INDEX player_current_status_id ON player(current_status_id);
  CREATE        INDEX player_last_login_id     ON player(last_login_id);

CREATE TABLE ip (
    ip_id             INET PRIMARY KEY
  , current_status_id INTEGER REFERENCES ip_status_log ON DELETE RESTRICT
);
  CREATE INDEX ip_ip                ON ip USING GIST (ip_id INET_OPS);
  CREATE INDEX ip_current_status_id ON ip(current_status_id);

CREATE TABLE asn (
    asn_id            INTEGER PRIMARY KEY
  , current_status_id INTEGER REFERENCES asn_status_log ON DELETE RESTRICT
);
  CREATE INDEX asn_current_status_id ON asn(current_status_id);

-- LOGS

CREATE TABLE player_status_log (
    id          INTEGER     PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , timestamp   TIMESTAMPTZ NOT NULL    GENERATED ALWAYS AS (CURRENT_TIMESTAMP) STORED
  , executor_id INTEGER     NOT NULL REFERENCES player        ON DELETE RESTRICT
  , player_id   INTEGER     NOT NULL REFERENCES player        ON DELETE RESTRICT
  , status_id   INTEGER     NOT NULL REFERENCES player_status ON DELETE RESTRICT
  , reason      TEXT
  , expires     INTEGER
);
  CREATE INDEX player_status_log_player_id ON player_status_log(player_id);
  CREATE INDEX player_status_log_timestamp ON player_status_log USING BRIN (timestamp);

CREATE TABLE ip_status_log (
    id          INTEGER     PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , timestamp   TIMESTAMPTZ NOT NULL    GENERATED ALWAYS AS (CURRENT_TIMESTAMP) STORED
  , executor_id INTEGER     NOT NULL REFERENCES player    ON DELETE RESTRICT
  , ip_id       INET        NOT NULL REFERENCES ip        ON DELETE RESTRICT
  , status_id   INTEGER     NOT NULL REFERENCES ip_status ON DELETE RESTRICT
  , reason      TEXT
  , expires     INTEGER
);
  CREATE INDEX ip_status_log_ip        ON ip_status_log(ip_id);
  CREATE INDEX ip_status_log_timestamp ON ip_status_log USING BRIN (timestamp);

CREATE TABLE asn_status_log (
    id          INTEGER     PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , timestamp   TIMESTAMPTZ NOT NULL    GENERATED ALWAYS AS (CURRENT_TIMESTAMP) STORED
  , executor_id INTEGER     NOT NULL REFERENCES player     ON DELETE RESTRICT
  , asn_id      INTEGER     NOT NULL REFERENCES asn        ON DELETE RESTRICT
  , status_id   INTEGER     NOT NULL REFERENCES asn_status ON DELETE RESTRICT
  , reason      TEXT
  , expires     INTEGER
);
  CREATE INDEX asn_status_log_asn       ON asn_status_log(asn_id);
  CREATE INDEX asn_status_log_timestamp ON asn_status_log USING BRIN (timestamp);

CREATE TABLE connection_log (
    id        INTEGER     PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , timestamp TIMESTAMPTZ NOT NULL    GENERATED ALWAYS AS (CURRENT_TIMESTAMP) STORED
  , player_id INTEGER     NOT NULL REFERENCES player ON DELETE RESTRICT
  , ip_id     INET        NOT NULL REFERENCES ip     ON DELETE RESTRICT
  , asn_id    INTEGER     NOT NULL REFERENCES asn    ON DELETE RESTRICT
  , success   BOOLEAN     NOT NULL
);
  CREATE INDEX log_player    ON connection_log(player_id);
  CREATE INDEX log_ip        ON connection_log(ip_id);
  CREATE INDEX log_asn       ON connection_log(asn_id);
  CREATE INDEX log_timestamp ON connection_log USING BRIN (timestamp);

CREATE TABLE assoc (
    player_id  INTEGER     NOT NULL REFERENCES player ON DELETE RESTRICT
  , ip_id      INET        NOT NULL REFERENCES ip     ON DELETE RESTRICT
  , asn_id     INTEGER     NOT NULL REFERENCES asn    ON DELETE RESTRICT
  , first_seen TIMESTAMPTZ NOT NULL GENERATED ALWAYS AS (CURRENT_TIMESTAMP) STORED
  , last_seen  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
  , PRIMARY KEY (player_id, ip_id, asn_id)
);
  CREATE INDEX assoc_player ON assoc(player_id);
  CREATE INDEX assoc_ip     ON assoc(ip_id);
  CREATE INDEX assoc_asn    ON assoc(asn_id);

CREATE TABLE report (
    id          INTEGER     PRIMARY KEY GENERATED ALWAYS AS IDENTITY
  , timestamp   TIMESTAMPTZ NOT NULL    GENERATED ALWAYS AS (CURRENT_TIMESTAMP) STORED
  , reporter_id INTEGER     NOT NULL REFERENCES player ON DELETE RESTRICT
  , report      TEXT        NOT NULL
);
  CREATE INDEX report_reporter  ON report(reporter_id);
  CREATE INDEX report_timestamp ON report USING BRIN (timestamp);
-- END REPORTS
COMMIT TRANSACTION;
