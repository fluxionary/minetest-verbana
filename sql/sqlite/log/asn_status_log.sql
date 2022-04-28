    SELECT executor.name executor_name
         , log.status_id status_id
         , log.timestamp timestamp
         , log.reason    reason
         , log.expires   expires
      FROM asn_status_log log
      JOIN player         executor ON log.executor_id == executor.id
     WHERE log.asn == ?
  ORDER BY log.timestamp
