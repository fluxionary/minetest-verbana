    SELECT timestamp
      FROM connection_log
     WHERE player_id == ?
  ORDER BY timestamp
     LIMIT 1
