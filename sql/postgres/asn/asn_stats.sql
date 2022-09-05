           SELECT COALESCE(player_status_log.status_id, ?)        AS player_status_id
                , COUNT(COALESCE(player_status_log.status_id, ?)) AS count
             FROM (SELECT DISTINCT player_id AS id
                              FROM assoc
                             WHERE asn_id = ?) AS asn_player
     NATURAL JOIN player
NATURAL LEFT JOIN player_status_log
         GROUP BY COALESCE(player_status_log.status_id, ?)
         ORDER BY COALESCE(player_status_log.status_id, ?)
