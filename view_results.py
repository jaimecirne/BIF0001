#!/usr/bin/env python3
import os
import pandas as pd
import pymysql
import matplotlib.pyplot as plt
import io
import base64
import warnings
from http.server import HTTPServer, SimpleHTTPRequestHandler

# Suppress pandas DBAPI2 warning
warnings.filterwarnings('ignore', message='pandas only supports SQLAlchemy connectable')

# Configuration from environment or defaults
MYSQL_USER = os.getenv("MYSQL_USER", "bif01")
MYSQL_PASS = os.getenv("MYSQL_PASS", "bif01")
DB_NAME    = os.getenv("DB_NAME", "JaimeCirne")
REPORT_FILE = 'report.html'
PORT = 8080

# Establish DB connection
temp_conn = pymysql.connect(
    host='localhost',
    user=MYSQL_USER,
    password=MYSQL_PASS,
    database=DB_NAME,
    cursorclass=pymysql.cursors.DictCursor
)

# Define queries for dashboard
QUERIES = {
    'Top Genes by Hits': (
        "SELECT cds AS Gene, hits AS Hits FROM hsa_count ORDER BY Hits DESC LIMIT 10;"
    ),
    'Top KOs by Hits': (
        "SELECT ko AS KO, total_hits AS Hits FROM ko_hits ORDER BY Hits DESC LIMIT 10;"
    ),
    'Top Pathways by KO Hits': (
        "SELECT k.total_hits AS Hits, m.path AS Pathway, m.path_desc AS Description "
        "FROM ko_hits k JOIN KOmap m USING(ko) ORDER BY Hits DESC LIMIT 10;"
    ),
    'Challenge: KO vs Pathways': (
        "SELECT k.ko AS KO, k.total_hits AS Hits, k.ko_desc AS Description, "
        "m.path AS Pathway, m.path_desc AS Path_Desc "
        "FROM ko_hits k JOIN KOmap m USING(ko) ORDER BY Hits DESC LIMIT 10;"
    ),
    'Bonus: Tumor-related KOs': (
        "SELECT k.ko AS KO, k.total_hits AS Hits, k.ko_desc AS Description, "
        "m.path AS Pathway, m.path_desc AS Path_Desc "
        "FROM ko_hits k JOIN KOmap m USING(ko) "
        "WHERE k.ko_desc LIKE '%tumor%' ORDER BY Hits DESC LIMIT 10;"
    )
}

# Prepare HTML sections
html_sections = []

# Raw download links
download_html = (
    "<h2>Raw Result Files</h2>"
    "<ul>"
    "<li><a href='resultado' download>CDS hit counts (resultado)</a></li>"
    "<li><a href='megakegg_tab' download>BLAST tabular output (megakegg_tab)</a></li>"
    "</ul>"
)
html_sections.append(download_html)

# Render summary tables and charts
for title, sql in QUERIES.items():
    cur = temp_conn.cursor()
    cur.execute(sql)
    df = pd.DataFrame(cur.fetchall())
    cur.close()

    if 'Hits' in df.columns:
        df['Hits'] = pd.to_numeric(df['Hits'], errors='coerce').fillna(0).astype(int)

    # HTML table
    table_html = df.to_html(index=False, border=0, classes='dataframe table', justify='left')
    section = f"<h2>{title}</h2>\n{table_html}"

    # Bar chart for top lists
    if title in ['Top Genes by Hits', 'Top KOs by Hits']:
        fig, ax = plt.subplots()
        df.plot.bar(x=df.columns[0], y='Hits', legend=False, ax=ax)
        ax.set_xlabel(df.columns[0]); ax.set_ylabel('Hits'); ax.set_title(title)
        plt.xticks(rotation=45, ha='right'); plt.tight_layout()
        buf = io.BytesIO(); fig.savefig(buf, format='png', bbox_inches='tight'); plt.close(fig)
        img = base64.b64encode(buf.getvalue()).decode()
        section += f"\n<img src='data:image/png;base64,{img}' alt='{title}'/>"

    # Horizontal bar for pathways
    if title == 'Top Pathways by KO Hits':
        fig, ax = plt.subplots()
        df.plot.barh(x='Pathway', y='Hits', legend=False, ax=ax)
        ax.invert_yaxis(); ax.set_xlabel('Hits'); ax.set_title(title)
        plt.tight_layout()
        buf = io.BytesIO(); fig.savefig(buf, format='png', bbox_inches='tight'); plt.close(fig)
        img = base64.b64encode(buf.getvalue()).decode()
        section += f"\n<img src='data:image/png;base64,{img}' alt='{title}'/>"

    html_sections.append(section)

# Full data tables
full_queries = [
    #('Full CDS Hit Counts', "SELECT cds AS Gene, hits AS Hits FROM hsa_count ORDER BY Hits DESC;"),
    #('Full BLAST Tabular Output', 
    # "SELECT cds AS Query, subject AS Subject, identity AS Identity, evalue AS E_Value, score AS BitScore FROM result_blast;")
]
for label, q in full_queries:
    cur = temp_conn.cursor()
    cur.execute(q)
    df_full = pd.DataFrame(cur.fetchall())
    cur.close()
    if not df_full.empty:
        html_sections.append(f"<h2>{label}</h2>\n" + df_full.to_html(index=False, border=0, classes='dataframe table', justify='left'))

# Correlation: CDS vs Hits
cur = temp_conn.cursor()
cur.execute("SELECT total_cds, total_hits FROM ko_hits;")
df_corr = pd.DataFrame(cur.fetchall())
cur.close()
if not df_corr.empty:
    corr = df_corr.corr()
    fig, ax = plt.subplots()
    cax = ax.matshow(corr)
    fig.colorbar(cax)
    ax.set_xticks(range(len(corr.columns))); ax.set_xticklabels(corr.columns, rotation=45)
    ax.set_yticks(range(len(corr.columns))); ax.set_yticklabels(corr.columns)
    ax.set_title('Correlation: Total_CDS vs Total_Hits', pad=20)
    plt.tight_layout()
    buf = io.BytesIO(); fig.savefig(buf, format='png', bbox_inches='tight'); plt.close(fig)
    img = base64.b64encode(buf.getvalue()).decode()
    html_sections.append(f"<h2>Correlation Matrix (CDS vs Hits)</h2>\n<img src='data:image/png;base64,{img}' alt='Correlation CDS vs Hits'/>")

# Close connection
temp_conn.close()

# Build HTML
html = (
    "<html><head><meta charset='UTF-8'><title>Analysis Report</title>" +
    "<style>body{font-family:Arial,sans-serif;margin:20px}.dataframe{margin-bottom:40px;overflow-x:auto;}" +
    "h2{border-bottom:1px solid #ccc;padding-bottom:5px;}img{max-width:100%;height:auto;}" +
    "</style></head><body><h1>Analysis Report</h1>" +
    "\n".join(html_sections) +
    "</body></html>"
)

with open(REPORT_FILE, 'w', encoding='utf-8') as f:
    f.write(html)
print(f"Report generated: {REPORT_FILE}")

# Serve report
class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path in ['/', '/report']:
            self.path = '/' + REPORT_FILE
        return super().do_GET()

server = HTTPServer(('0.0.0.0', PORT), Handler)
print(f"Serving report at http://alemanha.imd.ufrn.br:{PORT}/report")
try:
    server.serve_forever()
except KeyboardInterrupt:
    server.server_close()
