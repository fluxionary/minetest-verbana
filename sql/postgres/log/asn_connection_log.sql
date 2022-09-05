    SELECT player.name                 AS player_name
         , player.id                   AS player_id
         , log.ip_id                   AS ipint
         , log.success                 AS success
         , log.timestamp               AS timestamp
         , player_status_log.status_id AS player_status_id
         , ip.current_status_id        AS ip_status_id
      FROM connection_log AS log
      JOIN player            ON player.id == log.player_id
 LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
      JOIN ip                ON ip.ip_id == log.ip_id
 LEFT JOIN ip_status_log     ON ip.current_status_id == ip_status_log.id
     WHERE log.asn_id == ?
  ORDER BY timestamp DESC
     LIMIT ?
