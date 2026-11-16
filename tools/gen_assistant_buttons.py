"""Genera las flechas ◀ ▶ del asistente de ruta (Assistant.lua) con el aspecto de la X de
cerrar del juego: cuadrado rojo con marco dorado y el símbolo en dorado.

Salen en Media/Assistant/ como TGA de 32x32 (sin compresión, con alfa):
ArrowLeft, ArrowLeft-Down (pulsado), ArrowLeft-Disabled, y lo mismo con ArrowRight.
Sin dependencias: se dibuja a mano con supermuestreo.

    python tools/gen_assistant_buttons.py
"""
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "Media" / "Assistant"
SIZE = 32
SS = 4  # supermuestreo por lado

OUTLINE = (34, 18, 6)
GOLD_TOP, GOLD_BOTTOM = (247, 205, 96), (156, 104, 30)
RED_TOP, RED_BOTTOM = (176, 32, 16), (96, 10, 4)
GLYPH, GLYPH_EDGE = (255, 214, 64), (60, 28, 4)


def octagon(x, y, r, chamfer):
    """Dentro del cuadrado de semilado r con las esquinas cortadas."""
    return abs(x) <= r and abs(y) <= r and abs(x) + abs(y) <= 2 * r - chamfer


def triangle(x, y, pts):
    (x1, y1), (x2, y2), (x3, y3) = pts

    def side(ax, ay, bx, by):
        return (x - bx) * (ay - by) - (ax - bx) * (y - by)

    d1, d2, d3 = side(x1, y1, x2, y2), side(x2, y2, x3, y3), side(x3, y3, x1, y1)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def sample(x, y, direction):
    """Color y alfa de un punto (x, y desde el centro; y hacia abajo)."""
    t = (y + 14) / 28  # 0 arriba, 1 abajo
    # Flecha: triángulo apuntando a `direction` (1 derecha, -1 izquierda), con borde oscuro
    tip, back, half = 6.0, -4.5, 7.0
    core = [(direction * tip, 0.0), (direction * back, -half), (direction * back, half)]
    edge = [(direction * (tip + 2.2), 0.0), (direction * (back - 1.3), -half - 2.0), (direction * (back - 1.3), half + 2.0)]
    if triangle(x, y, core):
        return mix(GLYPH, (230, 160, 30), max(0.0, t)), 1.0
    if triangle(x, y, edge):
        return GLYPH_EDGE, 1.0
    if octagon(x, y, 9.5, 3.0):
        color = mix(RED_TOP, RED_BOTTOM, t)
        if y < -6:  # brillo arriba
            color = mix(color, (230, 90, 60), 0.25)
        return color, 1.0
    if octagon(x, y, 12.0, 4.0):
        return mix(GOLD_TOP, GOLD_BOTTOM, t), 1.0
    if octagon(x, y, 13.2, 4.6):
        return OUTLINE, 1.0
    return (0, 0, 0), 0.0


def render(direction, pressed=False, disabled=False):
    shift = 1.0 if pressed else 0.0
    pixels = []
    for py in range(SIZE):
        for px in range(SIZE):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + (sx + 0.5) / SS - SIZE / 2 - shift
                    y = py + (sy + 0.5) / SS - SIZE / 2 - shift
                    (cr, cg, cb), ca = sample(x, y, direction)
                    r, g, b, a = r + cr * ca, g + cg * ca, b + cb * ca, a + ca
            n = SS * SS
            if a > 0:
                r, g, b = r / a, g / a, b / a
            a = a / n
            if pressed:
                r, g, b = r * 0.8, g * 0.8, b * 0.8
            if disabled:
                grey = 0.3 * r + 0.59 * g + 0.11 * b
                r = g = b = grey * 0.55
            pixels.append((int(r + 0.5), int(g + 0.5), int(b + 0.5), int(a * 255 + 0.5)))
    return pixels


def write_tga(path, pixels):
    # Sin compresión, 32 bits, origen arriba a la izquierda (descriptor 0x28)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    body = bytearray()
    for r, g, b, a in pixels:
        body += bytes((b, g, r, a))
    path.write_bytes(header + bytes(body))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, direction in (("ArrowLeft", -1), ("ArrowRight", 1)):
        write_tga(OUT / f"{name}.tga", render(direction))
        write_tga(OUT / f"{name}-Down.tga", render(direction, pressed=True))
        write_tga(OUT / f"{name}-Disabled.tga", render(direction, disabled=True))
    print("escritas en", OUT)


if __name__ == "__main__":
    main()
