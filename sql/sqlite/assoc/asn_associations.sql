    SELECT
  DISTINCT player.name                 player_name
         , player_status_log.status_id player_status_id
         , last_log.ip                 ipint
         , last_log.asn                asn
      FROM assoc
      JOIN connection_log       USING (ip, asn)
      JOIN player                  ON player.id == assoc.player_id
 LEFT JOIN player_status_log       ON player_status_log.id == player.current_status_id
 LEFT JOIN connection_log last_log ON last_log.id == player.last_login_id
     WHERE assoc.asn == ?
       AND connection_log.timestamp >= ?
       AND player.flagged == 1
  ORDER BY LOWER(player.name)
