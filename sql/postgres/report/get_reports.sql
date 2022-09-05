SELECT player.name      AS reporter
     , report.report    AS report
     , report.timestamp AS timestamp
  FROM report
  JOIN player ON player.id == report.reporter_id
 WHERE report.timestamp >= ?
