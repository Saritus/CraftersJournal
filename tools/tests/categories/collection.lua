-- Colección de recetas: cuántas tienes de cada profesión y dónde conseguir las demás

for _, state in ipairs({ "empty", "scan", "full" }) do
  test("la portada y la colección de cada profesión se abren: " .. state, function()
    OpenPage("patterns")
    for _, prof in ipairs(ProfessionKeys()) do
      ES:SelectPage("pattern:" .. prof)
      RunTimers()
      expect(ES:GetMainFrame().pages["pattern:" .. prof]:IsShown(), "la colección de %s no se ve", prof)
    end
  end, { state = state })
end

test("las cuentas de una profesión cuadran", function()
  local known = {}
  local n = 0
  for id, r in pairs(ES.Data.Tailoring.recipes) do
    if r.fee and n < 7 then KNOWN_SPELLS[id], known[id], n = true, true, n + 1 end
  end
  SKILLS[ES.Data.Tailoring.skillLine] = { 120, 150 }
  local res = ES.Collection:Build("Tailoring")
  expect_eq(res.total, #res.entries, "total = recetas listadas")
  local k, sumTotal, sumKnown = 0, 0, 0
  for _, e in ipairs(res.entries) do
    if e.known then k = k + 1 end
    expect(e.known == (KNOWN_SPELLS[e.id] == true), "%s: sabida %s", tostring(e.recipe.name), tostring(e.known))
    expect(res.by[e.main], "%s: fuente %s desconocida", tostring(e.recipe.name), tostring(e.main))
  end
  for _, b in pairs(res.by) do sumTotal, sumKnown = sumTotal + b.total, sumKnown + b.known end
  expect_eq(res.known, k, "sabidas")
  expect_eq(res.known, 7, "sabidas (las 7 marcadas)")
  expect_eq(sumTotal, res.total, "suma por fuente")
  expect_eq(sumKnown, res.known, "sabidas por fuente")
  local pk, pt = ES.Collection:Progress("Tailoring")
  expect_eq(pk, 7, "progreso de la portada: sabidas")
  expect(pt >= res.total - 50 and pt > 0, "progreso de la portada: total %d (colección %d)", pt, res.total)
end)

test("una receta de instructor que no tienes: dónde y si ya puedes aprenderla", function()
  SKILLS[ES.Data.Tailoring.skillLine] = { 100, 150 }
  local res = ES.Collection:Build("Tailoring")
  local found
  for _, e in ipairs(res.entries) do
    if not e.known and e.recipe.fee and e.recipe.train and e.recipe.train <= 100 then found = e break end
  end
  expect(found, "ninguna receta de instructor por debajo de 100")
  local trainer = false
  for _, s in ipairs(found.sources) do if s.kind == "trainer" then trainer = true end end
  expect(trainer, "%s no dice que es de instructor", tostring(found.recipe.name))
  expect(found.learnableNow, "%s (instructor, nivel %d) no sale como que ya puedes aprenderla", tostring(found.recipe.name), found.recipe.train)
  expect(#res.next > 0, "sin «siguientes recetas»")
end)

test("las recetas sabidas se guardan por personaje", function()
  SKILLS[ES.Data.Cooking.skillLine] = { 50, 75 }
  for id in pairs(ES.Data.Cooking.recipes) do KNOWN_SPELLS[id] = true break end
  ES.Collection:SaveKnown("Cooking")
  local mine = ES.db.known and ES.db.known[ES:CharKey()]
  expect(mine and mine.Cooking and #mine.Cooking >= 1, "no se guardaron")
end)
