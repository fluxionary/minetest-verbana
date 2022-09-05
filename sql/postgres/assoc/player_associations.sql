      SELECT assoc.ip_id              AS ipint
           , assoc.asn_id             AS asn
           , ip_status_log.status_id  AS ip_status_id
           , asn_status_log.status_id AS asn_status_id
        FROM assoc
     NATURAL JOIN player
     NATURAL JOIN ip
NATURAL LEFT JOIN ip_status_log
     NATURAL JOIN asn
NATURAL LEFT JOIN asn_status_log
       WHERE player.id == ?
    ORDER BY assoc.asn_id, assoc.ip_id
