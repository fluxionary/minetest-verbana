    SELECT player.name                 player_name
         , player.id                   player_id
         , log.ip                      ipint
         , log.success                 success
         , log.timestamp               timestamp
         , player_status_log.status_id player_status_id
         , ip.current_status_id        ip_status_id
      FROM connection_log log
      JOIN player            ON player.id == log.player_id
 LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
      JOIN ip                ON ip.ip == log.ip
 LEFT JOIN ip_status_log     ON ip.current_status_id == ip_status_log.id
     WHERE log.asn == ?
  ORDER BY timestamp DESC
     LIMIT ?
