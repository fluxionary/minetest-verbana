      SELECT
    DISTINCT player.name                 AS player_name
           , player_status_log.status_id AS player_status_id
           , connection_log.ip_id        AS ip
           , connection_log.asn_id       AS asn
        FROM assoc
     NATURAL JOIN connection_log
     NATURAL JOIN player
NATURAL LEFT JOIN player_status_log
NATURAL LEFT JOIN connection_log
       WHERE assoc.asn_id == ?
         AND connection_log.timestamp >= ?
         AND player.flagged == 1
    ORDER BY LOWER(player.name)
