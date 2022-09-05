INSERT INTO assoc (player_id, ip_id, asn_id)
           VALUES (?,         ?,  ?)
      ON CONFLICT (player_id, ip_id, asn_id)
    DO UPDATE SET last_seen = CURRENT_TIMESTAMP
