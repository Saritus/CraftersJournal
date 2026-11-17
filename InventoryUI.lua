local _, ES = ...
local L = ES.L

-- Pestaña "Inventario": qué vender de tus bolsas, dónde (vendedor o AH) y cuánto
-- sacas. Arriba, lo que ha subido de precio (véndelo ahora); lo que necesitan tus
-- rutas empezadas se guarda. Con el vendedor abierto, el clic vende; con la AH
-- abierta, anuncia. Solo lee las bolsas (el banco no se ve sin abrirlo).

local Inventory = {}
ES.Inventory = Inventory

local GREEN, GREY, ORANGE, GOLD = "|cff40ff40", "|cff999999", "|cffff9933", "|cffffd100"
local RISE = 1.3          -- "ha subido": el mínimo de ahora, un 30% o más sobre su referencia
local AH_MIN_GAIN = 5     -- la AH tiene que dejar al menos 5c por unidad más que el vendedor
local AH_MIN_PCT = 0.15   -- y un 15% más
local AH_FEW = 5          -- con alertas dudosas, unas pocas a la AH y el resto al vendedor
-- Duración de la subasta: lo que se vende bien, 24 h (el depósito vuelve igual y está
-- más tiempo a la vista); lo dudoso, 8 h: si caduca se pierde un tercio del depósito
-- y se puede volver a probar o bajar el precio
local AH_HOURS_GOOD, AH_HOURS_RISKY = 24, 8
local DE_MIN_GAIN = 10    -- se avisa de desencantar si deja al menos 10c más que venderlo
local DE_MIN_PCT = 0.20   -- y un 20% más (es una media: cada desencantamiento sale al azar)

-- Objetos de tus bolsas: { [itemID] = { count, bound, noValue, quality } }
local function BagContents()
  local items = {}
  local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local getInfo = C_Container and C_Container.GetContainerItemInfo
  local getID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  if not numSlots or not getID then return items end
  for bag = 0, 4 do
    for slot = 1, numSlots(bag) or 0 do
      local id = getID(bag, slot)
      if id then
        local info = getInfo and getInfo(bag, slot)
        local it = items[id] or { count = 0 }
        it.count = it.count + (info and info.stackCount or 1)
        it.bound = it.bound or (info and info.isBound) or nil
        it.noValue = it.noValue or (info and info.hasNoValue) or nil
        it.quality = it.quality or (info and info.quality) or nil
        items[id] = it
      end
    end
  end
  return items
end
Inventory.BagContents = BagContents -- (para pruebas)

-- Lo que necesitan tus rutas empezadas desde tu nivel: { [itemID] = unidades }
local function RouteNeeds()
  local need = {}
  for _, prof in ipairs(ES.PROFESSIONS) do
    local plan = ES:RouteLock(prof.key) and ES:LockedPlan(prof.key)
    local data = ES.Data[prof.key]
    if plan and data then
      local rank = ES:GetProfessionSkill(data.skillLine)
      -- (la ruta entera, no solo el tramo: si no, te diría que vendas lo del siguiente)
      for itemID, n in pairs(ES.Planner.RouteNeed(prof.key, plan, rank, { keep = true })) do
        need[itemID] = (need[itemID] or 0) + n.need
      end
    end
  end
  return need
end

-- Lo que no se propone vender nunca:
--   herramientas de profesión (Blacksmith Hammer, Arclight Spanner, varas de
--     encantar, pico de minero, cuchillo de desollar, cañas): sin ellas no fabricas
--     ni recolectas, aunque el vendedor pague 3 cobres (Discord)
--   lo que marcas tú con clic derecho (ES.db.neverSell[itemID] = true)
-- ES.db.neverSell[itemID] = false: una herramienta que sí quieres vender
local GATHER_TOOLS = {
  [2901] = true,  -- Mining Pick
  [7005] = true,  -- Skinning Knife
  [6256] = true, [6365] = true, [6366] = true, [6367] = true, -- cañas de pescar
  [12225] = true, [19022] = true, [19970] = true,
}
local toolItems
function Inventory.IsTool(itemID)
  if not toolItems then
    toolItems = {}
    for _, t in pairs(ES.Data.Tools or {}) do toolItems[t.item] = true end
    for id in pairs(GATHER_TOOLS) do toolItems[id] = true end
  end
  return toolItems[itemID] or false
end

-- Objetos de los conjuntos del gestor de equipo (tu equipo de daño, de curar...):
-- { [itemID] = true }. Se mira como mucho una vez por segundo (se pregunta por cada
-- objeto de las bolsas)
local setItems, setItemsAt
local function EquipmentSetItems()
  local now = GetTime and GetTime() or 0
  if setItems and setItemsAt == now then return setItems end
  setItems, setItemsAt = {}, now
  local sets = C_EquipmentSet
  if not (sets and sets.GetEquipmentSetIDs and sets.GetItemIDs) then return setItems end
  for _, setID in ipairs(sets.GetEquipmentSetIDs() or {}) do
    for _, id in pairs(sets.GetItemIDs(setID) or {}) do
      if type(id) == "number" and id > 0 then setItems[id] = true end
    end
  end
  return setItems
end

-- Tu equipo: el ligado a ti (soulbound: tu otro equipo, de daño o de curar, lo que te
-- dieron las misiones) o el que está en un conjunto del gestor de equipo. Vender todo
-- lo vendía con un clic sin mirar (CurseForge). Los verdes sin ligar de botín sí se
-- proponen: es de donde sale casi todo el oro. Lo que fabricas y lo gris, también.
-- `bound`: ligado en tus bolsas. Solo con la opción ES.db.protectGear (Options.lua;
-- por defecto no: se propone todo, y lo tuyo lo apartas con clic derecho)
local craftedItems
function Inventory.IsGear(itemID, bound)
  if not ES.db.protectGear then return false end
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local equipLoc = instant and select(4, instant(itemID))
  if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then return false end
  if not (bound or EquipmentSetItems()[itemID]) then return false end
  local _, quality = ES:GetItemData(itemID)
  if quality == 0 then return false end -- (sin saber la calidad aún: se protege)
  if not craftedItems then
    craftedItems = {}
    for _, p in ipairs(ES.PROFESSIONS) do
      for _, r in pairs(ES.Data[p.key] and ES.Data[p.key].recipes or {}) do
        if r.out then craftedItems[r.out[1]] = true end
      end
    end
  end
  return not craftedItems[itemID]
end

-- ¿No se vende? Devuelve "user" (lo marcaste), "tool" (herramienta), "gear" (tu
-- equipo: ligado o en un conjunto) o nil. `bound`: ligado en tus bolsas
function Inventory.NeverSell(itemID, bound)
  local mark = ES.db.neverSell and ES.db.neverSell[itemID]
  if mark == true then return "user" end
  if mark ~= false and Inventory.IsTool(itemID) then return "tool" end
  if mark ~= false and Inventory.IsGear(itemID, bound) then return "gear" end
  return nil
end

-- Marcar o desmarcar "no vender nunca" (clic derecho en una fila)
function Inventory.SetNeverSell(itemID, on)
  ES.db.neverSell = ES.db.neverSell or {}
  if on then
    ES.db.neverSell[itemID] = true
  else
    -- (una herramienta o un equipo desmarcados se pueden vender: false; lo demás vuelve a lo normal)
    -- (equipo: como si estuviera ligado; si no lo está, el false no cambia nada)
    if Inventory.IsTool(itemID) or Inventory.IsGear(itemID, true) then ES.db.neverSell[itemID] = false else ES.db.neverSell[itemID] = nil end
  end
  ES:Print(string.format(on and L["%s: no se propondrá venderlo. Se deshace con clic derecho en \"No se venden\" (pestaña Inventario)."]
    or L["%s: vuelve a proponerse para vender."], ES:DataItemName(itemID) or ("#" .. itemID)))
  -- Todas las ventanas que proponen vender (si no, la fila seguía ahí y cada clic
  -- derecho repetía el aviso)
  if ES.RenderInventory then ES:RenderInventory() end
  if ES.VendorShop and ES.VendorShop.Refresh then ES.VendorShop:Refresh() end
  if ES.AuctionSell and ES.AuctionSell.Refresh then ES.AuctionSell:Refresh() end
end

-- Qué hacer con cada objeto de tus bolsas:
-- { itemID, count, keep, vendorN, vendorUnit, ahN, ahUnit (neto por unidad), listPrice,
--   value, rise (subida respecto a su referencia, 0.4 = +40%), ref, verdict, fair }
function Inventory:List()
  local scan = ES.db.scans and ES.db.scans[ES:RealmKey()]
  local need = RouteNeeds()
  local list = {}
  for id, it in pairs(BagContents()) do
    local never = Inventory.NeverSell(id, it.bound)
    local keep = never and it.count or math.min(it.count, need[id] or 0)
    local n = it.count - keep
    local vendor = not it.noValue and ES:VendorSellPrice(id) or 0
    -- (sellN: las que se podrían vender; con alertas dudosas solo AH_FEW van a la AH,
    -- y la ventana junto a la AH ofrece Ctrl+clic para anunciarlas todas)
    local e = { itemID = id, count = it.count, keep = keep, never = never, vendorUnit = vendor, vendorN = 0, ahN = 0, value = 0, sellN = n }
    local entry = scan and scan.items[id]
    -- Tu escaneo no lo tiene: el precio de Auctionator o TSM, si lo hay (solo el
    -- mínimo; Market:AddonPrice). Tu escaneo siempre manda
    if n > 0 and not it.bound and not (entry and entry.minUnit) then
      local ext = ES.Market:AddonPrice(id)
      if ext then
        entry = { minUnit = ext.price }
        e.priceSource, e.priceAge = ext.source, ext.age
      end
    end
    -- Sin precio en la AH no se ha comparado: que se vea (si no, "al vendedor" parece
    -- que la AH paga menos)
    if n > 0 and not it.bound and not (entry and entry.minUnit) then e.noAH = true end
    if n > 0 and not it.bound and entry and entry.minUnit then
      local fair = ES.Market:FairPrice(id, entry.minUnit)
      local listPrice = ES.Market.ListPrice(fair)
      -- Lo que te queda es tras la comisión: el depósito se devuelve al venderse
      local verdict = ES.Market:Signals(id).verdict
      -- Precio inflado (ha subido de golpe): para estimar se cuenta el de los últimos
      -- días, pero lo que ya llevas tiene el vendedor de suelo. Se prueban unas pocas en
      -- la AH al precio real si, aun perdiendo el depósito una vez, sale mejor que el
      -- vendedor (ver abajo), salvo que TSM diga que se vende poco o bastante más barato.
      -- Discord: Star Ruby a 85s en la AH (antes ~50-60s) iba al vendedor a 50s
      if fair.inflated then
        local d = ES.Market:Demand(id)
        local against = d.known and (d.flag or (d.avg and d.avg < fair.current * ES.Market.TSM_LOW_PRICE))
        if not against then
          e.tryRise, listPrice = true, math.max(1, fair.current - 1)
          if verdict == "good" then verdict = "watch" end -- (unas pocas, con el riesgo del depósito)
        end
      end
      e.hours = verdict == "good" and AH_HOURS_GOOD or AH_HOURS_RISKY
      local perUnit, cut = ES.Planner.AuctionCosts(vendor, { hours = e.hours, neutral = ES:IsNeutralAH() })
      local net = listPrice and listPrice * (1 - cut)
      e.fair, e.verdict, e.listPrice, e.ref = fair, verdict, listPrice, fair.ref
      e.depositUnit = perUnit -- (depósito por unidad: lo que se arriesga anunciándolas todas)
      if fair.ref and entry.minUnit >= fair.ref * RISE then e.rise = entry.minUnit / fair.ref - 1 end
      -- ...pero si no sabemos que se venda (pocos datos, ojo), puede caducar y el
      -- depósito se pierde (el de 8 h: 20% del vendedor, mínimo por subasta): la AH
      -- tiene que compensar aunque se pierda una vez. Si no, al vendedor
      local compare = net
      if net and verdict ~= "good" then
        local stack = ES.Calc.StackSize(id)
        local m = math.max(1, math.min(n, stack))
        e.depositRisk = ES.Calc.Deposit(perUnit, m, m) / m
        compare = net - e.depositRisk
      end
      if net and compare - vendor < math.max(AH_MIN_GAIN, vendor * AH_MIN_PCT) and net - vendor >= math.max(AH_MIN_GAIN, vendor * AH_MIN_PCT) then
        e.riskyAH, e.ahNet = true, net -- en la AH valdría más, pero no compensa el riesgo de perder el depósito
      end
      if net and compare - vendor >= math.max(AH_MIN_GAIN, vendor * AH_MIN_PCT) and verdict ~= "avoid" then
        local onAH = verdict == "good" and n or math.min(n, AH_FEW)
        e.ahN, e.ahUnit = onAH, net
      end
    end
    e.vendorN = vendor > 0 and (n - e.ahN) or 0
    -- Al vendedor solo se propone lo que NO vale para la AH (CurseForge: "me propone
    -- vender la mitad del inventario, aunque en la AH valga más"). Sin precio de AH no
    -- se sabe (no escaneaste, o nadie lo vende ahora) y la AH arriesgada sí vale más si
    -- se vende: ninguno de los dos va a "Vender al vendedor", salen aparte (unsure) y
    -- se pueden vender con clic. Lo gris (calidad 0) sí: la AH no lo quiere
    local poor = it.quality == 0
    if e.vendorN > 0 and e.ahN == 0 and ((e.noAH and not poor) or e.riskyAH) then e.unsure = true end
    e.value = e.ahN * (e.ahUnit or 0) + e.vendorN * vendor
    -- Solo informativo: si desencantarlo (también lo ligado) vale bastante más que
    -- venderlo, se dice en la fila y el tooltip; el addon no desencanta nada
    local de = n > 0 and ES.Disenchant:Value(id, scan)
    local sellUnit = math.max(vendor, e.ahN > 0 and e.ahUnit or 0)
    if de and de.value - sellUnit >= math.max(DE_MIN_GAIN, sellUnit * DE_MIN_PCT) then
      e.de, e.deCan, e.deRank = de, ES.Disenchant:CanDisenchant(de.skill)
    end
    -- (lo que no se vende sale aparte: herramientas solo si las llevas, que se vea por
    -- qué no se proponen; lo tuyo, siempre, para poder desmarcarlo. Y lo que en la AH
    -- no compensa y el vendedor no compra, para que se sepa por qué no se propone:
    -- Basic Campfire Kit a 50c con 3.278 a la venta y 1s de depósito si caduca)
    if e.value > 0 or keep > 0 or e.riskyAH then list[#list + 1] = e end
  end
  table.sort(list, function(a, b) return a.value > b.value or (a.value == b.value and a.itemID < b.itemID) end)
  return list
end

---------------------------------------------------------------------------
-- Página
---------------------------------------------------------------------------
local function ItemLabel(itemID) return ES.UI.ItemLabel(itemID, L["Objeto "] .. itemID) end

-- Cabecera con icono, título y subtítulo; franja de cifras; estado; lista con scroll.
-- stats = { { key, label } }
function ES.UI.ListPage(page, title, icon, stats)
  local Label = ES.UI.Label
  local head = ES.UI.CardHead(page) -- (fondo y colores de Subir profesiones)
  page.icon = head:CreateTexture(nil, "ARTWORK")
  page.icon:SetSize(44, 44)
  page.icon:SetPoint("LEFT", 12, 0)
  if icon then
    page.icon:SetTexture(icon)
    page.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
  local name = Label(head, title, "GameFontNormalHuge")
  name:SetPoint("TOPLEFT", page.icon, "TOPRIGHT", 12, 2)
  name:SetTextColor(0.96, 0.79, 0.25)
  page.subtitle = Label(head, "", "GameFontHighlightSmall")
  page.subtitle:SetPoint("BOTTOMLEFT", page.icon, "BOTTOMRIGHT", 12, 2)
  page.subtitle:SetPoint("RIGHT", -170, 0)
  page.subtitle:SetJustifyH("LEFT")
  -- Botón a la derecha de la cabecera (cada página decide qué hace)
  page.action = CreateFrame("Button", nil, head, "UIPanelButtonTemplate")
  page.action:SetSize(150, 24)
  page.action:SetPoint("RIGHT", -14, 0)
  page.action:Hide()

  local strip = CreateFrame("Frame", nil, page)
  strip:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 4, -6)
  strip:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -4, -6)
  strip:SetHeight(46)
  page.stats = {}
  for i, s in ipairs(stats) do
    local label = Label(strip, s.label, "GameFontDisableSmall")
    label:SetPoint("TOPLEFT", (i - 1) * 196 + 6, -2)
    local value = Label(strip, "", "GameFontHighlightLarge")
    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    page.stats[s.key] = value
  end
  page.status = Label(page, "", "GameFontHighlightSmall")
  page.status:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 2, -2)
  page.status:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
  page.status:SetJustifyH("LEFT")
  page.status:SetWordWrap(false)

  local list = ES.UI.ListPanel(page, head, 70)
  local scroll = ES.UI.WheelScroll(list)
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -8, 8)
  page.content = CreateFrame("Frame", nil, scroll)
  page.content:SetSize(ES.UI.LIST_WIDTH, 1)
  scroll:SetScrollChild(page.content)
  page.rows = {}
  page.empty = Label(page.content, "", "GameFontDisable")
  page.empty:SetPoint("TOP", 0, -30)
  page.empty:SetWidth(600)

  -- Llegan nombres e iconos de objetos que faltaban: se repinta (page.Render, si se ve)
  ES.SafeRegister(page, "GET_ITEM_INFO_RECEIVED")
  page:SetScript("OnEvent", function(self)
    -- (sin verse, nada: al abrirse se pinta entera, OnShow)
    if self.pendingItems and not self.refreshQueued and self:IsVisible() then
      self.refreshQueued = true
      C_Timer.After(0.5, function()
        self.refreshQueued = false
        if self:IsVisible() and self.Render then self.Render() end
      end)
    end
  end)
end

-- noActions: sin las líneas de qué hace el clic (la ventana junto a la AH pone las suyas)
local function Tooltip(e, noActions)
  return function(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.itemID) else GameTooltip:AddLine((ItemLabel(e.itemID))) end
    GameTooltip:AddLine(" ")
    if e.keep > 0 then
      GameTooltip:AddLine(string.format(L["Guarda %d: las necesitan tus rutas empezadas."], e.keep), 0.4, 1, 0.4, true)
    end
    if e.ahN > 0 then
      GameTooltip:AddDoubleLine(string.format(L["%d en la AH a %s"], e.ahN, ES.Money(e.listPrice)),
        "+" .. ES.Money(e.ahN * e.ahUnit), 1, 0.82, 0, 1, 1, 1)
      GameTooltip:AddLine(L["(lo que te queda tras la comisión de la AH; el depósito se devuelve al venderse)"], 0.6, 0.6, 0.6, true)
      -- De cuándo es ese precio (viejo: en naranja; puede haber bajado)
      local scan = ES.db.scans and ES.db.scans[ES:RealmKey()]
      if e.priceSource then
        GameTooltip:AddLine(e.priceAge and e.priceAge > 0 and string.format(L["Precio de %s (hace %d días): tu escaneo no tenía este objeto."], e.priceSource, e.priceAge)
          or string.format(L["Precio de %s: tu escaneo no tenía este objeto."], e.priceSource), 0.6, 0.6, 0.6, true)
      elseif scan and scan.time and ES.TimeAgo then
        local old = time() - scan.time > ES.Ledger.OLD_PRICES
        GameTooltip:AddLine(string.format(L["Precio del escaneo de la AH de %s."], ES.TimeAgo(scan.time)),
          old and 1 or 0.6, old and 0.6 or 0.6, old and 0.2 or 0.6, true)
      end
      if e.hours == AH_HOURS_RISKY and e.depositRisk then
        GameTooltip:AddLine(string.format(L["Subasta de %d h: no se sabe si se vende y, si caduca, pierdes solo %s de depósito por subasta."],
          e.hours, ES.Money(e.depositRisk)), 0.6, 0.6, 0.6, true)
      end
    end
    if e.vendorN > 0 then
      GameTooltip:AddDoubleLine(string.format(L["%d al vendedor a %s"], e.vendorN, ES.Money(e.vendorUnit)),
        "+" .. ES.Money(e.vendorN * e.vendorUnit), 1, 0.82, 0, 1, 1, 1)
    end
    if e.de then
      GameTooltip:AddLine(" ")
      GameTooltip:AddDoubleLine(L["Desencantado daría de media"], ES.Money(e.de.value), 1, 0.82, 0, 1, 1, 1)
      for _, r in ipairs(e.de.results) do
        GameTooltip:AddDoubleLine(string.format("  %.2f× %s", r[2], (ItemLabel(r[1]))), ES.Money(math.floor(r[3])), 0.8, 0.8, 0.8, 0.8, 0.8, 0.8)
      end
      GameTooltip:AddLine(L["Media aproximada (tabla de Classic): cada desencantamiento sale al azar. Los materiales, a lo que te queda vendiéndolos en la AH."], 0.6, 0.6, 0.6, true)
      if e.de.partial then
        GameTooltip:AddLine(L["Algún material no salía en el escaneo: se cuenta a precio de vendedor (puede valer más)."], 1, 0.6, 0.2, true)
      end
      if not e.deCan then
        GameTooltip:AddLine(e.deRank and string.format(L["Necesitas Encantamiento %d para desencantarlo (tienes %d)."], e.de.skill, e.deRank)
          or string.format(L["Un encantador (Encantamiento %d) sacaría más desencantándolo."], e.de.skill), 1, 0.6, 0.2, true)
      end
    end
    if e.riskyAH then
      GameTooltip:AddLine(string.format(L["En la AH te quedarían %s, pero no se sabe si se vende: si caduca pierdes %s de depósito por subasta. Al vendedor es seguro."],
        ES.Money(e.ahNet), ES.Money(e.depositRisk)), 1, 0.6, 0.2, true)
    end
    if e.noAH then
      GameTooltip:AddLine(L["No salía en el último escaneo de la AH: no se sabe si allí vale más. Escanea la AH para compararlo."], 1, 0.6, 0.2, true)
    end
    if e.rise then
      GameTooltip:AddLine(string.format(L["Ha subido un %d%%: los últimos días estaba a ~%s."], math.floor(e.rise * 100 + 0.5), ES.Money(e.ref)),
        0.4, 1, 0.4, true)
    end
    if e.tryRise and e.ahN > 0 then
      -- (al precio real: la línea de "se cuenta a" del precio inflado no vale aquí)
      GameTooltip:AddLine(string.format(L["Ha subido de golpe y puede que no se venda a este precio: se prueba con %d. Si caduca solo pierdes el depósito y lo sigues pudiendo vender al vendedor (%s)."],
        e.ahN, ES.Money(e.vendorUnit)), 1, 0.82, 0, true)
    else
      ES.Market.AddFairToTooltip(e.fair)
    end
    if e.ahN > 0 or e.verdict then ES.Market.AddToTooltip(e.itemID) end
    if noActions then
      GameTooltip:Show()
      return
    end
    GameTooltip:AddLine(" ")
    if e.ahN > 0 and ES:IsAuctionHouseOpen() then
      GameTooltip:AddLine(string.format(L["Clic: anunciar %d en la AH."], e.ahN), 0.5, 0.8, 1)
    elseif e.vendorN > 0 and ES.Ledger:MerchantOpen() then
      GameTooltip:AddLine(string.format(L["Clic: vender %d al vendedor."], e.vendorN), 0.5, 0.8, 1)
    elseif not e.never then
      GameTooltip:AddLine(L["Abre el vendedor o la Casa de Subastas para venderlo desde aquí."], 0.6, 0.6, 0.6, true)
    end
    if e.never then
      GameTooltip:AddLine(e.never == "tool" and L["Herramienta de profesión: sin ella no puedes fabricar o recolectar. No se propone venderla."]
        or e.never == "gear" and L["Tu equipo (ligado a ti o en un conjunto del gestor de equipo): no se propone venderlo, para no venderlo sin querer. Se cambia en /cj opciones."]
        or L["Lo marcaste para no venderlo."], 0.4, 1, 0.4, true)
      GameTooltip:AddLine(L["Clic derecho: volver a proponerlo para vender."], 0.6, 0.6, 0.6)
    elseif e.keep < e.count then
      GameTooltip:AddLine(L["Clic derecho: no venderlo nunca."], 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
  end
end

Inventory.Tooltip = Tooltip -- (también la ventana junto a la AH, AuctionSellUI.lua)

-- Clic: con la AH abierta anuncia lo que va a la AH; con el vendedor, vende lo suyo
local function Act(e)
  if e.ahN > 0 and ES:IsAuctionHouseOpen() then
    -- (con confirmación, si está activada: AuctionSellUI.lua)
    ES.AuctionSell.Post(e.itemID, e.ahN, e.listPrice, e.hours, function()
      C_Timer.After(0.6, function() ES:RenderInventory() end)
    end)
    return
  elseif e.vendorN > 0 and ES.Ledger:MerchantOpen() then
    ES.Ledger:SellToVendor(e.itemID, e.vendorN)
  else
    return
  end
  C_Timer.After(0.6, function() ES:RenderInventory() end)
end

local function Line(e, mode)
  local name, texture = ItemLabel(e.itemID)
  local sub
  if mode == "notworth" then
    -- En la AH te quedaría algo, pero si caduca el depósito se lo come, y el vendedor
    -- no lo compra: por eso no se propone (antes desaparecía sin decir por qué)
    sub = GREY .. string.format(L["AH: te quedarían %s, pero si caduca pierdes %s de depósito · el vendedor no lo compra"],
      ES.Money(e.ahNet or 0), ES.Money(e.depositRisk or 0)) .. "|r"
  elseif mode == "never" then
    sub = GREY .. (e.never == "tool" and L["herramienta de profesión: no se vende"]
      or e.never == "gear" and L["tu equipo: no se vende"] or L["lo marcaste para no venderlo"])
      .. " · " .. L["clic derecho: volver a proponerlo"] .. "|r"
  elseif mode == "keep" then
    sub = GREEN .. string.format(L["guarda %d para tus rutas"], e.keep) .. "|r"
      .. (e.count > e.keep and (GREY .. " · " .. string.format(L["%d de sobra"], e.count - e.keep) .. "|r") or "")
  else
    local parts = {}
    if e.ahN > 0 then
      parts[#parts + 1] = string.format(L["%sAH: %d a %s|r (%s)"], GOLD, e.ahN, ES.Money(e.listPrice), ES.Market.LABELS[e.verdict] or "")
    end
    if e.vendorN > 0 then parts[#parts + 1] = string.format(L["vendedor: %d a %s"], e.vendorN, ES.Money(e.vendorUnit)) end
    if e.noAH then parts[#parts + 1] = ORANGE .. L["sin precio de AH"] .. "|r" end
    if e.riskyAH then parts[#parts + 1] = GREY .. L["AH arriesgada: puede caducar"] .. "|r" end
    if e.de then parts[#parts + 1] = GOLD .. string.format(L["desencantado: ~%s"], ES.Money(e.de.value)) .. "|r" end
    if e.rise then parts[1] = GREEN .. string.format(L["+%d%% sobre su precio habitual"], math.floor(e.rise * 100 + 0.5)) .. "|r · " .. (parts[1] or "") end
    if e.keep > 0 then parts[#parts + 1] = GREY .. string.format(L["guarda %d para tus rutas"], e.keep) .. "|r" end
    sub = table.concat(parts, " · ")
  end
  local sells = mode ~= "keep" and mode ~= "never" and mode ~= "notworth"
  return {
    icon = texture or 134400, title = string.format("%d× %s", e.count, name or ("#" .. e.itemID)), sub = sub,
    value = sells and ES.UI.Signed(-e.value) or "", item = e.itemID,
    tooltip = Tooltip(e), onClick = sells and function() Act(e) end or nil,
    -- Clic derecho: no venderlo nunca (o, en "No se venden", volver a proponerlo)
    onRightClick = (sells or mode == "never") and function() Inventory.SetNeverSell(e.itemID, mode ~= "never") end or nil,
  }
end

function ES:CreateInventoryPage(page)
  ES.UI.ListPage(page, L["Inventario"], "Interface\\Icons\\INV_Misc_Bag_08", {
    { key = "total",  label = L["Sacarías vendiéndolo"] },
    { key = "ah",     label = L["En la Casa de Subastas"] },
    { key = "vendor", label = L["Al vendedor"] },
    { key = "rising", label = L["Han subido de precio"] },
  })
  page.subtitle:SetText(L["Qué vender de tus bolsas, dónde y cuánto sacas. Lo que necesitan tus rutas empezadas se guarda."])
  -- Con el vendedor abierto: vender de golpe todo lo que va al vendedor
  page.action:SetScript("OnClick", function()
    -- (la sección "Vender al vendedor", la misma que la ventana del vendedor: no lo
    -- que no tiene precio de AH ni la AH arriesgada)
    local list, total = Inventory:Sections().vendor, 0
    if #list == 0 then return end
    for _, e in ipairs(list) do total = total + (e.vendorN or 0) * (e.vendorUnit or 0) end
    -- Pregunta antes (ES:Confirm, UI.lua; se quita con su casilla o en /cj opciones, Inventario)
    ES:Confirm({ key = "noInventorySellConfirm", title = L["Vender al vendedor"],
      text = string.format(L["¿Vender %d objetos al vendedor por %s?"], #list, ES.Money(total)),
      onYes = function()
        for _, e in ipairs(list) do ES.Ledger:SellToVendor(e.itemID, e.vendorN) end
        ES:Print(string.format(L["Vendidos %d objetos al vendedor."], #list))
        C_Timer.After(0.8, function() ES:RenderInventory() end)
      end })
  end)
  page.action:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Vende al vendedor todo lo que va al vendedor (no lo que va a la AH ni lo que guardan tus rutas)."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  page.action:SetScript("OnLeave", function() GameTooltip:Hide() end)
  page.Render = function() ES:RenderInventory() end
  page:SetScript("OnShow", page.Render)
  -- Cambian tus bolsas, abres o cierras el vendedor o la AH: se repinta (si se ve)
  local f = CreateFrame("Frame")
  for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" }) do
    ES.SafeRegister(f, ev)
  end
  f:SetScript("OnEvent", function() if page:IsVisible() then ES:RenderInventory() end end)
  self.inventoryPage = page
end

-- Las secciones de la pestaña: ÚNICO reparto, que usan también las ventanas junto al
-- vendedor (la sección "vendor") y junto a la AH ("rising" y "ah"). Así enseñan
-- exactamente lo mismo que la pestaña (antes la del vendedor hacía su propia lista y
-- proponía el resto "vendedor: 2" de objetos que la pestaña pone en la AH)
-- { rising, ah, vendor, unsure, keep, never, notWorth } de Inventory:List()
-- (unsure: sin precio de AH o AH arriesgada; el vendedor los compraría, pero no se
-- proponen: ni la ventana del vendedor ni "Vender al vendedor" los venden)
function Inventory:Sections(list)
  list = list or self:List()
  local s = { rising = {}, ah = {}, vendor = {}, unsure = {}, keep = {}, never = {}, notWorth = {} }
  for _, e in ipairs(list) do
    if e.value > 0 and e.rise and e.ahN > 0 then s.rising[#s.rising + 1] = e
    elseif e.ahN > 0 then s.ah[#s.ah + 1] = e
    elseif e.unsure then s.unsure[#s.unsure + 1] = e
    elseif e.vendorN > 0 then s.vendor[#s.vendor + 1] = e
    elseif e.riskyAH and not e.never and e.count > e.keep then s.notWorth[#s.notWorth + 1] = e end
    if e.never then s.never[#s.never + 1] = e
    elseif e.keep > 0 then s.keep[#s.keep + 1] = e end
  end
  return s
end

function ES:RenderInventory()
  local page = self.inventoryPage
  if not page or not page:IsVisible() then return end
  local list = Inventory:List()
  local Signed = ES.UI.Signed
  local sec = Inventory:Sections(list)
  local rising, ah, vendor, keep, never = sec.rising, sec.ah, sec.vendor, sec.keep, sec.never
  -- "Al vendedor": solo la sección del vendedor, lo que vende su botón y la ventana del
  -- vendedor. El resto al vendedor de una fila de la AH ("AH: 5 · vendedor: 2") no lo
  -- vende ningún botón: sumarlo prometía un oro que no se sacaba
  local tAH, tVendor = 0, 0
  for _, e in ipairs(list) do tAH = tAH + e.ahN * (e.ahUnit or 0) end
  for _, e in ipairs(vendor) do tVendor = tVendor + e.vendorN * e.vendorUnit end
  page.stats.total:SetText(Signed(-(tAH + tVendor)))
  page.stats.ah:SetText(tAH > 0 and Signed(-tAH) or (GREY .. "—|r"))
  page.stats.vendor:SetText(tVendor > 0 and Signed(-tVendor) or (GREY .. "—|r"))
  page.stats.rising:SetText(tostring(#rising))

  local scan = ES.db.scans and ES.db.scans[ES:RealmKey()]
  local postState = ES.Ledger:PostPriceState()
  if postState == "scanning" or (scan and postState == "old" and ES:IsAuctionHouseOpen()) then
    -- Al anunciar: escaneando (el clic no anuncia hasta que acabe) o precios de hace más
    -- de 1 h con la AH abierta
    page.status:SetText(ES.Ledger:PostPriceWarning())
  elseif not scan then
    page.status:SetText(ORANGE .. L["Sin escaneo de la AH: al vendedor solo se propone lo gris. Escanea para ver qué vale más en la AH.|r"])
  else
    local mins = math.floor((time() - scan.time) / 60)
    page.status:SetText(mins > 12 * 60 and (ORANGE .. string.format(L["Precios de la AH de hace %d h: escanea antes de anunciar.|r"], math.floor(mins / 60)))
      or (GREY .. string.format(L["Precios de la AH de hace %d min · neto tras la comisión|r"], mins)))
  end
  local merchant = ES.Ledger:MerchantOpen()
  -- Qué hace el clic en una fila ahora mismo (vender o anunciar sin buscarlo en las bolsas)
  local hint = merchant and L["Clic en una fila: venderla al vendedor."]
    or ES:IsAuctionHouseOpen() and L["Clic en una fila: anunciarla en la AH."]
    or L["Con vendedor o AH abiertos, clic en una fila para venderla."] -- (corto: comparte línea con los precios)
  page.hintText = "  |cff80ccff" .. hint .. "|r" -- (también al avanzar el escaneo, ES:UpdatePostStatus)
  page.status:SetText(page.status:GetText() .. page.hintText)
  page.action:SetShown(merchant and #vendor > 0)
  page.action:SetText(L["Vender al vendedor"])

  local lines = {}
  -- (el clic derecho, a la vista y no solo en el tooltip: en el encabezado de la
  -- primera sección de vender, encima de las filas a las que se aplica)
  local hinted = false
  local function Section(title, items, mode)
    if #items == 0 then return end
    if not mode and not hinted then
      hinted = true
      title = title .. GREY .. "  ·  " .. L["Clic derecho en una fila: no venderlo nunca."] .. "|r"
    end
    lines[#lines + 1] = { section = title }
    for _, e in ipairs(items) do lines[#lines + 1] = Line(e, mode) end
  end
  Section(L["Ha subido: véndelo ahora"], rising)
  Section(L["Vender en la Casa de Subastas"], ah)
  Section(L["Vender al vendedor"], vendor)
  Section(L["Sin precio fiable de AH: no se propone al vendedor"], sec.unsure)
  Section(L["Guardar para tus rutas"], keep, "keep")
  Section(L["No compensa venderlo ahora"], sec.notWorth, "notworth")
  Section(L["No se venden"], never, "never")
  page.empty:SetText(#lines == 0 and L["No llevas nada que se pueda vender."] or "")
  ES.UI.RenderLines(page, lines)
end
