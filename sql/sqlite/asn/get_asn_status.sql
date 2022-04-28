SELECT executor.id   executor_id
     , executor.name executor_name
     , status.id     id
     , status.name   name
     , log.timestamp timestamp
     , log.reason    reason
     , log.expires   expires
  FROM asn
  JOIN asn_status_log log      ON asn.current_status_id == log.id
  JOIN asn_status     status   ON log.status_id == status.id
  JOIN player         executor ON log.executor_id == executor.id
 WHERE asn.asn == ?
 LIMIT 1
