"""Genera la flecha 3D del asistente de ruta (Assistant.lua): una flecha con volumen
(lomo en el centro, laterales y sombra en el suelo) vista desde detrás y arriba, en
FRAMES ángulos. Se pinta en blanco cálido: el juego la tiñe (SetVertexColor) de dorado,
verde o rojo según vayas bien orientado.

Salen en Media/Assistant/ como TGA sin compresión, con alfa:
  Arrow.tga   - GRID x GRID fotogramas de CELL px (el 0 apunta hacia delante; van en
                el sentido de las agujas del reloj, de izquierda a derecha y de arriba abajo)
  Arrived.tga - "has llegado": un anillo en el suelo con la flecha apuntando hacia abajo
  Pin.tga, Edge.tga, Dot.tga - minimapa y mapa del mundo: el destino, la flecha del
                borde del minimapa (se gira en el juego) y los puntos de la línea

Sin dependencias: se rasteriza a mano (z-buffer y supermuestreo).

    python tools/gen_assistant_arrow.py
"""
import math
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "Media" / "Assistant"
GRID, CELL = 8, 64
FRAMES = GRID * GRID
SS = 3  # supermuestreo por lado
ELEV = math.radians(50)  # cámara: 50º sobre el suelo, detrás de la flecha
SCALE = 25.0  # píxeles por unidad
LIGHT = (-0.45, 0.35, 0.82)  # de arriba, a la izquierda y un poco de delante
H, RIDGE = 0.12, 0.20  # alto de los bordes y del lomo


def norm(v):
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return sum(a[i] * b[i] for i in range(3))


LIGHT = norm(LIGHT)


def arrow_mesh():
    """Triángulos de la flecha apuntando a +Y, sobre el suelo (z = 0)."""
    tip = (0.0, 1.0, RIDGE)
    cn, ct = (0.0, 0.12, RIDGE), (0.0, -0.9, RIDGE)
    tris = []
    for s in (1, -1):
        head, notch, tail = (0.58 * s, 0.12, H), (0.22 * s, 0.12, H), (0.22 * s, -0.9, H)
        tris += [(tip, head, notch), (tip, notch, cn), (cn, notch, tail), (cn, tail, ct)]
    # Laterales: del borde de arriba al suelo, por todo el contorno
    outline = [tip, (0.58, 0.12, H), (0.22, 0.12, H), (0.22, -0.9, H), ct,
               (-0.22, -0.9, H), (-0.22, 0.12, H), (-0.58, 0.12, H)]
    for i in range(len(outline)):
        a, b = outline[i], outline[(i + 1) % len(outline)]
        a0, b0 = (a[0], a[1], 0.0), (b[0], b[1], 0.0)
        tris += [(a, b, b0), (a, b0, a0)]
    return tris


def footprint():
    pts = [(0.0, 1.0), (0.58, 0.12), (0.22, 0.12), (0.22, -0.9), (-0.22, -0.9), (-0.22, 0.12), (-0.58, 0.12)]
    return [((0.0, 1.0, 0.0), (p[0], p[1], 0.0), (q[0], q[1], 0.0)) for p, q in zip(pts[1:], pts[2:])]


def rotate(p, theta):
    """Giro en el sentido de las agujas del reloj visto desde arriba (+Y hacia +X)."""
    c, s = math.cos(theta), math.sin(theta)
    return (p[0] * c + p[1] * s, -p[0] * s + p[1] * c, p[2])


def project(p, size, cx, cy):
    # Pantalla: x a la derecha, y hacia abajo. Profundidad: más pequeña = más cerca
    sx = cx + p[0] * SCALE * SS
    sy = cy - (p[1] * math.sin(ELEV) + p[2] * math.cos(ELEV)) * SCALE * SS
    depth = p[1] * math.cos(ELEV) - p[2] * math.sin(ELEV)
    return sx, sy, depth


def raster(tri, size, cx, cy, plot):
    (x1, y1, d1), (x2, y2, d2), (x3, y3, d3) = [project(p, size, cx, cy) for p in tri]
    area = (x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)
    if abs(area) < 1e-9:
        return
    minx, maxx = max(0, int(min(x1, x2, x3))), min(size - 1, int(max(x1, x2, x3)) + 1)
    miny, maxy = max(0, int(min(y1, y2, y3))), min(size - 1, int(max(y1, y2, y3)) + 1)
    for py in range(miny, maxy + 1):
        y = py + 0.5
        for px in range(minx, maxx + 1):
            x = px + 0.5
            w1 = ((x2 - x) * (y3 - y) - (x3 - x) * (y2 - y)) / area
            w2 = ((x3 - x) * (y1 - y) - (x1 - x) * (y3 - y)) / area
            w3 = 1 - w1 - w2
            if w1 < -1e-6 or w2 < -1e-6 or w3 < -1e-6:
                continue
            plot(px, py, w1 * d1 + w2 * d2 + w3 * d3)


def shade(n):
    """Blanco cálido con luz difusa, ambiente y un brillo."""
    if n[2] < 0:
        n = tuple(-c for c in n)
    diff = max(0.0, dot(n, LIGHT))
    view = norm((0.0, -math.cos(ELEV), math.sin(ELEV)))
    half = norm(tuple(LIGHT[i] + view[i] for i in range(3)))
    spec = max(0.0, dot(n, half)) ** 24
    k = 0.32 + 0.68 * diff
    base = (255 * k, 246 * k, 222 * k)
    return tuple(min(255.0, c + 210 * spec) for c in base)


def render(theta, mesh, shadow, arrived=False):
    size = CELL * SS
    cx, cy = size / 2, size / 2 + 6 * SS
    color = [[None] * size for _ in range(size)]
    alpha = [[0.0] * size for _ in range(size)]
    zbuf = [[1e9] * size for _ in range(size)]

    # Sombra en el suelo, desplazada y transparente
    for tri in shadow:
        moved = [rotate((p[0] + 0.06, p[1] - 0.10, 0.0), theta) for p in tri]

        def plot_shadow(px, py, d):
            if alpha[py][px] < 0.35:
                color[py][px], alpha[py][px] = (0.0, 0.0, 0.0), 0.35
        raster(moved, size, cx, cy, plot_shadow)

    for tri in mesh:
        pts = [rotate(p, theta) for p in tri]
        n = norm(cross(sub(pts[1], pts[0]), sub(pts[2], pts[0])))
        # Normal hacia fuera: hacia arriba en la cara de arriba; en los laterales, lejos del centro
        mid = tuple(sum(p[i] for p in pts) / 3 for i in range(3))
        if n[2] < -0.2 or (abs(n[2]) <= 0.2 and dot(n, (mid[0], mid[1], 0.0)) < 0):
            n = tuple(-c for c in n)
        c = shade(n)

        def plot(px, py, d, c=c):
            if d < zbuf[py][px]:
                zbuf[py][px] = d
                color[py][px], alpha[py][px] = c, 1.0
        raster(pts, size, cx, cy, plot)

    # Contorno oscuro de 1 px (a escala final): se lee sobre cualquier fondo
    edge = SS
    solid = [[alpha[y][x] >= 1.0 for x in range(size)] for y in range(size)]
    for y in range(size):
        for x in range(size):
            if solid[y][x]:
                continue
            near = False
            for dy in range(-edge, edge + 1):
                yy = y + dy
                if 0 <= yy < size:
                    for dx in range(-edge, edge + 1):
                        xx = x + dx
                        if 0 <= xx < size and solid[yy][xx]:
                            near = True
                            break
                if near:
                    break
            if near:
                color[y][x], alpha[y][x] = (40.0, 26.0, 8.0), max(alpha[y][x], 0.9)

    # Reducir (media con alfa)
    out = []
    for y in range(CELL):
        row = []
        for x in range(CELL):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    yy, xx = y * SS + sy, x * SS + sx
                    al = alpha[yy][xx]
                    if al > 0:
                        cr, cg, cb = color[yy][xx]
                        r, g, b, a = r + cr * al, g + cg * al, b + cb * al, a + al
            if a > 0:
                r, g, b = r / a, g / a, b / a
            row.append((int(r + 0.5), int(g + 0.5), int(b + 0.5), int(a / (SS * SS) * 255 + 0.5)))
        out.append(row)
    return out


def arrived_icon():
    """Anillo en el suelo (elipse por la perspectiva) y la flecha encima apuntando abajo."""
    size = CELL * SS
    pix = [[(0.0, 0.0, 0.0, 0.0)] * size for _ in range(size)]
    cx, cy = size / 2, size * 0.68
    rx, ry = size * 0.36, size * 0.36 * math.sin(ELEV)
    for y in range(size):
        for x in range(size):
            e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if 0.62 <= e <= 1.0:
                k = 0.75 + 0.25 * (1 - abs(e - 0.81) / 0.19)
                pix[y][x] = (255 * k, 246 * k, 222 * k, 1.0)
            elif 0.52 <= e < 0.62 or 1.0 < e <= 1.12:
                pix[y][x] = (40.0, 26.0, 8.0, 0.9)
    # Flecha hacia abajo (triángulo con borde) sobre el anillo
    tw, top, bottom = size * 0.2, size * 0.08, size * 0.56

    def inside(x, y, grow):
        t = (y - (top - grow)) / ((bottom + grow) - (top - grow))
        return 0 <= t <= 1 and abs(x - cx) <= (tw + grow) * (1 - t)
    for y in range(size):
        for x in range(size):
            if inside(x, y, 0):
                k = 0.55 + 0.45 * (1 - (x - cx + tw) / (2 * tw)) if x < cx else 0.8
                pix[y][x] = (255 * k, 246 * k, 222 * k, 1.0)
            elif inside(x, y, 3 * SS):
                pix[y][x] = (40.0, 26.0, 8.0, 0.9)
    out = []
    for y in range(CELL):
        row = []
        for x in range(CELL):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    cr, cg, cb, al = pix[y * SS + sy][x * SS + sx]
                    r, g, b, a = r + cr * al, g + cg * al, b + cb * al, a + al
            if a > 0:
                r, g, b = r / a, g / a, b / a
            row.append((int(r + 0.5), int(g + 0.5), int(b + 0.5), int(a / (SS * SS) * 255 + 0.5)))
        out.append(row)
    return out


def small_icon(kind, size=32):
    """Iconos del minimapa y del mapa (blancos, para teñirlos):
    pin  - el destino: un rombo con borde oscuro
    edge - en el borde del minimapa: una flecha que apunta hacia arriba (se gira)
    dot  - punto de la línea del jugador al destino"""
    ss = 4
    big = size * ss
    c = big / 2
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            r = g = b = a = 0.0
            for sy in range(ss):
                for sx in range(ss):
                    px, py = (x * ss + sx + 0.5 - c) / c, (y * ss + sy + 0.5 - c) / c  # -1..1
                    col, al = None, 0.0
                    if kind == "pin":
                        d = abs(px) + abs(py)
                        if d <= 0.62:
                            k = 0.75 + 0.25 * (1 - (px - py + 1.24) / 2.48)  # luz arriba a la izquierda
                            col, al = (255 * k, 246 * k, 222 * k), 1.0
                        elif d <= 0.82:
                            col, al = (40, 26, 8), 0.95
                    elif kind == "edge":
                        t = (py + 0.8) / 1.5  # 0 en la punta (arriba), 1 en la base
                        w = 0.62 * t
                        if 0 <= t <= 1 and abs(px) <= w:
                            k = 0.7 + 0.3 * (1 - t)
                            col, al = (255 * k, 246 * k, 222 * k), 1.0
                        else:
                            t2 = (py + 1.0) / 1.85
                            if 0 <= t2 <= 1 and abs(px) <= 0.62 * t2 + 0.12:
                                col, al = (40, 26, 8), 0.95
                    else:  # dot
                        d = math.sqrt(px * px + py * py)
                        if d <= 0.5:
                            col, al = (255, 246, 222), 1.0
                        elif d <= 0.75:
                            col, al = (40, 26, 8), 0.8
                    if col:
                        r, g, b, a = r + col[0] * al, g + col[1] * al, b + col[2] * al, a + al
            if a > 0:
                r, g, b = r / a, g / a, b / a
            row.append((int(r + 0.5), int(g + 0.5), int(b + 0.5), int(a / (ss * ss) * 255 + 0.5)))
        rows.append(row)
    return rows


def write_tga(path, rows):
    h, w = len(rows), len(rows[0])
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x28)
    body = bytearray()
    for row in rows:
        for r, g, b, a in row:
            body += bytes((b, g, r, a))
    path.write_bytes(header + bytes(body))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    mesh, shadow = arrow_mesh(), footprint()
    sheet = [[(0, 0, 0, 0)] * (GRID * CELL) for _ in range(GRID * CELL)]
    for i in range(FRAMES):
        cell = render(2 * math.pi * i / FRAMES, mesh, shadow)
        oy, ox = (i // GRID) * CELL, (i % GRID) * CELL
        for y in range(CELL):
            sheet[oy + y][ox:ox + CELL] = cell[y]
    write_tga(OUT / "Arrow.tga", sheet)
    write_tga(OUT / "Arrived.tga", arrived_icon())
    for kind, name in (("pin", "Pin"), ("edge", "Edge"), ("dot", "Dot")):
        write_tga(OUT / f"{name}.tga", small_icon(kind))
    print("escritas en", OUT)


if __name__ == "__main__":
    main()
