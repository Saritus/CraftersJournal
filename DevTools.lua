local _, ES = ...

---------------------------------------------------------------------------
-- Herramientas del desarrollador. ESTE ARCHIVO NO SE PUBLICA: en el .toc va dentro
-- de #@do-not-package@ (el empaquetador de CurseForge quita esas líneas) y .pkgmeta y
-- tools/package.py lo dejan fuera del zip. Los jugadores no tienen estos comandos.
--
--   /cj whatsnew            todas las novedades (como mucho 3), sin contar como vistas
--   /cj whatsnew 0.55.0     solo las de esa versión
--   /cj mem                 en qué se va la memoria del addon (estimado, por partes) y
--                           cuánto había en cada momento de la entrada
--   /cj mem clear           cuánto libera vaciar cada caché
---------------------------------------------------------------------------

-- Bytes aproximados de un valor y lo que cuelga de él (Lua 5.1 de 64 bits: tabla 56,
-- casilla de array 16, nodo del hash 40 redondeado a potencia de 2, cadena 24 + largo).
-- `seen` comparte lo ya contado: lo que cuelga de dos sitios cuenta en el primero
local function Size(v, seen)
  local t = type(v)
  if t == "string" then
    if seen[v] then return 0 end
    seen[v] = true
    return 24 + #v
  end
  if t ~= "table" or seen[v] then return 0 end
  seen[v] = true
  local n = #v
  local hash = 0
  local bytes = 56 + n * 16
  for k, x in pairs(v) do
    if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then hash = hash + 1 end
    bytes = bytes + Size(k, seen) + Size(x, seen)
  end
  local nodes = 1
  while nodes < hash do nodes = nodes * 2 end
  return bytes + (hash > 0 and nodes * 40 or 0)
end

-- Memoria del addon ahora (KB), tras recoger la basura
local function AddonKB()
  collectgarbage("collect")
  local Update = (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage) or UpdateAddOnMemoryUsage
  local Usage = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
  if Update then Update() end
  return Usage and Usage("CraftersJournal") or 0
end

-- Cuándo crece: la memoria en cada momento de la entrada (para /cj mem)
local timeline = {}
local function Mark(label) timeline[#timeline + 1] = { label, AddonKB() } end
Mark("archivos cargados")
do
  local f = CreateFrame("Frame")
  for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }) do f:RegisterEvent(e) end
  local entered
  f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "CraftersJournal" then return end
    Mark(event)
    if event == "PLAYER_ENTERING_WORLD" and not entered and C_Timer then
      entered = true
      for _, s in ipairs({ 3, 6, 10, 20, 40, 90 }) do C_Timer.After(s, function() Mark("+" .. s .. " s") end) end
    end
  end)
end

-- Cuánto libera vaciar cada caché que se puede vaciar sin romper nada (se rehace al usarla)
local function ClearReport()
  local function Freed(label, fn)
    local before = AddonKB()
    pcall(fn)
    ES:Print(string.format("  %6.2f MB  %s", (before - AddonKB()) / 1024, label))
  end
  ES:Print("Vaciando cachés (lo que libera cada una):")
  Freed("rutas de la portada (homePlanCache)", function() ES:ClearHomeCache() end)
  Freed("Ganar dinero (Earn)", function() ES.Earn:Clear() end)
  Freed("Merchant's Favor", function() ES.Favor.Clear() end)
  Freed("demanda de TSM", function() ES.Market.ClearTSM() end)
end

local function MemoryReport()
  local total = AddonKB()
  local seen, rows = {}, {}
  local function Add(name, v) rows[#rows + 1] = { name, Size(v, seen) } end
  -- Primero lo guardado (por clave), los datos y los textos; después el resto de ES
  for k, v in pairs(ES.db or {}) do Add("db." .. tostring(k), v) end
  Add("Data", ES.Data)
  Add("Locales", ES.Locales)
  for k, v in pairs(ES) do
    if type(v) == "table" and k ~= "db" and k ~= "Data" and k ~= "Locales" then Add("ES." .. tostring(k), v) end
  end
  table.sort(rows, function(a, b) return a[2] > b[2] end)
  local reached = 0
  for _, r in ipairs(rows) do reached = reached + r[2] end
  ES:Print(string.format("Memoria: %.1f MB en total (tras recoger la basura); %.1f MB alcanzables desde ES (estimado)",
    total / 1024, reached / 1048576))
  for i = 1, math.min(15, #rows) do
    if rows[i][2] < 50 * 1024 then break end
    ES:Print(string.format("  %6.2f MB  %s", rows[i][2] / 1048576, rows[i][1]))
  end
  ES:Print(string.format("  %6.2f MB  el resto (variables locales: cachés de rutas, índice de mercado...)",
    math.max(0, total / 1024 - reached / 1048576)))
  ES:Print("Al entrar (MB, tras recoger la basura):")
  local prev
  for _, m in ipairs(timeline) do
    ES:Print(string.format("  %6.2f  %s%s", m[2] / 1024, m[1],
      prev and string.format("  (%+.2f)", (m[2] - prev) / 1024) or ""))
    prev = m[2]
  end
end
ES.MemoryReport, ES.MemoryClearReport = MemoryReport, ClearReport -- (pruebas)

-- Lo llama el comando /cj (Core.lua) antes que los suyos. Devuelve true si era de aquí
function ES.DevCommand(msg)
  if msg:match("^mem%s*$") then MemoryReport() return true end
  if msg:match("^mem%s+clear%s*$") then ClearReport() return true end
  local version = msg:match("^whatsnew%s*(%S*)$")
  if not version then return false end
  local notes = {}
  for _, v in ipairs(ES.WHATS_NEW) do
    if version == "" or v.version == version then notes[#notes + 1] = v end
    if #notes >= 3 then break end
  end
  if #notes == 0 then
    ES:Print("No hay notas de la versión " .. version .. " en ES.WHATS_NEW (WhatsNew.lua).")
  else
    ES:ShowWhatsNew(notes, true)
  end
  return true
end
