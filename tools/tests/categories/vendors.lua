-- Vendedores e instructores: comprar justo lo que falta y aprender con un clic

-- Un material de la lista de compra (la de la ruta entera) que se compra al vendedor
local function VendorMaterial()
  local best
  for _, s in ipairs(ES.Shopping.Status().lists) do
    for _, e in ipairs(s.items) do
      if e.it.source == "vendor" and (not best or e.it.itemID < best) then best = e.it.itemID end
    end
  end
  return best
end

-- La ruta de Sastrería de 1 a 125, con la lista de la ruta entera (no por tramos)
local function TailoringRoute()
  ES.db.prof.Tailoring = ES.db.prof.Tailoring or {}
  ES.db.prof.Tailoring.byPhase = false
  return StartRoute("Tailoring", 1, 125)
end

test("vendedor abierto sin ruta: ventana sin errores", function()
  OpenMerchant({ { item = 2320, price = 10 }, { item = 2324, price = 25 } })
  ES.VendorShop:Refresh()
  expect_eq(#ES.VendorShop:List(), 0, "sin ruta ni lista no hay nada que comprar")
  CloseMerchant()
end, { state = "scan" })

test("vendedor abierto: ofrece justo lo que falta y lo compra", function()
  TailoringRoute()
  local itemID = VendorMaterial()
  expect(itemID, "la ruta de Sastrería no pide nada de vendedor")
  local list
  OpenMerchant({ { item = itemID, price = ES.Data.VendorPrices[itemID] } })
  list = ES.VendorShop:List()
  local e = expect(list[1], "el vendedor no ofrece %d", itemID)
  expect_eq(e.itemID, itemID, "material")
  BAGS[itemID] = 1
  list = ES.VendorShop:List()
  e = list[1]
  expect_eq(e.qty, e.need - 1, "con 1 en las bolsas, lo que falta")
  ES.VendorShop:Buy(e)
  RunTimers()
  expect_eq(BAGS[itemID], e.need, "unidades tras comprar")
  local again = ES.VendorShop:List()[1]
  expect_eq(again and again.qty, 0, "tras comprar ya no falta nada")
  note("material %d: pedía %d", itemID, e.need)
end, { state = "scan" })

test("vendedor que vende por lotes: compra lotes enteros", function()
  TailoringRoute()
  local itemID = VendorMaterial()
  expect(itemID, "sin material de vendedor")
  OpenMerchant({ { item = itemID, price = 50, batch = 5 } })
  local e = expect(ES.VendorShop:List()[1], "no lo ofrece")
  expect_eq(e.qty % 5, 0, "lotes de 5")
  expect(e.qty >= e.need, "compra %d y faltan %d", e.qty, e.need)
end, { state = "scan" })

test("instructor abierto: apunta los precios que enseña", function()
  -- Un instructor de Sastrería con dos recetas de los datos
  local recipes = {}
  for id, r in pairs(ES.Data.Tailoring.recipes) do
    if r.fee and #recipes < 2 then recipes[#recipes + 1] = { id = id, r = r } end
  end
  local services = {}
  for i, x in ipairs(recipes) do
    services[i] = { name = x.r.nameEN or x.r.name, kind = "available", cost = 1234 + i, skill = x.r.train or 1, spell = x.id }
  end
  GetNumTrainerServices = function() return #services end
  GetTrainerServiceInfo = function(i) local s = services[i] return s.name, "", s.kind end
  GetTrainerServiceCost = function(i) return services[i].cost end
  GetTrainerServiceSkillReq = function(i) return "Tailoring", services[i].skill, true end
  GetTrainerServiceSkillLine = function() return ES:ProfLabel("Tailoring") end -- (en el idioma del cliente)
  GetTrainerServiceItemLink = function() return nil end
  GetTrainerServiceLink = function(i) return "|Hspell:" .. services[i].spell .. "|h[x]|h" end
  GetTrainerServiceTypeFilter = function() return true end
  SetTrainerServiceTypeFilter = function() end
  FireEvent("TRAINER_SHOW")
  RunTimers()
  local fees = ES.db.trainerFees or {}
  local seen = 0
  for _, x in ipairs(recipes) do if fees[x.id] then seen = seen + 1 end end
  note("precios apuntados: %d de %d", seen, #recipes)
  expect_eq(seen, #recipes, "recetas con el precio del instructor")
  FireEvent("TRAINER_CLOSED")
end, { state = "scan" })
