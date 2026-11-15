local _, ES = ...

---------------------------------------------------------------------------
-- Herramientas del desarrollador. ESTE ARCHIVO NO SE PUBLICA: en el .toc va dentro
-- de #@do-not-package@ (el empaquetador de CurseForge quita esas líneas) y .pkgmeta y
-- tools/package.py lo dejan fuera del zip. Los jugadores no tienen estos comandos.
--
--   /cj whatsnew            todas las novedades (como mucho 3), sin contar como vistas
--   /cj whatsnew 0.48.0     solo las de esa versión
---------------------------------------------------------------------------

-- Lo llama el comando /cj (Core.lua) antes que los suyos. Devuelve true si era de aquí
function ES.DevCommand(msg)
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
