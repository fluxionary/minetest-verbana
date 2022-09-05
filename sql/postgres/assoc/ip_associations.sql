           SELECT
         DISTINCT player.name                 AS player_name
                , player_status_log.status_id AS player_status_id
             FROM assoc
     NATURAL JOIN connection_log
     NATURAL JOIN player
NATURAL LEFT JOIN player_status_log
            WHERE assoc.ip_id == ?
              AND connection_log.timestamp >= ?
         ORDER BY LOWER(player.name)
