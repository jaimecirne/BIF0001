#!/usr/bin/env bash
set -euo pipefail
#set -x #Debug Print all actions of script
# ----------------------------------------
# Configuration (edit as needed)
# ----------------------------------------
WORKDIR="${PWD}"
BLAST_SRC="/home/treinamento/blast_aula"
MYSQL_USER="bif01"
MYSQL_PASS="bif01"
DB_NAME="JaimeCirne"

export MYSQL_USER
export MYSQL_PASS
export DB_NAME

# Activate the virtualenv
source "${WORKDIR}/../.venv/bin/activate"

# ----------------------------------------
# 1) Prepare directories & copy inputs
# ----------------------------------------
mkdir -p "${WORKDIR}/blast" "${WORKDIR}/mysql"
cp "${BLAST_SRC}/CDS/h.sapiens.nuc" "${WORKDIR}/blast/"
cp "${BLAST_SRC}/454data/tumor.seq"* "${WORKDIR}/blast/"
cp "${BLAST_SRC}/mysql_aula/"* "${WORKDIR}/mysql/"

# ----------------------------------------
# 2) Run MegaBLAST
# ----------------------------------------
echo ">> Running MegaBLAST..."
cd "${WORKDIR}/blast"
megablast \
  -i h.sapiens.nuc \
  -d tumor.seq \
  -D 3 \
  -F F \
  -a 10 \
  -p 97 \
  -s 80 \
  -o megakegg  

# ----------------------------------------
# 3) Process results
# ----------------------------------------
echo ">> Processing BLAST output..."
python3 "${WORKDIR}/process_results.py" ${WORKDIR}/blast/megakegg

# ----------------------------------------
# 4) Initialize MySQL schema & load data
# ----------------------------------------
echo ">> Initializing MySQL schema..."
mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" < "${WORKDIR}/mysql/schema.sql"

echo ">> Loading data & updating tables..."
mysql --local-infile=1 -u "${MYSQL_USER}" -p"${MYSQL_PASS}" "${DB_NAME}" \
  < "${WORKDIR}/mysql/load_data.sql"

# DEBUG counts
echo
echo ">> DEBUG: row counts in each table"
mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" "${DB_NAME}" -e \
  "SELECT 'hsa_count' AS table_name, COUNT(*) AS row_count FROM hsa_count \
   UNION ALL \
   SELECT 'ko_hits', COUNT(*)     FROM ko_hits \
   UNION ALL \
   SELECT 'KOmap',   COUNT(*)     FROM KOmap;"

# JOIN challenge
echo
echo ">> [CHALLENGE] Top 10 KOs with metabolic pathways:"
mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" "${DB_NAME}" -e \
  "SELECT 
     k.*, m.path, m.path_desc
   FROM ko_hits AS k
   INNER JOIN KOmap AS m
     ON k.ko = m.ko
   ORDER BY k.total_hits DESC
   LIMIT 10;"

echo
echo ">> [BONUS] KOs with 'tumor' in their description:"
mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" "${DB_NAME}" -e \
  "SELECT 
     k.*, m.path, m.path_desc
   FROM ko_hits AS k
   INNER JOIN KOmap AS m
     ON k.ko = m.ko
   WHERE k.ko_desc LIKE '%tumor%'
   ORDER BY k.total_hits DESC
   LIMIT 10;"

echo ">> Running ad-hoc queries..."
mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" "${DB_NAME}" \
  < "${WORKDIR}/mysql/queries.sql"

# ----------------------------------------
# Pretty‐print helper
# ----------------------------------------
mysql_fmt() {
  # $1 = database, $2 = SQL query
  mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" -B -e "$2" "$1" \
    | column -t -s $'\t'
}

# ----------------------------------------
# 5) Print nicely formatted tables to Bash
# ----------------------------------------
echo
echo ">> Top 10 genes by hit count:"
mysql_fmt "${DB_NAME}" "
  SELECT cds       AS Gene,
         hits      AS Hits
    FROM hsa_count
   ORDER BY Hits DESC
   LIMIT 10;
"

echo
echo ">> Top 10 KOs by total hits:"
mysql_fmt "${DB_NAME}" "
  SELECT ko        AS KO,
         total_hits AS Hits
    FROM ko_hits
   ORDER BY Hits DESC
   LIMIT 10;
"

echo
echo ">> Top 10 pathways by KO hits:"
mysql_fmt "${DB_NAME}" "
  SELECT total_hits AS Hits,
         path       AS Pathway,
         path_desc  AS Description
    FROM ko_hits AS k
    JOIN KOmap   AS m USING(ko)
   ORDER BY Hits DESC
   LIMIT 10;
"

echo
echo ">> [CHALLENGE] Top 10 KOs with metabolic pathways:"
mysql_fmt "${DB_NAME}" "
  SELECT k.ko        AS KO,
         k.total_hits AS Hits,
         k.ko_desc    AS Description,
         m.path       AS Pathway,
         m.path_desc  AS Path_Desc
    FROM ko_hits AS k
    JOIN KOmap   AS m USING(ko)
   ORDER BY Hits DESC
   LIMIT 10;
"

echo
echo ">> [BONUS] KOs with 'tumor' in their description:"
mysql_fmt "${DB_NAME}" "
  SELECT k.ko        AS KO,
         k.total_hits AS Hits,
         k.ko_desc    AS Description,
         m.path       AS Pathway,
         m.path_desc  AS Path_Desc
    FROM ko_hits AS k
    JOIN KOmap   AS m USING(ko)
   WHERE k.ko_desc LIKE '%tumor%'
   ORDER BY Hits DESC
   LIMIT 10;
"

echo ">> Visualizing results..."
python3 "${WORKDIR}/view_results.py" megakegg

echo ">> All done! Results are in the MySQL database: ${DB_NAME}"
