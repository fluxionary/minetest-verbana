UPDATE assoc
   SET last_seen = ?
 WHERE player_id == ?
   AND ip == ?
   AND asn == ?
