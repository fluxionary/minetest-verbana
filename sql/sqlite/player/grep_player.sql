    SELECT player.name                 name
         , player_status_log.status_id player_status_id
         , last_log.ip                 ipint
         , last_log.asn                asn
      FROM player
 LEFT JOIN player_status_log       ON player_status_log.id == player.current_status_id
 LEFT JOIN connection_log last_log ON last_log.id == player.last_login_id
     WHERE LOWER(player.name) GLOB LOWER(?)
  ORDER BY LOWER(player.name)
     LIMIT ?
