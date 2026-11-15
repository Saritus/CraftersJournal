"""Rendimiento con tus datos guardados reales (harness.py): cuánto tarda cada cálculo
que el addon hace en el juego. Lo que se repite solo (al recoger botín, al fabricar,
al abrir el vendedor o la AH) tiene que ser rápido: en el juego un fotograma son
~16 ms y lo que pase de unos pocos ms se nota.
Uso:  python pilot_perf.py
"""
exec(open(__file__.replace("pilot_perf.py", "harness.py"), encoding="utf-8").read())
print(run(r"""
local out = {}
local clock = os.clock
local function T(name, n, fn)
  fn() -- (la primera vez puede preparar cachés: se mide aparte)
  local t0 = clock()
  for _ = 1, n do fn() end
  local ms = (clock() - t0) * 1000 / n
  out[#out+1] = string.format("%-58s %8.2f ms", name, ms)
  return ms
end
local function Cold(name, fn)
  local t0 = clock()
  fn()
  out[#out+1] = string.format("%-58s %8.2f ms", name .. " (en frío)", (clock() - t0) * 1000)
end
-- Ingeniería y Sastrería, como un jugador con dos profesiones de fabricación
local ENG, TAI = ES.Data.Engineering, ES.Data.Tailoring
ES.GetProfessionSkill = function(_, line)
  if line == ENG.skillLine then return 150, 225 end
  if line == TAI.skillLine then return 160, 225 end
end
ES.IsRecipeKnown = function(_, id)
  local r = ENG.recipes[id] or TAI.recipes[id]
  return r ~= nil and (r.fee ~= nil or r.basic) and (r.train or 1) <= 160
end
-- (en el juego el historial de mercado se prepara en segundo plano al entrar y tras
-- cada escaneo, repartido entre fotogramas: aquí, de golpe y aparte)
Cold("Historial de mercado: Market:Index (en el juego, en segundo plano)", function() ES.Market:Index() end)
Cold("Ganar dinero: Earn:Ideas", function() ES.Earn:Clear() ES.Earn:Ideas() end)
T("Ganar dinero: Earn:Ideas (con caché)", 50, function() ES.Earn:Ideas() end)
T("Ganar dinero: Earn:Ideas tras un cambio de bolsas", 10, function() ES.Earn:Clear(true) ES.Earn:Ideas() end)
T("Ganar dinero: Earn:Ideas tras un escaneo o aprender", 3, function() ES.Earn:Clear() ES.Earn:Ideas() end)
-- Bolsas llenas: 80 objetos distintos del escaneo (las de verdad no las ve el harness)
do
  local ids = {}
  for id in pairs(ES.db.scans[ES:RealmKey()].items) do
    ids[#ids + 1] = id
    if #ids >= 80 then break end
  end
  C_Container = C_Container or {}
  C_Container.GetContainerNumSlots = function(bag) return bag <= 4 and 16 or 0 end
  C_Container.GetContainerItemID = function(bag, slot) return ids[bag * 16 + slot] end
  C_Container.GetContainerItemInfo = function(bag, slot)
    local id = ids[bag * 16 + slot]
    return id and { itemID = id, stackCount = 5 } or nil
  end
  local savedCount = ES.ItemCount
  ES.ItemCount = function(_, id) for _, x in ipairs(ids) do if x == id then return 5 end end return 0 end
end
T("Inventario: Inventory:List (80 objetos)", 10, function() ES.Inventory:List() end)
T("Inventario: Sections (ventana de vender y del vendedor)", 10, function() ES.Inventory:Sections() end)
T("Lista de compra: Shopping.Status", 50, function() ES.Shopping.Status() end)
Cold("Merchant's Favor: Favor:Options", function() ES.Favor.Clear() ES.Favor:Options() end)
T("Merchant's Favor: Favor:Options (con caché)", 10, function() ES.Favor:Options() end)
T("Ganar dinero: Earn:Leftovers", 10, function() ES.Earn:Leftovers() end)
T("Avisos de habilidad: ProfessionSkillStamp", 200, function() ES:ProfessionSkillStamp() end)
T("Reputación: RepStamp", 200, function() ES:RepStamp() end)
return table.concat(out, "\n")
"""))
