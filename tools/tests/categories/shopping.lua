-- Lista de compra: lo que pide la ruta empezada y lo que añades desde Ganar dinero o
-- la Calculadora; lo que llevas en las bolsas se descuenta al enseñarla

local function ItemsOf(status, kind)
  local out = {}
  for _, s in ipairs(status.lists) do
    if not kind or s.list.kind == kind then
      for _, e in ipairs(s.items) do out[e.it.itemID] = e end
    end
  end
  return out
end

for _, state in ipairs({ "empty", "scan", "full" }) do
  test("la pestaña se abre: " .. state, function()
    OpenPage("shopping")
    expect(ES:GetMainFrame().pages.shopping:IsShown(), "la página no se ve")
  end, { state = state })
end

test("lista añadida: pide solo lo que falta con lo que llevas", function()
  -- (datos completos: una lista con 10 Light Leather y 20 Linen Cloth; en las bolsas
  -- 4 Light Leather y 30 Linen Cloth)
  local items = ItemsOf(ES.Shopping.Status(), "money")
  local leather, linen = expect(items[2318], "falta Light Leather"), expect(items[2589], "falta Linen Cloth")
  expect_eq(leather.bought, 4, "Light Leather que llevas")
  expect_eq(leather.left, 6, "Light Leather que falta")
  expect_eq(linen.left, 0, "Linen Cloth que falta (llevas de sobra)")
  local id, n = ES.Shopping.NextToBuy(ES.Shopping.Status())
  expect_eq(id, 2318, "lo siguiente que comprar")
  expect_eq(n, 6, "cuántas")
  OpenPage("shopping")
end, { state = "full" })

test("añadir lo mismo dos veces lo junta", function()
  local list = ES.Shopping.Add("calc", "x", {
    { itemID = 2592, quantity = 3, unit = 40, source = "ah" },
    { itemID = 2592, quantity = 2, unit = 40, source = "ah" },
    { itemID = 2589, quantity = 5, unit = 15, source = "craft" }, -- (lo que se fabrica no se compra)
  })
  expect_eq(#list.items, 1, "materiales en la lista")
  expect_eq(list.items[1].need, 5, "Wool Cloth juntado")
  expect_eq(list.items[1].unit, 40, "precio por unidad")
  expect_eq(ES.Shopping.Add("calc", "nada", { { itemID = 2592, quantity = 0 } }), nil, "una lista vacía no se añade")
end, { state = "full" })

test("añadir con la misma clave sustituye la anterior", function()
  ES.Shopping.Add("calc", "uno", { { itemID = 2592, quantity = 3, unit = 40 } }, { key = 7 })
  ES.Shopping.Add("calc", "dos", { { itemID = 2592, quantity = 9, unit = 40 } }, { key = 7 })
  local n, need = 0, nil
  for _, l in ipairs(ES.Shopping.Lists()) do if l.kind == "calc" and l.key == 7 then n = n + 1 need = l.items[1].need end end
  expect_eq(n, 1, "listas con la misma clave")
  expect_eq(need, 9, "la nueva")
end, { state = "full" })

test("Ganar dinero añade a la lista lo que compra el lote", function()
  ES.db.earnMinProfit = 1
  ES.Earn:Clear()
  local res = ES.Earn:Ideas()
  expect(#res.batch > 0, "sin lote")
  local shopping = res.shopping
  expect(shopping and #shopping > 0, "el lote no compra nada")
  local total = 0
  for _, it in ipairs(shopping) do
    expect(it.itemID and (it.quantity or it.need or 0) > 0, "material sin cantidad")
    total = total + (it.quantity or it.need)
  end
  note("el lote compra %d materiales (%d unidades)", #shopping, total)
end, { state = "full" })

test("ruta empezada: su lista sale sola y descuenta las bolsas", function()
  local page, plan = StartRoute("Tailoring", 1, 75)
  local status = ES.Shopping.Status()
  local items = ItemsOf(status, "phase")
  local first = next(items)
  expect(first, "la ruta empezada no tiene lista")
  local e = items[first]
  local need = e.it.need
  -- Con la mitad en las bolsas, falta la otra mitad
  BAGS[first] = math.floor(need / 2)
  ES.Earn:Clear()
  items = ItemsOf(ES.Shopping.Status(), "phase")
  expect_eq(items[first].left, need - math.floor(need / 2), "lo que falta con la mitad en las bolsas")
  note("material %d: pide %d, llevas %d", first, need, math.floor(need / 2))
  OpenPage("shopping")
end, { state = "scan" })

test("ruta acabada: su lista guardada se quita sola", function()
  local list = ES.Shopping.Add("route", "vieja", { { itemID = 2589, quantity = 5, unit = 15 } }, { key = "Tailoring" })
  expect(list, "no se añadió")
  SKILLS[ES.Data.Tailoring.skillLine] = { 300, 300 }
  ES.Shopping.Status()
  for _, l in ipairs(ES.Shopping.Lists()) do expect(not (l.kind == "route" and l.key == "Tailoring"), "la lista de la ruta acabada sigue") end
end, { state = "full" })
