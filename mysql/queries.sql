-- Top 10 genes by hit count
SELECT * 
  FROM hsa_count 
 ORDER BY hits DESC 
 LIMIT 10;

-- Top 10 KOs by total hits
SELECT * 
  FROM ko_hits 
 ORDER BY total_hits DESC 
 LIMIT 10;

-- Example join: which pathways are most active?
SELECT k.total_hits,
       m.path,
       m.path_desc
  FROM ko_hits AS k
  JOIN KOmap   AS m USING(ko)
 ORDER BY k.total_hits DESC
 LIMIT 10;
