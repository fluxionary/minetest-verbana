    SELECT player.name                 AS player_name
         , player_status_log.status_id AS player_status_id
         , player_status_log.reason    AS reason
         , player_status_log.expires   AS expires
      FROM player
 LEFT JOIN player_status_log ON player.id == player_status_log.player_id
     WHERE player_status_log.status_id == ?
