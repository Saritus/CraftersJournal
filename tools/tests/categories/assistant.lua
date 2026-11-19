-- Asistente de ruta: el banner con el paso que toca de la ruta empezada

local A

local function Steps()
  local lines = ES:RouteLines("Tailoring", { buy = true })
  local current
  for _, l in ipairs(lines or {}) do if l.current then current = l end end
  return lines, current
end

test("sin ruta empezada no sale", function()
  A = ES.Assistant
  A.Update()
  local f = A.Frame()
  expect(not (f and f:IsShown()), "el asistente sale sin ruta")
end)

test("con una ruta empezada sale con el paso que toca", function()
  A = ES.Assistant
  StartRoute("Tailoring", 1, 75)
  A.Update()
  RunTimers()
  local f = expect(A.Frame(), "no hay ventana del asistente")
  expect(f:IsShown(), "con una ruta empezada el asistente debería verse")
  local st = A.State()
  local lines, current = Steps()
  expect(current, "la ruta no tiene paso actual")
  expect(#st.steps > 0, "el asistente no tiene pasos")
  local title = tostring(f.banner.title._text)
  expect(title == tostring(current.bannerTitle or current.title), "el banner dice «%s» y el paso actual de la ruta es «%s»",
    title, tostring(current.bannerTitle or current.title))
  note("paso: %s · %s", tostring(f.banner.level._text), title)
end, { state = "scan" })

test("flechas: ojear el paso siguiente y volver", function()
  A = ES.Assistant
  StartRoute("Tailoring", 1, 75)
  A.Update()
  local f, st = A.Frame(), A.State()
  if #st.steps < 2 then note("solo un paso: nada que ojear") return end
  local title = f.banner.title._text
  f.arrows.next._scripts.OnClick(f.arrows.next)
  expect(st.peek, "no ojea el siguiente")
  f.arrows.prev._scripts.OnClick(f.arrows.prev)
  expect(st.peek == nil and f.banner.title._text == title, "no vuelve al paso actual")
end, { state = "scan" })

test("al subir de nivel pasa al paso siguiente", function()
  A = ES.Assistant
  local page, plan = StartRoute("Tailoring", 1, 75)
  A.Update()
  local before = A.State().index
  local first = plan.steps[1]
  expect(first and plan.steps[2], "la ruta tiene un solo paso")
  SKILLS[ES.Data.Tailoring.skillLine] = { first.to, 75 }
  FireEvent("SKILL_LINES_CHANGED")
  RunTimers()
  A.Update()
  RunTimers()
  local _, current = Steps()
  local f = A.Frame()
  expect(A.State().index ~= before or tostring(f.banner.title._text) == tostring(current.bannerTitle or current.title),
    "el asistente no avanza al subir a %d", first.to)
  expect(tostring(f.banner.title._text) == tostring(current.bannerTitle or current.title), "el banner no es el paso actual")
end, { state = "scan" })

test("en combate no se toca lo protegido", function()
  A = ES.Assistant
  StartRoute("Tailoring", 1, 75)
  IN_COMBAT = true
  FireEvent("PLAYER_REGEN_DISABLED")
  A.Update()
  IN_COMBAT = false
  FireEvent("PLAYER_REGEN_ENABLED")
  RunTimers()
end, { state = "scan" })
