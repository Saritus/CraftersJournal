"""Ganar dinero: lo intermedio solo con recetas que sabes (Heavy Dynamite, Ingeniería 150).

Reporte de CurseForge: la lista de compra de Heavy Dynamite pedía Heavy Stone en
lugar de Heavy Blasting Powder. Ganar dinero fabricaba lo intermedio con cualquier
receta que pudieras aprender (como las rutas), aunque no la supieras. Con tus datos
guardados reales (harness.py) comprueba:
  - sin saber Heavy Blasting Powder: no se pide Heavy Stone (se compra la pólvora hecha)
  - sabiéndola: si sale más barato, se pide Heavy Stone y el tooltip dice que antes
    hay que fabricar la pólvora
Uso:  python pilot_dynamite.py
"""
exec(open(__file__.replace("pilot_dynamite.py", "harness.py"), encoding="utf-8").read())
print(run(r"""
local out = {}
local function g(c) return string.format("%.2fg", (c or 0) / 10000) end
local ENG = ES.Data.Engineering
local POWDER_RECIPE, STONE, POWDER, DYNAMITE = 3945, 2838, 4377, 4378
ES.GetProfessionSkill = function(_, line)
  if line == ENG.skillLine then return 150, 225 end
end
local knowPowder = true
ES.IsRecipeKnown = function(_, id)
  if id == POWDER_RECIPE then return knowPowder end
  local r = ENG.recipes[id]
  return r ~= nil and (r.fee ~= nil or r.basic) and (r.train or 1) <= 150
end
ES.db.earnMinProfit, ES.db.earnQty = 0, nil
local function Dynamite()
  ES.Earn:Clear()
  local res = ES.Earn:Ideas()
  for _, list in ipairs({ res.batch, res.vendor, res.ideas }) do
    for _, idea in ipairs(list) do if idea.e and idea.e.itemID == DYNAMITE then return idea end end
  end
end
local function Asks(idea, itemID)
  for _, s in ipairs(ES.Earn.Shopping({ idea })) do if s.itemID == itemID then return s.quantity end end
end
-- Sin saber hacer la pólvora: nada de Heavy Stone
knowPowder = false
local idea = Dynamite()
if idea then
  assert(not Asks(idea, STONE), "sin saber Heavy Blasting Powder, la lista pide Heavy Stone")
  for _, a in ipairs(idea.actions or {}) do
    assert(not (a.kind == "craft" and a.item == POWDER), "sin saber Heavy Blasting Powder, se fabrica la pólvora")
  end
  out[#out+1] = string.format("sin saber la pólvora: Heavy Dynamite x%d, compra %s pólvora hecha, sin Heavy Stone",
    idea.crafts or 0, tostring(Asks(idea, POWDER)))
else
  out[#out+1] = "sin saber la pólvora: Heavy Dynamite ya no da beneficio (comprando la pólvora hecha)"
end
-- Sabiéndola: puede pedir Heavy Stone, y el tooltip dice que antes hay que hacer la pólvora
knowPowder = true
idea = Dynamite()
if idea and Asks(idea, STONE) then
  ES:GetMainFrame()
  ES:SelectPage("money")
  ES:RenderEarn()
  local lines = {}
  local savedAL = GameTooltip.AddLine
  GameTooltip.AddLine = function(_, a) lines[#lines + 1] = tostring(a) end
  for _, r in ipairs(ES.earnPage.rows) do
    if r.item == DYNAMITE and r.tooltip then r.tooltip(r) end
  end
  GameTooltip.AddLine = savedAL
  local joined = table.concat(lines, "|")
  assert(joined:find("fabrica tú") or joined:find("Craft these first"), "el tooltip no dice que antes hay que fabricar la pólvora: " .. joined)
  out[#out+1] = string.format("sabiéndola: compra %d Heavy Stone y el tooltip dice que antes fabriques la pólvora", Asks(idea, STONE))
else
  out[#out+1] = "sabiéndola: no pide Heavy Stone con estos precios"
end
return table.concat(out, "\n")
"""))
