-- 1) Create your database
DROP DATABASE IF EXISTS JaimeCirne;
CREATE DATABASE JaimeCirne;
USE JaimeCirne;

-- 2) Raw BLAST results table
CREATE TABLE result_blast (
  cds      VARCHAR(15),
  subject  VARCHAR(50),
  identity DOUBLE(5,2),
  evalue   VARCHAR(10),
  score    INT,
  INDEX(cds)
);

-- 3) Count hits per CDS
CREATE TABLE hsa_count AS
  SELECT cds, COUNT(*) AS hits
    FROM result_blast
   GROUP BY cds;

-- 4) Gene descriptions
CREATE TABLE hsa_description (
  cds         VARCHAR(15),
  description VARCHAR(150),
  INDEX(cds)
);

-- 5) KO mapping table
CREATE TABLE hsa_ko (
  cds  VARCHAR(15),
  ko   VARCHAR(11),
  hits BIGINT DEFAULT 0,
  INDEX(cds),
  INDEX(ko)
);

-- 6) Aggregated KO hits
CREATE TABLE ko_hits AS
  SELECT ko,
         COUNT(DISTINCT cds) AS total_cds,
         SUM(hits) AS total_hits
    FROM hsa_ko
   GROUP BY ko;

-- 7) KO descriptions
CREATE TABLE ko_description (
  ko          VARCHAR(11) PRIMARY KEY,
  description VARCHAR(150)
);

-- 8) KEGG pathway map
CREATE TABLE KOmap (
  path      VARCHAR(25),
  ko        VARCHAR(25),
  path_desc VARCHAR(150)
);
