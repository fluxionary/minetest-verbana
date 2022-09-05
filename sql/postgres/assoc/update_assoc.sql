UPDATE assoc
   SET last_seen = ?
 WHERE player_id == ?
   AND ip_id == ?
   AND asn_id == ?
