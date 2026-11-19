-- Datos de prueba fijos: lo guardado en tres estados y los precios de la AH.
--   Fixtures.State("empty")  usuario nuevo: nada guardado, sin escaneo
--   Fixtures.State("scan")   un escaneo de la AH y nada más
--   Fixtures.State("full")   escaneo, recetas aprendidas, profesiones con nivel,
--                            cálculos, y tras arrancar: historial y lista de compra
--
-- Los precios no se escriben a mano para miles de objetos: salen de una regla fija por
-- objeto (Fixtures.Price). Unos pocos tienen precio a mano (Fixtures.FIXED) para las
-- cuentas que las pruebas comprueban "como hechas a mano".

Fixtures = {}

-- Precios a mano (cobre por unidad)
Fixtures.FIXED = {
  [2318] = 25,    -- Light Leather
  [2319] = 60,    -- Medium Leather
  [2589] = 15,    -- Linen Cloth
  [2592] = 40,    -- Wool Cloth
  [2770] = 30,    -- Copper Ore
  [2840] = 50,    -- Copper Bar
  [765] = 20,     -- Silverleaf
  [2447] = 25,    -- Peacebloom
  [2672] = 30,    -- Stringy Wolf Meat
}

-- Regla fija: más caro que el vendedor (así el vendedor sale mejor cuando vende el
-- objeto), y si no lo vende, a partir de lo que paga el vendedor por él, o del número
-- del objeto. Siempre un entero > 0
function Fixtures.Price(itemID)
  local fixed = Fixtures.FIXED[itemID]
  if fixed then return fixed end
  local D = ES.Data
  local vendor = D.VendorPrices and D.VendorPrices[itemID]
  if vendor and vendor > 0 then return math.ceil(vendor * 1.25) + 1 end
  local sell = D.SellPrices and D.SellPrices[itemID]
  if sell and sell > 0 then return sell * 3 + (itemID % 50) end
  return 20 + (itemID % 89) * 7
end

-- Objetos con precio en el escaneo: materiales y resultados de todas las recetas y
-- lo que llena las cajas de Merchant's Favor
function Fixtures.ScannedItems()
  local set = {}
  for _, key in ipairs(ProfessionKeys()) do
    local data = ES.Data[key]
    for _, r in pairs(data and data.recipes or {}) do
      for _, mat in ipairs(r.r or {}) do set[mat[1]] = true end
      if r.out then set[r.out[1]] = true end
    end
  end
  for _, crate in ipairs(ES.Data.Crates or {}) do
    for _, fill in ipairs(crate.fills or {}) do set[fill[1]] = true end
  end
  local ids = {}
  for id in pairs(set) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

-- Un escaneo de la AH con la forma que guarda Scanner:Finish
function Fixtures.Scan(when)
  local items, total = {}, 0
  for _, id in ipairs(Fixtures.ScannedItems()) do
    local p = Fixtures.Price(id)
    local qty = 20 + (id % 7) * 10
    items[id] = {
      listings = 4, quantity = qty, minUnit = p, avgUnit = math.floor(p * 1.1 + 0.5),
      sellers = 3, topShare = 0.4, median = math.floor(p * 1.05 + 0.5),
      ladder = { p, math.floor(qty / 2), math.floor(p * 1.2 + 0.5), qty - math.floor(qty / 2) },
    }
    total = total + 4
  end
  local n = 0
  for _ in pairs(items) do n = n + 1 end
  return { time = when or (NOW - 600), total = total, unique = n, items = items }
end

local function RealmKey() return REALM .. "-" .. FACTION end
local function CharKey() return "Bruno-" .. REALM end

-- Las primeras recetas (por nivel naranja) de una profesión
local function FirstRecipes(profKey, n)
  local list = {}
  for id, r in pairs(ES.Data[profKey].recipes) do list[#list + 1] = { id = id, t = r.t[1] } end
  table.sort(list, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.id < b.id end)
  local out = {}
  for i = 1, math.min(n, #list) do out[i] = list[i].id end
  return out
end

-- Niveles de profesión del estado "full" (el resto no las tiene)
Fixtures.FULL_SKILLS = { Leatherworking = { 120, 150 }, Tailoring = { 80, 150 }, Cooking = { 180, 225 } }

function Fixtures.State(name)
  if name == "empty" then return nil end
  local db = { scans = { [RealmKey()] = Fixtures.Scan() } }
  if name == "scan" then return db end
  assert(name == "full", "estado desconocido: " .. tostring(name))
  db.known = { [CharKey()] = {} }
  for prof, s in pairs(Fixtures.FULL_SKILLS) do
    SKILLS[ES.Data[prof].skillLine] = { s[1], s[2] }
    local ids = FirstRecipes(prof, 12)
    db.known[CharKey()][prof] = ids
    for _, id in ipairs(ids) do KNOWN_SPELLS[id] = true end
  end
  db.neverSell = { [2318] = true }
  db.lang = "es"
  return db
end

-- Lo que se monta con el addon ya arrancado (usa sus propias funciones)
function Fixtures.After(name)
  if name ~= "full" then return end
  local key = ES:RealmKey()
  -- Historial: tres escaneos, una hora entre cada uno, con ventas de por medio
  local S = ES.History
  local function sigs(list)
    local t = {}
    for _, a in ipairs(list) do S.AddAuction(t, S.Signature(a[1], a[2], a[3], a[4]), a[5]) end
    return t
  end
  local base = NOW - 3 * 3600
  for step, left in ipairs({ 10, 6, 4 }) do
    local a = {}
    for _ = 1, left do a[#a + 1] = { 2318, 5, 125, "Ana", 4 } end
    S:Record(key, sigs(a), ";2318:25:" .. left, base + step * 3600)
  end
  -- Una lista de la compra (como la que añade Ganar dinero)
  ES.Shopping.Add("money", "Prueba", {
    { itemID = 2318, quantity = 10, unit = 25, source = "ah" },
    { itemID = 2589, quantity = 20, unit = 15, source = "ah" },
  })
  -- Bolsas con algo de todo
  BAGS[2318], BAGS[2589], BAGS[2592] = 4, 30, 12
end
