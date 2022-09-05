    SELECT log.ip_id                AS ip
         , log.asn_id               AS asn
         , log.success              AS success
         , log.timestamp            AS timestamp
         , ip_status_log.status_id  AS ip_status_id
         , asn_status_log.status_id AS asn_status_id
      FROM connection_log AS log
      JOIN player         ON player.id         == log.player_id
      JOIN ip             ON ip.ip_id          == log.ip_id
 LEFT JOIN ip_status_log  ON ip_status_log.id  == ip.current_status_id
      JOIN asn            ON asn.asn_id        == log.asn_id
 LEFT JOIN asn_status_log ON asn_status_log.id == asn.current_status_id
     WHERE player.id == ?
  ORDER BY timestamp DESC
     LIMIT ?
