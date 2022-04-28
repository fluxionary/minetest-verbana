    SELECT log.ip                   ipint
         , log.asn                  asn
         , log.success              success
         , log.timestamp            timestamp
         , ip_status_log.status_id  ip_status_id
         , asn_status_log.status_id asn_status_id
      FROM connection_log log
      JOIN player         ON player.id         == log.player_id
      JOIN ip             ON ip.ip             == log.ip
 LEFT JOIN ip_status_log  ON ip_status_log.id  == ip.current_status_id
      JOIN asn            ON asn.asn           == log.asn
 LEFT JOIN asn_status_log ON asn_status_log.id == asn.current_status_id
     WHERE player.id == ?
  ORDER BY timestamp DESC
     LIMIT ?
