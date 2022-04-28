SELECT master.name name
  FROM player master
 WHERE master.id == ?
 UNION
SELECT alt.name
  FROM player master
  JOIN player alt    ON alt.master_id == master.id
 WHERE master.id == ?
