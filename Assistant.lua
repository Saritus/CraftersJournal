local _, ES = ...
local L = ES.L

-- Asistente de ruta (docs/ASISTENTE.md): un banner pequeño y flotante con el paso
-- actual de la ruta empezada, para seguirla sin abrir la ventana del addon.
--   · Lo que enseña y lo que hace al pulsar es la fila `current` de la vista Ruta
--     (ES:RouteLines): el asistente NUNCA decide nada de la ruta por su cuenta.
--   · Un solo asistente, de la última ruta empezada. Sale solo con una ruta empezada;
--     la × lo cierra para esa ruta (vuelve con /cj mini o al empezar otra).
--   · Debajo, una tira fina: ◀ ▶ para ojear los pasos, tu nivel y el progreso del paso.

local A = {}
ES.Assistant = A

local WIDTH, BANNER_MIN, ICON, LEVEL_W = 420, 64, 42, 64
local PAD, CLOSE_SIZE, ARROW_GAP = 12, 22, 4 -- margen del marco, la X y las flechas, flecha-banner
local SIDE = CLOSE_SIZE + ARROW_GAP + 6 -- margen a los lados: ahí van ◀ ▶
local MEDIA = "Interface\\AddOns\\CraftersJournal\\Media\\Assistant\\"
local PEEK_SECONDS = 8  -- ojeando otro paso: vuelve solo al actual
local GREY, GREEN = "|cff999999", "|cff40ff40"
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.6, 1.6, 0.1

local frame, banner, arrows, menu, useButton
local state = { steps = {}, index = nil, peek = nil }

local function DB()
  ES.db.assistant = ES.db.assistant or {}
  return ES.db.assistant
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- La profesión que sigue: la de la última ruta empezada (las rutas son de cada personaje)
function A.Profession()
  local best, started
  for _, p in ipairs(ES.PROFESSIONS or {}) do
    local lock = ES.Data[p.key] and ES.db.prof and ES:RouteLock(p.key)
    if lock and (not started or (lock.started or 0) > started) then best, started = p.key, lock.started or 0 end
  end
  return best
end

-- ¿Cerrado (×) para la ruta que sigue? Se guarda con la ruta: otra ruta vuelve a sacarlo
local function Hidden(profKey)
  local settings = ES.db.prof and ES.db.prof[profKey]
  local lock = ES:RouteLock(profKey)
  return settings ~= nil and lock ~= nil and settings.assistantHidden ~= nil and settings.assistantHidden == lock.started
end

local function SetHidden(profKey, hidden)
  local settings = ES.db.prof and ES.db.prof[profKey]
  local lock = ES:RouteLock(profKey)
  if settings and lock then settings.assistantHidden = hidden and lock.started or nil end
end


---------------------------------------------------------------------------
-- Botón seguro para usar un pergamino (como SetUseItem en la vista Ruta): suelto en
-- UIParent y colocado encima del banner; se suelta al entrar en combate (en ese
-- momento aún se puede), así el banner nunca queda protegido
---------------------------------------------------------------------------
local function ReleaseUse()
  if not useButton or InCombat() then return end
  useButton:ClearAllPoints()
  useButton:Hide()
end

local function SetUseItem(itemID)
  if InCombat() then return end
  if not itemID then ReleaseUse() return end
  if not useButton then
    useButton = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    useButton:RegisterForClicks("AnyUp", "AnyDown")
    useButton:SetAttribute("type", "item")
    useButton:SetScript("OnEnter", function() local f = banner:GetScript("OnEnter") if f then f(banner) end end)
    useButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  useButton:SetFrameStrata(banner:GetFrameStrata())
  useButton:SetFrameLevel(banner:GetFrameLevel() + 5)
  useButton:ClearAllPoints()
  useButton:SetPoint("TOPLEFT", banner, "TOPLEFT")
  useButton:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT")
  useButton:SetAttribute("item", "item:" .. itemID)
  useButton.itemID = itemID -- (para pruebas)
  useButton:Show()
end

---------------------------------------------------------------------------
-- Pintado
---------------------------------------------------------------------------
local function Fade()
  if banner.fade then banner.fade:Stop() banner.fade:Play() end
end

-- La fila que se enseña: la actual o, ojeando, otra (solo para mirar: no se pulsa)
local function Paint()
  if not frame then return end
  local line = state.peek and state.steps[state.peek] or state.line
  local peeking = state.peek ~= nil and state.peek ~= state.index
  -- Lo que hace el clic: lo mismo que la fila (ES.UI.RowClick); ojeando, nada
  local active = line and not peeking and not state.completed
  banner.onClick = active and line.onClick or nil
  banner.go = active and line.go or nil
  banner.ahItem = active and line.ahItem or nil
  banner.item = line and line.item or nil
  banner.tooltip = line and line.tooltip or nil
  if state.completed then
    banner.onClick = function() A.OpenWindow() end
  elseif peeking then
    banner.onClick = function() A.Peek(nil) end
  end
  SetUseItem(active and line.useItem or nil)

  local icon = state.completed and state.profIcon or (line and line.icon) or ES.ICON
  if icon == ES.QUEST_ICON and ES.SetQuestIcon then ES.SetQuestIcon(banner.icon) else banner.icon:SetTexture(icon) end
  if line and line.iconSize then banner.icon:SetTexCoord(0, 1, 0, 1) else banner.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  if state.completed then
    banner.title:SetText(GREEN .. L["¡Ruta completada!"] .. "|r")
    banner.sub:SetText(string.format(L["%s de %d a %d · clic para abrir la ventana"], state.profName, state.lock.from, state.lock.to))
  elseif line then
    -- (bannerTitle / bannerSub: lo mismo de la fila, más corto: "Fabrica 4× ..." y
    -- "4 fabricaciones · ~4 min", sin precios)
    banner.title:SetText(line.bannerTitle or line.title or "")
    banner.sub:SetText(line.bannerSub or line.sub or "")
  else
    banner.title:SetText(state.profName or "")
    banner.sub:SetText(GREY .. L["Abre la ventana del addon para ver la ruta."] .. "|r")
  end
  -- Alto según el texto (nunca se corta): el banner crece y el marco con él
  local th = (tonumber(banner.title:GetStringHeight()) or 0) + 4 + (tonumber(banner.sub:GetStringHeight()) or 0)
  banner.text:SetHeight(math.max(1, th))
  local h = math.max(BANNER_MIN, math.ceil(th) + 20)
  banner:SetHeight(h)
  frame:SetHeight(PAD + h + PAD)
  banner.title:SetAlpha(peeking and 0.6 or 1)
  banner.sub:SetAlpha(peeking and 0.6 or 1)
  banner.icon:SetDesaturated(peeking and true or false)
  if peeking then
    banner:SetBackdropBorderColor(0.45, 0.36, 0.18, 1)
  else
    banner:SetBackdropBorderColor(1, 0.82, 0.25, 1)
  end

  -- Columna de nivel, como en la fila: "226–230" en fabricar, "225" en aprender o entrenar
  local level = state.completed and tostring(state.lock.to) or (line and line.level) or ""
  banner.level:SetText((peeking or (line and line.done)) and (GREY .. level .. "|r") or level)

  -- ◀ ▶: si hay paso anterior o siguiente que ojear
  arrows.prev:SetEnabled(#state.steps > 0 and (state.peek or state.index or 1) > 1)
  arrows.next:SetEnabled(#state.steps > 0 and (state.peek or state.index or #state.steps) < #state.steps)
end

---------------------------------------------------------------------------
-- Marco
---------------------------------------------------------------------------
-- Por su esquina de arriba: si el texto hace crecer el marco, crece hacia abajo
local function SavePosition()
  local left, top = tonumber(frame:GetLeft()), tonumber(frame:GetTop())
  if not (left and top) then return end
  local db = DB()
  db.left, db.top = left, top
  db.point, db.relPoint, db.x, db.y = nil, nil, nil, nil -- (formato de antes)
end

local function ApplyLayout()
  local db = DB()
  frame:SetScale(db.scale or 1)
  frame:ClearAllPoints()
  if db.left and db.top then
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.left, db.top)
  else
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
end

local function MenuButton(text, onClick)
  local b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
  b:SetSize(150, 22)
  b:SetText(text)
  b:SetScript("OnClick", function() onClick() A.RefreshMenu() end)
  return b
end

-- Menú del clic derecho: bloquear y tamaño
local function CreateMenu()
  menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  menu:SetSize(166, 104)
  menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  menu:SetBackdropColor(0.10, 0.08, 0.05, 0.97)
  menu:SetBackdropBorderColor(0.52, 0.38, 0.17, 1)
  menu:SetFrameStrata("DIALOG")
  menu:SetPoint("TOPLEFT", frame, "TOPRIGHT", 2, 0)
  menu:EnableMouse(true)
  menu.lock = MenuButton("", function() DB().locked = not DB().locked end)
  menu.lock:SetPoint("TOP", 0, -8)
  menu.bigger = MenuButton(L["Más grande"], function()
    DB().scale = math.min(SCALE_MAX, (DB().scale or 1) + SCALE_STEP)
    frame:SetScale(DB().scale)
  end)
  menu.bigger:SetPoint("TOP", menu.lock, "BOTTOM", 0, -2)
  menu.smaller = MenuButton(L["Más pequeño"], function()
    DB().scale = math.max(SCALE_MIN, (DB().scale or 1) - SCALE_STEP)
    frame:SetScale(DB().scale)
  end)
  menu.smaller:SetPoint("TOP", menu.bigger, "BOTTOM", 0, -2)
  menu.close = MenuButton(L["Cerrar menú"], function() menu:Hide() end)
  menu.close:SetPoint("TOP", menu.smaller, "BOTTOM", 0, -2)
  menu:Hide()
end

function A.RefreshMenu()
  if not menu then return end
  menu.lock:SetText(DB().locked and L["Desbloquear"] or L["Bloquear"])
end

local function StartMove()
  if not DB().locked and not InCombat() then frame:StartMoving() end
end

local function StopMove()
  frame:StopMovingOrSizing()
  SavePosition()
end

local function CreateUI()
  -- Marco como la ventana del addon (roca oscura con borde de diálogo), con margen
  -- alrededor del banner: respira, y por el margen se arrastra
  frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, PAD + BANNER_MIN + PAD)
  frame:SetBackdrop({
    bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 20,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  frame:SetBackdropColor(0.045, 0.042, 0.037, 0.99)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", StartMove)
  frame:SetScript("OnDragStop", StopMove)
  frame:Hide()

  banner = CreateFrame("Button", nil, frame, "BackdropTemplate")
  frame.banner = banner
  banner:SetPoint("TOPLEFT", SIDE, -PAD)
  banner:SetPoint("TOPRIGHT", -SIDE, -PAD)
  banner:SetHeight(BANNER_MIN)
 -- Como la fila del paso actual en la ventana (borde dorado)
  banner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  banner:SetBackdropColor(0.17, 0.13, 0.06, 0.96)
  banner:SetBackdropBorderColor(1, 0.82, 0.25, 1)
  local hl = banner:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 2, -2)
  hl:SetPoint("BOTTOMRIGHT", -2, 2)
  hl:SetColorTexture(1, 0.82, 0.25, 0.08)

  -- Columna de nivel, como en las filas de la ruta (centrada y con su línea)
  banner.level = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  banner.level:SetPoint("CENTER", banner, "LEFT", LEVEL_W / 2 + 1, 0)
  banner.level:SetWordWrap(false)
  banner.levelLine = banner:CreateTexture(nil, "ARTWORK")
  banner.levelLine:SetWidth(1)
  banner.levelLine:SetPoint("TOPLEFT", LEVEL_W, -8)
  banner.levelLine:SetPoint("BOTTOMLEFT", LEVEL_W, 8)
  banner.levelLine:SetColorTexture(0.40, 0.29, 0.13, 0.8)

  -- Marco del icono: borde dorado y un filo oscuro por dentro (como los botones de acción)
  banner.iconFrame = banner:CreateTexture(nil, "BACKGROUND", nil, 1)
  banner.iconFrame:SetSize(ICON + 4, ICON + 4)
  banner.iconFrame:SetPoint("LEFT", LEVEL_W + 9, 0)
  banner.iconFrame:SetColorTexture(0.85, 0.68, 0.30, 1)
  local inner = banner:CreateTexture(nil, "BACKGROUND", nil, 2)
  inner:SetSize(ICON + 2, ICON + 2)
  inner:SetPoint("CENTER", banner.iconFrame)
  inner:SetColorTexture(0, 0, 0, 1)
  banner.icon = banner:CreateTexture(nil, "ARTWORK")
  banner.icon:SetSize(ICON, ICON)
  banner.icon:SetPoint("CENTER", banner.iconFrame)

  -- Ancho fijo: el texto se parte en líneas y el banner crece lo que haga falta (Layout)
  local textW = WIDTH - 2 * SIDE - (LEVEL_W + 9 + ICON + 4 + 10) - 8
  banner.text = CreateFrame("Frame", nil, banner)
  banner.text:SetSize(textW, 1)
  banner.text:SetPoint("LEFT", banner.iconFrame, "RIGHT", 10, 0)
  banner.title = banner.text:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  banner.title:SetPoint("TOPLEFT")
  banner.title:SetWidth(textW)
  banner.title:SetJustifyH("LEFT")
  banner.title:SetWordWrap(true)
  banner.sub = banner.text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  banner.sub:SetPoint("TOPLEFT", banner.title, "BOTTOMLEFT", 0, -4)
  banner.sub:SetWidth(textW)
  banner.sub:SetJustifyH("LEFT")
  banner.sub:SetWordWrap(true)
  banner.sub:SetTextColor(0.75, 0.72, 0.65)

  -- Al cambiar de paso, el nuevo entra con un fundido
  banner.fade = banner:CreateAnimationGroup()
  local alpha = banner.fade:CreateAnimation("Alpha")
  alpha:SetFromAlpha(0)
  alpha:SetToAlpha(1)
  alpha:SetDuration(0.3)

  banner:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  banner:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      if not menu then CreateMenu() end
      A.RefreshMenu()
      menu:SetShown(not menu:IsShown())
      return
    end
    ES.UI.RowClick(self, button)
    A.Refresh() -- (lo que hizo el clic puede cambiar el paso: se relee enseguida)
  end)
  banner:SetScript("OnEnter", function(self)
    -- Instructor o vendedor: tu clic le pone la estrella si está cerca (Waypoints.lua)
    if self.go and not self.onClick then ES.Waypoints.HoverRow(self) end
    if self.tooltip then self.tooltip(self) end
  end)
  banner:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- Se arrastra también desde el banner, si no está bloqueado
  banner:RegisterForDrag("LeftButton")
  banner:SetScript("OnDragStart", StartMove)
  banner:SetScript("OnDragStop", StopMove)

  -- La X de la ventana del addon, más pequeña, en la esquina del marco
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close = close
  close:SetSize(CLOSE_SIZE, CLOSE_SIZE)
  close:SetPoint("TOPRIGHT", -1, -1)
  close:SetFrameLevel(banner:GetFrameLevel() + 10)
  close:SetScript("OnClick", function() A.Close() end)
  close:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["Cerrar el asistente (vuelve con /cj mini)"])
    GameTooltip:Show()
  end)
  close:SetScript("OnLeave", function() GameTooltip:Hide() end)
  banner.close = close

  -- ◀ ▶ a los lados del banner, en el margen del marco (sin barra: el paso ya dice lo
  -- que queda). Con el aspecto y el tamaño de la X (Media/Assistant,
  -- tools/gen_assistant_buttons.py)
  arrows = {}
  frame.arrows = arrows

  local function Arrow(dir)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    local tex = MEDIA .. (dir < 0 and "ArrowLeft" or "ArrowRight")
    b:SetNormalTexture(tex)
    b:SetPushedTexture(tex .. "-Down")
    b:SetDisabledTexture(tex .. "-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    b:SetScript("OnClick", function() A.Step(dir) end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(dir < 0 and L["Paso anterior"] or L["Paso siguiente"])
      GameTooltip:AddLine(L["Solo para mirarlo: vuelve solo al paso actual."], 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  arrows.prev = Arrow(-1)
  arrows.prev:SetPoint("RIGHT", banner, "LEFT", -ARROW_GAP, 0)
  arrows.next = Arrow(1)
  arrows.next:SetPoint("LEFT", banner, "RIGHT", ARROW_GAP, 0)

  ApplyLayout()
end

---------------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------------
-- Relee la ruta (las filas de ES:RouteLines) y decide qué enseñar. Se llama con cada
-- cambio que puede mover el paso: bolsas, nivel, recetas, empezar o dejar una ruta
function A.Update()
  if not ES.db then return end
  local profKey = A.Profession()
  if not profKey or Hidden(profKey) then
    if frame then frame:Hide() end
    state.profKey = nil
    return
  end
  if not frame then CreateUI() end
  local data = ES.Data[profKey]
  local lock = ES:RouteLock(profKey)
  local rank = data.skillLine and ES:GetProfessionSkill(data.skillLine) or nil
  -- Las filas de la vista Ruta, más las de compra (solo el asistente: la ventana tiene
  -- Materiales y la Lista de compra)
  local lines = ES:RouteLines(profKey, { buy = true }) or {}
  -- Los pasos de la ruta: las filas con nivel (sin el total, avisos ni citas)
  local steps, index = {}, nil
  for _, line in ipairs(lines) do
    if line.level then
      steps[#steps + 1] = line
      if line.current and not index then index = #steps end
    end
  end
  -- Sin fila actual (antes del primer paso, o con la ruta a medias de rehacer): el
  -- primero sin hacer
  if not index then
    for i, line in ipairs(steps) do
      if not line.done then index = i break end
    end
  end
  local completed = lock.completed or (rank ~= nil and rank >= lock.to) or (#steps > 0 and not index)
  local changed = state.profKey ~= profKey or state.index ~= index or state.completed ~= completed
    or (state.line and steps[index or 0] and state.line.title ~= steps[index].title)
  local prof
  for _, p in ipairs(ES.PROFESSIONS or {}) do if p.key == profKey then prof = p end end
  state.profKey, state.lock, state.rank, state.steps, state.index = profKey, lock, rank, steps, index
  state.line, state.completed = index and steps[index] or nil, completed
  state.profName, state.profIcon = ES:ProfLabel(profKey), prof and prof.icon or ES.ICON
  if state.peek and state.peek > #steps then state.peek = nil end
  local wasShown = frame:IsShown()
  frame:Show()
  Paint()
  if changed and wasShown then Fade() end
end

-- Varias cosas cambian a la vez (comprar, fabricar...): una sola vez, al momento siguiente
local pending = false
function A.Refresh()
  if pending then return end
  pending = true
  C_Timer.After(0.2, function()
    pending = false
    local ok, err = pcall(A.Update)
    if not ok and ES.RecordError then ES:RecordError("asistente", err) end
  end)
end

-- Ojear otro paso con ◀ ▶ (nil: volver al actual). Vuelve solo al cabo de un rato
local peekStamp = 0
function A.Peek(i)
  if i == state.index then i = nil end
  state.peek = i
  peekStamp = peekStamp + 1
  local mine = peekStamp
  if i then
    C_Timer.After(PEEK_SECONDS, function()
      if mine == peekStamp and state.peek then state.peek = nil Paint() end
    end)
  end
  Paint()
  Fade()
end

function A.Step(dir)
  local n = #state.steps
  if n == 0 then return end
  local at = (state.peek or state.index or 1) + dir
  A.Peek(math.max(1, math.min(n, at)))
end

-- La ventana completa en la ruta de la profesión que sigue
function A.OpenWindow()
  local profKey = state.profKey
  if not profKey then ES:ShowMainFrame() return end
  if ES.db.prof[profKey] then ES.db.prof[profKey].view = "route" end
  ES:ShowMainFrame(profKey)
end

function A.Close()
  if state.profKey then SetHidden(state.profKey, true) end
  if menu then menu:Hide() end
  ReleaseUse()
  if frame then frame:Hide() end
end

-- /cj mini: lo abre (aunque lo cerraras para esta ruta) o lo cierra
function A.Toggle()
  local profKey = A.Profession()
  if not profKey then
    ES:Print(L["No tienes ninguna ruta empezada: empieza una en la ventana del addon (botón Empezar ruta)."])
    return
  end
  if frame and frame:IsShown() then
    A.Close()
  else
    SetHidden(profKey, false)
    A.Update()
  end
end

A.State = function() return state end -- (para pruebas)
A.Frame = function() return frame end   -- (para pruebas)

-- Al entrar en combate se suelta el botón seguro del pergamino (en ese momento aún se
-- puede); al salir, se vuelve a poner si hace falta
do
  local f = CreateFrame("Frame")
  ES.SafeRegister(f, "PLAYER_REGEN_DISABLED")
  ES.SafeRegister(f, "PLAYER_REGEN_ENABLED")
  ES.SafeRegister(f, "PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      ReleaseUse()
    elseif event == "PLAYER_ENTERING_WORLD" then
      -- (los datos del personaje y las profesiones ya están: Core.lua)
      C_Timer.After(1, A.Refresh)
    else
      A.Refresh()
    end
  end)
end
