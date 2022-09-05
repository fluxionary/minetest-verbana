    SELECT
  DISTINCT player2.name                 AS player_name
         , player_status_log2.status_id AS player_status_id
         , connection_log.ip_id         AS ip
         , connection_log.asn_id        AS asn
      FROM player
      JOIN assoc                                   ON assoc.player_id == player.id
 LEFT JOIN connection_log                          ON connection_log.id == player.last_login_id
      JOIN assoc             AS assoc2             ON assoc2.ip_id == assoc.ip_id
      JOIN player            AS player2            ON player2.id == assoc2.player_id
 LEFT JOIN player_status_log AS player_status_log2 ON player_status_log2.id == player2.current_status_id
     WHERE player.id == ?
       AND player.id != assoc2.player_id
  ORDER BY LOWER(player2.name)
