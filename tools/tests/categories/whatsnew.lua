-- Novedades: la ventana con lo nuevo, una vez por versión

local function SetVersion(v)
  GetAddOnMetadata = function(_, field) if field == "Version" then return v end end
end

local function Latest() return ES.WHATS_NEW[1].version end

test("comparar versiones número a número", function()
  local C = ES.CompareVersions
  expect_eq(C("0.9.0", "0.10.0"), -1, "0.9.0 < 0.10.0")
  expect_eq(C("0.10.0", "0.9.0"), 1, "0.10.0 > 0.9.0")
  expect_eq(C("0.63.0", "0.63.0"), 0, "iguales")
  expect_eq(C("1.0", "1.0.0"), 0, "1.0 = 1.0.0")
  expect_eq(C("0.63.1", "0.63.0"), 1, "parche")
end, { boot = false })

test("las notas: de la más nueva a la más antigua, sin las de versiones por publicar", function()
  local list = ES.WHATS_NEW
  expect(#list > 0, "sin notas")
  for i = 2, #list do
    expect(ES.CompareVersions(list[i - 1].version, list[i].version) > 0, "notas desordenadas: %s antes de %s", list[i - 1].version, list[i].version)
  end
  for _, v in ipairs(list) do
    expect(#v.items > 0, "%s sin novedades", v.version)
    for _, it in ipairs(v.items) do
      expect(type(it.title) == "string" and it.title ~= "" and type(it.text) == "string", "%s: novedad sin título o texto", v.version)
    end
  end
  local since = ES:WhatsNewSince(list[#list].version, list[2] and list[2].version or list[1].version)
  for _, v in ipairs(since) do
    expect(ES.CompareVersions(v.version, list[2] and list[2].version or list[1].version) <= 0, "sale %s, aún sin publicar", v.version)
  end
  expect(#since <= 3, "más de 3 versiones de golpe")
end, { boot = false })

test("versión nueva: sale una vez", function()
  SetVersion(Latest())
  ES.db.whatsNewSeen = list and nil or (ES.WHATS_NEW[2] and ES.WHATS_NEW[2].version or "0.1.0")
  ES:CheckWhatsNew()
  local f = expect(ES.WhatsNewFrame(), "no sale la ventana de novedades")
  expect(f:IsShown(), "la ventana no se ve")
  expect_eq(ES.db.whatsNewSeen, Latest(), "versión vista")
  f:Hide()
  ES:CheckWhatsNew()
  expect(not f:IsShown(), "sale otra vez con la misma versión")
end, { state = "scan" })

test("instalación nueva: no hay novedades que enseñar", function()
  SetVersion(Latest())
  ES:CheckWhatsNew()
  local f = ES.WhatsNewFrame()
  expect(not (f and f:IsShown()), "sale a quien acaba de instalar")
  expect_eq(ES.db.whatsNewSeen, Latest(), "no apunta la versión")
end, { state = "empty" })

test("«no volver a mostrar» y la opción la apagan", function()
  SetVersion(Latest())
  ES.db.whatsNewSeen = "0.1.0"
  ES.db.noWhatsNew = true
  ES:CheckWhatsNew()
  local f = ES.WhatsNewFrame()
  expect(not (f and f:IsShown()), "sale con la opción apagada")
end, { state = "scan" })

test("copia de desarrollo: no sale sola", function()
  SetVersion("@project-version@")
  expect_eq(ES.AddonVersion(), "dev", "versión de desarrollo")
  ES.db.whatsNewSeen = "0.1.0"
  ES:CheckWhatsNew()
  local f = ES.WhatsNewFrame()
  expect(not (f and f:IsShown()), "sale en la copia de desarrollo")
end, { state = "scan" })

test("al entrar sale a los pocos segundos", function()
  SetVersion(Latest())
  local db = Fixtures.State("scan")
  db.whatsNewSeen = "0.1.0"
  Boot(db)
  RunTimers()
  local f = ES.WhatsNewFrame()
  expect(f and f:IsShown(), "no salió al entrar")
end, { boot = false })
