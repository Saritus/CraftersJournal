-- Inventario: qué vender de tus bolsas, dónde (vendedor o AH) y qué guardar

local function Entry(list, itemID)
  for _, e in ipairs(list) do if e.itemID == itemID then return e end end
end

for _, state in ipairs({ "empty", "scan", "full" }) do
  test("la pestaña se abre: " .. state, function()
    BAGS[2589], BAGS[2318], BAGS[4306] = 12, 5, 3
    OpenPage("inventory")
    expect(ES:GetMainFrame().pages.inventory:IsShown(), "la página no se ve")
  end, { state = state })
end

test("cada objeto: lo que se guarda y lo que se vende suman lo que llevas", function()
  BAGS[2589], BAGS[2318], BAGS[2592], BAGS[4306], BAGS[2934], BAGS[2320] = 40, 12, 20, 7, 30, 5
  local list = ES.Inventory:List()
  expect(#list > 0, "no propone nada")
  for _, e in ipairs(list) do
    local where = "objeto " .. e.itemID
    local sold = (e.vendorN or 0) + (e.ahN or 0) + (e.ahLater or 0)
    expect(e.keep >= 0 and e.keep <= e.count, "%s: guarda %s de %s", where, tostring(e.keep), tostring(e.count))
    expect(sold <= e.count - e.keep, "%s: vende %d y guarda %d de %d", where, sold, e.keep, e.count)
    expect_near(e.value, (e.ahN or 0) * (e.ahUnit or 0) + (e.vendorN or 0) * (e.vendorUnit or 0), 0.5, where .. ": valor")
    expect_finite(e.value, where .. ": valor")
  end
  note("%d objetos en la lista", #list)
end)

test("lo que marcas para no vender nunca se guarda entero", function()
  BAGS[2318] = 12
  ES.Inventory.SetNeverSell(2318, true)
  local e = expect(Entry(ES.Inventory:List(), 2318), "Light Leather no sale en la lista")
  expect_eq(e.keep, 12, "Light Leather guardada")
  expect_eq(e.vendorN + e.ahN + (e.ahLater or 0), 0, "Light Leather vendida")
end)

test("lo gris va siempre al vendedor", function()
  BAGS[4306] = 7
  BAG_FLAGS[4306] = { quality = 0 }
  local e = expect(Entry(ES.Inventory:List(), 4306), "no sale en la lista")
  expect_eq(e.ahN, 0, "a la AH")
  expect_eq(e.vendorN, 7, "al vendedor")
end)

test("sin precio de la AH: al vendedor, y lo dice", function()
  BAGS[4306] = 7
  ES.db.scans[ES:RealmKey()].items[4306] = nil
  local e = expect(Entry(ES.Inventory:List(), 4306), "no sale en la lista")
  expect(e.noAH, "no dice que no hay precio de la AH")
  expect_eq(e.vendorN, 7, "al vendedor")
end)

test("lo que pide tu ruta empezada se guarda", function()
  local page, plan = StartRoute("Tailoring", 1, 75)
  local need = ES.Planner.RouteNeed("Tailoring", plan, 1, { keep = true })
  local itemID, n = next(need)
  expect(itemID, "la ruta no pide nada")
  BAGS[itemID] = n.need + 3
  local e = expect(Entry(ES.Inventory:List(), itemID), "el material no sale en la lista")
  expect(e.keep >= math.ceil(n.need - 0.001), "guarda %d y la ruta pide %s", e.keep, tostring(n.need))
end)

test("vender al vendedor: con él abierto, el botón vende lo de esa sección", function()
  BAGS[4306] = 7
  BAG_FLAGS[4306] = { quality = 0 }
  OpenPage("inventory")
  OpenMerchant({})
  local sec = ES.Inventory:Sections()
  expect(sec.vendor and #sec.vendor > 0, "nada que vender al vendedor")
  ES.VendorShop:Sell(ES.VendorShop:SellList())
  RunTimers()
  expect(BAGS[4306] == 0, "no se vendió el gris (quedan %s)", tostring(BAGS[4306]))
end)
