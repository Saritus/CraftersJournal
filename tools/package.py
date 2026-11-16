"""Genera el zip para CurseForge tal como lo haría BigWigsMods/packager.

  - Solo lo que se publica: fuera tools/, docs/, dist/, .github/, *.py, *.md y los
    archivos ocultos (.git, .pkgmeta...), igual que en .pkgmeta.
  - Dentro del zip, la carpeta CraftersJournal/ (lo que se copia a Interface\\AddOns).
  - La versión sale del .toc (## Version).
  - Las herramientas del desarrollador (DevTools.lua) no van: ni el archivo ni su
    línea del .toc (#@do-not-package@).

Uso: python tools/package.py          -> dist/CraftersJournal-<versión>.zip
Pasa las pruebas antes (python tools/build_data.py).
"""
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "CraftersJournal"
IGNORE_DIRS = {"tools", "docs", "dist", ".github", ".git", "__pycache__"}
IGNORE_EXT = {".py", ".md", ".pyc"}
# Herramientas del desarrollador y el asistente de ruta, que aún no se publica (como
# en .pkgmeta)
IGNORE_FILES = {"DevTools.lua", "Assistant.lua"}
IGNORE_PREFIXES = ("Media/Assistant/",)
# Como BigWigsMods/packager: en el .toc se quita lo que va entre estas dos líneas
DO_NOT_PACKAGE = re.compile(r"^#@do-not-package@\s*$.*?^#@end-do-not-package@\s*$\n?", re.M | re.S)


def published(path):
    rel = path.relative_to(ROOT)
    if any(part in IGNORE_DIRS or part.startswith(".") for part in rel.parts):
        return False
    if rel.as_posix() in IGNORE_FILES or rel.as_posix().startswith(IGNORE_PREFIXES):
        return False
    return path.suffix not in IGNORE_EXT


def main():
    toc = (ROOT / f"{NAME}.toc").read_text(encoding="utf-8")
    version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
    dest = ROOT / "dist" / f"{NAME}-{version}.zip"
    dest.parent.mkdir(exist_ok=True)
    files = sorted(p for p in ROOT.rglob("*") if p.is_file() and published(p))
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files:
            arc = f"{NAME}/{p.relative_to(ROOT).as_posix()}"
            if p.suffix == ".toc":
                z.writestr(arc, DO_NOT_PACKAGE.sub("", p.read_text(encoding="utf-8")))
            else:
                z.write(p, arc)
        names = z.namelist()
    # Nada del desarrollador en lo que se publica
    with zipfile.ZipFile(dest) as z:
        toc_out = z.read(f"{NAME}/{NAME}.toc").decode("utf-8")
        assert "DevTools" not in toc_out and f"{NAME}/DevTools.lua" not in z.namelist(), \
            "DevTools.lua se ha colado en el zip"
        assert "Assistant" not in toc_out and not any("Assistant" in n for n in z.namelist()), \
            "el asistente (aún sin publicar) se ha colado en el zip"
    print(f"{dest} ({dest.stat().st_size // 1024} KB, {len(names)} archivos, versión {version})")


if __name__ == "__main__":
    main()
