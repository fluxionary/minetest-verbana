SELECT id
     , name
  FROM player
 WHERE LOWER(name) == LOWER(?)
 LIMIT 1
