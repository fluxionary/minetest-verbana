    SELECT executor.name AS executor_name
         , log.status_id AS status_id
         , log.timestamp AS timestamp
         , log.reason    AS reason
         , log.expires   AS expires
      FROM asn_status_log AS log
      JOIN player         AS executor ON log.executor_id == executor.id
     WHERE log.asn_id == ?
  ORDER BY log.timestamp
