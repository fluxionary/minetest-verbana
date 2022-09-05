    SELECT executor.name executor_name
         , log.status_id AS status_id
         , log.timestamp AS timestamp
         , log.reason    AS reason
         , log.expires   AS expires
      FROM player_status_log AS log
      JOIN player                        ON log.player_id   == player.id
      JOIN player            AS executor ON log.executor_id == executor.id
     WHERE player.id == ?
  ORDER BY log.timestamp
