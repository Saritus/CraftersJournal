"""Rutas: aprender una receta para pocas fabricaciones solo si compensa.

Con tus datos guardados reales (harness.py) y un personaje nuevo (de 1 al objetivo),
cada profesión con y sin la regla (Planner.LEARN_WORTH): cuántos pasos de "aprender
para 1-5 fabricaciones" había, cuántos quedan y cuánto más cuesta la ruta.
Uso:  python pilot_learn_worth.py [Leatherworking ...]
"""
import sys
PROFS = sys.argv[1:] or ["Leatherworking", "Tailoring", "Blacksmithing", "Engineering", "Alchemy", "Enchanting", "Cooking", "FirstAid"]
exec(open(__file__.replace("pilot_learn_worth.py", "harness.py"), encoding="utf-8").read())
print(run(r"""
local out = {}
local function g(c) return string.format("%.2fg", (c or 0) / 10000) end
ES.IsRecipeKnown = function() return false end
ES.GetProfessionSkill = function() return nil end
local function Few(plan)
  local n, names = 0, {}
  for _, st in ipairs(plan.steps) do
    if st.learnSource ~= nil and st.learnSource ~= "known" and (st.crafts or 0) <= ES.Planner.LEARN_FEW_CRAFTS then
      n = n + 1
      names[#names + 1] = string.format("%s %d-%d (%.0f fab.)", st.recipe and st.recipe.name or st.id, st.from, st.to, st.crafts)
    end
  end
  return n, table.concat(names, ", ")
end
local saved = ES.Planner.LEARN_WORTH
for _, key in ipairs({ PROFS }) do
  local data = ES.Data[key]
  local opts = ES:PlanOptions(key, 1, 300)
  opts.owned = nil
  ES.Planner.SetLearnWorth(0)
  local before = ES.Planner:Plan(data, opts)
  ES.Planner.SetLearnWorth(saved)
  local after = ES.Planner:Plan(data, opts)
  local nb, wb = Few(before)
  local na, wa = Few(after)
  out[#out+1] = string.format("%-15s pasos %2d -> %2d · aprender para pocas: %d -> %d · coste %s -> %s (%+.2fg)",
    key, #before.steps, #after.steps, nb, na, g(before.net), g(after.net), (after.net - before.net) / 10000)
  if nb > 0 then out[#out+1] = "    antes: " .. wb end
  if na > 0 then out[#out+1] = "    quedan (compensan): " .. wa end
end
-- El caso que se comprueba: Peletería 50-150, Hillman's Leather Vest 102-105 (4
-- fabricaciones, patrón de la AH). Con la regla (5s) se queda: hacer esos puntos con
-- Cured Medium Hide cuesta ~28s más. Con un umbral de 50s, se cambia por ella
do
  local opts = ES:PlanOptions("Leatherworking", 50, 150)
  opts.owned = nil
  local function Has(p, name) for _, st in ipairs(p.steps) do if st.recipe.name == name then return true end end end
  ES.Planner.SetLearnWorth(saved)
  local keep = ES.Planner:Plan(ES.Data.Leatherworking, opts)
  ES.Planner.SetLearnWorth(5000)
  local merged = ES.Planner:Plan(ES.Data.Leatherworking, opts)
  ES.Planner.SetLearnWorth(saved)
  if Has(keep, "Hillman's Leather Vest") then
    assert(not Has(merged, "Hillman's Leather Vest"), "con un umbral de 50s, el paso de 4 fabricaciones no se quitó")
    out[#out+1] = "Peletería 50-150: Hillman's Leather Vest (4 fab.) se queda con 5s (ahorra más) y se quita con 50s: OK"
  else
    out[#out+1] = "Peletería 50-150: con estos precios ya no sale Hillman's Leather Vest (sin comprobar)"
  end
end
return table.concat(out, "\n")
""".replace("{ PROFS }", "{ " + ", ".join('"%s"' % p for p in PROFS) + " }")))
