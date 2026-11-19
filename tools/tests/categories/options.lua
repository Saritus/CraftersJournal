-- Opciones: la ventana, y cada opción cambia lo que guarda y se aplica sin errores

local PAGES = { "home", "shopping", "money", "inventory", "favor", "calc", "patterns", "Leatherworking" }

test("la ventana de opciones se abre en cada categoría", function()
  for _, cat in ipairs(ES.OPTION_CATEGORIES) do
    ES:OpenOptions(cat.key)
    RunTimers()
  end
  local w = ES:OptionsWindow()
  expect(w and w:IsShown(), "la ventana no se ve")
end, { state = "full" })

test("cada opción de casilla: cambia lo guardado y se aplica", function()
  BAGS[2589], BAGS[2318] = 40, 12
  OpenPage("inventory")
  local n = 0
  for _, opt in ipairs(ES.OPTIONS) do
    if opt.kind ~= "slider" then
      for _, on in ipairs({ false, true }) do
        if opt.set then opt.set(on) else ES:SetOption(opt.key, on) end
        RunTimers()
        if opt.get then
          expect_eq(opt.get(), on, opt.key .. " tras cambiarla")
        else
          expect_eq(ES.db[opt.key], (not on) or nil, opt.key .. " guardada")
        end
      end
      n = n + 1
    end
  end
  note("%d opciones de casilla", n)
  for _, page in ipairs(PAGES) do ES:SelectPage(page) RunTimers() end
end, { state = "full" })

test("cada deslizador: cada escalón se guarda y se aplica", function()
  local n = 0
  for _, opt in ipairs(ES.OPTIONS) do
    if opt.kind == "slider" then
      for _, v in ipairs(opt.steps) do
        ES.db[opt.key] = v
        if opt.apply then opt.apply(v) else ES:ApplyOptions(opt.key) end
        RunTimers()
        no_error(opt.text, v)
      end
      n = n + 1
    end
  end
  expect(n > 0, "no hay deslizadores")
  OpenPage("money")
end, { state = "full" })

test("botón del minimapa: esconder y volver a enseñar", function()
  SlashCmdList.CRAFTERSJOURNAL("minimap")
  expect(ES.db.minimap.hide, "/cj minimap no lo esconde")
  SlashCmdList.CRAFTERSJOURNAL("minimap")
  expect(not ES.db.minimap.hide, "/cj minimap no lo enseña")
end)

test("comandos /cj sin errores", function()
  for _, cmd in ipairs({ "", "opciones", "errores", "minimap", "minimap", "ayuda", "algo raro" }) do
    no_error(SlashCmdList.CRAFTERSJOURNAL, cmd)
    RunTimers()
  end
end, { state = "full" })
