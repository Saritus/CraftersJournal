"""Genera Data/Bankers.lua para el asistente de ruta (Assistant.lua): los banqueros de
QuestieDB (marca BANKER) con su nombre, bando y sitio, como los PNJ de Data/Sources.lua.

Va aparte de Sources.lua (y, como el asistente, solo en la copia de desarrollo:
#@do-not-package@ en el .toc) para no rehacer el resto de datos.

Uso:  python tools/gen_bankers.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from questie import NPC, NPC_BANKER, all_ids, field, load_store, row, seq, zone_tables  # noqa: E402

ADDON = Path(__file__).resolve().parent.parent
# Capitales por área: un PNJ amistoso con los dos bandos dentro de una solo atiende a ese
# bando (como en gen_sources.py)
CAPITALS = {1519: "A", 1537: "A", 1657: "A", 1637: "H", 1497: "H", 1638: "H"}


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

    entries = {}
    for npc_id in all_ids("Npc"):
        r = row("Npc", npc_id)
        flags = r and field("Npc", npc_id, NPC["npcFlags"], r)
        if not isinstance(flags, int) or not flags & NPC_BANKER:
            continue
        name = field("Npc", npc_id, NPC["name"], r)
        if not name:
            continue
        spawns = field("Npc", npc_id, NPC["spawns"], r) or {}
        home = field("Npc", npc_id, NPC["zoneID"], r)
        spawns = {int(k): seq(v) for k, v in (spawns.items() if isinstance(spawns, dict) else enumerate(seq(spawns), 1))}
        zone = home if home in spawns else (min(spawns) if spawns else None)
        spots = [(float(seq(p)[0]), float(seq(p)[1])) for p in spawns.get(zone, [])
                 if len(seq(p)) >= 2 and 0 <= float(seq(p)[0]) <= 100 and 0 <= float(seq(p)[1]) <= 100]
        if not spots or zone is None or not ui_map(zone):
            continue  # (sin sitio no sirve para llevarte)
        side = {"A": "A", "H": "H", "AH": ""}.get(field("Npc", npc_id, NPC["friendlyToFaction"], r), "X")
        if side == "":
            side = CAPITALS.get(zone) or CAPITALS.get(parent_o.get(zone) or parent.get(zone)) or ""
        cx, cy = sum(s[0] for s in spots) / len(spots), sum(s[1] for s in spots) / len(spots)
        x, y = min(spots, key=lambda s: (s[0] - cx) ** 2 + (s[1] - cy) ** 2)
        entries[npc_id] = (name, side, ui_map(zone), round(x / 100, 4), round(y / 100, 4))

    def q(s):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

    out = ["local _, ES = ...", "",
           "-- Generado por tools/gen_bankers.py desde QuestieDB: no editar a mano.",
           "-- Banqueros (asistente de ruta: ir a sacar materiales del banco). Su sitio va con",
           "-- los demás PNJ (ES.Data.NPCs, el formato de Data/Sources.lua) si no estaba ya", "",
           "ES.Data.NPCs = ES.Data.NPCs or {}",
           "local NPCs = ES.Data.NPCs"]
    for npc_id, (name, side, m, x, y) in sorted(entries.items()):
        out.append(f"NPCs[{npc_id}] = NPCs[{npc_id}] or {{ {q(name)}, {q(side)}, {m}, {x}, {y} }}")
    out += ["", "ES.Data.Bankers = { " + ", ".join(str(i) for i in sorted(entries)) + " }", ""]
    dest = ADDON / "Data" / "Bankers.lua"
    dest.write_text("\n".join(out), encoding="utf-8")
    print(f"{dest}: {len(entries)} banqueros")


if __name__ == "__main__":
    main()
