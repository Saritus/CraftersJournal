-- Idiomas: el addon está escrito en español; cada texto se traduce por su clave
-- (el texto en español) en Locales/enUS.lua, deDE.lua y frFR.lua. Los nombres de
-- recetas y objetos de cada idioma, en Data/Names_*.lua (solo los que cambian
-- respecto al inglés: un hueco quiere decir «igual que en inglés»).

local function ReadFile(path)
  local f = assert(io.open(ADDON_DIR .. "/" .. path:gsub("\\", "/"), "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

-- Lo que no se traduce al pasar: %s, %d, %.1f..., colores |c...|r e iconos |T
local function Tokens(s)
  local t = {}
  for tok in s:gmatch("%%[-+ #0]*%d*%.?%d*[dsfxXq%%]") do t[#t + 1] = tok end
  for _ in s:gmatch("|c%x%x%x%x%x%x%x%x") do t[#t + 1] = "c" end
  for _ in s:gmatch("|r") do t[#t + 1] = "r" end
  for _ in s:gmatch("|T") do t[#t + 1] = "T" end
  return table.concat(t, " ")
end

-- Los textos que el código pide con L["..."] (literales), con dónde
local function UsedKeys()
  local used = {}
  for _, f in ipairs(TOC_FILES) do
    -- (Locale.lua no: su L["texto"] es un ejemplo en un comentario)
    if not f:match("^Libs") and not f:match("^Data") and not f:match("^Locales") and f ~= "Locale.lua" then
      local src = ReadFile(f)
      local line = 1
      local pos = 1
      for s, key, e in src:gmatch('()L%["(.-)"%]()') do
        if not key:find('\\', 1, true) then -- (las de comillas escapadas, aparte: raras)
          local _, nl = src:sub(pos, s):gsub("\n", "")
          line, pos = line + nl, s
          used[key] = used[key] or (f .. ":" .. line)
        end
      end
    end
  end
  return used
end

local function Sorted(t) table.sort(t) return t end

test("cada texto que pide el código está traducido al inglés", function()
  local used, missing, n = UsedKeys(), {}, 0
  for key, where in pairs(used) do
    n = n + 1
    if not ES.Locales.en[key] then missing[#missing + 1] = where .. ": " .. key end
  end
  note("%d textos distintos en el código", n)
  expect(n > 200, "se leyeron pocos textos (%d): ¿ha cambiado la forma de L[...]?", n)
  Sorted(missing)
  expect(#missing == 0, "%d textos sin inglés (salen en español):\n    %s", #missing, table.concat(missing, "\n    "):sub(1, 1500))
end, { boot = false })

test("alemán y francés: las mismas claves y el mismo formato que el inglés", function()
  for _, lang in ipairs({ "de", "fr" }) do
    local loc = expect(ES.Locales[lang], "falta ES.Locales.%s", lang)
    local missing, extra, bad = {}, {}, {}
    for key, en in pairs(ES.Locales.en) do
      local v = loc[key]
      if not v then missing[#missing + 1] = key
      elseif Tokens(v) ~= Tokens(en) then bad[#bad + 1] = key .. " -> " .. v end
    end
    for key in pairs(loc) do if not ES.Locales.en[key] then extra[#extra + 1] = key end end
    expect(#missing == 0, "%s: %d sin traducir: %s", lang, #missing, table.concat(Sorted(missing), " | "):sub(1, 600))
    expect(#extra == 0, "%s: %d que el inglés no tiene: %s", lang, #extra, table.concat(Sorted(extra), " | "):sub(1, 600))
    expect(#bad == 0, "%s: formato distinto del inglés: %s", lang, table.concat(Sorted(bad), " | "):sub(1, 600))
  end
end, { boot = false })

test("inglés: el mismo formato que el texto en español", function()
  local bad = {}
  for key, en in pairs(ES.Locales.en) do
    if Tokens(key) ~= Tokens(en) then bad[#bad + 1] = key .. " -> " .. en end
  end
  expect(#bad == 0, "%d traducciones con otros %%s/%%d/colores que el original:\n    %s", #bad, table.concat(Sorted(bad), "\n    "):sub(1, 1500))
end, { boot = false })

test("nombres de los datos: de recetas que existen y sin vacíos", function()
  local recipes = {}
  for _, prof in ipairs(ProfessionKeys()) do
    for id in pairs(ES.Data[prof].recipes) do recipes[id] = true end
  end
  for lang, set in pairs(ES.Data.Names) do
    local orphan, empty, ns, ni = {}, {}, 0, 0
    for id, name in pairs(set.spells or {}) do
      ns = ns + 1
      if not recipes[id] then orphan[#orphan + 1] = tostring(id) end
      if type(name) ~= "string" or name == "" then empty[#empty + 1] = "receta " .. id end
    end
    for id, name in pairs(set.items or {}) do
      ni = ni + 1
      if type(name) ~= "string" or name == "" then empty[#empty + 1] = "objeto " .. id end
    end
    note("%s: %d recetas y %d objetos con nombre propio", lang, ns, ni)
    expect(ns > 1000 and ni > 1000, "%s: pocos nombres (%d recetas, %d objetos)", lang, ns, ni)
    expect(#empty == 0, "%s: nombres vacíos: %s", lang, table.concat(empty, ", "):sub(1, 400))
    expect(#orphan == 0, "%s: nombres de recetas que no están en los datos: %s", lang, table.concat(Sorted(orphan), ", "):sub(1, 400))
  end
end, { boot = false })

test("cambiar de idioma: textos, recetas y números", function()
  ES:SetLanguage("de")
  expect_eq(ES.L["Lista de compra"], "Einkaufsliste", "texto en alemán")
  expect_eq(ES.Num(2.5), "2,5", "coma decimal en alemán")
  ES:SetLanguage("en")
  expect_eq(ES.L["Lista de compra"], ES.Locales.en["Lista de compra"], "texto en inglés")
  expect_eq(ES.Data.Leatherworking.recipes[2149].name, "Handstitched Leather Boots", "receta con su nombre original")
  expect_eq(ES.Num(2.5), "2.5", "punto decimal en inglés")
  ES:SetLanguage("es")
  expect_eq(ES.L["Lista de compra"], "Lista de compra", "texto en español")
end)

-- Cambiar de idioma con cada pestaña abierta (la ventana se vuelve a crear)
for _, page in ipairs({ "home", "shopping", "money", "inventory", "favor", "calc", "patterns", "Leatherworking", "pattern:Tailoring" }) do
  test("cambiar de idioma con la página «" .. page .. "» abierta", function()
    OpenPage(page)
    for _, l in ipairs(ES.LANGS) do
      local lang = l.key
      ES:SetLanguage(lang)
      RunTimers()
      expect(ES:GetMainFrame():IsShown(), "al pasar a %s la ventana se cerró", lang)
      expect_eq(ES.db.lastPage, page, "página tras pasar a " .. lang)
    end
  end, { state = "full" })
end
