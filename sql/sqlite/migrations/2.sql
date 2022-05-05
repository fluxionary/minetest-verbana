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

INSERT INTO new_ip (ipv6, current_status_id)
SELECT '::FFFF:'
    || CAST((ip / 16777216) AS INT) || '.'
    || CAST((ip / 65535) AS INT) || '.'
    || CAST((ip / 256) AS INT) || '.'
    || ip % 256 AS ipv6
     , current_status_id
  FROM ip;

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
