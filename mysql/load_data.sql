-- mysql/load_data.sql

-- 1) Load the tabularized BLAST output
DROP TABLE IF EXISTS result_blast;
CREATE TABLE result_blast (
  cds      VARCHAR(15),
  subject  VARCHAR(50),
  identity DOUBLE(5,2),
  evalue   VARCHAR(10),
  score    INT,
  INDEX(cds)
);
LOAD DATA LOCAL INFILE '../blast/megakegg_tab'
INTO TABLE result_blast
FIELDS TERMINATED BY '\t';

-- 2) Recompute hsa_count from loaded BLAST hits
DROP TABLE IF EXISTS hsa_count;
CREATE TABLE hsa_count AS
  SELECT cds, COUNT(*) AS hits
    FROM result_blast
   GROUP BY cds;

-- 3) Load gene descriptions and (optionally) enrich hsa_count
LOAD DATA LOCAL INFILE '../mysql/hsa_description'
INTO TABLE hsa_description
FIELDS TERMINATED BY '\t';
ALTER TABLE hsa_count ADD COLUMN description VARCHAR(150);
UPDATE hsa_count
  JOIN hsa_description USING(cds)
     SET hsa_count.description = hsa_description.description;

-- 4) Load KO mappings and update hits
LOAD DATA LOCAL INFILE '../mysql/hsa_ko.list'
INTO TABLE hsa_ko
FIELDS TERMINATED BY '\t';
UPDATE hsa_ko
  JOIN hsa_count USING(cds)
     SET hsa_ko.hits = hsa_count.hits;
DELETE FROM hsa_ko WHERE hits = 0;

-- 5) Recompute ko_hits from populated hsa_ko
DROP TABLE IF EXISTS ko_hits;
CREATE TABLE ko_hits AS
  SELECT ko,
         COUNT(DISTINCT cds) AS total_cds,
         SUM(hits)          AS total_hits
    FROM hsa_ko
   GROUP BY ko;

-- 6) Load KO descriptions and enrich ko_hits
LOAD DATA LOCAL INFILE '../mysql/ko_desc'
INTO TABLE ko_description
FIELDS TERMINATED BY '\t';
ALTER TABLE ko_hits ADD COLUMN ko_desc VARCHAR(150);
UPDATE ko_hits
  JOIN ko_description USING(ko)
     SET ko_hits.ko_desc = ko_description.description;

-- 7) Load (or reload) KEGG pathway associations
TRUNCATE TABLE KOmap;
LOAD DATA LOCAL INFILE '../mysql/KO2map'
INTO TABLE KOmap
FIELDS TERMINATED BY '\t';
