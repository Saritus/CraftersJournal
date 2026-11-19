-- Merchant's Favor: con qué llenar cada Waylaid Crate y cuál da el Favor más barato

local function SetPrice(itemID, price, qty)
  qty = qty or 100
  ES.db.scans[ES:RealmKey()].items[itemID] = { listings = 5, quantity = qty, minUnit = price, avgUnit = price,
    sellers = 3, topShare = 0.3, median = price, ladder = { price, qty } }
end

local function Option(list, crateID)
  for _, o in ipairs(list) do if o.crate.id == crateID then return o end end
end

for _, state in ipairs({ "empty", "scan", "full" }) do
  test("la pestaña se abre: " .. state, function()
    OpenPage("favor")
    expect(ES:GetMainFrame().pages.favor:IsShown(), "la página no se ve")
  end, { state = state })
end

test("cada caja: el relleno más barato y las cuentas", function()
  ES.Favor.Clear()
  local list = ES.Favor:Options()
  expect_eq(#list, #ES.Data.Crates, "cajas")
  local prev
  for _, o in ipairs(list) do
    local where = "caja " .. o.crate.id
    for i = 2, #o.fills do
      expect(o.fills[i - 1].cost <= o.fills[i].cost, "%s: rellenos sin ordenar", where)
    end
    if o.fill then
      expect(o.fill == o.fills[1] or (o.fill.have >= o.fill.n and o.fill.cost <= o.fills[1].cost * 1.1),
        "%s: no propone el relleno más barato", where)
      if o.crateCost then
        expect_near(o.total, o.crateCost + o.fill.cost, 0.5, where .. ": total = caja + relleno")
        expect_near(o.perFavor, o.total / o.crate.favor, 0.01, where .. ": por Favor")
      end
    end
    if prev and prev.perFavor and o.perFavor then
      expect(prev.perFavor <= o.perFavor, "%s: el orden no es del Favor más barato al más caro", where)
    end
    if o.perFavor then prev = o end
  end
end)

test("una caja con precios conocidos: la cuenta hecha a mano", function()
  -- Apprentice Ore (248683): 20 Copper Ore o 20 Tin Ore, 5 de Favor. Copper a 30c,
  -- Tin a 100c; la caja a 500c en la AH. Total: 500 + 20 × 30 = 1100; 220 por Favor
  local crate
  for _, c in ipairs(ES.Data.Crates) do if c.id == 248683 then crate = c end end
  expect(crate and crate.favor == 5, "la caja 248683 ya no es como se espera")
  SetPrice(2770, 30)
  SetPrice(2771, 100)
  SetPrice(248683, 500, 10)
  ES.Favor.Clear()
  local o = expect(Option(ES.Favor:Options(), 248683), "no sale la caja")
  expect_eq(o.fill.itemID, 2770, "relleno")
  expect_near(o.fill.cost, 600, 0.5, "relleno: 20 × 30")
  expect_near(o.total, 1100, 0.5, "total")
  expect_near(o.perFavor, 220, 0.01, "por Favor")
end)

test("con el relleno en las bolsas se dice que ya lo tienes", function()
  SetPrice(2770, 30)
  SetPrice(2771, 100)
  BAGS[2771] = 20
  ES.Favor.Clear()
  local o = Option(ES.Favor:Options(), 248683)
  -- Tin cuesta más del 10% que Copper: sigue proponiendo Copper
  expect_eq(o.fill.itemID, 2770, "con Tin en las bolsas pero mucho más caro")
  SetPrice(2771, 32)
  ES.Favor.Clear()
  o = Option(ES.Favor:Options(), 248683)
  expect_eq(o.fill.itemID, 2771, "con Tin en las bolsas y casi igual de caro: el que tienes")
  expect(o.haveFill, "no dice que ya lo tienes")
  OpenPage("favor")
end)

test("el Favor que tienes sale en la página", function()
  FAVOR = 37
  expect_eq(ES.Favor.Balance(), 37, "Favor que tienes")
  OpenPage("favor")
end)
