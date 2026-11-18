"""Genera Data/Mailboxes.lua para el asistente de ruta (Assistant.lua): los buzones de
QuestieDB (objetos "Mailbox") con su sitio, como PNJ de ES.Data.NPCs para poder llevarte
al más cercano (WP.Target("mailbox")). Solo el sitio: el addon no usa el correo.

Va aparte, como Data/Bankers.lua (y, como el asistente, solo en la copia de desarrollo:
#@do-not-package@ en el .toc).

Uso:  python tools/gen_mailboxes.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from questie import all_ids, field, load_store, row, seq, zone_tables  # noqa: E402

ADDON = Path(__file__).resolve().parent.parent
# Capitales por área: el buzón de una capital es para su bando (como en gen_bankers.py)
CAPITALS = {1519: "A", 1537: "A", 1657: "A", 1637: "H", 1497: "H", 1638: "H"}
OBJ_NAME, OBJ_SPAWNS = 1, 4
FIRST_ID = 9000001  # (IDs propios, lejos de los de los PNJ)


def main():
    print("Leyendo QuestieDB ...", file=sys.stderr)
    load_store()
    zt = zone_tables()
    area, area_o = zt.get("areaIdToUiMapId", {}), zt.get("areaIdToUiMapIdOverride", {})
    parent, parent_o = zt.get("subZoneToParentZone", {}), zt.get("subZoneToParentZoneOverride", {})

    def ui_map(a):
        m = area_o.get(a) or area.get(a)
        if not m:
            p = parent_o.get(a) or parent.get(a)
            m = p and (area_o.get(p) or area.get(p))
        return m or None

    spots = set()
    for obj_id in all_ids("Object"):
        r = row("Object", obj_id)
        name = field("Object", obj_id, OBJ_NAME, r)
        if not isinstance(name, str) or name.lower() != "mailbox":
            continue
        spawns = field("Object", obj_id, OBJ_SPAWNS, r) or {}
        items = spawns.items() if isinstance(spawns, dict) else enumerate(seq(spawns), 1)
        for zone, points in items:
            zone = int(zone)
            m = ui_map(zone)
            if not m:
                continue
            side = CAPITALS.get(zone) or CAPITALS.get(parent_o.get(zone) or parent.get(zone)) or ""
            for p in seq(points):
                p = seq(p)
                if len(p) >= 2 and 0 <= float(p[0]) <= 100 and 0 <= float(p[1]) <= 100:
                    spots.add((side, m, round(float(p[0]) / 100, 4), round(float(p[1]) / 100, 4)))

    out = ["local _, ES = ...", "local L = ES.L", "",
           "-- Generado por tools/gen_mailboxes.py desde QuestieDB: no editar a mano.",
           "-- Buzones (asistente de ruta: ir a recoger lo comprado en la AH). Solo el sitio,",
           "-- como PNJ (ES.Data.NPCs, el formato de Data/Sources.lua): el addon no usa el correo", "",
           "ES.Data.NPCs = ES.Data.NPCs or {}",
           "local NPCs = ES.Data.NPCs",
           "local NAME = L[\"Buzón\"]",
           "ES.Data.Mailboxes = {}",
           "local function M(id, side, map, x, y)",
           "  NPCs[id] = { NAME, side, map, x, y }",
           "  ES.Data.Mailboxes[#ES.Data.Mailboxes + 1] = id",
           "end"]
    for i, (side, m, x, y) in enumerate(sorted(spots)):
        out.append(f'M({FIRST_ID + i}, "{side}", {m}, {x}, {y})')
    out.append("")
    dest = ADDON / "Data" / "Mailboxes.lua"
    dest.write_text("\n".join(out), encoding="utf-8")
    print(f"{dest}: {len(spots)} buzones")


if __name__ == "__main__":
    main()
