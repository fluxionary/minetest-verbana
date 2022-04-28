    SELECT
  DISTINCT other.name                  player_name
         , player_status_log.status_id player_status_id
         , connection_log.ip           ipint
         , connection_log.asn          asn
      FROM player
      JOIN assoc player_assoc ON player_assoc.player_id == player.id
      JOIN assoc other_assoc  ON other_assoc.ip == player_assoc.ip
      JOIN player other       ON other.id == other_assoc.player_id
 LEFT JOIN player_status_log  ON player_status_log.id == other.current_status_id
 LEFT JOIN connection_log     ON connection_log.id == player.last_login_id
     WHERE player.id == ?
       AND player.id != other_assoc.player_id
  ORDER BY LOWER(other.name)
