      SELECT executor.id   AS executor_id
           , executor.name AS executor_name
           , status.id     AS id
           , status.name   AS name
           , log.timestamp AS timestamp
           , log.reason    AS reason
           , log.expires   AS expires
        FROM asn
NATURAL JOIN asn_status_log AS log
NATURAL JOIN asn_status     AS status
        JOIN player         AS executor ON log.executor_id == executor.id
       WHERE asn_id == ?
       LIMIT 1
