"""Genera Data/MatVendors.lua: quién vende cada material de profesión en Forever y
dónde está.

Lee forever_mat_vendors.csv (item, npc) y forever_mat_npcs.csv (npc, name, side, map,
x, y) de la carpeta de datos de Forever que no va en el repositorio (junto al
repositorio, CraftersJournal-private, o en CJ_PRIVATE_DATA).

Va aparte de Sources.lua (rehacerlo desde QuestieDB arrastra cambios ajenos) y manda
sobre él para los materiales que conoce: Waypoints (WP.Vendors) usa esta lista en vez
de la de QuestieDB, que es la de Classic. Los PNJ se añaden a ES.Data.NPCs si no estaban.

Uso:  python tools/gen_mat_vendors.py
"""
import csv
import os
from collections import defaultdict
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ADDON = TOOLS.parent
PRIVATE = Path(os.environ.get("CJ_PRIVATE_DATA") or (ADDON.parent / "CraftersJournal-private"))


def rows(name):
    with open(PRIVATE / name, encoding="utf-8") as f:
        return list(csv.DictReader(line for line in f if not line.startswith("#")))


def q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    sold = defaultdict(set)
    for r in rows("forever_mat_vendors.csv"):
        sold[int(r["item"])].add(int(r["npc"]))
    npcs = {int(r["npc"]): r for r in rows("forever_mat_npcs.csv")}
    out = ["local _, ES = ...", "",
           "-- Generado por tools/gen_mat_vendors.py: no editar a mano.",
           "-- Quién vende cada material de profesión en Forever. Manda sobre los vendedores",
           "-- de Data/Sources.lua (QuestieDB: los de Classic) para estos materiales",
           "-- (Waypoints.lua, WP.Vendors). Sus PNJ van con los demás (ES.Data.NPCs, el",
           "-- formato de Data/Sources.lua) si no estaban ya", "",
           "ES.Data.NPCs = ES.Data.NPCs or {}",
           "local NPCs = ES.Data.NPCs"]
    used = sorted({n for s in sold.values() for n in s if n in npcs})
    for n in used:
        r = npcs[n]
        out.append(f"NPCs[{n}] = NPCs[{n}] or {{ {q(r['name'])}, {q(r['side'])}, {int(r['map'])}, {float(r['x'])}, {float(r['y'])} }}")
    out += ["", "ES.Data.MatVendors = {"]
    for item in sorted(sold):
        ids = sorted(n for n in sold[item] if n in npcs)
        if ids:
            out.append(f"  [{item}] = {{ {', '.join(str(i) for i in ids)} }},")
    out += ["}", ""]
    dest = ADDON / "Data" / "MatVendors.lua"
    dest.write_text("\n".join(out), encoding="utf-8")
    print(f"{dest}: {len(sold)} materiales, {len(used)} PNJ")


if __name__ == "__main__":
    main()
