SELECT executor.id    executor_id
     , executor.name  executor_name
     , status.id      id
     , status.name    name
     , log.timestamp  timestamp
     , log.reason     reason
     , log.expires    expires
     , player.flagged flagged
  FROM player
  JOIN player_status_log log      ON player.current_status_id == log.id
  JOIN player_status     status   ON log.status_id == status.id
  JOIN player            executor ON log.executor_id == executor.id
 WHERE player.id == ?
 LIMIT 1
