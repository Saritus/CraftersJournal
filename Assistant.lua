local _, ES = ...
local L = ES.L

-- Asistente de ruta (docs/ASISTENTE.md): un banner pequeño y flotante con el paso
-- actual de la ruta empezada, para seguirla sin abrir la ventana del addon.
--   · Lo que enseña y lo que hace al pulsar es la fila `current` de la vista Ruta
--     (ES:RouteLines): el asistente NUNCA decide nada de la ruta por su cuenta.
--   · Un solo asistente, de la última ruta empezada. En beta: desactivado por defecto
--     (A.Enabled, /cj opciones). La × lo cierra para esa ruta (vuelve con /cj mini, el
--     catalejo junto a Dejar ruta o al empezar otra).
--   · Debajo, una pestaña que se despliega al pasar el ratón: ◀ 7/15 ▶ para ojear pasos.
--   · Encima, la flecha GPS (y el destino en el minimapa y el mapa del mundo).

local A = {}
ES.Assistant = A

local WIDTH, BANNER_H, ICON, LEVEL_W = 420, 68, 42, 58 -- (tamaño fijo: cabe un título de dos líneas y el subtítulo)
local LEVEL_STRIPE = 9 -- la franja de color de la izquierda y su margen: el nivel va a su derecha

-- El nivel siempre cabe en su columna, sea cual sea el número ("226–230" con la letra
-- normal pisaba la franja de color): con la letra normal si cabe; si no, más pequeña;
-- y si aún no, el rango en dos líneas (226– / 230). `color`: código de color o nil
function A.FitLevel(fs, text, color)
  local room = LEVEL_W - LEVEL_STRIPE - 4
  local function Set(t) fs:SetText(color and (color .. t .. "|r") or t) end
  fs:SetWidth(0)
  fs:SetFontObject(GameFontNormal)
  Set(text)
  if (tonumber(fs:GetStringWidth()) or 0) <= room then return end
  fs:SetFontObject(GameFontNormalSmall)
  if (tonumber(fs:GetStringWidth()) or 0) <= room then return end
  local a, b = text:match("^(%d+)(%D.*)$")
  if a then Set(a .. "\n" .. b) end
  fs:SetWidth(room)
end
local PAD, CLOSE_SIZE, COUNT_W = 12, 22, 52 -- margen del marco, la X y las flechas, el "7/20" entre ellas
-- Pestaña de ◀ ▶: margen dentro, cuánto se mete bajo el marco, distancia al borde derecho
local TAB_INSET, TAB_TUCK, TAB_RIGHT = 9, 8, 14
local TAB_H = TAB_INSET + 22 + TAB_TUCK + 4 -- (22: las flechas, como la X)
-- Pestaña de pasos que se despliega al pasar el ratón: lo que tarda en abrirse y en
-- cerrarse (s) y cuánto espera al salir antes de plegarse (sin parpadeos al moverte)
local SLIDE_IN, SLIDE_OUT, SLIDE_WAIT = 0.15, 0.2, 0.5
local MEDIA = "Interface\\AddOns\\CraftersJournal\\Media\\Assistant\\"
local PEEK_SECONDS = 8  -- ojeando otro paso: vuelve solo al actual
local GREY, GREEN = "|cff999999", "|cff40ff40"
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.6, 1.6, 0.1
local SHOW_BETA = true -- etiqueta "BETA" en el marco: false cuando salga de pruebas

local frame, banner, arrows, menu, useButton
local state = { steps = {}, index = nil, peek = nil }

local function DB()
  ES.db.assistant = ES.db.assistant or {}
  return ES.db.assistant
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- La profesión que sigue: la de la última ruta empezada o abierta con el botón del
-- asistente en la ventana (settings.assistantPicked); las rutas son de cada personaje
function A.Profession()
  local best, newest
  for _, p in ipairs(ES.PROFESSIONS or {}) do
    local lock = ES.Data[p.key] and ES.db.prof and ES:RouteLock(p.key)
    if lock then
      -- (con "no sacarlo solo" en las opciones, solo las que abriste tú: botón o /cj mini)
      local picked = ES.db.prof[p.key].assistantPicked
      local at
      if DB().noAuto then at = picked else at = math.max(lock.started or 0, picked or 0) end
      if at and (not newest or at > newest) then best, newest = p.key, at end
    end
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
  useButton:SetFrameStrata(banner.hoverStrata) -- (una capa por encima del banner: ver CreateUI)
  useButton:SetFrameLevel(banner:GetFrameLevel() + 5)
  useButton:ClearAllPoints()
  useButton:SetPoint("TOPLEFT", banner, "TOPLEFT")
  useButton:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT")
  useButton:SetAttribute("item", "item:" .. itemID)
  useButton.itemID = itemID -- (para pruebas)
  useButton:Show()
end

---------------------------------------------------------------------------
-- Navegación propia (docs/ASISTENTE.md, sección 4): una flecha 3D que apunta al PNJ del
-- paso actual, con las yardas y el tiempo. No usa Shortest Path, TomTom ni el punto de
-- ruta del juego (la ventana sigue usándolos al pulsar). Las cuentas, en el mapa del
-- continente en el que estás: tu posición y la del PNJ en ese mapa y su tamaño en yardas
---------------------------------------------------------------------------
local NAV_GRID, NAV_FRAMES = 8, 64 -- Media/Assistant/Arrow.tga (tools/gen_assistant_arrow.py)
local ARRIVE_YARDS = 10            -- más cerca: "Has llegado" (la flecha no se quita)
local NAV_TICK = 0.05              -- s entre cálculos
local NAV_W, NAV_ARROW = 190, 40   -- el panel de la flecha y la flecha
local TWO_PI = 2 * math.pi
local CONTINENT = 2                -- Enum.UIMapType.Continent

-- El continente de un mapa (subiendo por sus padres), o nil
local function Continent(map)
  local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  local guard = 0
  while info and info.mapType ~= CONTINENT and (info.parentMapID or 0) > 0 and guard < 8 do
    info, guard = C_Map.GetMapInfo(info.parentMapID), guard + 1
  end
  return info and info.mapType == CONTINENT and info.mapID or nil
end

-- Ancho y alto de un mapa en yardas (de sus esquinas en el mundo; vale para cualquier eje)
local yardsCache = {}
local function MapYards(map)
  local c = yardsCache[map]
  if c then return c[1], c[2] end
  if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local function World(u, v)
    local ok, _, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(u, v))
    if ok and pos then return pos:GetXY() end
  end
  local ax, ay = World(0, 0)
  local bx, by = World(1, 0)
  local cx, cy = World(0, 1)
  if not (ax and bx and cx) then return nil end
  local w, h = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2), math.sqrt((cx - ax) ^ 2 + (cy - ay) ^ 2)
  if w <= 0 or h <= 0 then return nil end
  yardsCache[map] = { w, h }
  return w, h
end

-- Dónde está el PNJ respecto a ti: yardas al este y al sur. Si no se puede: nil y por
-- qué ("continent": en otro continente; "here": aquí no hay posición, p. ej. en una
-- mazmorra; "unknown": no se sabe dónde está el PNJ)
function A.Relative(npc)
  if not (npc and npc.map and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
    return nil, "unknown"
  end
  local mine = Continent(C_Map.GetBestMapForUnit("player"))
  if not mine then return nil, "here" end
  if Continent(npc.map) ~= mine then return nil, "continent" end
  local me = C_Map.GetPlayerMapPosition(mine, "player")
  if not me then return nil, "here" end
  local ok, instance, world = pcall(C_Map.GetWorldPosFromMapPos, npc.map, CreateVector2D(npc.x, npc.y))
  if not (ok and world and C_Map.GetMapPosFromWorldPos) then return nil, "unknown" end
  local ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, instance, world, mine)
  if not (ok2 and pos) then return nil, "unknown" end
  local w, h = MapYards(mine)
  if not w then return nil, "unknown" end
  local tx, ty = pos:GetXY()
  local px, py = me:GetXY()
  return (tx - px) * w, (ty - py) * h
end

-- En otro continente: cómo se cruza, por bando (sección 4). Los sitios, con el nombre de
-- la zona que da el juego (sale en tu idioma). Mapas: 1414 Kalimdor, 1415 Reinos del Este
local CROSSINGS = {
  Alliance = {
    [1414] = { kind = "boat", from = { 1437 } },        -- a Kalimdor: barco en los Humedales (Menethil)
    [1415] = { kind = "boat", from = { 1439, 1445 } },  -- a los Reinos: barco en Costa Oscura o Marjal Revolcafango
  },
  Horde = {
    [1414] = { kind = "zeppelin", from = { 1420, 1434 } }, -- a Kalimdor: zepelín en Tirisfal o Tuercespina
    [1415] = { kind = "zeppelin", from = { 1411 } },       -- a los Reinos: zepelín en Durotar (Orgrimmar)
  },
}

local function MapName(map)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  return info and info.name or tostring(map)
end

-- "Está en Kalimdor" y "Barco en Humedales", o nil si no se sabe
function A.TravelHint(npc)
  local to = npc and Continent(npc.map)
  local route = to and CROSSINGS[UnitFactionGroup and UnitFactionGroup("player") or ""]
  route = route and route[to]
  if not route then return nil end
  local places = {}
  for _, map in ipairs(route.from) do places[#places + 1] = MapName(map) end
  local where = table.concat(places, L[" o "])
  return string.format(L["Está en %s"], MapName(to)),
    string.format(route.kind == "boat" and L["Barco en %s"] or L["Zepelín en %s"], where)
end

-- Ángulo al PNJ desde hacia donde miras, en el sentido de las agujas del reloj (0 =
-- delante), de 0 a 2π. GetPlayerFacing: 0 al norte y crece hacia el oeste
function A.Turn(east, south, facing)
  local bearing = math.atan2(east, -south) -- desde el norte, en el sentido del reloj
  return (bearing + facing) % TWO_PI
end

-- Fotograma de la flecha para ese giro (0 = delante), y sus coordenadas en la textura
function A.ArrowCoords(turn)
  local i = math.floor(turn / TWO_PI * NAV_FRAMES + 0.5) % NAV_FRAMES
  local col, row = i % NAV_GRID, math.floor(i / NAV_GRID)
  return i, col / NAV_GRID, (col + 1) / NAV_GRID, row / NAV_GRID, (row + 1) / NAV_GRID
end

-- Color: verde de frente, dorado de lado, rojo detrás
local NAV_GREEN, NAV_GOLD, NAV_RED = { 0.35, 1, 0.35 }, { 1, 0.82, 0.25 }, { 1, 0.3, 0.25 }
function A.TurnColor(turn)
  local off = math.abs((turn + math.pi) % TWO_PI - math.pi) / math.pi -- 0 de frente, 1 detrás
  local a, b, t = NAV_GREEN, NAV_GOLD, off * 2
  if off > 0.5 then a, b, t = NAV_GOLD, NAV_RED, (off - 0.5) * 2 end
  return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

local function Duration(secs)
  secs = math.floor(secs + 0.5)
  if secs < 60 then return string.format(L["~%d s"], secs) end
  return string.format(L["~%d min"], math.floor(secs / 60 + 0.5))
end

---------------------------------------------------------------------------
-- Minimapa y mapa del mundo (sección 4): el destino con su icono; en el minimapa, si
-- queda fuera, una flecha en el borde, y una línea de puntos desde ti. Sin librerías:
-- el tamaño del minimapa en yardas según su zoom (dentro o fuera de edificios) y su giro
---------------------------------------------------------------------------
local MINIMAP_YARDS = { -- diámetro en yardas por zoom (0 a 5)
  outdoor = { 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
  indoor = { 300, 240, 180, 120, 80, 50 },
}
local DOTS = 7
local mini, worldPin

local function PinTexture(parent, name, size, layer)
  local t = parent:CreateTexture(nil, layer or "OVERLAY")
  t:SetTexture(MEDIA .. name)
  t:SetSize(size, size)
  t:SetVertexColor(NAV_GOLD[1], NAV_GOLD[2], NAV_GOLD[3])
  t:Hide()
  return t
end

local function HideMini()
  if not mini then return end
  mini.pin:Hide()
  mini.edge:Hide()
  for _, d in ipairs(mini.dots) do d:Hide() end
end

local function HideWorld()
  if worldPin then worldPin:Hide() end
end

-- east, south: yardas al destino; facing: hacia dónde miras (por si el minimapa gira)
function A.UpdateMinimap(east, south, facing)
  if not Minimap then return end
  if not mini then
    mini = { dots = {} }
    mini.pin = PinTexture(Minimap, "Pin", 14)
    mini.edge = PinTexture(Minimap, "Edge", 14)
    for i = 1, DOTS do mini.dots[i] = PinTexture(Minimap, "Dot", 5, "ARTWORK") end
  end
  local zoom = (Minimap.GetZoom and tonumber(Minimap:GetZoom()) or 0) + 1
  local sizes = (IsIndoors and IsIndoors()) and MINIMAP_YARDS.indoor or MINIMAP_YARDS.outdoor
  local radius = (tonumber(Minimap:GetWidth()) or 140) / 2
  local perYard = radius / ((sizes[zoom] or sizes[1]) / 2)
  local x, y = east * perYard, -south * perYard -- (y hacia arriba: el norte)
  -- Minimapa que gira contigo: lo de delante, arriba
  if facing and GetCVar and GetCVar("rotateMinimap") == "1" then
    local c, s = math.cos(facing), math.sin(facing)
    x, y = x * c + y * s, -x * s + y * c
  end
  local dist = math.sqrt(x * x + y * y)
  local inner = radius - 8
  local onEdge = dist > inner
  local px, py = x, y
  if onEdge then px, py = x / dist * inner, y / dist * inner end
  local icon = onEdge and mini.edge or mini.pin
  mini.pin:SetShown(not onEdge)
  mini.edge:SetShown(onEdge)
  icon:ClearAllPoints()
  icon:SetPoint("CENTER", Minimap, "CENTER", px, py)
  if onEdge then icon:SetRotation(math.atan2(-x, y)) end -- (la flecha del borde apunta hacia allí)
  -- Línea de puntos desde ti (sin los que caen encima de tu flecha o del icono)
  local len = math.min(dist, inner)
  for i, dot in ipairs(mini.dots) do
    local t = i / (DOTS + 1)
    local show = len * t > 10 and len * (1 - t) > 9
    dot:SetShown(show)
    if show then
      dot:ClearAllPoints()
      dot:SetPoint("CENTER", Minimap, "CENTER", px * t, py * t)
    end
  end
  return onEdge
end

-- El destino en el mapa del mundo abierto (si cae en el mapa que estás mirando)
function A.UpdateWorldMap(npc)
  local wm = WorldMapFrame
  if not (wm and wm:IsShown() and wm.GetMapID and wm.GetCanvas and npc and npc.map and C_Map
      and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then
    HideWorld()
    return
  end
  local canvas = wm:GetCanvas()
  if not worldPin then
    worldPin = CreateFrame("Frame", nil, canvas)
    worldPin:SetSize(20, 20)
    worldPin.icon = PinTexture(worldPin, "Pin", 20)
    worldPin.icon:SetAllPoints()
    worldPin.icon:Show()
    worldPin:EnableMouse(true)
    worldPin:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.name or "")
      GameTooltip:AddLine(L["Asistente de la ruta"], 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    worldPin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local ok, instance, world = pcall(C_Map.GetWorldPosFromMapPos, npc.map, CreateVector2D(npc.x, npc.y))
  local ok2, _, pos = false, nil, nil
  if ok and world then ok2, _, pos = pcall(C_Map.GetMapPosFromWorldPos, instance, world, wm:GetMapID()) end
  local x, y = ok2 and pos and pos:GetXY()
  if not (x and y) or x < 0 or x > 1 or y < 0 or y > 1 then HideWorld() return end
  -- Mismo tamaño en pantalla con cualquier zoom del mapa
  local zoom = wm.ScrollContainer and wm.ScrollContainer.GetCanvasScale and wm.ScrollContainer:GetCanvasScale() or 1
  local k = 1 / math.max(0.01, zoom)
  worldPin:SetScale(k)
  worldPin:SetFrameLevel((canvas:GetFrameLevel() or 0) + 2000)
  worldPin:ClearAllPoints()
  worldPin:SetPoint("CENTER", canvas, "TOPLEFT", x * canvas:GetWidth() / k, -y * canvas:GetHeight() / k)
  worldPin.name = npc.name
  worldPin:Show()
end

local nav -- el panel de la flecha (CreateUI)

-- Pinta la flecha hacia el destino del paso (state.navNpc); sin destino, se esconde
local function NavTick()
  if not nav then return end
  -- (celebrando el paso hecho: la flecha sigue con su destino hasta que entre el siguiente)
  if state.hold then return end
  local npc = state.navNpc and ES.Waypoints.NPC(state.navNpc)
  if not npc or state.completed then
    nav:Hide()
    HideMini()
    HideWorld()
    return
  end
  -- Cada parte, con su opción (Route Assistant): el destino en el mapa del mundo, en el
  -- minimapa y la flecha GPS
  if DB().noWorldPin then HideWorld() else A.UpdateWorldMap(npc) end
  local east, south = A.Relative(npc)
  local facing = GetPlayerFacing and GetPlayerFacing()
  if east and facing and not DB().noMinimapPin then A.UpdateMinimap(east, south, facing) else HideMini() end
  if DB().noArrow then nav:Hide() return end
  nav:Show()
  nav.hint = nil
  if not east or not facing then
    -- Sin flecha: en otro continente, o aquí no hay posición (mazmorra)
    local why = select(2, A.Relative(npc))
    nav.arrow:Hide()
    -- Otro continente: cómo cruzar ("Está en Kalimdor" / "Barco en Humedales")
    local place, crossing = nil, nil
    if why == "continent" then place, crossing = A.TravelHint(npc) end
    if place then
      nav.big:SetText(place)
      nav.small:SetText(crossing)
      nav.hint = crossing -- (entero en el tooltip: en el panel puede cortarse)
    else
      nav.big:SetText(why == "continent" and L["En otro continente"] or GREY .. L["Sin posición aquí"] .. "|r")
      nav.small:SetText(npc.name .. " · " .. ES.Waypoints.ZoneName(npc))
    end
    return
  end
  nav.arrow:Show()
  local dist = math.sqrt(east * east + south * south)
  if dist <= ARRIVE_YARDS then
    nav.arrow:SetTexture(MEDIA .. "Arrived")
    nav.arrow:SetTexCoord(0, 1, 0, 1)
    nav.arrow:SetVertexColor(NAV_GREEN[1], NAV_GREEN[2], NAV_GREEN[3])
    -- Al llegar, lo útil: a quién buscas y que un clic aquí lo selecciona y lo marca
    nav.big:SetText(GREEN .. npc.name .. "|r")
    nav.small:SetText(L["Clic para marcarlo"])
    return
  end
  local turn = A.Turn(east, south, facing)
  local _, l, r, t, b = A.ArrowCoords(turn)
  nav.arrow:SetTexture(MEDIA .. "Arrow")
  nav.arrow:SetTexCoord(l, r, t, b)
  nav.arrow:SetVertexColor(A.TurnColor(turn))
  -- Tiempo: a tu velocidad de correr (o la de la montura que llevas)
  local speed = GetUnitSpeed and select(2, GetUnitSpeed("player")) or 7
  -- (arriba las yardas y el tiempo; debajo, a quién: si el nombre es largo, se corta él)
  nav.big:SetText(string.format(L["%d yd"], math.floor(dist + 0.5)) .. GREY .. "  "
    .. Duration(dist / math.max(7, speed or 7)) .. "|r")
  nav.small:SetText(npc.name)
end
A.NavTick = NavTick -- (para pruebas)

---------------------------------------------------------------------------
-- Pintado
---------------------------------------------------------------------------
local function Fade()
  if banner.fade then banner.fade:Stop() banner.fade:Play() end
end

-- Paso completado: un brillo dorado en el icono y un ✓ que se van solos, sobre el paso
-- hecho; el siguiente entra al acabar (A.Update)
A.CELEBRATE_HOLD = 1.0
local function Celebrate()
  if not banner.done then return end
  banner.done:Stop()
  banner.done:Play()
end
A.Celebrate = Celebrate -- (para pruebas)

-- Pestaña de pasos (◀ 7/15 ▶): por defecto se despliega al pasar el ratón por el
-- asistente (o por ella, o por la flecha) y se pliega sola al salir, tras SLIDE_WAIT;
-- mientras ojeas un paso, se queda abierta. Con "Siempre visibles" no se pliega.
-- Plegada, sube y se esconde bajo el asistente (va por debajo de él)
local leftFor = 0
local SLIDE_PX = 12 -- lo que se desliza al desplegarse

-- ¿El ratón está sobre `region` (o hasta `below` píxeles por debajo)? Por su rectángulo
-- en pantalla, no por qué marco tiene el ratón: así cuenta aunque encima esté el botón
-- seguro de la estrella (Waypoints.lua) o la flecha
function A.MouseOver(region, below)
  if not (region and region.IsVisible and region:IsVisible() and GetCursorPosition) then return false end
  local left, right = tonumber(region:GetLeft()), tonumber(region:GetRight())
  local top, bottom = tonumber(region:GetTop()), tonumber(region:GetBottom())
  if not (left and right and top and bottom) then return false end
  local scale = tonumber(region:GetEffectiveScale()) or 1
  local x, y = GetCursorPosition()
  x, y = (tonumber(x) or 0) / scale, (tonumber(y) or 0) / scale
  return x >= left and x <= right and y <= top and y >= bottom - (below or 0)
end

function A.SlideTab(elapsed)
  local tab = frame and frame.tab
  if not tab or DB().noSteps then return end
  local want
  if DB().stepsAlways or state.peek then
    want = 1
  else
    -- Ratón sobre el asistente o sobre la zona de la pestaña, debajo (aunque esté
    -- plegada: al bajar hacia ella no se cierra), o sobre la flecha
    local over = A.MouseOver(frame, TAB_H) or (nav and nav:IsShown() and A.MouseOver(nav, 0)) or false
    leftFor = over and 0 or (leftFor + (elapsed or 0))
    want = (over or leftFor < SLIDE_WAIT) and 1 or 0
  end
  local open = tab.open or 0
  if open == want and (want == 0) ~= tab:IsShown() then return end
  local step = (elapsed or 0) / (want > open and SLIDE_IN or SLIDE_OUT)
  open = want > open and math.min(want, open + step) or math.max(want, open - step)
  tab.open = open
  -- Baja un poco al desplegarse y aparece a la vez (plegada: escondida)
  tab:ClearAllPoints()
  tab:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -TAB_RIGHT, TAB_TUCK + (1 - open) * SLIDE_PX)
  tab:SetAlpha(open)
  tab:SetShown(open > 0)
end

-- Color del tipo de paso (la franja del banner): verde fabricar, dorado comprar o sacar
-- del banco, azul ir a un PNJ (entrenar, aprender la profesión o una receta), gris hecho
local STEP_COLORS = {
  craft = { 0.35, 0.85, 0.35 }, buy = { 1, 0.78, 0.2 }, npc = { 0.35, 0.65, 1 },
  done = { 0.5, 0.5, 0.5 }, completed = { 0.35, 0.85, 0.35 },
}
function A.StepKind(line, completed)
  if completed then return "completed" end
  if not line then return "done" end
  if line.done then return "done" end
  if line.buyRow then return "buy" end
  if line.stepRecipe or (not line.go and line.item) then return "craft" end -- (también convertir esencias)
  return "npc"
end
function A.StepColor(line, completed)
  local c = STEP_COLORS[A.StepKind(line, completed)]
  return c[1], c[2], c[3]
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
  -- El banner tiene siempre el mismo tamaño (no "baila" al cambiar de paso): el texto
  -- se centra en vertical dentro (título en una o dos líneas, subtítulo en una)
  local th = (tonumber(banner.title:GetStringHeight()) or 0) + 4 + (tonumber(banner.sub:GetStringHeight()) or 0)
  banner.text:SetHeight(math.max(1, th))
  banner.title:SetAlpha(peeking and 0.6 or 1)
  banner.sub:SetAlpha(peeking and 0.6 or 1)
  banner.icon:SetDesaturated(peeking and true or false)
  if peeking then
    banner:SetBackdropBorderColor(0.45, 0.36, 0.18, 1)
  else
    banner:SetBackdropBorderColor(1, 0.82, 0.25, 1)
  end
  local r, g, b = A.StepColor(line, state.completed)
  banner.stripe:SetColorTexture(r, g, b, (peeking or (line and line.done)) and 0.35 or 1)

  -- Columna de nivel, como en la fila: "226–230" en fabricar, "225" en aprender o entrenar
  local level = state.completed and tostring(state.lock.to) or (line and line.level) or ""
  A.FitLevel(banner.level, level, (peeking or (line and line.done)) and GREY or nil)

  -- ◀ ▶: si hay paso anterior o siguiente que ojear; entre ellas, cuál es de cuántos
  -- (ojeando, el que miras, en gris; con la ruta completada, el último)
  local n = #state.steps
  local at = state.peek or (state.completed and n) or state.index or n
  -- (opción "Mostrar las flechas de pasos"; si se despliega al pasar el ratón, SlideTab)
  if DB().noSteps then frame.tab:Hide() elseif DB().stepsAlways then frame.tab:Show() end
  arrows.prev:SetEnabled(n > 0 and at > 1)
  arrows.next:SetEnabled(n > 0 and at < n)
  local count = n > 0 and string.format("%d/%d", at, n) or ""
  arrows.count:SetText(peeking and (GREY .. count .. "|r") or count)
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
  menu:SetFrameStrata("FULLSCREEN_DIALOG") -- (encima del asistente, que va en DIALOG)
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
  frame:SetSize(WIDTH, PAD + BANNER_H + PAD)
  frame:SetBackdrop({
    bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 20,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  frame:SetBackdropColor(0.045, 0.042, 0.037, 0.99)
  -- Siempre por encima de las ventanas (la del addon va en HIGH, como la mayoría): si
  -- no, al abrirlo con su botón podía quedar debajo de la ventana y no verse
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", StartMove)
  frame:SetScript("OnDragStop", StopMove)
  frame:Hide()

  banner = CreateFrame("Button", nil, frame, "BackdropTemplate")
  frame.banner = banner
  banner:SetPoint("TOPLEFT", PAD, -PAD)
  banner:SetPoint("TOPRIGHT", -PAD, -PAD)
  banner:SetHeight(BANNER_H)
  -- El botón seguro de la estrella (Waypoints.lua, HoverRow), una capa por encima: así
  -- tu clic siempre le llega a él y no al banner
  banner.hoverStrata = "FULLSCREEN_DIALOG"
 -- Como la fila del paso actual en la ventana (borde dorado)
  banner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  banner:SetBackdropColor(0.17, 0.13, 0.06, 0.96)
  banner:SetBackdropBorderColor(1, 0.82, 0.25, 1)
  local hl = banner:CreateTexture(nil, "HIGHLIGHT")
  hl:SetPoint("TOPLEFT", 2, -2)
  hl:SetPoint("BOTTOMRIGHT", -2, 2)
  hl:SetColorTexture(1, 0.82, 0.25, 0.08)
  -- Franja a la izquierda con el color del tipo de paso (StepColor): de un vistazo
  banner.stripe = banner:CreateTexture(nil, "ARTWORK")
  banner.stripe:SetPoint("TOPLEFT", 3, -3)
  banner.stripe:SetPoint("BOTTOMLEFT", 3, 3)
  banner.stripe:SetWidth(4)

  -- Columna de nivel, como en las filas de la ruta (centrada y con su línea)
  banner.level = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  -- (centrada en lo que queda a la derecha de la franja de color: A.FitLevel)
  banner.level:SetPoint("CENTER", banner, "LEFT", (LEVEL_STRIPE + LEVEL_W) / 2, 0)
  banner.level:SetJustifyH("CENTER")
  banner.level:SetWordWrap(true)
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

  -- Tamaño fijo: el título en una o dos líneas y el subtítulo en una (si no caben, se
  -- cortan con "..."; lo completo, en el tooltip)
  local textW = WIDTH - 2 * PAD - (LEVEL_W + 9 + ICON + 4 + 10) - 8
  banner.text = CreateFrame("Frame", nil, banner)
  banner.text:SetSize(textW, 1)
  banner.text:SetPoint("LEFT", banner.iconFrame, "RIGHT", 10, 0)
  banner.title = banner.text:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  banner.title:SetPoint("TOPLEFT")
  banner.title:SetWidth(textW)
  banner.title:SetJustifyH("LEFT")
  banner.title:SetWordWrap(true)
  if banner.title.SetMaxLines then banner.title:SetMaxLines(2) end
  banner.sub = banner.text:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  banner.sub:SetPoint("TOPLEFT", banner.title, "BOTTOMLEFT", 0, -4)
  banner.sub:SetWidth(textW)
  banner.sub:SetJustifyH("LEFT")
  banner.sub:SetWordWrap(false)
  banner.sub:SetTextColor(0.75, 0.72, 0.65)

  -- Paso completado: brillo dorado alrededor del icono y un ✓, que aparecen y se van
  -- (Celebrate). Escondidos (alfa 0) salvo mientras dura la animación
  local done = CreateFrame("Frame", nil, banner)
  done:SetAllPoints(banner.iconFrame)
  done:SetFrameLevel(banner:GetFrameLevel() + 3)
  done:SetAlpha(0)
  local glow = done:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(1, 0.85, 0.3)
  glow:SetSize(ICON * 1.9, ICON * 1.9)
  glow:SetPoint("CENTER")
  local check = done:CreateTexture(nil, "OVERLAY", nil, 1)
  check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  check:SetSize(22, 22)
  check:SetPoint("BOTTOMRIGHT", 6, -6)
  banner.done = done:CreateAnimationGroup()
  -- (dura A.CELEBRATE_HOLD: se va justo cuando entra el paso siguiente)
  for i, step in ipairs({ { 0, 1, 0.15 }, { 1, 1, 0.55 }, { 1, 0, 0.3 } }) do
    local a = banner.done:CreateAnimation("Alpha")
    a:SetFromAlpha(step[1])
    a:SetToAlpha(step[2])
    a:SetDuration(step[3])
    a:SetOrder(i)
  end

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
    -- Celebrando el paso hecho: el banner aún enseña ese paso (y su clic, que volvería a
    -- hacerlo: fabricar de más). El clic solo acaba la celebración y enseña el siguiente
    if state.hold then
      A.EndHold()
      return
    end
    ES.UI.RowClick(self, button)
    -- (lo que hizo el clic puede cambiar el paso: se relee enseguida; y la flecha vuelve
    -- a buscar el PNJ más cercano desde donde estás ahora)
    state.navKey = nil
    A.Refresh()
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
  -- Etiqueta "BETA", discreta, sobre el borde de arriba a la izquierda (se quita cuando
  -- el asistente salga de pruebas: SHOW_BETA). Al pasar el ratón, para qué es
  if SHOW_BETA then
    local beta = CreateFrame("Frame", nil, frame)
    frame.beta = beta
    beta:SetFrameLevel(banner:GetFrameLevel() + 10)
    beta.text = beta:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    beta.text:SetText(L["BETA"])
    beta.text:SetTextColor(0.85, 0.7, 0.35, 0.85)
    beta.text:SetPoint("CENTER")
    beta:SetSize((tonumber(beta.text:GetStringWidth()) or 30) + 10, 14)
    beta:SetPoint("TOPLEFT", 14, 6)
    local bg = beta:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.05, 0.04, 0.95)
    beta:EnableMouse(true)
    beta:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(L["Asistente de ruta (beta)"])
      GameTooltip:AddLine(L["En pruebas. Si algo no va como esperas, cuéntanoslo en Discord."], 0.8, 0.8, 0.8, true)
      GameTooltip:Show()
    end)
    beta:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
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

  -- ◀ ▶ juntas en una pestaña que cuelga de abajo a la derecha, con el mismo marco que
  -- el asistente (su borde de arriba queda bajo el del marco: parece que cuelga). Con
  -- el aspecto y el tamaño de la X (Media/Assistant, tools/gen_assistant_buttons.py)
  local tab = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.tab = tab
  tab:SetSize(TAB_INSET * 2 + CLOSE_SIZE * 2 + COUNT_W, TAB_H)
  tab:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -TAB_RIGHT, TAB_TUCK)
  tab.open = 1 -- 0 plegada (escondida bajo el asistente) a 1 desplegada: ver SlideTab
  tab:SetBackdrop({
    bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 20,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  tab:SetBackdropColor(0.045, 0.042, 0.037, 0.99)
  tab:EnableMouse(true) -- (por la pestaña también se arrastra)
  tab:RegisterForDrag("LeftButton")
  tab:SetScript("OnDragStart", StartMove)
  tab:SetScript("OnDragStop", StopMove)
  -- Debajo del marco (el borde del marco tapa el de arriba de la pestaña)
  frame:SetFrameLevel(10)
  tab:SetFrameLevel(frame:GetFrameLevel() - 1)
  arrows = {}
  frame.arrows = arrows

  local function Arrow(dir)
    local b = CreateFrame("Button", nil, tab)
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
  arrows.prev:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", TAB_INSET, TAB_INSET)
  arrows.next = Arrow(1)
  arrows.next:SetPoint("LEFT", arrows.prev, "RIGHT", COUNT_W, 0)
  -- Entre las flechas, qué paso es de cuántos ("7/20")
  arrows.count = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  arrows.count:SetPoint("LEFT", arrows.prev, "RIGHT", 0, 0)
  arrows.count:SetPoint("RIGHT", arrows.next, "LEFT", 0, 0)
  arrows.count:SetJustifyH("CENTER")
  arrows.count:SetWordWrap(false)

  -- Flecha GPS: un panel que cuelga por encima, en el centro, con el mismo marco (su
  -- borde de abajo queda bajo el del asistente). Solo con un PNJ al que ir (NavTick)
  -- (botón: al pulsarlo se selecciona al PNJ y se le pone la estrella, ver más abajo)
  nav = CreateFrame("Button", nil, frame, "BackdropTemplate")
  frame.nav = nav
  nav:SetSize(NAV_W, NAV_ARROW + TAB_TUCK + 10)
  nav:SetPoint("BOTTOM", frame, "TOP", 0, -TAB_TUCK)
  nav:SetBackdrop({
    bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 20,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
  })
  nav:SetBackdropColor(0.045, 0.042, 0.037, 0.99)
  nav:SetFrameLevel(frame:GetFrameLevel() - 1)
  nav:EnableMouse(true) -- (también se arrastra por aquí)
  nav:RegisterForDrag("LeftButton")
  nav:SetScript("OnDragStart", StartMove)
  nav:SetScript("OnDragStop", StopMove)
  -- Clic en la flecha: selecciona al PNJ del paso y le pone la estrella (si está cerca),
  -- para verlo entre varios en una sala. Como las filas (Waypoints.lua, HoverRow): un
  -- botón seguro con la macro se pone encima al pasar el ratón; tu clic la lanza
  nav.go = function() return state.navNpc end
  nav.hoverStrata = "FULLSCREEN_DIALOG"
  nav:RegisterForClicks("LeftButtonUp")
  nav:SetScript("OnClick", function() end) -- (lo hace la macro del botón seguro)
  nav:SetScript("OnEnter", function(self)
    local npc = state.navNpc and ES.Waypoints.NPC(state.navNpc)
    if not npc then return end
    ES.Waypoints.HoverRow(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(npc.name)
    GameTooltip:AddLine(ES.Waypoints.LocationText(npc), 0.8, 0.8, 0.8)
    if self.hint then GameTooltip:AddLine(self.hint, 1, 0.82, 0, true) end
    GameTooltip:AddLine(L["Clic: seleccionarlo y marcarlo con una estrella (si está cerca)."], 0.5, 0.8, 1, true)
    GameTooltip:Show()
  end)
  nav:SetScript("OnLeave", function() GameTooltip:Hide() end)
  nav.tooltip = nav:GetScript("OnEnter") -- (el botón seguro lo vuelve a enseñar: HoverRow)
  nav.arrow = nav:CreateTexture(nil, "ARTWORK")
  nav.arrow:SetSize(NAV_ARROW, NAV_ARROW)
  nav.arrow:SetPoint("TOPLEFT", 9, -5)
  nav.big = nav:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  nav.big:SetPoint("TOPLEFT", nav.arrow, "TOPRIGHT", 3, -7)
  nav.big:SetPoint("RIGHT", -12, 0)
  nav.big:SetJustifyH("LEFT")
  nav.big:SetWordWrap(false)
  nav.small = nav:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nav.small:SetPoint("TOPLEFT", nav.big, "BOTTOMLEFT", 0, -3)
  nav.small:SetPoint("RIGHT", -12, 0)
  nav.small:SetJustifyH("LEFT")
  nav.small:SetWordWrap(false)
  nav.small:SetTextColor(0.75, 0.72, 0.65)
  nav:Hide()
  -- Cerrado el asistente, fuera los iconos del minimapa y del mapa
  frame:SetScript("OnHide", function()
    HideMini()
    HideWorld()
  end)
  -- Se recalcula unas veces por segundo mientras se ve (giras, andas)
  local wait = 0
  frame:SetScript("OnUpdate", function(_, elapsed)
    A.SlideTab(elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    wait = NAV_TICK
    NavTick()
  end)

  ApplyLayout()
end

---------------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------------
-- Relee la ruta (las filas de ES:RouteLines) y decide qué enseñar. Se llama con cada
-- cambio que puede mover el paso: bolsas, nivel, recetas, empezar o dejar una ruta
-- Beta: desactivado por defecto; se activa en /cj opciones (Asistente de ruta)
function A.Enabled()
  return ES.db ~= nil and DB().enabled == true
end

function A.Update()
  if not ES.db then return end
  local profKey = A.Enabled() and A.Profession()
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
  -- Avance en la ruta sin contar las filas de compra: aparecen y desaparecen delante del
  -- paso (según lo que llevas) y movían su número sin que hubieras hecho nada (salían el
  -- brillo y el fundido de "paso hecho" al ponerse un aviso de compra)
  local progress = 0
  for i = 1, index or 0 do
    if not steps[i].buyRow then progress = progress + 1 end
  end
  local cur = index and steps[index]
  local changed = state.profKey ~= profKey or state.completed ~= completed
    or (state.line and cur and state.line.title ~= cur.title) or ((state.line == nil) ~= (cur == nil))
  -- ¿Has acabado un paso? (la misma ruta, y avanza o se completa la ruta)
  local advanced = state.profKey == profKey and state.progress ~= nil
    and (progress > state.progress or (completed and not state.completed))
  state.progress = progress
  local prof
  for _, p in ipairs(ES.PROFESSIONS or {}) do if p.key == profKey then prof = p end end
  state.profKey, state.lock, state.rank, state.steps, state.index = profKey, lock, rank, steps, index
  state.line, state.completed = index and steps[index] or nil, completed
  state.profName, state.profIcon = ES:ProfLabel(profKey), prof and prof.icon or ES.ICON
  if state.peek and state.peek > #steps then state.peek = nil end
  -- Destino de la flecha: el PNJ del paso (instructor, vendedor, subastador...), el más
  -- cercano AL EMPEZAR el paso, y no cambia mientras dura (no salta de uno a otro por el
  -- camino). Pulsar el banner lo vuelve a buscar (state.navKey = nil)
  local line = state.line
  local key = line and not completed and (tostring(line.title) .. "|" .. tostring(line.level)) or nil
  if key ~= state.navKey then
    state.navKey, state.navNpc = key, nil
    if key and line.go then
      local ok, npcID = pcall(line.go)
      state.navNpc = ok and npcID or nil
    end
  end
  local wasShown = frame:IsShown()
  frame:Show()
  state.celebrated = advanced and wasShown or nil -- (para pruebas)
  if advanced and wasShown and C_Timer and A.CELEBRATE_HOLD > 0 then
    -- Paso hecho: el ✓ sale sobre ESE paso, que aún se ve, y luego entra el siguiente.
    -- Antes se pintaba el nuevo y el ✓ caía encima ("Compra 10× Gold Bar" con un ✓,
    -- como si ya estuviera comprado)
    Celebrate()
    local token = {}
    state.hold = token
    C_Timer.After(A.CELEBRATE_HOLD, function()
      if state.hold == token then A.EndHold() end
    end)
    return
  end
  -- (mientras se celebra el paso hecho, lo que llegue se pinta al acabar: el estado ya
  -- está al día y el pintado lo recoge)
  if state.hold then return end
  Paint()
  NavTick()
  if changed and wasShown then Fade() end
end

-- Acaba la celebración del paso hecho: entra el siguiente (al pasar el tiempo o con un clic)
function A.EndHold()
  if not state.hold then return end
  state.hold = nil
  if banner and banner.done then banner.done:Stop() end
  Paint()
  NavTick()
  Fade()
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
  if not A.Enabled() then
    ES:Print(L["El asistente de ruta está en beta: actívalo en /cj opciones (Asistente de ruta)."])
    return
  end
  local profKey = A.Profession()
  if not profKey then
    -- (con "no sacarlo solo": la última ruta empezada, que pasa a ser la que sigue)
    local newest
    for _, p in ipairs(ES.PROFESSIONS or {}) do
      local lock = ES.Data[p.key] and ES.db.prof and ES:RouteLock(p.key)
      if lock and (not newest or (lock.started or 0) > newest) then profKey, newest = p.key, lock.started or 0 end
    end
    if profKey then ES.db.prof[profKey].assistantPicked = time() + 0.5 end
  end
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

-- Opciones del asistente, en su categoría de la ventana de opciones (Options.lua). Se
-- añaden desde aquí: el asistente aún no se publica y, sin él, no salen
if ES.OPTIONS and ES.OPTION_CATEGORIES then
  table.insert(ES.OPTION_CATEGORIES, { key = "assistant", label = "Asistente de ruta" })
  -- La primera: activarlo (beta, desactivado por defecto). Las demás solo valen con él
  table.insert(ES.OPTIONS, { key = "assistantEnabled", cat = "assistant", label = "Activar el asistente de ruta (beta)",
    desc = "Un banner pequeño que te guía por tu ruta empezada paso a paso, sin abrir la ventana del addon: qué toca, una flecha hasta el instructor o el vendedor, y qué comprar. Está en pruebas: cuéntanos en Discord qué tal.",
    get = function() return A.Enabled() end,
    set = function(on)
      DB().enabled = on or nil
      A.Refresh()
      -- (el botón del catalejo junto a Dejar ruta sale o se quita)
      for _, page in ipairs(ES.professionPages or {}) do
        if page.initialized and page:IsVisible() then ES:RenderPlan(page) end
      end
    end })
  table.insert(ES.OPTIONS, { key = "assistantAuto", cat = "assistant", label = "Sacar el asistente al empezar una ruta",
    desc = "Al empezar una ruta sale solo el asistente con ella. Desactivado, solo sale cuando lo abres: botón del catalejo junto a Dejar ruta, o /cj mini.",
    get = function() return not DB().noAuto end,
    set = function(on) DB().noAuto = (not on) or nil A.Refresh() end })
  table.insert(ES.OPTIONS, { key = "assistantLocked", cat = "assistant", label = "Bloquear el asistente",
    desc = "No se mueve al arrastrarlo. También con clic derecho sobre él, donde además se cambia su tamaño.",
    get = function() return DB().locked == true end,
    set = function(on) DB().locked = on or nil A.RefreshMenu() end })
  table.insert(ES.OPTIONS, { key = "assistantArrow", cat = "assistant", label = "Mostrar la flecha GPS",
    desc = "Encima del asistente, una flecha que te lleva al instructor o al vendedor del paso, con las yardas y el tiempo. Al pulsar el banner se marca además el camino como en la ventana del addon.",
    get = function() return not DB().noArrow end,
    set = function(on) DB().noArrow = (not on) or nil A.NavTick() end })
  table.insert(ES.OPTIONS, { key = "assistantMinimapPin", cat = "assistant", label = "Destino en el minimapa",
    desc = "El instructor o el vendedor del paso en el minimapa, con una línea de puntos desde ti; si queda fuera, una flecha en el borde.",
    get = function() return not DB().noMinimapPin end,
    set = function(on) DB().noMinimapPin = (not on) or nil A.NavTick() end })
  table.insert(ES.OPTIONS, { key = "assistantWorldPin", cat = "assistant", label = "Destino en el mapa del mundo",
    desc = "El instructor o el vendedor del paso en el mapa del mundo, cuando lo abres.",
    get = function() return not DB().noWorldPin end,
    set = function(on) DB().noWorldPin = (not on) or nil A.NavTick() end })
  table.insert(ES.OPTIONS, { key = "assistantSteps", cat = "assistant", label = "Mostrar las flechas de pasos",
    desc = "Debajo del asistente, el icono de la profesión y las flechas para ojear los pasos anteriores y siguientes (\"7/15\"). Desactivadas, solo se ve el paso actual.",
    get = function() return not DB().noSteps end,
    set = function(on) DB().noSteps = (not on) or nil state.peek = nil A.Refresh() end })
  table.insert(ES.OPTIONS, { key = "assistantStepsAlways", cat = "assistant", label = "Flechas de pasos siempre visibles",
    desc = "Activado, la pestaña de las flechas de pasos se ve siempre. Desactivado, se despliega al pasar el ratón por el asistente y se pliega al salir.",
    get = function() return DB().stepsAlways == true end,
    set = function(on) DB().stepsAlways = on or nil A.Refresh() end })
end

-- El botón del asistente en la ventana (junto a Dejar ruta): si ya sigue esta ruta y se
-- ve, lo cierra; si no, lo abre con esta (sustituye a la que siguiera)
function A.ToggleFor(profKey)
  if not (profKey and ES:RouteLock(profKey) and A.Enabled()) then return end
  if frame and frame:IsShown() and state.profKey == profKey then
    A.Close()
    return
  end
  ES.db.prof[profKey].assistantPicked = time() + 0.5 -- (gana a una ruta empezada en el mismo segundo)
  SetHidden(profKey, false)
  A.Update()
end

---------------------------------------------------------------------------
-- Banco (docs/ASISTENTE.md, sección 3): el juego solo da lo que hay en el banco con el
-- banco abierto. Se guarda una foto por personaje (ES.charData.bank) al abrirlo y cada
-- vez que cambia; las filas de compra (ProfessionUI.lua, AddBuyLines) restan lo que hay
-- y antes de comprar piden ir a sacarlo. Con el banco abierto, su clic lo saca: justo
-- lo que falta, partiendo montones, a huecos libres de tus bolsas
---------------------------------------------------------------------------
local bankOpen = false
local BANK = BANK_CONTAINER or -1

local function BankBags()
  local first = (NUM_BAG_SLOTS or 4) + 1
  local list = { BANK }
  for bag = first, first + (NUM_BANKBAGSLOTS or 6) - 1 do list[#list + 1] = bag end
  return list
end

local function NumSlots(bag)
  local f = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  return f and f(bag) or 0
end

-- itemID, unidades y si está bloqueado (moviéndose) de un hueco; nil si está vacío
local function SlotItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount, info.isLocked end
    return nil
  end
  if GetContainerItemInfo then
    local _, count, locked, _, _, _, _, _, _, id = GetContainerItemInfo(bag, slot)
    return id, count, locked
  end
end

local function Pickup(bag, slot)
  local f = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
  if f then f(bag, slot) end
end

local function Split(bag, slot, n)
  local f = (C_Container and C_Container.SplitContainerItem) or SplitContainerItem
  if f then f(bag, slot, n) end
end

local function BankData()
  local c = ES.charData
  if not c then return nil end
  c.bank = c.bank or {}
  return c.bank
end

-- Foto de lo que hay en el banco (solo con el banco abierto)
local function SnapshotBank()
  local data = BankData()
  if not (data and bankOpen) then return end
  local items = {}
  for _, bag in ipairs(BankBags()) do
    for slot = 1, NumSlots(bag) do
      local id, count = SlotItem(bag, slot)
      if id then items[id] = (items[id] or 0) + (count or 1) end
    end
  end
  data.items, data.time = items, time()
end
A.SnapshotBank = SnapshotBank -- (para pruebas)

-- Unidades de un objeto en el banco según la última foto (0 si nunca lo abriste)
function A.BankCount(itemID)
  local data = BankData()
  return data and data.items and data.items[itemID] or 0
end

function A.BankOpen() return bankOpen end
A.SetBankOpen = function(v) bankOpen = v end -- (para pruebas)

-- Saca a las bolsas lo que falta de cada material (items: { itemID, quantity }): montones
-- enteros si caben, si no partidos, siempre a huecos libres de las bolsas (no se juntan
-- con montones a medias: así cada movimiento es uno solo). Devuelve lo que no cupo
function A.TakeFromBank(items)
  if not bankOpen then return end
  if CursorHasItem and CursorHasItem() then ClearCursor() end
  -- Huecos libres de tus bolsas (0 a NUM_BAG_SLOTS)
  local free = {}
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, NumSlots(bag) do
      if not SlotItem(bag, slot) then free[#free + 1] = { bag, slot } end
    end
  end
  local left = 0
  for _, want in ipairs(items) do
    local need = want.quantity
    for _, bag in ipairs(BankBags()) do
      for slot = 1, NumSlots(bag) do
        if need <= 0 then break end
        local id, count, locked = SlotItem(bag, slot)
        if id == want.itemID and not locked and count and count > 0 then
          local dest = table.remove(free, 1)
          if not dest then break end
          local take = math.min(count, need)
          if take < count then Split(bag, slot, take) else Pickup(bag, slot) end
          Pickup(dest[1], dest[2])
          -- Una bolsa de profesión puede no aceptarlo: entonces se devuelve al banco
          if CursorHasItem and CursorHasItem() then
            ClearCursor()
          else
            need = need - take
          end
        end
      end
    end
    left = left + math.max(0, need)
  end
  if left > 0 then
    ES:Print(string.format(L["No cabe todo en tus bolsas: faltan %d por sacar del banco."], left))
  end
  return left
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

-- Banco: foto al abrirlo y cuando cambia (sacar o meter algo); al cerrarlo, la ruta se
-- relee (el clic de su fila ya no saca, marca el camino)
do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BAG_UPDATE_DELAYED" }) do
    ES.SafeRegister(f, e)
  end
  local stamp = 0
  f:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then
      bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
      bankOpen = false
      A.Refresh()
      return
    elseif not bankOpen then
      return
    end
    -- (varios cambios seguidos al sacar: una sola foto)
    stamp = stamp + 1
    local mine = stamp
    C_Timer.After(0.2, function()
      if mine ~= stamp then return end
      SnapshotBank()
      A.Refresh()
    end)
  end)
end
