      SELECT executor.id   AS executor_id
           , executor.name AS executor_name
           , status.id     AS id
           , status.name   AS name
           , log.timestamp AS timestamp
           , log.reason    AS reason
           , log.expires   AS expires
        FROM ip
NATURAL JOIN ip_status_log log
NATURAL JOIN ip_status     status
        JOIN player        executor ON log.executor_id == executor.id
       WHERE ip.ip_id == ?
       LIMIT 1
