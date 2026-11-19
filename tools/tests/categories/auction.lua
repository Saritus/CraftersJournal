-- Casa de Subastas: escanear, precios, historial, compras y vender

local function OpenAH()
  AuctionFrame:Show()
  FireEvent("AUCTION_HOUSE_SHOW")
  RunTimers()
end

test("escaneo completo: guarda el precio por unidad más bajo de cada objeto", function()
  AUCTIONS = {
    { item = 2318, count = 5, buyout = 125, owner = "Ana", tl = 4 },  -- 25 c/u
    { item = 2318, count = 10, buyout = 300, owner = "Pepe", tl = 4 }, -- 30 c/u
    { item = 2589, count = 20, buyout = 400, owner = "Luis", tl = 3 }, -- 20 c/u
    { item = 2589, count = 1, buyout = 18, owner = "Ana", tl = 2 },    -- 18 c/u
  }
  OpenAH()
  ES.Scanner:Start()
  RunTimers()
  expect(not ES.Scanner:IsBusy(), "el escaneo no termina")
  local scan = expect(ES.db.scans[ES:RealmKey()], "no se guardó el escaneo")
  expect_eq(scan.items[2318].minUnit, 25, "Light Leather")
  expect_eq(scan.items[2589].minUnit, 18, "Linen Cloth")
  expect_eq(scan.items[2318].quantity, 15, "Light Leather a la venta")
  expect_eq(scan.items[2589].listings, 2, "subastas de Linen Cloth")
  expect_eq(scan.total, 4, "subastas leídas")
  OpenMain()
end, { state = "empty" })

test("el servidor devuelve 0 subastas: no se borra el escaneo bueno", function()
  local before = ES.db.scans[ES:RealmKey()]
  AUCTIONS = {}
  OpenAH()
  ES.Scanner:Start()
  RunTimers()
  expect(ES.db.scans[ES:RealmKey()] == before, "el escaneo vacío sustituyó al bueno")
end, { state = "scan" })

test("no se escanea dos veces en 15 minutos", function()
  AUCTIONS = { { item = 2318, count = 5, buyout = 125, owner = "Ana", tl = 4 } }
  OpenAH()
  ES.Scanner:Start()
  RunTimers()
  local queried = false
  local saved = QueryAuctionItems
  QueryAuctionItems = function(...) queried = true return saved(...) end
  ES.Scanner:Start()
  expect(not queried, "pidió otra vez antes de 15 min")
  NOW = NOW + 16 * 60
  ES.Scanner:Start()
  expect(queried, "pasados 15 min no deja escanear")
  RunTimers()
  QueryAuctionItems = saved
end, { state = "empty" })

test("historial: tres escaneos y lo que se vendió entre ellos", function()
  local n, comparisons = ES.History:Summary()
  expect_eq(n, 3, "escaneos en el historial")
  expect_eq(comparisons, 2, "comparaciones")
end, { state = "full" })

test("precio de mercado: con un escaneo, el más bajo", function()
  local fp = ES.Market:FairPrice(2318, 25)
  expect(fp and fp.price, "sin precio")
  expect_eq(fp.price, 25, "precio de Light Leather")
  local sig = ES.Market:Signals(2318)
  expect(sig and sig.verdict, "sin veredicto de mercado")
end, { state = "scan" })

test("una compra en la AH cuenta para la lista de compra", function()
  OpenAH()
  ES.ahOpen = true
  ERR_AUCTION_WON_S = "You won an auction for %s"
  local id, n = ES.Ledger.ParseAuctionWon("You won an auction for |cffffffff|Hitem:765::|h[Silverleaf]|h|rx21")
  expect(id == 765 and n == 21, "no lee el mensaje: %s %s", tostring(id), tostring(n))
  FireEvent("CHAT_MSG_SYSTEM", "You won an auction for |cffffffff|Hitem:765::|h[Silverleaf]|h|rx21")
  expect_eq(ES:HaveForShopping(765), 21, "comprado y aún en el correo")
  BAGS[765] = 21
  expect_eq(ES:HaveForShopping(765), 21, "recogido: no cuenta dos veces")
end, { state = "full" })

test("dos compras iguales seguidas cuentan las dos", function()
  OpenAH()
  ES.ahOpen = true
  ERR_AUCTION_WON_S = "You won an auction for %s"
  local msg = "You won an auction for |cffffffff|Hitem:765::|h[Silverleaf]|h|rx5"
  FireEvent("CHAT_MSG_SYSTEM", msg)
  NOW = NOW + 1
  FireEvent("CHAT_MSG_SYSTEM", msg)
  expect_eq(ES:HaveForShopping(765), 10, "dos compras de 5")
end, { state = "full" })

test("al abrir la AH: lista de compra y ventana de vender sin errores", function()
  BAGS[2589], BAGS[2318] = 40, 12
  OpenAH()
  if ES.AuctionSell and ES.AuctionSell.Refresh then ES.AuctionSell:Refresh() end
  local mini = ES.ShoppingMini and ES.ShoppingMini()
  note("lista de compra junto a la AH: %s", mini and tostring(mini:IsShown()) or "no hay")
  AuctionFrame:Hide()
  FireEvent("AUCTION_HOUSE_CLOSED")
  RunTimers()
  expect(not ES.ahOpen, "la AH sigue contando como abierta al cerrarla")
end, { state = "full" })

test("AH neutral: sin soporte, sin errores", function()
  NPC_FACTION = nil
  OpenAH()
  expect(ES.neutralAH, "no detecta la neutral")
  expect(not ES.ahOpen, "la neutral cuenta como AH abierta")
  NPC_FACTION = "Alliance"
end, { state = "scan" })
