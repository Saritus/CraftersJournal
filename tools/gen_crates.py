"""Waylaid Crates (Merchant's Favor) -> Data/Crates.lua

Del cliente de WoW Forever (wago.tools DB2):
  - ItemSparse: las 30 cajas con etiqueta ("Waylaid Crate: Expert Fabrics") y los
    objetos con que se llenan (por su nombre exacto)
  - ItemXItemEffect + ItemEffect: el hechizo "Stock Crate" de cada caja
  - Spell (Description_lang): la lista de paquetes posibles ("- $M3 Bolt of Mageweave")
  - SpellEffect (EffectBasePointsF): cuántos pide cada uno ($M3 = efecto de índice 2)
Merchant's Favor que da cada caja: no está en el cliente (lo da el servidor al
entregarla). Es lo de las guías (FAVOR, abajo); Artesano no sale en ninguna y se
estima siguiendo la serie (favorGuess).
Uso: python gen_crates.py   (al cambiar de versión del cliente: BUILD)
"""
import csv
import io
import re
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "Data" / "Crates.lua"
BUILD = "1.60.1.70862"
CURRENCY = 3402  # Merchant's Favor (CurrencyTypes)

TIERS = {"Apprentice": 1, "Journeyman": 2, "Expert": 3, "Artisan": 4}
# Merchant's Favor por caja: [rango] = { materias primas, fabricados } (wow-professions.com,
# theforeverera.com, 2026-11). Artesano: sin dato en las guías -> serie (+5 / +10)
FAVOR = {1: (5, 10), 2: (10, 20), 3: (15, 30), 4: (20, 40)}
FAVOR_GUESS = {4}
CRAFTED = {"Fabrics", "Ingots", "Parts"}
# Nivel de personaje que piden (guías)
LEVEL = {1: 10, 2: 10, 3: 20, 4: 35}
# Nombres con varios objetos en el cliente: el que se usa de verdad (el de Classic;
# 11099 es otro "Dark Iron Ore" que no se mina)
PREFER = {"Dark Iron Ore": 11370}


def table(name):
    url = f"https://wago.tools/db2/{name}/csv?build={BUILD}&locale=enUS"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    data = urllib.request.urlopen(req, timeout=180).read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(data)))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    items = table("ItemSparse")
    name_of = {int(r["ID"]): r["Display_lang"] for r in items}
    by_name = {}
    for r in items:
        by_name.setdefault(r["Display_lang"], []).append(int(r["ID"]))
    effect_of = {}
    for r in table("ItemXItemEffect"):
        effect_of.setdefault(int(r["ItemID"]), []).append(int(r["ItemEffectID"]))
    spell_of_effect = {int(r["ID"]): int(r["SpellID"]) for r in table("ItemEffect")}
    desc = {int(r["ID"]): r.get("Description_lang") or "" for r in table("Spell")}
    points = {}
    for r in table("SpellEffect"):
        points[(int(r["SpellID"]), int(r["EffectIndex"]))] = int(float(r["EffectBasePointsF"] or 0))

    crates, names = [], {}
    for item_id, name in sorted(name_of.items()):
        m = re.match(r"Waylaid Crate: (?:(Earthly|Flowering) )?(Apprentice|Journeyman|Expert|Artisan) (\w+)$", name)
        if not m:
            continue
        flavor, tier_name, kind = m.groups()
        tier = TIERS[tier_name]
        spells = [spell_of_effect[e] for e in effect_of.get(item_id, []) if e in spell_of_effect]
        fills = []
        for sp in spells:
            for idx, label in re.findall(r"\$M(\d+) ([^\r\n|]+)", desc.get(sp, "")):
                label = label.strip()
                ids = by_name.get(label)
                if not ids:
                    print(f"  ! {name}: '{label}' no está en ItemSparse", file=sys.stderr)
                    continue
                pick = PREFER.get(label, min(ids))
                if len(ids) > 1 and label not in PREFER:
                    print(f"  ? {name}: '{label}' tiene varios ids {ids}: se usa {pick}", file=sys.stderr)
                qty = points.get((sp, int(idx) - 1), 0)
                if qty <= 0:
                    print(f"  ! {name}: '{label}' sin cantidad", file=sys.stderr)
                    continue
                fills.append((pick, qty))
                names[pick] = label
        if not fills:
            print(f"  ! {name}: sin paquetes", file=sys.stderr)
            continue
        crafted = kind in CRAFTED
        crates.append({"id": item_id, "name": name, "tier": tier, "kind": (flavor + " " if flavor else "") + kind,
                       "crafted": crafted, "favor": FAVOR[tier][1 if crafted else 0],
                       "guess": tier in FAVOR_GUESS, "level": LEVEL[tier], "fills": fills})
        names[item_id] = name

    out = [
        "-- Generado por tools/gen_crates.py (cliente de WoW Forever, wago.tools DB2). No editar a mano.",
        "-- Waylaid Crates: cada una se llena con UNO de sus paquetes (fills = { { objeto, cantidad } })",
        "-- y se entrega al representante de tu bando por Merchant's Favor (favor; guess = estimado).",
        "local _, ES = ...",
        "ES.Data = ES.Data or {}",
        "ES.Data.ItemNames = ES.Data.ItemNames or {}",
        f"ES.Data.FAVOR_CURRENCY = {CURRENCY}",
        "ES.Data.Crates = {",
    ]
    for c in crates:
        fills = ", ".join(f"{{ {i}, {q} }}" for i, q in c["fills"])
        out.append(f"  {{ id = {c['id']}, tier = {c['tier']}, kind = {lua_str(c['kind'])}, crafted = {str(c['crafted']).lower()}, "
                   f"favor = {c['favor']}{', guess = true' if c['guess'] else ''}, level = {c['level']}, fills = {{ {fills} }} }}, -- {c['name']}")
    out.append("}")
    for i in sorted(names):
        out.append(f"ES.Data.ItemNames[{i}] = ES.Data.ItemNames[{i}] or {lua_str(names[i])}")
    OUT.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    print(f"{OUT.name}: {len(crates)} cajas, {sum(len(c['fills']) for c in crates)} paquetes")


if __name__ == "__main__":
    sys.exit(main())
