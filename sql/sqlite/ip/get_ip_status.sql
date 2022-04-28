SELECT executor.id   executor_id
     , executor.name executor_name
     , status.id     id
     , status.name   name
     , log.timestamp timestamp
     , log.reason    reason
     , log.expires   expires
  FROM ip
  JOIN ip_status_log log      ON ip.current_status_id == log.id
  JOIN ip_status     status   ON log.status_id == status.id
  JOIN player        executor ON log.executor_id == executor.id
 WHERE ip.ip == ?
 LIMIT 1
