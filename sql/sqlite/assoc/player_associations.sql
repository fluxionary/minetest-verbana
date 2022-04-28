    SELECT assoc.ip                 ipint
         , assoc.asn                asn
         , ip_status_log.status_id  ip_status_id
         , asn_status_log.status_id asn_status_id
      FROM assoc
      JOIN player         ON player.id == assoc.player_id
      JOIN ip             ON ip.ip == assoc.ip
 LEFT JOIN ip_status_log  ON ip.current_status_id == ip_status_log.id
      JOIN asn            ON asn.asn == assoc.asn
 LEFT JOIN asn_status_log ON asn.current_status_id == asn_status_log.id
     WHERE player.id == ?
  ORDER BY assoc.asn, assoc.ip
