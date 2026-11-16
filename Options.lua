local _, ES = ...
local L = ES.L

---------------------------------------------------------------------------
-- Opciones del addon, en su propia ventana (ES:OpenOptions): la abren el engranaje de
-- la cabecera (junto al idioma), /cj opciones y "Todas las opciones" del menú del
-- engranaje de las ventanas junto al vendedor, la AH y la profesión. A la izquierda,
-- las categorías (General y una por pestaña o ventana con opciones); a la derecha, las
-- casillas de la elegida. Ya no se registran en las opciones del juego (AddOns).
-- Si salen solas las ventanas junto al vendedor y junto a la Casa de Subastas, y si se
-- propone vender tu equipo (ligado o en un conjunto), entre otras:
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
-- Nombre de una opción (su etiqueta en el panel), para el menú del engranaje
local function OptionLabel(key)
  for _, o in ipairs(ES.OPTIONS or {}) do
    if o.key == key then return L[o.label] end
  end
end

-- Menú pequeño del engranaje: la opción justa de esa ventana ("No mostrar esta
-- ventana", lo mismo que quitar su casilla en las opciones) y, debajo, todas las
-- opciones. Antes el engranaje abría el panel entero y había que buscar la casilla
local function GearMenu(gear, frame, key)
  local m = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  m:SetSize(230, 112)
  m:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 6, -4)
  if m.SetFrameStrata then m:SetFrameStrata("DIALOG") end
  if m.SetClampedToScreen then m:SetClampedToScreen(true) end
  m:EnableMouse(true)
  m:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  m:SetBackdropColor(0.08, 0.06, 0.04, 0.98)
  m:SetBackdropBorderColor(0.52, 0.38, 0.17, 1)
  m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  m.title:SetPoint("TOPLEFT", 12, -10)
  m.title:SetPoint("RIGHT", -12, 0)
  m.title:SetJustifyH("LEFT")
  m.title:SetWordWrap(false)
  m.off = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
  m.off:SetSize(206, 24)
  m.off:SetPoint("TOP", 0, -30)
  m.off:SetScript("OnClick", function()
    m.open = false
    m:Hide()
    ES:SetOption(key, false) -- (como quitar su casilla: la ventana se cierra al momento)
    ES:Print(string.format(L["%s: desactivada. Vuelve a activarla en /cj opciones."], OptionLabel(key) or key))
  end)
  m.note = m:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  m.note:SetPoint("TOP", m.off, "BOTTOM", 0, -5)
  m.note:SetWidth(206)
  m.all = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
  m.all:SetSize(206, 22)
  m.all:SetPoint("BOTTOM", 0, 10)
  m.all:SetScript("OnClick", function()
    m.open = false
    m:Hide()
    ES:OpenOptions(ES:OptionCategory(key)) -- (en la categoría de esta ventana)
  end)
  -- Textos al mostrarse (el idioma puede haber cambiado)
  m:SetScript("OnShow", function()
    m.title:SetText(OptionLabel(key) or "Crafter's Journal")
    m.off:SetText(L["No mostrar esta ventana"])
    m.note:SetText(L["Se vuelve a activar en /cj opciones."])
    m.all:SetText(L["Todas las opciones"])
  end)
  m:SetScript("OnHide", function() m.open = false end)
  m:Hide()
  return m
end

-- Dibujo de un botón de engranaje (el de las ventanas de al lado y el de la cabecera)
-- El engranaje de 64 px del mapa (el cuarto de arriba a la izquierda del archivo): se
-- ve nítido al reducirlo. El de antes (UI-OptionsButton) es pequeño y salía borroso.
-- Lo usa también ForeverRecipeBook en este cliente. En gris y teñido de dorado
local GEAR = "Interface\\WorldMap\\Gear_64.png"
local function GearTexture(tex, r, g, b)
  if not tex then return end
  tex:SetTexture(GEAR)
  tex:SetTexCoord(0, 0.5, 0, 0.5)
  tex:SetDesaturated(true)
  tex:SetVertexColor(r, g, b)
end
function ES.StyleGear(b)
  -- Apagado como el resto de la cabecera; al pasar el ratón, se ilumina el mismo engranaje
  -- (el recuadro de UI-Common-MouseHilight se veía como un cuadrado)
  b:SetNormalTexture(GEAR)
  GearTexture(b:GetNormalTexture(), 0.88, 0.72, 0.38)
  local hover = b:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  GearTexture(hover, 1, 0.85, 0.45)
  hover:SetAlpha(0.5)
  b:SetHighlightTexture(hover, "ADD")
  b:SetPushedTexture(GEAR)
  local pushed = b:GetPushedTexture()
  if pushed then
    GearTexture(pushed, 0.66, 0.54, 0.3)
    pushed:ClearAllPoints()
    pushed:SetPoint("TOPLEFT", 1, -1)
    pushed:SetPoint("BOTTOMRIGHT", 1, -1)
  end
end

-- Engranaje en la esquina de las ventanas que salen solas (vendedor, AH, profesión).
-- `close`: su ✕, si tiene (va a su izquierda). `key`: la opción que la quita; con
-- ella, el clic abre un menú pequeño con esa opción (GearMenu); sin ella, el panel
function ES:OptionsGear(frame, close, key)
  local b = CreateFrame("Button", nil, frame)
  b:SetSize(18, 18)
  -- La ✕ (UIPanelCloseButton) mide 32 px con ~6 de aire alrededor del dibujo: pegado a
  -- su borde ya queda separado. Antes iba 4 px dentro y se montaba sobre la ✕ (y algo
  -- más alto, el dibujo de la ✕ está 1 px por debajo del centro)
  if close then b:SetPoint("RIGHT", close, "LEFT", 0, -1) else b:SetPoint("TOPRIGHT", -9, -9) end
  ES.StyleGear(b)
  b:SetScript("OnClick", function()
    if not key then ES:OpenOptions() return end
    b.menu = b.menu or GearMenu(b, frame, key)
    GameTooltip:Hide()
    -- (abierto o no: su propia marca, que OnHide pone a false también cuando se
    -- cierra la ventana de debajo)
    b.menu.open = not b.menu.open
    b.menu:SetShown(b.menu.open)
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Opciones"])
    GameTooltip:AddLine(L["Clic: dejar de mostrar esta ventana, o ver todas las opciones."], 1, 1, 1, true)
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
  -- General
  -- (se guarda en ES.db.minimap.hide, el sitio de LibDBIcon: también /cj minimap)
  { key = "minimap", cat = "general", label = "Botón del minimapa", desc = "El botón de Crafter's Journal junto al minimapa. También con /cj minimap.",
    get = function() return not (ES.db.minimap and ES.db.minimap.hide) end,
    set = function(on) ES:SetMinimapShown(on) end },
  { key = "noChatAlerts", cat = "general", label = "Avisos en el chat",
    desc = "Tras un escaneo: recetas de botín que te faltan y están en la AH, y si tu ruta empezada cuesta bastante más con los precios nuevos. Desactivados, la ruta lo sigue diciendo en su línea de estado." },
  -- Lista de compra
  { key = "noAuctionWindows", cat = "shopping", label = "Lista de compra junto a la Casa de Subastas",
    desc = "Al abrir la AH: los materiales de tu ruta que te faltan, para comprarlos. Desactivada, se sigue pudiendo abrir con el botón de encima de la AH." },
  -- Casa de Subastas
  { key = "noAuctionSellWindow", cat = "auction", label = "Vender en la AH desde tus bolsas",
    desc = "Al abrir la AH: una ventana con lo de tus bolsas que se vende mejor en la AH. Clic en una fila para anunciarlo." },
  { key = "noPostConfirm", cat = "auction", label = "Confirmar antes de anunciar en la AH",
    desc = "Al anunciar más de una unidad de golpe (ventana de vender, Inventario, ruta), pregunta antes cuántas y a qué precio. Así un clic sin querer no anuncia un montón." },
  { key = "noForeignScans", cat = "auction", label = "Leer los escaneos de otros addons",
    desc = "Si otro addon (Auctionator...) escanea la AH, se leen sus precios y no hace falta escanear dos veces. Desactivada, si ese addon escanea al abrir la AH casi nunca podrás escanear tú (uno cada 15 min)." },
  -- Vendedor
  { key = "noVendorWindow", cat = "vendor", label = "Ventana junto al vendedor",
    desc = "Al abrir un vendedor: lo que te falta de la lista de compra y lo que puedes venderle, con los botones Comprar todo y Vender todo." },
  -- Inventario (qué se propone vender: también la ventana del vendedor)
  -- (por defecto desactivada: se propone todo y lo tuyo lo apartas con clic derecho)
  { key = "protectGear", cat = "inventory", label = "No vender tu equipo",
    desc = "Activado, el equipo ligado a ti (tu otro equipo, lo de las misiones) y el de los conjuntos del gestor de equipo no se propone vender (ni Vender todo lo vende); los verdes sin ligar de botín, lo que fabricas y lo gris, sí. Desactivado, se propone todo: lo que quieras guardar, clic derecho y no se vende nunca.",
    get = function() return ES.db.protectGear == true end,
    set = function(on) ES.db.protectGear = on or nil ES:ApplyOptions("protectGear", on) end },
  { key = "noAddonPrices", cat = "inventory", label = "Usar los precios de Auctionator o TSM",
    desc = "Si tu escaneo no tiene un objeto de tus bolsas, se usa el precio que guarda Auctionator o TSM para decidir si va a la AH o al vendedor. Tu escaneo siempre manda." },
  -- Ganar dinero (la ventana junto a la profesión enseña lo que propone esa pestaña)
  { key = "noCraftWindow", cat = "earn", label = "Ventana junto a la profesión",
    desc = "Al abrir una profesión: lo que la pestaña Ganar dinero propone fabricar de esa profesión. Clic en una fila para fabricarlo." },
}
ES.OPTIONS = OPTIONS -- (el menú del engranaje saca de aquí el nombre de cada ventana)

-- Categorías de la ventana, en el orden de la lista de la izquierda: General y una por
-- pestaña o ventana que tiene opciones (cada opción dice la suya en `cat`)
local CATEGORIES = {
  { key = "general",   label = "General" },
  { key = "shopping",  label = "Lista de compra" },
  { key = "auction",   label = "Casa de Subastas" },
  { key = "vendor",    label = "Vendedor" },
  { key = "inventory", label = "Inventario" },
  { key = "earn",      label = "Ganar dinero" },
}
ES.OPTION_CATEGORIES = CATEGORIES

-- Categoría de una opción (para abrir la ventana justo donde está)
function ES:OptionCategory(key)
  for _, o in ipairs(OPTIONS) do
    if o.key == key then return o.cat end
  end
end

---------------------------------------------------------------------------
-- Ventana de opciones, al estilo de la del diario de mazmorras: cabecera con el
-- título y la ✕, categorías a la izquierda y, a la derecha, el nombre de la elegida
-- y sus casillas (con rueda y guía si no caben)
---------------------------------------------------------------------------
local WIN_W, WIN_H = 660, 440
local PAD, TOP = 14, 52       -- márgenes; TOP: bajo la cabecera
local SIDE_W = 176            -- lista de categorías
local GOLD = { 0.96, 0.79, 0.25 }
local CONTENT_W = WIN_W - PAD * 2 - SIDE_W - 8 - 24 -- ancho de las casillas (sin la guía)
local DESC_W = CONTENT_W - 44

local function Box(parent, r, g, b, a)
  local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  p:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  p:SetBackdropColor(r, g, b, a)
  p:SetBackdropBorderColor(0.52, 0.38, 0.17, 1)
  return p
end

-- Una casilla: marca, nombre y, debajo, qué hace
local function CreateCheck(page, o)
  local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb.label = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 6, 1)
  cb.label:SetWidth(DESC_W)
  cb.label:SetJustifyH("LEFT")
  cb.desc = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cb.desc:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -5)
  cb.desc:SetWidth(DESC_W)
  cb.desc:SetJustifyH("LEFT")
  cb.desc:SetTextColor(0.78, 0.74, 0.66)
  cb.option = o
  cb:SetScript("OnClick", function(self)
    local on = self:GetChecked() and true or false
    if o.set then o.set(on) else ES:SetOption(o.key, on) end
  end)
  return cb
end

-- Textos y marcas de una categoría (el idioma o las opciones pueden haber cambiado) y
-- las filas una debajo de otra: cada una mide lo que ocupe su descripción
local function RefreshPage(page)
  local y = -6
  for _, cb in ipairs(page.checks) do
    local o = cb.option
    cb.label:SetText(L[o.label])
    cb.desc:SetText(L[o.desc])
    if o.get then cb:SetChecked(o.get()) else cb:SetChecked(not ES.db[o.key]) end
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", 6, y)
    local descH = tonumber(cb.desc:GetStringHeight()) or 0
    y = y - math.max(30, 24 + descH) - 14
  end
  page:SetHeight(math.max(1, -y))
end

local function CategoryButton(f, i, cat)
  local b = CreateFrame("Button", nil, f.side)
  b:SetHeight(24)
  b:SetPoint("TOPLEFT", 8, -10 - (i - 1) * 26)
  b:SetPoint("TOPRIGHT", -8, -10 - (i - 1) * 26)
  -- La elegida: fondo dorado suave con una barra a la izquierda
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints()
  b.sel:SetColorTexture(0.68, 0.52, 0.20, 0.28)
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetPoint("TOPLEFT", 0, 0)
  b.bar:SetPoint("BOTTOMLEFT", 0, 0)
  b.bar:SetWidth(3)
  b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.text:SetPoint("LEFT", 12, 0)
  b.text:SetPoint("RIGHT", -6, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  b.key = cat.key
  b:SetScript("OnClick", function() f:SelectCategory(cat.key) end)
  return b
end

local window
local function CreateWindow()
  local f = CreateFrame("Frame", "CraftersJournalOptionsFrame", UIParent, "BackdropTemplate")
  f:SetSize(WIN_W, WIN_H)
  -- El marco de la ventana principal: roca oscura con borde de diálogo
  f:SetBackdrop({
    bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(0.045, 0.042, 0.037, 0.99)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetFrameStrata("DIALOG") -- (encima de la ventana principal, que va en HIGH)
  f:Hide()
  tinsert(UISpecialFrames, "CraftersJournalOptionsFrame") -- cerrar con Escape

  -- Cabecera: banda marrón con líneas doradas, como la de la ventana principal
  local band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  band:SetPoint("TOPLEFT", 12, -10)
  band:SetPoint("TOPRIGHT", -12, -10)
  band:SetHeight(32)
  band:SetColorTexture(0.14, 0.10, 0.055, 0.96)
  for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", 0.65 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0.45 } }) do
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetPoint(edge[1], band, edge[1], 0, 0)
    line:SetPoint(edge[2], band, edge[2], 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.68, 0.52, 0.20, edge[3])
  end
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOP", 0, -18)
  f.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  f.closeButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  f.closeButton:SetPoint("TOPRIGHT", -3, -3)
  -- Esquina para ampliar o reducir, como la ventana principal (escala en ES.db.optionsScale)
  ES.AddScaleGrip(f, "optionsScale")

  -- Izquierda: las categorías
  f.side = Box(f, 0.13, 0.095, 0.06, 0.95)
  f.side:SetPoint("TOPLEFT", PAD, -TOP)
  f.side:SetPoint("BOTTOMLEFT", PAD, PAD)
  f.side:SetWidth(SIDE_W)
  f.categoryButtons = {}
  for i, cat in ipairs(CATEGORIES) do f.categoryButtons[i] = CategoryButton(f, i, cat) end

  -- Abajo de las categorías: la versión del addon, pequeña y en blanco suave, y encima
  -- una invitación al Discord (abre la ventana con el enlace para copiarlo)
  f.version = f.side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.version:SetPoint("BOTTOM", 0, 10)
  f.version:SetTextColor(0.78, 0.76, 0.72)
  f.version:SetAlpha(0.75)
  local discord = CreateFrame("Button", nil, f.side, "BackdropTemplate")
  f.discordButton = discord
  discord:SetPoint("BOTTOMLEFT", 8, 28)
  discord:SetPoint("BOTTOMRIGHT", -8, 28)
  discord:SetHeight(42)
  discord:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  discord:SetBackdropColor(0.20, 0.16, 0.10, 0.95)
  discord:SetBackdropBorderColor(0.68, 0.52, 0.20, 0.9)
  discord:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  discord.icon = discord:CreateTexture(nil, "OVERLAY")
  discord.icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
  discord.icon:SetSize(22, 22)
  discord.icon:SetPoint("LEFT", 8, 0)
  discord.title = discord:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  discord.title:SetPoint("TOPLEFT", discord.icon, "TOPRIGHT", 6, 1)
  discord.title:SetPoint("RIGHT", -6, 0)
  discord.title:SetJustifyH("LEFT")
  discord.title:SetWordWrap(false)
  discord.sub = discord:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  discord.sub:SetPoint("TOPLEFT", discord.title, "BOTTOMLEFT", 0, -3)
  discord.sub:SetPoint("RIGHT", -6, 0)
  discord.sub:SetJustifyH("LEFT")
  discord.sub:SetWordWrap(false)
  discord.sub:SetTextColor(0.78, 0.76, 0.72)
  discord:SetScript("OnClick", function() ES:ShowReportDialog("join") end)

  -- Derecha: nombre de la categoría, línea dorada y sus casillas
  f.body = Box(f, 0.18, 0.14, 0.10, 0.95)
  f.body:SetPoint("TOPLEFT", f.side, "TOPRIGHT", 8, 0)
  f.body:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  f.heading = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.heading:SetPoint("TOPLEFT", 18, -14)
  f.heading:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  local rule = f.body:CreateTexture(nil, "ARTWORK")
  rule:SetPoint("TOPLEFT", 14, -40)
  rule:SetPoint("TOPRIGHT", -14, -40)
  rule:SetHeight(1)
  rule:SetColorTexture(0.68, 0.52, 0.20, 0.55)
  f.scroll = ES.UI.WheelScroll(f.body, 40)
  f.scroll:SetPoint("TOPLEFT", 10, -48)
  f.scroll:SetPoint("BOTTOMRIGHT", -14, 10)
  -- (la guía mide la página que se ve ahora)
  local shown = { GetHeight = function()
    local page = f.pages[f.selected or ""]
    return page and page:GetHeight() or 0
  end }
  f.indicator = ES.UI.ScrollIndicator(f.scroll, shown, 5)

  -- Una página por categoría, con sus casillas. f.checks: todas, en el orden de OPTIONS
  f.pages, f.checks = {}, {}
  for _, cat in ipairs(CATEGORIES) do
    local page = CreateFrame("Frame", nil, f.scroll)
    page:SetSize(CONTENT_W, 1)
    page:Hide()
    page.key, page.label, page.checks = cat.key, cat.label, {}
    f.pages[cat.key] = page
  end
  for _, o in ipairs(OPTIONS) do
    local page = f.pages[o.cat] or f.pages.general
    local cb = CreateCheck(page, o)
    page.checks[#page.checks + 1] = cb
    f.checks[#f.checks + 1] = cb
  end

  -- Enseña una categoría (la de antes si no existe la pedida)
  function f:SelectCategory(key)
    local page = self.pages[key] or self.pages[self.selected or ""] or self.pages.general
    self.selected = page.key
    for _, b in ipairs(self.categoryButtons) do
      local on = b.key == page.key
      b.sel:SetShown(on)
      b.bar:SetShown(on)
      if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
    end
    for _, p in pairs(self.pages) do p:SetShown(p == page) end
    self.heading:SetText(L[page.label])
    RefreshPage(page)
    self.scroll:SetScrollChild(page)
    if self.scroll.UpdateScrollChildRect then self.scroll:UpdateScrollChildRect() end
    self.scroll:SetVerticalScroll(0)
    self.indicator:Update()
  end

  -- Textos al mostrarse: el idioma o las opciones pueden haber cambiado
  function f:Refresh()
    self.title:SetText("Crafter's Journal · " .. L["Opciones"])
    for i, b in ipairs(self.categoryButtons) do b.text:SetText(L[CATEGORIES[i].label]) end
    self.discordButton.title:SetText(L["Únete a nuestro Discord"])
    self.discordButton.sub:SetText(L["Ideas, errores y novedades"])
    local version = ES.AddonVersion and ES.AddonVersion()
    self.version:SetText(version and string.format(L["Versión %s"], version) or "")
    self:SelectCategory(self.selected or "general")
  end
  f:SetScript("OnShow", function(self) self:Refresh() end)
  return f
end

-- La ventana de opciones (se crea la primera vez)
function ES:OptionsWindow()
  window = window or CreateWindow()
  return window
end

-- Abre las opciones; `category` (opcional): la que se enseña, si no la última vista
function ES:OpenOptions(category)
  local w = self:OptionsWindow()
  if category then w.selected = category end
  if w:IsShown() then w:Refresh() else w:Show() end
end

-- Engranaje de la cabecera: abre o cierra la ventana
function ES:ToggleOptions()
  if window and window:IsShown() then window:Hide() return end
  self:OpenOptions()
end
