    SELECT master.id   AS id
         , master.name AS name
      FROM player
 LEFT JOIN player AS master ON master.id == player.master_id
     WHERE player.id = ?
