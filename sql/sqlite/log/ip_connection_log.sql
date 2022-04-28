    SELECT player.name                 player_name
         , player.id                   player_id
         , log.asn                     asn
         , log.success                 success
         , log.timestamp               timestamp
         , player_status_log.status_id player_status_id
         , asn_status_log.status_id    asn_status_id
      FROM connection_log log
      JOIN player            ON player.id == log.player_id
 LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
      JOIN asn               ON asn.asn == log.asn
 LEFT JOIN asn_status_log    ON asn.current_status_id == asn_status_log.id
     WHERE log.ip == ?
  ORDER BY timestamp DESC
     LIMIT ?
