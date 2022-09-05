SELECT master.name AS name
  FROM player AS master
 WHERE master.id == ?
 UNION
SELECT alt.name AS name
  FROM player AS master
  JOIN player AS alt    ON alt.master_id == master.id
 WHERE master.id == ?
