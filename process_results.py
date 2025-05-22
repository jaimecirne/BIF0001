#!/usr/bin/env python3
import sys
from collections import Counter

def main(blast_output):
    # read & filter out comment lines
    lines = [l for l in open(blast_output) if not l.startswith('#')]

    # 2a) Count hits per CDS
    cds_list = [line.split()[0] for line in lines]
    counts = Counter(cds_list)
    with open('resultado', 'w') as fout:
        for gene, cnt in counts.most_common():
            fout.write(f"{cnt} {gene}\n")

    # 2b) Extract columns: query, subject, identity, e-value, score
    # (columns 1,2,3,11,12 in BLAST tabular output) :contentReference[oaicite:2]{index=2}:contentReference[oaicite:3]{index=3}
    with open('megakegg_tab', 'w') as fout:
        for line in lines:
            parts = line.split()
            if len(parts) >= 12:
                fout.write("\t".join([parts[0], parts[1], parts[2], parts[10], parts[11]]) + "\n")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: process_results.py <megakegg_file>")
        sys.exit(1)
    main(sys.argv[1])
