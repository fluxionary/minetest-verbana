SELECT player.name                 player_name
     , executor.name               executor_name
     , player_status_log.status_id status_id
     , player_status_log.timestamp timestamp
     , player_status_log.reason    reason
     , player_status_log.expires   expires
  FROM player_status_log
  JOIN player          ON player.id        == player_status_log.player_id
  JOIN player executor ON executor.id      == player_status_log.executor_id
 WHERE executor.id != ?
 ORDER BY player_status_log.timestamp DESC
 LIMIT ?
