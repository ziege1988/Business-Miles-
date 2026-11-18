#!/usr/bin/env python3
"""Erzeugt die PLZ→Ort-Tabelle (Resources/plz.json und web/data/plz.json).

Quelle: npm-Paket "postleitzahlen" (Daten © OpenStreetMap-Mitwirkende, ODbL,
aufbereitet von suche-postleitzahl.org).
Aufruf:  npm pack postleitzahlen && tar xzf postleitzahlen-*.tgz
         python3 tools/build_plz.py package/data
"""
import json, os, sys

src = sys.argv[1]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
table = {}
for name in sorted(os.listdir(src)):
    if name.endswith(".json") and len(name) == 10:
        with open(os.path.join(src, name), encoding="utf-8") as f:
            places = [p.strip() for p in json.load(f) if p.strip()]
        if places:
            table[name[:5]] = places
out = json.dumps(table, ensure_ascii=False, separators=(",", ":"))
for target in ("Resources/plz.json", "web/data/plz.json"):
    with open(os.path.join(root, target), "w", encoding="utf-8") as f:
        f.write(out)
print(len(table), "Postleitzahlen,", len(out.encode()), "Bytes")
