    SELECT player.name                 player_name
         , player_status_log.status_id player_status_id
         , player_status_log.reason    reason
         , player_status_log.expires   expires
      FROM player
 LEFT JOIN player_status_log ON player.id == player_status_log.player_id
     WHERE player_status_log.status_id == ?
