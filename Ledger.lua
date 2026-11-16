local _, ES = ...
local L = ES.L

-- Lo que el addon lee del juego al comprar, vender y entrenar (sin apuntar dinero:
-- el gasto real de la ruta se quitó porque se apuntaba mal con varias rutas):
--   (lo comprado en la AH no se sigue hasta el buzón: "tienes" son solo tus bolsas)
--   instructor: el precio real de cada receta (Ledger:ReadTrainer, Planner.Fee)
--   vendedor: qué vende y a cuánto (la ventana de compra de VendorUI.lua)
-- Vender al vendedor y anunciar en la AH desde la vista Profit: siempre con un
-- clic del jugador que dice exactamente qué va a hacer. El addon no compra ni
-- vende nada sin ese clic.

local Ledger = {}
ES.Ledger = Ledger

-- Diario de lo que lee (para diagnosticar en el juego): ES.db.ledgerLog
local function Log(text)
  ES.db.ledgerLog = ES.db.ledgerLog or {}
  local log = ES.db.ledgerLog
  log[#log + 1] = (date and date("%H:%M:%S ") or "") .. text
  while #log > 60 do table.remove(log, 1) end
end
Ledger.Log = Log

-- Funciones de las bolsas: C_Container (cliente moderno) o las de siempre. Se buscan
-- al usarlas, no al cargar (así también valen las de las pruebas)
local function CC(name) return (C_Container and C_Container[name]) or _G[name] end
local function NumSlots(bag) local f = CC("GetContainerNumSlots") return f and f(bag) or 0 end
local function ContainerItemID(bag, slot) local f = CC("GetContainerItemID") return f and f(bag, slot) end
local function UseItem(bag, slot) local f = CC("UseContainerItem") if f then f(bag, slot) end end

-- Una casilla libre en una bolsa normal (no de hierbas, de encantamiento...): bag, slot
local function EmptySlot()
  local free = CC("GetContainerNumFreeSlots")
  for bag = 0, 4 do
    local n, family = 1, 0
    if free then n, family = free(bag) end
    if (n or 0) > 0 and (family or 0) == 0 then
      for slot = 1, NumSlots(bag) do
        if not ContainerItemID(bag, slot) then return bag, slot end
      end
    end
  end
end

-- Unidades de un objeto en una casilla de las bolsas
local function SlotCount(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    return info and info.stackCount or 0
  end
  local _, count = GetContainerItemInfo(bag, slot)
  return count or 0
end

-- Casillas de las bolsas (no el banco) con este objeto: { {bag, slot, count} }
local function Slots(itemID)
  local list = {}
  for bag = 0, 4 do
    for slot = 1, NumSlots(bag) or 0 do
      if ContainerItemID(bag, slot) == itemID then
        list[#list + 1] = { bag = bag, slot = slot, count = SlotCount(bag, slot) }
      end
    end
  end
  return list
end

local function BagCount(itemID)
  local n = 0
  for _, s in ipairs(Slots(itemID)) do n = n + s.count end
  return n
end
Ledger.BagCount = BagCount

-- Profesión del instructor abierto (por la línea de habilidad de lo que enseña), o nil
local PROF_SPELLS = { Alchemy = 2259, Blacksmithing = 2018, Enchanting = 7411, Engineering = 4036,
  Leatherworking = 2108, Tailoring = 3908, Cooking = 2550, FirstAid = 3273 }
local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return GetSpellInfo and (GetSpellInfo(id))
end
local function TrainerProfession()
  if not (GetNumTrainerServices and GetTrainerServiceSkillLine) then return nil end
  for i = 1, GetNumTrainerServices() or 0 do
    local line = GetTrainerServiceSkillLine(i)
    if line and line ~= "" then
      for key, spell in pairs(PROF_SPELLS) do
        if line == SpellName(spell) or line == ES:ProfLabel(key) then return key end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Precios reales del instructor: al abrirlo se lee lo que cobra y el nivel que pide
-- por cada receta y se guarda en CraftersJournalDB.trainerFees[spellID] =
-- { cost, skill, rep, time }. Forever ha cambiado precios y tiene recetas nuevas
-- sin precio conocido: lo visto en el juego manda sobre los datos (Planner.Fee)
---------------------------------------------------------------------------
-- Descuento del instructor por reputación (UnitReaction: 5 amistoso ... 8 exaltado)
local REP_DISCOUNT = { [5] = 0.05, [6] = 0.10, [7] = 0.15, [8] = 0.20 }

-- Precio sin el descuento de reputación (el que vale para todos)
local function BaseCost(seen)
  local d = REP_DISCOUNT[seen.rep or 0]
  return d and math.floor(seen.cost / (1 - d) + 0.5) or seen.cost
end
Ledger.BaseCost = BaseCost

-- Receta de la casilla `i` del instructor: por enlace (hechizo/encantamiento u objeto
-- fabricado) o por nombre (el del juego, en su idioma). `exact`: el instructor no es de
-- una profesión del addon (minería...): solo por el hechizo. Por el objeto, "Smelt
-- Gold" (Minería 155, Gold Bar) se tomaba por Transmute: Iron to Gold y la ruta la
-- aprendía a 155 (Discord: pide 225)
local function ServiceRecipe(i, profs, exact)
  local link = GetTrainerServiceItemLink and GetTrainerServiceItemLink(i)
  local spell = link and tonumber(link:match("spell:(%d+)") or link:match("enchant:(%d+)"))
  local item = link and tonumber(link:match("item:(%d+)"))
  local name = GetTrainerServiceInfo and (GetTrainerServiceInfo(i))
  -- (el instructor habla el idioma del cliente, no el del addon)
  local set = ES.NamesFor(ES.DefaultLanguage())
  local names = set and set.spells or {}
  local byName = {}
  for _, key in ipairs(profs) do
    for id, r in pairs(ES.Data[key].recipes) do
      if spell == id then return id, r, key end
      if exact then -- (solo el hechizo: ver arriba)
      elseif item and r.out and r.out[1] == item then return id, r, key
      elseif name and (name == r.name or name == r.nameEN or name == names[id] or name == SpellName(id)) then
        byName[#byName + 1] = { id, r, key }
      end
    end
  end
  if #byName == 1 then return unpack(byName[1]) end -- con dos del mismo nombre no se adivina
end

-- La lista del instructor sigue sus filtros (disponibles / no disponibles / ya
-- sabidas): al abrirlo se muestran todos un momento para leer todas sus recetas y
-- se dejan como estaban. Solo al abrirlo (TRAINER_SHOW): cambiar un filtro lanza
-- TRAINER_UPDATE, que lee sin tocarlos (así no se repite sin fin)
local FILTERS = { "available", "unavailable", "used" }
-- Una vez: fuera lo leído de un instructor con un nivel menor que el de los datos del
-- juego. Son lecturas equivocadas de antes de ServiceRecipe(exact): un instructor de
-- minería apuntaba Smelt Gold (155, su precio) como Transmute: Iron to Gold. Se
-- vuelven a leer bien la próxima vez que abras el instructor de la profesión
function Ledger:CleanTrainerFees()
  local db = ES.db
  if not db or db.trainerFeesChecked or type(db.trainerFees) ~= "table" then
    if db then db.trainerFeesChecked = true end
    return 0
  end
  db.trainerFeesChecked = true
  local removed = 0
  for id, seen in pairs(db.trainerFees) do
    for _, p in ipairs(ES.PROFESSIONS or {}) do
      local r = ES.Data[p.key] and ES.Data[p.key].recipes and ES.Data[p.key].recipes[id]
      if r then
        if type(seen) == "table" and seen.skill and r.train and seen.skill < r.train then
          db.trainerFees[id] = nil
          removed = removed + 1
        end
        break
      end
    end
  end
  return removed
end

function Ledger:ReadAllTrainerServices()
  if not (GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter) then return self:ReadTrainer() end
  local hidden = {}
  for _, f in ipairs(FILTERS) do
    if not GetTrainerServiceTypeFilter(f) then
      hidden[#hidden + 1] = f
      SetTrainerServiceTypeFilter(f, 1)
    end
  end
  self.fullList = true -- (la lista entera: lo que no sale, este instructor no lo enseña)
  local ok, changed = pcall(self.ReadTrainer, self)
  self.fullList = nil
  for _, f in ipairs(hidden) do SetTrainerServiceTypeFilter(f, 0) end
  if not ok then error(changed, 0) end
  return changed
end

function Ledger:ReadTrainer()
  if not (ES.db and GetNumTrainerServices and GetTrainerServiceCost) then return 0 end
  local prof = TrainerProfession()
  local profs = {}
  if prof then
    profs[1] = ES.Data[prof] and ES.Data[prof].recipes and prof or nil
  else
    for _, p in ipairs(ES.PROFESSIONS or {}) do
      if ES.Data[p.key] and ES.Data[p.key].recipes then profs[#profs + 1] = p.key end
    end
  end
  if #profs == 0 then return 0 end
  ES.db.trainerFees = ES.db.trainerFees or {}
  local rep = UnitReaction and UnitReaction("npc", "player") or nil
  local changed = 0
  local changedProfs = {}
  local listed, top, low = {}, 0, math.huge
  local guid = UnitGUID and UnitGUID("npc")
  local npc = guid and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
  for i = 1, GetNumTrainerServices() or 0 do
    local kind = GetTrainerServiceInfo and select(3, GetTrainerServiceInfo(i))
    if kind ~= "header" then
      local id, r, key = ServiceRecipe(i, profs, prof == nil) -- (sin profesión conocida: solo por el hechizo)
      local cost = id and GetTrainerServiceCost(i)
      if cost then
        local skill = GetTrainerServiceSkillReq and select(2, GetTrainerServiceSkillReq(i))
        local old = ES.db.trainerFees[id]
        if not old or old.cost ~= cost or old.skill ~= skill or old.rep ~= rep then
          changed = changed + 1
          changedProfs[key] = true
        end
        -- (npc: el instructor donde se vio, para llevarte a él: Forever enseña algunas
        -- solo en sitios concretos, como Stranglethorn)
        ES.db.trainerFees[id] = { cost = cost, skill = skill, rep = rep, prof = key, time = time(), npc = npc or (old and old.npc) }
        listed[id] = true
        if skill and skill > 0 then
          top = math.max(top, skill)
          low = math.min(low, skill)
        end
      end
    end
  end
  -- Recetas de instructor de los datos que no enseña ningún instructor visto (con su
  -- lista entera a la vista): Forever ha quitado o movido algunas (Green Iron
  -- Leggings) y la ruta pedía aprender algo que tu instructor no tiene. Solo dentro
  -- del tramo de niveles que enseña cada instructor visto (en Forever cada rango
  -- tiene los suyos: uno de Experto no dice nada de las de Oficial). Si otro
  -- instructor la enseña (en Stranglethorn, por ejemplo), vuelve
  if self.fullList and prof and top > 0 then
    local seen = ES.db.trainerListed or {}
    ES.db.trainerListed = seen
    seen[prof] = seen[prof] or { ranges = {}, ids = {} }
    local s = seen[prof]
    s.ranges = s.ranges or {}
    local key = low .. "-" .. top
    s.ranges[key] = { low, top }
    for id in pairs(listed) do s.ids[id] = true end
    -- "rank": el instructor de su rango no la tiene; Forever ha subido algunas al
    -- rango siguiente (Green Iron Leggings, de 130, la enseña el de Experto: Bengus
    -- Deepforge), así que la fila Entrenar lleva a ese. "gone": tampoco está en un
    -- instructor de más nivel que hayas visto: no se enseña, fuera de las rutas
    local function Covered(level)
      for _, rg in pairs(s.ranges) do
        if level >= rg[1] and level <= rg[2] then return true end
      end
      return false
    end
    local function Above(level)
      for _, rg in pairs(s.ranges) do
        if rg[1] > level then return true end
      end
      return false
    end
    ES.db.trainerMissing = ES.db.trainerMissing or {}
    local missing = ES.db.trainerMissing
    for id, r in pairs(ES.Data[prof].recipes) do
      local trainerRecipe = (r.fee or r.trainer) and not r.scroll and not r.basic and not r.favor
      local level = r.train or 0
      local now = trainerRecipe and not s.ids[id] and Covered(level) and (Above(level) and "gone" or "rank") or nil
      if missing[id] ~= now then
        missing[id] = now
        changed = changed + 1
        changedProfs[prof] = true
      end
    end
    -- Tu ruta empezada pasa por una de ellas (aún no la has hecho): ya no se puede
    -- seguir; se suelta y se calcula otra desde tu nivel
    local lock = ES.RouteLock and ES:RouteLock(prof)
    if lock and lock.choice then
      local skill = ES:GetProfessionSkill(ES.Data[prof].skillLine) or lock.from
      for s, id in pairs(lock.choice) do
        if s >= skill and missing[id] == "gone" and not (ES.IsRecipeKnown and ES:IsRecipeKnown(id)) then
          ES:StopRoute(prof)
          ES:Print(string.format(L["Tu ruta de %s usaba %s, que este instructor no enseña: se calcula otra desde tu nivel."],
            ES:ProfLabel(prof), ES.Data[prof].recipes[id].name))
          changedProfs[prof] = true
          changed = changed + 1
          break
        end
      end
    end
  end
  if changed > 0 then
    Log(string.format("instructor%s: %d precios nuevos o cambiados", prof and (" de " .. prof) or "", changed))
    -- Las rutas de esas profesiones se rehacen con el precio real, también la fijada:
    -- el precio del instructor es un dato, no un precio de mercado (sus recetas no
    -- cambian, solo lo que cuesta aprenderlas)
    for key in pairs(changedProfs) do
      if ES.InvalidatePlan then ES:InvalidatePlan(key) end
      if ES.lockedPlans then ES.lockedPlans[key] = nil end
    end
    if ES.RefreshProfessionPages then ES:RefreshProfessionPages() end
  end
  return changed
end

---------------------------------------------------------------------------
-- Vendedor abierto: qué vende y a cuánto (VendorUI.lua)
---------------------------------------------------------------------------
-- Objeto de la casilla `i` del vendedor abierto
local function MerchantItemID(i)
  local id = GetMerchantItemID and GetMerchantItemID(i)
  if not id and GetMerchantItemLink then
    local link = GetMerchantItemLink(i)
    id = link and tonumber(link:match("item:(%d+)"))
  end
  return id
end
Ledger.MerchantItemID = MerchantItemID

-- Precio, cuántos vienen por compra, cuántos quedan (-1 sin límite), si se compra con
-- oro. Forever (cliente moderno) usa C_MerchantFrame.GetItemInfo; el clásico, GetMerchantItemInfo
local function MerchantInfo(i)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    local info = C_MerchantFrame.GetItemInfo(i)
    if info then
      return info.price, info.stackCount, info.numAvailable, info.isPurchasable ~= false and not info.hasExtendedCost
    end
  elseif GetMerchantItemInfo then
    local _, _, price, stack, avail, purchasable, _, ext = GetMerchantItemInfo(i)
    return price, stack, avail, purchasable ~= false and not ext
  end
end
Ledger.MerchantInfo = MerchantInfo

---------------------------------------------------------------------------
-- Lo que paga el vendedor: el precio que da el juego (o el de los datos), y nada
-- más. Antes se "aprendía" de tus ventas (el dinero que entraba tras vender), pero
-- el dinero entra por muchas cosas a la vez: dos ventas cobradas juntas dejaron
-- Barbaric Leggings a 63s 02c en vez de 31s 51c y Ganar dinero prometía el doble
-- (CurseForge). Con los datos del cliente de lanzamiento ya no hacía falta (de 120
-- objetos vendidos, todos coincidían): se quitó, y lo aprendido se borra al entrar
-- (Core.lua: ES.db.sellSeen)
---------------------------------------------------------------------------

do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE", "PLAYER_ENTERING_WORLD",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "AUCTION_HOUSE_THROTTLED_SYSTEM_READY", "AUCTION_HOUSE_AUCTION_CREATED", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE" }) do
    ES.SafeRegister(f, e)
  end
  f:SetScript("OnEvent", function(_, event, ...)
    if not ES.db then return end
    -- Respuesta de la AH al anuncio pendiente (ver PostOnAH): creada, o un error en rojo
    if Ledger.pendingPost then
      if event == "AUCTION_HOUSE_AUCTION_CREATED" then
        Ledger:ConfirmPost(true)
        return
      elseif event == "CHAT_MSG_SYSTEM" and ERR_AUCTION_STARTED and (...) == ERR_AUCTION_STARTED then
        Ledger:ConfirmPost(true) -- ("Subasta creada.": por si el cliente no tiene el evento)
        return
      elseif event == "UI_ERROR_MESSAGE" then
        -- Solo un error de la AH (o sin dinero para el depósito) rechaza el anuncio:
        -- un "Out of range" o "Not enough mana" a la vez no tiene que ver con él
        local _, message = ...
        if Ledger.IsAuctionError(message) then
          Ledger:ConfirmPost(false, message)
          return
        end
      end
    end
    if event == "AUCTION_HOUSE_AUCTION_CREATED" or event == "CHAT_MSG_SYSTEM" or event == "UI_ERROR_MESSAGE" then return end
    if event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
      -- Se pulsó con la AH ocupada: avisa de que ya se puede (anunciar necesita un clic)
      local b = Ledger.ahBusy
      Ledger.ahBusy = nil
      if b and b.waiting and ES:IsAuctionHouseOpen() then
        ES:Print(L["La Casa de Subastas ya está lista: vuelve a pulsar."])
      end
      return
    end
    if event == "AUCTION_HOUSE_CLOSED" then Ledger.ahBusy = nil end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" or event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
      -- La vista Profit cambia sus clics (vender al vendedor, anunciar en la AH)
      if ES.RefreshAfterBags then ES:RefreshAfterBags() end
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
      local ok, err = pcall(event == "TRAINER_SHOW" and Ledger.ReadAllTrainerServices or Ledger.ReadTrainer, Ledger)
      if not ok then Log("instructor: error leyendo precios: " .. tostring(err)) end
    elseif event == "PLAYER_ENTERING_WORLD" then
      -- Compras de la AH "en el correo" de versiones anteriores: ya no se cuentan
      ES.db.mailBought, ES.db.ahOnWay = nil, nil
    end
  end)
end

---------------------------------------------------------------------------
-- Vender y anunciar (vista Profit): siempre desde un clic del jugador
---------------------------------------------------------------------------
function Ledger:MerchantOpen()
  return MerchantFrame and MerchantFrame:IsShown() and true or false
end

-- Vende hasta `n` unidades al vendedor abierto, pilas enteras que quepan en `n`.
-- Devuelve cuántas vendió.
function Ledger:SellToVendor(itemID, n)
  if not self:MerchantOpen() or not CC("UseContainerItem") or n <= 0 then return 0 end
  local sold = 0
  local slots = Slots(itemID)
  for _, s in ipairs(slots) do
    if sold + s.count <= n then
      UseItem(s.bag, s.slot)
      sold = sold + s.count
      s.used = true
    end
  end
  -- Lo que queda está en una pila más grande (17 y hay que vender 12): se parte. Las
  -- 12 van a una casilla libre y se vende esa pila; las otras 5 se quedan
  local left = n - sold
  if left > 0 then
    local from
    for _, s in ipairs(slots) do if not s.used and s.count > left then from = s break end end
    local bag, slot = EmptySlot()
    local split, pickup = CC("SplitContainerItem"), CC("PickupContainerItem")
    if from and bag and split and pickup and not (CursorHasItem and CursorHasItem()) then
      split(from.bag, from.slot, left)
      pickup(bag, slot)
      -- (el juego tarda un momento en dejar la pila nueva en su casilla)
      C_Timer.After(0.5, function()
        if self:MerchantOpen() and ContainerItemID(bag, slot) == itemID then UseItem(bag, slot) end
      end)
      sold = n
    elseif from and not bag then
      ES:Print(string.format(L["Vendidos %d de %d: para vender el resto hace falta un hueco libre en la bolsa (se parte la pila)."], sold, n))
    else
      ES:Print(string.format(L["Vendidos %d de %d: el resto está en pilas más grandes de lo que hay que vender."], sold, n))
    end
  end
  return sold
end

-- Precio de anuncio en la AH de Forever: solo admite platas enteras (redondeo hacia abajo)
function Ledger.PostPrice(unit)
  unit = math.floor(unit or 0)
  return math.max(unit - unit % 100, 100)
end

---------------------------------------------------------------------------
-- Lo que tienes para la lista de compra: lo que llevas en las bolsas. No se mira el
-- correo: lo comprado en la AH cuenta cuando lo recoges. Antes se apuntaba lo comprado
-- "de camino" (ES.db.ahOnWay) y se descontaba al recogerlo, pero si se perdía un
-- descuento se quedaba pegado (Discord: "48 en el correo" sin nada en el buzón): se
-- quitó, y lo guardado se borra al entrar (ver arriba, PLAYER_ENTERING_WORLD)
---------------------------------------------------------------------------
function ES:HaveForShopping(itemID)
  return self:ItemCount(itemID) or 0
end

-- AH ocupada: cada cuánto se repite el aviso y cuándo se olvida un intento viejo (s)
local AH_BUSY_REPRINT, AH_BUSY_RESET = 10, 30
-- s que se espera la confirmación de un anuncio (AUCTION_HOUSE_AUCTION_CREATED o el
-- "Subasta creada." del chat) antes de darlo por hecho
local POST_CONFIRM_WAIT = 4

-- Duraciones de la AH, por su índice en C_AuctionHouse (1, 2, 3). Forever tiene
-- subastas de 2, 8 y 24 h (Planner.DURATIONS); el cliente moderno, de 12, 24 y 48.
-- Se pregunta al juego: el depósito de la 3 frente al de la 1 es 12 veces (2/8/24)
-- o 4 (12/24/48). Si no responde (o el depósito mínimo los iguala), 2/8/24.
local DURATION_SETS = { { 2, 8, 24 }, { 12, 24, 48 } }
function Ledger.DurationIndex(hours, AH, location, itemID, qty, commodity)
  if not Ledger.durationHours then
    local calc = AH and (commodity and AH.CalculateCommodityDeposit or AH.CalculateItemDeposit)
    if calc then
      local arg = commodity and itemID or location
      local ok1, d1 = pcall(calc, arg, 1, qty)
      local ok3, d3 = pcall(calc, arg, 3, qty)
      if ok1 and ok3 and type(d1) == "number" and type(d3) == "number" and d1 > 0 then
        local r = d3 / d1
        if r > 8 then Ledger.durationHours = DURATION_SETS[1]
        elseif r > 2.5 then Ledger.durationHours = DURATION_SETS[2] end
      end
    end
  end
  local set = Ledger.durationHours or DURATION_SETS[1]
  for i, h in ipairs(set) do
    if h >= (hours or 24) then return i, h end
  end
  return #set, set[#set]
end

-- Precios de la AH más viejos que esto: al anunciar se avisa en naranja (sin bloquear;
-- otros vendedores pueden haber bajado el precio)
Ledger.OLD_PRICES = 3600

-- Estado de los precios a los que se anuncia, para la ventana de vender y el
-- Inventario: "scanning" (no se anuncia hasta que acabe; con el % hecho),
-- "old" (con las horas) o nil (recientes o sin escaneo, que ya avisa cada ventana)
function Ledger:PostPriceState()
  if ES.Scanner and ES.Scanner:IsBusy() then
    return "scanning", math.floor((ES.Scanner.progress or 0) * 100)
  end
  local scan = ES.db.scans and ES.db.scans[ES:RealmKey()]
  if scan and scan.time and time() - scan.time > Ledger.OLD_PRICES then
    return "old", math.floor((time() - scan.time) / 3600)
  end
end

-- La línea en naranja de ese estado, o nil
function Ledger:PostPriceWarning()
  local state, n = self:PostPriceState()
  if state == "scanning" then
    return "|cffff9933" .. string.format(L["Escaneando la AH (%d%%): espera para anunciar al precio de ahora."], n) .. "|r"
  elseif state == "old" then
    return "|cffff9933" .. string.format(L["Precios de hace %d h: pueden haber cambiado. Escanea antes de anunciar."], n) .. "|r"
  end
end

-- Anuncia `n` unidades en la AH abierta a `unit` cobre cada una, en una subasta de
-- `hours` horas (24 por defecto; ver DurationIndex). Solo con la AH de Forever
-- (C_AuctionHouse); con la clásica, se anuncia a mano. Los materiales
-- (commodities) van en un solo anuncio; el resto, todos de una vez y, si la AH no
-- lo acepta, de uno en uno. Devuelve cuántos anunció.
function Ledger:PostOnAH(itemID, n, unit, hours)
  local AH = C_AuctionHouse
  if not (ES:IsAuctionHouseOpen() and AH and AH.PostItem and ItemLocation) then
    ES:Print(L["Anúncialo desde la ventana de la Casa de Subastas."])
    return 0
  end
  -- Escaneando (tuyo o el de otro addon al abrir la AH): el precio de la fila es el del
  -- escaneo anterior y en unos segundos llega el de ahora. Se espera (antes se
  -- anunciaba al precio viejo)
  if ES.Scanner and ES.Scanner:IsBusy() then
    ES:Print(string.format(L["Escaneando la AH (%d%%): espera a que acabe para anunciar al precio de ahora."],
      math.floor((ES.Scanner.progress or 0) * 100)))
    return 0
  end
  if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
    -- Ocupada: tras cada anuncio el servidor tarda un momento en aceptar otro (o otro
    -- addon está buscando). Se avisa una vez, no en cada clic, y cuando el juego dice
    -- que está lista. Nunca se anuncia con la AH ocupada: el servidor lo rechazaba en
    -- silencio y el chat decía "Anunciados" igualmente (antes se intentaba a los 3 s)
    local now = GetTime()
    local b = Ledger.ahBusy
    if not b or now - b.since > AH_BUSY_RESET then
      b = { since = now }
      Ledger.ahBusy = b
    end
    if not b.printed or now - b.printed > AH_BUSY_REPRINT then
      ES:Print(L["La Casa de Subastas está ocupada: vuelve a pulsar en un momento."])
      b.printed = now
    end
    b.waiting = true
    return 0
  end
  if Ledger.pendingPost then
    -- El anuncio anterior aún no está confirmado: uno cada vez
    ES:Print(L["La Casa de Subastas está ocupada: vuelve a pulsar en un momento."])
    return 0
  end
  Ledger.ahBusy = nil
  local slot
  for _, s in ipairs(Slots(itemID)) do
    local locked = C_Container and C_Container.GetContainerItemInfo and (C_Container.GetContainerItemInfo(s.bag, s.slot) or {}).isLocked
    if not locked then slot = s break end
  end
  if not slot or n <= 0 then return 0 end
  local qty = math.min(n, BagCount(itemID))
  local location = ItemLocation:CreateFromBagAndSlot(slot.bag, slot.slot)
  local commodity = false
  if AH.GetItemCommodityStatus then
    local ok, status = pcall(AH.GetItemCommodityStatus, location)
    local COMMODITY = Enum and Enum.ItemCommodityStatus and Enum.ItemCommodityStatus.Commodity or 2
    commodity = ok and status == COMMODITY
  end
  local price = Ledger.PostPrice(unit)
  local duration, postHours = Ledger.DurationIndex(hours, AH, location, itemID, qty, commodity)
  local ok, err
  if commodity and AH.PostCommodity then
    ok, err = pcall(AH.PostCommodity, location, duration, qty, price)
  else
    ok, err = pcall(AH.PostItem, location, duration, qty, nil, price)
    if not ok and qty > 1 then -- no acepta varios de una vez: uno (el resto, con otro clic)
      qty = 1
      ok, err = pcall(AH.PostItem, location, duration, 1, nil, price)
    end
  end
  if not ok then
    ES:Print(L["No se pudo anunciar: "] .. tostring(err))
    return 0
  end
  -- "Anunciados" solo cuando la AH lo confirma (antes se decía al pedirlo, aunque el
  -- servidor lo rechazara); si da un error, se dice cuál (ver ConfirmPost)
  local p = { text = string.format(L["Anunciados %d de %s a %s cada uno (%d h)."], qty, ES:DataItemName(itemID) or itemID, ES.Money(price), postHours),
    name = ES:DataItemName(itemID) or tostring(itemID) }
  Ledger.pendingPost = p
  C_Timer.After(POST_CONFIRM_WAIT, function()
    -- Sin confirmación ni error (el cliente no avisa): se da por hecho, como antes
    if Ledger.pendingPost == p then Ledger:ConfirmPost(true) end
  end)
  return qty
end

-- ¿Es `message` un error de la AH? Los textos del juego ERR_AUCTION_* (en el idioma
-- del cliente) y el de no tener dinero (el depósito). Se leen una vez de _G
local auctionErrors
function Ledger.IsAuctionError(message)
  if type(message) ~= "string" then return false end
  if not auctionErrors then
    auctionErrors = {}
    for k, v in pairs(_G) do
      if type(k) == "string" and type(v) == "string" and k:find("^ERR_AUCTION") then auctionErrors[v] = true end
    end
    if type(ERR_NOT_ENOUGH_MONEY) == "string" then auctionErrors[ERR_NOT_ENOUGH_MONEY] = true end
  end
  return auctionErrors[message] == true
end

-- Respuesta de la AH al último anuncio: ok (creado) o el mensaje de error
function Ledger:ConfirmPost(ok, message)
  local p = Ledger.pendingPost
  if not p then return end
  Ledger.pendingPost = nil
  if ok then
    ES:Print(p.text)
  else
    ES:Print(string.format(L["La Casa de Subastas no aceptó %s: %s"], p.name, tostring(message or "?")))
  end
  if ES.AuctionSell then ES.AuctionSell:Refresh() end
end
