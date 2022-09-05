    SELECT player.name                 AS name
         , player_status_log.status_id AS player_status_id
         , last_log.ip_id              AS ip
         , last_log.asn_id             AS asn
      FROM player
 LEFT JOIN player_status_log          ON player_status_log.id == player.current_status_id
 LEFT JOIN connection_log AS last_log ON last_log.id == player.last_login_id
     WHERE LOWER(player.name) LIKE LOWER(?)
  ORDER BY LOWER(player.name)
     LIMIT ?
