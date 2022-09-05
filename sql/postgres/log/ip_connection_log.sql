    SELECT player.name                 AS player_name
         , player.id                   AS player_id
         , log.asn_id                  AS asn
         , log.success                 AS success
         , log.timestamp               AS timestamp
         , player_status_log.status_id AS player_status_id
         , asn_status_log.status_id    AS asn_status_id
      FROM connection_log AS log
      JOIN player            ON player.id == log.player_id
 LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
      JOIN asn               ON asn.asn_id == log.asn_id
 LEFT JOIN asn_status_log    ON asn.current_status_id == asn_status_log.id
     WHERE log.ip_id == ?
  ORDER BY timestamp DESC
     LIMIT ?
