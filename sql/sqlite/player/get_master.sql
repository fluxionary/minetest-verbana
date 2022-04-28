    SELECT master.id   id
         , master.name name
      FROM player
 LEFT JOIN player master ON master.id == player.master_id
     WHERE player.id = ?
