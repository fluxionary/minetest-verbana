    SELECT executor.name executor_name
         , log.status_id status_id
         , log.timestamp timestamp
         , log.reason    reason
         , log.expires   expires
      FROM player_status_log log
      JOIN player                     ON log.player_id   == player.id
      JOIN player            executor ON log.executor_id == executor.id
     WHERE player.id == ?
  ORDER BY log.timestamp
