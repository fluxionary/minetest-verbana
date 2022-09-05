SELECT executor.id    AS executor_id
     , executor.name  AS executor_name
     , status.id      AS id
     , status.name    AS name
     , log.timestamp  AS timestamp
     , log.reason     AS reason
     , log.expires    AS expires
     , player.flagged AS flagged
  FROM player
  JOIN player_status_log AS log      ON player.current_status_id == log.id
  JOIN player_status     AS status   ON log.status_id == status.id
  JOIN player            AS executor ON log.executor_id == executor.id
 WHERE player.id == ?
 LIMIT 1
