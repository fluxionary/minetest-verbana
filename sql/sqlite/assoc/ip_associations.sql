    SELECT
  DISTINCT player.name                 player_name
         , player_status_log.status_id player_status_id
      FROM assoc
      JOIN connection_log USING (ip, asn)
      JOIN player            ON player.id == assoc.player_id
 LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
     WHERE assoc.ip == ?
       AND connection_log.timestamp >= ?
  ORDER BY LOWER(player.name)
