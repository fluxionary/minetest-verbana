SELECT player.name      reporter
     , report.report    report
     , report.timestamp timestamp
  FROM report
  JOIN player ON player.id == report.reporter_id
 WHERE report.timestamp >= ?
