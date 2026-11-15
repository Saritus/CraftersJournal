local _, ES = ...
local L = ES.L

---------------------------------------------------------------------------
-- Opciones del addon, en las opciones del juego (Opciones > AddOns > Crafter's
-- Journal) y con /cj opciones: si salen solas las ventanas junto al vendedor y junto
-- a la Casa de Subastas, y si se propone vender tu equipo (ligado o en un conjunto).
--   ES.db.protectGear      = true: tu equipo (ligado o en un conjunto) no se propone
--                            vender (InventoryUI.lua). Por defecto no: se propone todo
--   ES.db.noChatAlerts     = true: sin los avisos del chat tras un escaneo (recetas
--                            de botín en la AH, ruta que cuesta más con precios nuevos)
--   ES.db.minimap.hide     = true: sin botón del minimapa (LibDBIcon)
--   ES.db.noVendorWindow   = true: no sale la ventana junto al vendedor
--   ES.db.noCraftWindow    = true: no sale la ventana de Ganar dinero junto a la
--                            ventana de una profesión (CraftWindowUI.lua)
--   ES.db.noAuctionWindows = true: no sale sola la lista de compra junto a la AH; el
--                            botón de la AH la sigue abriendo a mano
--   ES.db.noAuctionSellWindow = true: no sale la ventana de vender en la AH lo de tus
--                            bolsas (AuctionSellUI.lua). Antes iba con noAuctionWindows:
--                            quien la tenía desactivada sigue sin las dos (ver Migrate)
--   ES.db.noForeignScans   = true: no se lee el escaneo que pide otro addon (Scanner.lua,
--                            OnForeignScan); su barrera de 15 min se sigue anotando
--   ES.db.noPostConfirm    = true: anunciar en la AH sin preguntar antes (AuctionSellUI.lua,
--                            Sell.Post). Se apaga también con "No volver a preguntar"
-- Todas salen por defecto (es lo normal del addon); la primera vez que sale cada una
-- se dice en el chat que se puede quitar aquí (ES:WindowTip)
---------------------------------------------------------------------------

function ES:VendorWindowOn() return not (self.db and self.db.noVendorWindow) end
function ES:AuctionWindowsOn() return not (self.db and self.db.noAuctionWindows) end
function ES:AuctionSellWindowOn() return not (self.db and self.db.noAuctionSellWindow) end

-- Una vez: quien había quitado las ventanas de la AH (eran una sola opción) tampoco
-- ve la de vender ahora que va aparte
function ES:MigrateWindowOptions()
  local db = self.db
  if not db or db.sellWindowSplit then return end
  db.sellWindowSplit = true
  if db.noAuctionWindows and db.noAuctionSellWindow == nil then db.noAuctionSellWindow = true end
  db.auctionSellWindow = nil -- (de una prueba en la que venía desactivada por defecto)
end

-- La primera vez que sale sola cada ventana (junto al vendedor, la AH o la
-- profesión), un aviso en el chat: se puede quitar en /cj opciones. CurseForge: no
-- sabían que se podía y les parecía que el addon se metía en medio
local TIPS = {
  vendor = "Esta ventana sale sola al abrir un vendedor. Si no la quieres, quítala en /cj opciones.",
  shopping = "La lista de compra sale sola al abrir la Casa de Subastas. Si no la quieres, quítala en /cj opciones.",
  sell = "La ventana de vender en la AH sale sola al abrir la Casa de Subastas. Si no la quieres, quítala en /cj opciones.",
  craft = "Esta ventana sale sola al abrir una profesión. Si no la quieres, quítala en /cj opciones.",
}
-- Engranaje en la esquina de las ventanas que salen solas (vendedor, AH, profesión):
-- abre estas opciones, donde se quita. `close`: su ✕, si tiene (va a su izquierda)
function ES:OptionsGear(frame, close)
  local b = CreateFrame("Button", nil, frame)
  b:SetSize(18, 18)
  -- La ✕ (UIPanelCloseButton) mide 32 px con ~6 de aire alrededor del dibujo: pegado a
  -- su borde ya queda separado. Antes iba 4 px dentro y se montaba sobre la ✕ (y algo
  -- más alto, el dibujo de la ✕ está 1 px por debajo del centro)
  if close then b:SetPoint("RIGHT", close, "LEFT", 0, -1) else b:SetPoint("TOPRIGHT", -9, -9) end
  local GEAR = "Interface\\Buttons\\UI-OptionsButton"
  b:SetNormalTexture(GEAR)
  -- Apagado como el resto de la cabecera; al pasar el ratón, se ilumina el mismo engranaje
  -- (el recuadro de UI-Common-MouseHilight se veía como un cuadrado)
  local normal = b:GetNormalTexture()
  if normal and normal.SetVertexColor then normal:SetVertexColor(0.8, 0.7, 0.5) end
  b:SetHighlightTexture(GEAR, "ADD")
  b:SetPushedTexture(GEAR)
  local pushed = b:GetPushedTexture()
  if pushed then
    pushed:ClearAllPoints()
    pushed:SetPoint("TOPLEFT", 1, -1)
    pushed:SetPoint("BOTTOMRIGHT", 1, -1)
    if pushed.SetVertexColor then pushed:SetVertexColor(0.6, 0.5, 0.35) end
  end
  b:SetScript("OnClick", function() ES:OpenOptions() end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Opciones"])
    GameTooltip:AddLine(L["Si no quieres que esta ventana salga sola, quítala en las opciones."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.optionsGear = b
  return b
end

function ES:WindowTip(kind)
  local db = self.db
  if not db or not TIPS[kind] then return end
  if type(db.windowTips) ~= "table" then db.windowTips = {} end
  if db.windowTips[kind] then return end
  db.windowTips[kind] = true
  self:Print(L[TIPS[kind]])
end
function ES:CraftWindowOn() return not (self.db and self.db.noCraftWindow) end

-- Cambia una opción (on: la casilla marcada) y lo aplica al momento: la pestaña
-- Inventario y las ventanas del vendedor y la AH, si están abiertos
function ES:SetOption(key, on)
  self.db[key] = (not on) or nil
  self:ApplyOptions(key, on)
end

function ES:ApplyOptions(key, on)
  if self.RenderInventory then self:RenderInventory() end
  if self.VendorShop and self.VendorShop.Refresh then self.VendorShop:Refresh() end
  if self.AuctionSell and self.AuctionSell.Refresh then self.AuctionSell:Refresh() end
  if self.CraftWindow and self.CraftWindow.Refresh then self.CraftWindow:Refresh() end
  -- (la lista de compra: desactivada se quita; activada sale la próxima vez que
  -- abras la AH, o ya con el botón de encima de la AH)
  local mini = self.ShoppingMini and self.ShoppingMini()
  if key == "noAuctionWindows" and not on and mini then mini:Hide() end
end

local OPTIONS = {
  { key = "noVendorWindow", label = "Ventana junto al vendedor",
    desc = "Al abrir un vendedor: lo que te falta de la lista de compra y lo que puedes venderle, con los botones Comprar todo y Vender todo." },
  { key = "noAuctionWindows", label = "Lista de compra junto a la Casa de Subastas",
    desc = "Al abrir la AH: los materiales de tu ruta que te faltan, para comprarlos. Desactivada, se sigue pudiendo abrir con el botón de encima de la AH." },
  { key = "noAuctionSellWindow", label = "Vender en la AH desde tus bolsas",
    desc = "Al abrir la AH: una ventana con lo de tus bolsas que se vende mejor en la AH. Clic en una fila para anunciarlo." },
  { key = "noForeignScans", label = "Leer los escaneos de otros addons",
    desc = "Si otro addon (Auctionator...) escanea la AH, se leen sus precios y no hace falta escanear dos veces. Desactivada, si ese addon escanea al abrir la AH casi nunca podrás escanear tú (uno cada 15 min)." },
  { key = "noPostConfirm", label = "Confirmar antes de anunciar en la AH",
    desc = "Al anunciar más de una unidad de golpe (ventana de vender, Inventario, ruta), pregunta antes cuántas y a qué precio. Así un clic sin querer no anuncia un montón." },
  { key = "noCraftWindow", label = "Ventana junto a la profesión",
    desc = "Al abrir una profesión: lo que la pestaña Ganar dinero propone fabricar de esa profesión. Clic en una fila para fabricarlo." },
  -- (por defecto desactivada: se propone todo y lo tuyo lo apartas con clic derecho)
  { key = "protectGear", label = "No vender tu equipo",
    desc = "Activado, el equipo ligado a ti (tu otro equipo, lo de las misiones) y el de los conjuntos del gestor de equipo no se propone vender (ni Vender todo lo vende); los verdes sin ligar de botín, lo que fabricas y lo gris, sí. Desactivado, se propone todo: lo que quieras guardar, clic derecho y no se vende nunca.",
    get = function() return ES.db.protectGear == true end,
    set = function(on) ES.db.protectGear = on or nil ES:ApplyOptions("protectGear", on) end },
  { key = "noChatAlerts", label = "Avisos en el chat",
    desc = "Tras un escaneo: recetas de botín que te faltan y están en la AH, y si tu ruta empezada cuesta bastante más con los precios nuevos. Desactivados, la ruta lo sigue diciendo en su línea de estado." },
  -- (se guarda en ES.db.minimap.hide, el sitio de LibDBIcon: también /cj minimap)
  { key = "minimap", label = "Botón del minimapa", desc = "El botón de Crafter's Journal junto al minimapa. También con /cj minimap.",
    get = function() return not (ES.db.minimap and ES.db.minimap.hide) end,
    set = function(on) ES:SetMinimapShown(on) end },
}

local panel
local function CreatePanel()
  local p = CreateFrame("Frame", "CraftersJournalOptionsPanel", UIParent)
  p.name = "Crafter's Journal"
  p:Hide()
  p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  p.title:SetPoint("TOPLEFT", 16, -16)
  p.title:SetText("Crafter's Journal")
  p.checks = {}
  local y = -56
  for i, o in ipairs(OPTIONS) do
    local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 16, y)
    cb.label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.desc = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cb.desc:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -4)
    cb.desc:SetWidth(520)
    cb.desc:SetJustifyH("LEFT")
    cb.option = o
    cb:SetScript("OnClick", function(self)
      local on = self:GetChecked() and true or false
      if o.set then o.set(on) else ES:SetOption(o.key, on) end
    end)
    p.checks[i] = cb
    y = y - 58 -- (ya son 9: con 70 la última quedaba muy abajo)
  end
  -- Textos y casillas al mostrarse: el idioma o las opciones pueden haber cambiado
  p:SetScript("OnShow", function(self)
    self.sub = self.sub or self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6)
    self.sub:SetText(L["Ventanas, qué se propone vender, avisos y botón del minimapa."])
    for _, cb in ipairs(self.checks) do
      cb.label:SetText(L[cb.option.label])
      cb.desc:SetText(L[cb.option.desc])
      local o = cb.option
      if o.get then cb:SetChecked(o.get()) else cb:SetChecked(not ES.db[o.key]) end
    end
  end)
  -- Opciones del juego: la API nueva (Settings) o la de antes
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(p, p.name)
    Settings.RegisterAddOnCategory(category)
    ES.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(p)
  end
  return p
end

function ES:OptionsPanel()
  panel = panel or CreatePanel()
  return panel
end

function ES:OpenOptions()
  local p = self:OptionsPanel()
  if Settings and Settings.OpenToCategory and self.optionsCategory then
    local id = self.optionsCategory.GetID and self.optionsCategory:GetID() or self.optionsCategory.ID
    Settings.OpenToCategory(id)
  elseif InterfaceOptionsFrame_OpenToCategory then
    -- (la primera vez a veces abre la página general: se repite)
    InterfaceOptionsFrame_OpenToCategory(p)
    InterfaceOptionsFrame_OpenToCategory(p)
  else
    p:Show()
  end
end

-- Se registra al entrar (con ES.db ya cargada), para que salga en las opciones del juego
do
  local f = CreateFrame("Frame")
  ES.SafeRegister(f, "PLAYER_LOGIN")
  f:SetScript("OnEvent", function() if ES.db then ES:OptionsPanel() end end)
end
