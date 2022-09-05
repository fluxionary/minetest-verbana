SELECT player.name                 AS player_name
     , executor.name               AS executor_name
     , player_status_log.status_id AS status_id
     , player_status_log.timestamp AS timestamp
     , player_status_log.reason    AS reason
     , player_status_log.expires   AS expires
  FROM player_status_log
  JOIN player          ON player.id        == player_status_log.player_id
  JOIN player executor ON executor.id      == player_status_log.executor_id
 WHERE executor.id != ?
 ORDER BY player_status_log.timestamp DESC
 LIMIT ?
