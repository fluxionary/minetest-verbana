   SELECT COALESCE(player_status_log.status_id, ?)        player_status_id
        , COUNT(COALESCE(player_status_log.status_id, ?)) count
     FROM (SELECT DISTINCT player_id id FROM assoc WHERE asn = ?) asn_player
     JOIN player            ON player.id            == asn_player.id
LEFT JOIN player_status_log ON player_status_log.id == player.current_status_id
 GROUP BY COALESCE(player_status_log.status_id, ?)
 ORDER BY COALESCE(player_status_log.status_id, ?)
