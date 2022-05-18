BEGIN EXCLUSIVE TRANSACTION;
PRAGMA foreign_keys=off;
PRAGMA ignore_check_constraints=on;

UPDATE version SET version = 2;

CREATE TABLE new_ip (
    id                INTEGER PRIMARY KEY
  , ipv6              BLOB
  , current_status_id INTEGER
  , UNIQUE (ipv6)
  , FOREIGN KEY (current_status_id) REFERENCES ip_status_log(id)
);

CREATE TABLE new_ip_status_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT
  , executor_id INTEGER NOT NULL
  , ip_id       INTEGER NOT NULL
  , status_id   INTEGER NOT NULL
  , timestamp   INTEGER NOT NULL
  , reason      TEXT
  , expires     INTEGER
  , FOREIGN KEY (executor_id) REFERENCES player(id)
  , FOREIGN KEY (ip_id)       REFERENCES new_ip(id)
  , FOREIGN KEY (status_id)   REFERENCES ip_status(id)
);

CREATE TABLE new_connection_log (
    id        INTEGER PRIMARY KEY AUTOINCREMENT
  , player_id INTEGER NOT NULL
  , ip_id     INTEGER NOT NULL
  , asn       INTEGER NOT NULL
  , success   INTEGER NOT NULL
  , timestamp INTEGER NOT NULL
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (ip_id)     REFERENCES new_ip(id)
  , FOREIGN KEY (asn)       REFERENCES asn(asn)
);

CREATE TABLE new_assoc (
    player_id  INTEGER NOT NULL
  , ip_id      INTEGER NOT NULL
  , asn        INTEGER NOT NULL
  , first_seen INTEGER NOT NULL
  , last_seen  INTEGER NOT NULL
  , PRIMARY KEY (player_id, ip_id, asn)
  , FOREIGN KEY (player_id) REFERENCES player(id)
  , FOREIGN KEY (ip_id)     REFERENCES new_ip(id)
  , FOREIGN KEY (asn)       REFERENCES asn(asn)
);

INSERT INTO new_ip (ipv6)
SELECT '::FFFF:'
    || CAST((ip.ip / 16777216) AS INT) || '.'
    || CAST((ip.ip / 65535) AS INT) % 256 || '.'
    || CAST((ip.ip / 256) AS INT) % 256 || '.'
    || ip.ip % 256 AS ipv6
  FROM ip;

INSERT INTO new_ip_status_log (executor_id, ip_id, status_id, timestamp, reason, expires)
SELECT executor_id, (SELECT id FROM new_ip WHERE ipv6 = ('::FFFF:'
    || CAST((ip / 16777216) AS INT) || '.'
    || CAST((ip / 65535) AS INT) % 256 || '.'
    || CAST((ip / 256) AS INT) % 256 || '.'
    || ip % 256)), status_id, timestamp, reason, expires
  FROM ip_status_log;

UPDATE new_ip
   SET current_status_id = (
   SELECT new_ip_status_log.id
     FROM new_ip_status_log
        , ip_status_log
        , ip
    WHERE new_ip.ipv6 = ('::FFFF:'
          || CAST((ip.ip / 16777216) AS INT) || '.'
          || CAST((ip.ip / 65535) AS INT) % 256 || '.'
          || CAST((ip.ip / 256) AS INT) % 256 || '.'
          || ip.ip % 256)
      AND ip.current_status_id = ip_status_log.id
      AND ip_status_log.executor_id = new_ip_status_log.executor_id
      AND ip_status_log.status_id = new_ip_status_log.status_id
      AND ip_status_log.timestamp = new_ip_status_log.timestamp
      AND ip_status_log.reason = new_ip_status_log.reason
      AND ip_status_log.expires = new_ip_status_log.expires
   );

-- TODO: can't just alter the existing tables, dropping the constraints isn't feasible.
-- TODO: create new tables, and copy the data over, then delete the old ones
-- TODO: and delete the old ip table last

-- ALTER TABLE ip_status_log
--  ADD COLUMN ip_id INTEGER NOT NULL DEFAULT -1 REFERENCES new_ip(id);
--
-- UPDATE ip_status_log
--    SET ip_id = (
--        SELECT id
--          FROM new_ip
--         WHERE ipv6 = '::FFFF:'
--                   || CAST((ip / 16777216) AS INT) || '.'
--                   || CAST((ip / 65535) AS INT) || '.'
--                   || CAST((ip / 256) AS INT) || '.'
--                   || ip % 256
--    );
--
-- DROP INDEX ip_status_log_ip;
-- ALTER TABLE ip_status_log DROP COLUMN ip;
--
-- ALTER TABLE connection_log
--  ADD COLUMN ip_id INTEGER NOT NULL DEFAULT -1 REFERENCES ip(id);
--
-- ALTER TABLE assoc
--  ADD COLUMN ip_id INTEGER NOT NULL DEFAULT -1 REFERENCES ip(id);
--
--
--


DROP INDEX ip_current_status_id;
DROP TABLE ip;

ALTER TABLE new_ip RENAME TO ip;

CREATE INDEX ip_ipv6              ON ip(ipv6);
CREATE INDEX ip_current_status_id ON ip(current_status_id);

PRAGMA ignore_check_constraints=off;
PRAGMA foreign_keys=on;
COMMIT;
