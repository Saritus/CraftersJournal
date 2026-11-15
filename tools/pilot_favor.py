"""Merchant's Favor con tus datos guardados reales (harness.py): cada Waylaid Crate,
su paquete más barato y lo que cuesta cada punto de Favor con el último escaneo.
Uso:  python pilot_favor.py
"""
exec(open(__file__.replace("pilot_favor.py", "harness.py"), encoding="utf-8").read())
print(run(r"""
local out = {}
local function g(c) return c and string.format("%.2fg", c / 10000) or "-" end
ES.Favor.Clear()
local list = ES.Favor:Options()
local onAH, priced = 0, 0
for _, o in ipairs(list) do
  local c = o.crate
  if o.onAH then onAH = onAH + 1 end
  if o.fill then priced = priced + 1 end
  local fill = o.fill and string.format("%dx %s %s", o.fill.n, ES:DataItemName(o.fill.itemID) or o.fill.itemID, g(o.fill.cost)) or "sin precio"
  local crafts = o.fill and ES.Favor.Crafts(o.fill) or {}
  local craft = #crafts > 0 and (" (fabrica " .. crafts[1].qty .. "x " .. (ES:DataItemName(crafts[1].itemID) or crafts[1].itemID) .. ")") or ""
  out[#out+1] = string.format("%-34s %3s Favor  caja %-8s  %s%s  -> %s/punto", ES.Favor.CrateName(c), (c.guess and "~" or "") .. c.favor,
    o.crateCost and g(o.crateCost) or "-", fill, craft, o.perFavor and g(o.perFavor) or "-")
end
table.insert(out, 1, string.format("%d cajas: %d en la AH, %d con paquete con precio", #list, onAH, priced))
-- La pestaña se pinta sin errores
ES:GetMainFrame()
ES:SelectPage("favor")
ES:RenderFavor()
local n = 0
for _, row in ipairs(ES.favorPage.rows) do if row._shown ~= false then n = n + 1 if row.tooltip then row.tooltip(row) end end end
out[#out+1] = "pestaña: " .. n .. " filas"
return table.concat(out, "\n")
"""))
