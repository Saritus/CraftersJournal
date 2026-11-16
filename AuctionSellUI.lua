local _, ES = ...
local L = ES.L

-- Se quita con la opción "Vender en la AH desde tus bolsas" (ES.db.noAuctionSellWindow,
-- Options.lua). Al abrir la Casa de Subastas sale al lado una ventana (como la del vendedor,
-- VendorUI.lua) con lo que la pestaña Inventario dice que vendas en la AH: cuántos,
-- a cuánto y lo que te queda tras la comisión. Clic en una fila: anuncia todas las
-- de la fila; Mayús+clic, solo una (un anuncio por clic: la AH pide un clic del
-- jugador para cada uno). Ctrl+clic, si las alertas del mercado dejaron solo unas pocas
-- (Inventory: AH_FEW), todas las que podrías vender, avisando del riesgo (Discord:
-- "¿por qué me ofrece 5 Turtle Meat si tengo muchas?"). Clic derecho: no venderlo nunca. Va pegada a la AH, y la
-- lista de compra pequeña, si sale, a su derecha. Con la ventana grande al lado de la AH no sale (ya tienes el
-- Inventario ahí).

local Sell = {}
ES.AuctionSell = Sell

local ROW_H, MAX_ROWS = 34, 12
local WIDTH = 300
local COST_W = 74 -- columna del valor a la derecha (hasta "99g 99s 99c")
local GREEN, GREY = "|cff40ff40", "|cff999999"

local panel

-- EXACTAMENTE las secciones de AH de la pestaña Inventario ("Ha subido" y "Vender en
-- la Casa de Subastas", Inventory:Sections), lo que más deja arriba: { e de Inventory:List }
function Sell:List()
  local list = {}
  if not ES.Inventory then return list end
  local ok, sec = pcall(ES.Inventory.Sections, ES.Inventory)
  if not ok then return list end
  for _, e in ipairs(sec.rising) do list[#list + 1] = e end
  for _, e in ipairs(sec.ah) do list[#list + 1] = e end
  table.sort(list, function(a, b)
    local va, vb = a.ahN * (a.ahUnit or 0), b.ahN * (b.ahUnit or 0)
    return va > vb or (va == vb and a.itemID < b.itemID)
  end)
  return list
end

local function AHFrame()
  return AuctionHouseFrame or AuctionFrame
end

---------------------------------------------------------------------------
-- Confirmar antes de anunciar (todos los sitios que anuncian: esta ventana, el
-- Inventario y la vista Profit). CurseForge: un clic sin querer anunció de golpe lo que
-- acababa de comprar. Con la casilla "No volver a preguntar" se apaga la opción
-- (ES.db.noPostConfirm, Options.lua), que se vuelve a encender en /cj opciones.
-- El anuncio sale del clic en Anunciar: la AH pide un clic del jugador para cada uno
---------------------------------------------------------------------------
local confirm
local function ConfirmDialog()
  if confirm then return confirm end
  local d = CreateFrame("Frame", "CraftersJournalPostConfirm", UIParent, "BackdropTemplate")
  confirm = d
  d:SetSize(380, 170)
  d:SetPoint("CENTER", 0, 120)
  d:SetFrameStrata("DIALOG")
  d:EnableMouse(true)
  d:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  tinsert(UISpecialFrames, "CraftersJournalPostConfirm") -- Escape: cancelar
  d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  d.title:SetPoint("TOP", 0, -20)
  d.text = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  d.text:SetPoint("TOP", d.title, "BOTTOM", 0, -10)
  d.text:SetWidth(330)
  d.check = CreateFrame("CheckButton", nil, d, "UICheckButtonTemplate")
  d.check:SetSize(24, 24)
  d.check:SetPoint("TOPLEFT", 24, -78)
  d.checkLabel = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  d.checkLabel:SetPoint("LEFT", d.check, "RIGHT", 2, 1)
  -- Aviso en naranja (Ctrl+clic: anunciar todas pese a las alertas); oculto si no hay
  d.warn = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  d.warn:SetPoint("TOP", d.text, "BOTTOM", 0, -6)
  d.warn:SetWidth(330)
  d.warn:SetTextColor(1, 0.6, 0.2)
  d.note = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  d.note:SetPoint("TOPLEFT", d.check, "BOTTOMLEFT", 4, -1)
  d.note:SetWidth(320)
  d.note:SetJustifyH("LEFT")
  d.ok = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
  d.ok:SetSize(120, 24)
  d.ok:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -4, 18)
  d.cancel = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
  d.cancel:SetSize(120, 24)
  d.cancel:SetPoint("BOTTOMLEFT", d, "BOTTOM", 4, 18)
  d.cancel:SetScript("OnClick", function() d.pending = nil d:Hide() end)
  d.ok:SetScript("OnClick", function()
    local p = d.pending
    d.pending = nil
    d:Hide()
    if d.check:GetChecked() then
      ES.db.noPostConfirm = true
      ES:Print(L["Ya no se pide confirmación al anunciar. Se vuelve a activar en /cj opciones."])
    end
    if p then
      ES.Ledger:PostOnAH(p.itemID, p.n, p.unit, p.hours)
      if p.done then p.done() end
    end
  end)
  d:Hide()
  return d
end

-- Anuncia `n` de `itemID` a `unit` cada uno (`hours` h), preguntando antes si la opción
-- está activada. `done`: lo que se hace después (repintar). `warn`: aviso que se ve sí o
-- sí (en el diálogo o, sin confirmación, en el chat): anunciar todas pese a las alertas
local WARN_H = 40 -- alto extra del diálogo con aviso (dos líneas)
function Sell.Post(itemID, n, unit, hours, done, warn)
  if not n or n <= 0 then return end
  -- Sin confirmar: una sola unidad (un clic sin querer no hace daño), o si ahora no se
  -- puede (escaneando: PostOnAH ya lo dice)
  if n <= 1 or ES.db.noPostConfirm or (ES.Scanner and ES.Scanner:IsBusy()) then
    if warn and not (ES.Scanner and ES.Scanner:IsBusy()) then ES:Print(warn) end
    ES.Ledger:PostOnAH(itemID, n, unit, hours)
    if done then done() end
    return
  end
  local d = ConfirmDialog()
  d.pending = { itemID = itemID, n = n, unit = unit, hours = hours, done = done }
  d.title:SetText(L["Anunciar en la Casa de Subastas"])
  d.text:SetText(string.format(L["¿Anunciar %d × %s a %s cada uno (%d h)?"], n,
    (ES.UI.ItemLabel(itemID, "#" .. itemID)), ES.Money(ES.Ledger.PostPrice(unit)), hours or 24))
  -- (con aviso, el diálogo crece y la casilla baja para dejarle sitio)
  d.warn:SetText(warn or "")
  if warn then d.warn:Show() else d.warn:Hide() end
  local extra = warn and WARN_H or 0
  d:SetHeight(170 + extra)
  d.check:ClearAllPoints()
  d.check:SetPoint("TOPLEFT", 24, -78 - extra)
  d.check:SetChecked(false)
  d.checkLabel:SetText(L["No volver a preguntar"])
  d.note:SetText(L["Se puede volver a activar en /cj opciones (Confirmar antes de anunciar en la AH)."])
  d.ok:SetText(L["Anunciar"])
  d.cancel:SetText(CANCEL or L["Cancelar"])
  d:Show()
end

-- ¿Las alertas dejaron en la AH solo una parte de lo que podrías vender?
local function Capped(e)
  return (e.sellN or 0) > (e.ahN or 0) and e.verdict ~= "good"
end
Sell.Capped = Capped

-- Aviso de anunciar todas pese a las alertas: qué dicen y cuánto depósito se arriesga
local function AllWarning(e)
  local deposit = e.depositUnit and ES.Calc.Deposit(e.depositUnit, e.sellN, ES.Calc.StackSize(e.itemID))
  local label = ES.Market.LABELS and ES.Market.LABELS[e.verdict] or ""
  if deposit and deposit > 0 then
    return string.format(L["Las alertas del mercado dicen %s: puede que no se vendan todas. Si caducan, pierdes hasta %s de depósito."],
      label, ES.Money(deposit))
  end
  return string.format(L["Las alertas del mercado dicen %s: puede que no se vendan todas."], label)
end
Sell.AllWarning = AllWarning

local function RowClick(self, button)
  local e = self.entry
  if not e then return end
  if button == "RightButton" then
    if ES.Inventory then ES.Inventory.SetNeverSell(e.itemID, true) end
    return
  end
  local refresh = function() C_Timer.After(0.6, function() Sell:Refresh() end) end
  -- Ctrl+clic: todas las que podrías vender, sin el tope de las alertas (avisando)
  if IsControlKeyDown and IsControlKeyDown() and Capped(e) then
    Sell.Post(e.itemID, e.sellN, e.listPrice, e.hours, refresh, AllWarning(e))
    return
  end
  -- Clic: todas las que la fila dice que vendas en la AH (lo normal; esa cantidad ya
  -- es prudente: lo dudoso, pocas y a 8 h), como en la pestaña Inventario.
  -- Mayús+clic: una sola, para probar el precio (como Mayús en las bolsas: una parte)
  local n = (IsShiftKeyDown and IsShiftKeyDown()) and 1 or e.ahN
  Sell.Post(e.itemID, n, e.listPrice, e.hours, refresh)
end

local function RowEnter(self)
  if not self.entry then return end
  if ES.Inventory and ES.Inventory.Tooltip then
    ES.Inventory.Tooltip(self.entry, true)(self) -- (sin sus líneas de clic: aquí van las de esta ventana)
  end
  GameTooltip:AddLine(" ")
  if ES.Ledger:PostPriceState() == "scanning" then
    GameTooltip:AddLine(L["Escaneando la AH: espera a que acabe para anunciarlo."], 1, 0.6, 0.2, true)
    GameTooltip:Show()
    return
  end
  local e = self.entry
  -- Por qué solo unas pocas: el consejo de probar (como en la vista Ruta)
  if Capped(e) then
    GameTooltip:AddLine(string.format(L["Consejo: pon solo %d en la AH a %s para probar y vende el resto al vendedor; si se venden, anuncia más."],
      e.ahN, ES.Money(e.listPrice)), 1, 0.82, 0, true)
    GameTooltip:AddLine(" ")
  end
  GameTooltip:AddLine(string.format(L["Clic: anunciar %d."], e.ahN), 0.5, 0.8, 1)
  if e.ahN > 1 then
    GameTooltip:AddLine(L["Mayús+clic: anunciar solo 1."], 0.5, 0.8, 1)
  end
  if Capped(e) then
    GameTooltip:AddLine(string.format(L["Ctrl+clic: anunciar las %d, sin hacer caso a las alertas."], e.sellN), 0.5, 0.8, 1)
  end
  GameTooltip:AddLine(L["Clic derecho: no venderlo nunca."], 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- Escaneando: una capa oscura sobre las filas con un reloj de arena que se da la
-- vuelta y el %, que se ve de un vistazo que hay que esperar (el subtítulo en naranja
-- pasaba desapercibido). Tapa las filas: ni clic ni tooltip hasta que acabe
-- El reloj, quieto y redondo (máscara circular: sin el borde cuadrado del icono, que
-- girando quedaba mal); alrededor, el anillo de carga del juego dando vueltas
local HOURGLASS = "Interface\\Icons\\Spell_Holy_BorrowedTime"
local RING = "Interface\\COMMON\\StreamCircle"
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RING_SPEED = 2 * math.pi / 1.4 -- una vuelta cada 1,4 s
local function CreateWait(f)
  local w = CreateFrame("Frame", nil, f)
  w:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", -8, -4)
  w:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
  if w.SetFrameLevel and f.GetFrameLevel then w:SetFrameLevel((f:GetFrameLevel() or 1) + 20) end
  w:EnableMouse(true) -- (se traga los clics y el ratón sobre las filas)
  local bg = w:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.8)
  w.icon = w:CreateTexture(nil, "ARTWORK")
  w.icon:SetSize(34, 34)
  w.icon:SetPoint("CENTER", 0, 24)
  w.icon:SetTexture(HOURGLASS)
  w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if w.CreateMaskTexture and w.icon.AddMaskTexture then
    local mask = w:CreateMaskTexture()
    mask:SetAllPoints(w.icon)
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    w.icon:AddMaskTexture(mask)
  end
  w.ring = w:CreateTexture(nil, "OVERLAY")
  w.ring:SetSize(62, 62)
  w.ring:SetPoint("CENTER", w.icon, "CENTER")
  w.ring:SetTexture(RING)
  w.ring:SetVertexColor(1, 0.82, 0.25) -- (dorado, como los textos del addon)
  w.text = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  w.text:SetPoint("TOP", w.icon, "BOTTOM", 0, -18) -- (debajo del anillo)
  w.text:SetWidth(WIDTH - 40)
  w.text:SetJustifyH("CENTER")
  w.note = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  w.note:SetPoint("TOP", w.text, "BOTTOM", 0, -6)
  w.note:SetWidth(WIDTH - 40)
  w.note:SetJustifyH("CENTER")
  w.note:SetText(L["Espera para anunciar: al acabar, los precios se actualizan solos."])
  -- El anillo da vueltas (solo mientras se ve: OnUpdate no corre con la capa oculta)
  local angle = 0
  w:SetScript("OnUpdate", function(_, elapsed)
    angle = (angle - (elapsed or 0) * RING_SPEED) % (2 * math.pi)
    if w.ring.SetRotation then w.ring:SetRotation(angle) end
  end)
  w:Hide()
  return w
end

-- La capa de espera según el escaneo (también al avanzar el %: ES:UpdatePostStatus)
function Sell:UpdateWait()
  if not (panel and panel.wait) then return end
  local state, pct = ES.Ledger:PostPriceState()
  if state == "scanning" then
    panel.wait.text:SetText(string.format(L["Escaneando la AH... %d%%"], pct))
    panel.wait:Show()
  else
    panel.wait:Hide()
  end
end

local function CreatePanel(parent)
  local f = CreateFrame("Frame", "CraftersJournalAuctionSellPanel", parent or UIParent, "BackdropTemplate")
  f:SetWidth(WIDTH)
  -- (el mismo aspecto que la ventana del vendedor)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  local G = ES.UI.BROWN.group
  f:SetBackdropColor(G[1], G[2], G[3], 0.99)
  f:SetBackdropBorderColor(0.52, 0.38, 0.17, 1)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  f:EnableMouse(true)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", 12, -10)
  f.title:SetText("Crafter's Journal")
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function()
    -- (cerrada, no vuelve a salir hasta /reload o hasta abrir otra vez la AH)
    Sell.closed = true
    f:Hide()
    -- La lista de compra pasa a pegarse a la AH (sin hueco). Era PlaceShopping(), una
    -- local declarada más abajo: aquí era un global nil, daba error y no se movía
    if ES.PlaceShoppingMini then ES:PlaceShoppingMini() end
  end)
  f.closeButton = close
  ES:OptionsGear(f, close, "noAuctionSellWindow") -- (menú para quitar esta ventana)
  f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.sub:SetWidth(WIDTH - 24)
  f.sub:SetJustifyH("LEFT")
  f.rows = {}
  for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, f)
    row:SetSize(WIDTH - 16, ROW_H)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0.25, 0.1)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", 2, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
    row.name:SetPoint("RIGHT", row, "RIGHT", -COST_W, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.cost:SetPoint("TOP", row.name, "TOP", 0, 0)
    row.cost:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.cost:SetJustifyH("RIGHT")
    row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.qty:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 1)
    row.qty:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.qty:SetJustifyH("LEFT")
    row.qty:SetWordWrap(false)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = row
  end
  f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.hint:SetJustifyH("LEFT")
  if f.hint.SetSpacing then f.hint:SetSpacing(2) end
  f.wait = CreateWait(f)
  f:Hide()
  return f
end

-- Dónde va: pegada a la AH; la lista de compra pequeña, si sale, a su derecha
-- (ES:PlaceShoppingMini, ShoppingUI.lua)
local function Place(ah)
  panel:ClearAllPoints()
  panel:SetPoint("TOPLEFT", ah, "TOPRIGHT", 2, -12)
end

-- La lista de compra se coloca según si esta ventana se ve
local function PlaceShopping()
  if ES.PlaceShoppingMini then ES:PlaceShoppingMini() end
end

function Sell:Refresh()
  self:HookPanels()
  local ah = AHFrame()
  local main = CraftersJournalMainFrame
  if not (ah and ES:IsAuctionHouseOpen()) or self.closed or (main and main:IsShown()) or not ES:AuctionSellWindowOn() then
    if panel then panel:Hide() end
    PlaceShopping()
    return
  end
  local list = self:List()
  if #list == 0 then
    if panel then panel:Hide() end
    PlaceShopping()
    return
  end
  panel = panel or CreatePanel(ah)
  Place(ah)
  if panel.SetFrameStrata and ah.GetFrameStrata then panel:SetFrameStrata(ah:GetFrameStrata()) end
  -- Precios viejos: en naranja en lugar del subtítulo. Escaneando lo dice la capa de
  -- espera sobre las filas (Sell:UpdateWait; el clic no anuncia, Ledger:PostOnAH)
  local scanning = ES.Ledger:PostPriceState() == "scanning"
  panel.sub:SetText(not scanning and ES.Ledger:PostPriceWarning() or L["Para vender en la AH, de tus bolsas:"])
  local function H(fs) return math.min(tonumber(fs:GetStringHeight()) or 12, 40) end
  local y = -(10 + H(panel.title) + 3 + H(panel.sub) + 8)
  local shown = math.min(#list, MAX_ROWS)
  local anyCapped = false
  for i = 1, shown do
    local row, e = panel.rows[i], list[i]
    row.entry = e
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 8, y)
    y = y - ROW_H
    local _, _, texture = ES:GetItemData(e.itemID)
    row.icon:SetTexture(texture or (GetItemIcon and GetItemIcon(e.itemID)) or 134400)
    row.name:SetText((ES.UI.ItemLabel(e.itemID, "#" .. e.itemID)))
    -- Cuántos y a cuánto se anuncian, la duración y lo que dicen las alertas
    -- (si las alertas dejan solo unas pocas, de cuántas: "5 de 77")
    local verdict = ES.Market.LABELS and ES.Market.LABELS[e.verdict]
    local capped = Capped(e)
    anyCapped = anyCapped or capped
    local qty = capped and string.format(L["Anuncias %d de %d × %s · %d h"], e.ahN, e.sellN, ES.Money(e.listPrice), e.hours or 24)
      or string.format(L["Anuncias %d × %s · %d h"], e.ahN, ES.Money(e.listPrice), e.hours or 24)
    row.qty:SetText(qty .. (verdict and (" · " .. verdict) or ""))
    row.cost:SetText(GREEN .. "+" .. ES.Money(e.ahN * (e.ahUnit or 0)) .. "|r")
    row:Show()
  end
  for k = shown + 1, MAX_ROWS do
    panel.rows[k].entry = nil
    panel.rows[k]:Hide()
  end
  -- A la vista: qué hace el clic y el clic derecho (y cuántas no caben)
  panel.hint:ClearAllPoints()
  panel.hint:SetPoint("TOPLEFT", 12, y - 4)
  panel.hint:SetPoint("RIGHT", panel, "RIGHT", -12, 0)
  -- Una línea por acción, la tecla en el azul de las acciones del addon (antes era una
  -- sola línea gris que se partía y no se leía)
  local KEY = "|cff80ccff"
  local hint = KEY .. L["Clic"] .. "|r  " .. L["anunciar todas"] .. "\n"
    .. KEY .. L["Mayús+clic"] .. "|r  " .. L["anunciar solo 1"] .. "\n"
    .. (anyCapped and (KEY .. L["Ctrl+clic"] .. "|r  " .. L["todas, sin las alertas"] .. "\n") or "")
    .. KEY .. L["Clic derecho"] .. "|r  " .. L["no venderlo nunca"]
  if #list > shown then
    hint = hint .. "\n" .. GREY .. string.format(L["(%d más en la pestaña Inventario)"], #list - shown) .. "|r"
  end
  panel.hint:SetText(hint)
  -- (hasta 5 líneas: con Ctrl+clic y "N más en la pestaña Inventario")
  y = y - 4 - math.max(14, math.min(tonumber(panel.hint:GetStringHeight()) or 0, 90))
  panel:SetHeight(-y + 10)
  self:UpdateWait()
  panel:Show()
  ES:WindowTip("sell") -- (la primera vez: se puede quitar en /cj opciones)
  PlaceShopping() -- (la lista de compra, a la derecha de esta)
end

do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }) do
    ES.SafeRegister(f, e)
  end
  local queued = false
  f:SetScript("OnEvent", function(_, event)
    if not ES.db then return end
    if event == "AUCTION_HOUSE_CLOSED" then
      Sell.closed = nil
      if panel then panel:Hide() end
      if confirm then confirm.pending = nil confirm:Hide() end -- (sin AH no se puede anunciar)
      return
    end
    if event == "AUCTION_HOUSE_SHOW" then Sell.closed = nil end
    -- Con la AH cerrada no hay nada que hacer: GET_ITEM_INFO_RECEIVED y los cambios de
    -- bolsas llegan sin parar yendo por el mundo (otros addons piden objetos) y cada uno
    -- programaba un repintado
    if event ~= "AUCTION_HOUSE_SHOW" and not ES:IsAuctionHouseOpen() then return end
    -- (agrupado: al abrir la AH la lista de compra pequeña se coloca primero)
    if not queued then
      queued = true
      C_Timer.After(0.3, function()
        queued = false
        Sell:Refresh()
      end)
    end
  end)
end

-- La ventana grande aparece o se va (con ella al lado de la AH, esta no sale)
function Sell:HookPanels()
  local main = CraftersJournalMainFrame
  if main and not main.cjSellHook then
    main.cjSellHook = true
    main:HookScript("OnShow", function() Sell:Refresh() end)
    main:HookScript("OnHide", function() Sell:Refresh() end)
  end
end
