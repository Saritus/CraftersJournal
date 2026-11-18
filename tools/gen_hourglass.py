"""Genera el reloj de arena (⌛) del tiempo de camino de la flecha del asistente
(Assistant.lua, A.HOURGLASS): tapas doradas, cristal claro y arena. Los iconos del
juego que hay (Spell_Holy_BorrowedTime) no se entendían a tamaño de letra.

Sale en Media/Assistant/Hourglass.tga, 32x32 sin compresión, con alfa.

    python tools/gen_hourglass.py
"""
from pathlib import Path

from gen_assistant_buttons import SS, mix, write_tga

OUT = Path(__file__).resolve().parent.parent / "Media" / "Assistant" / "Hourglass.tga"
SIZE = 32

CAP_TOP, CAP_BOTTOM, CAP_EDGE = (250, 214, 120), (176, 120, 40), (60, 34, 8)
GLASS_EDGE = (235, 235, 240)
GLASS = (200, 220, 240)
SAND_TOP, SAND_BOTTOM = (255, 200, 70), (225, 140, 30)

CAP_Y, CAP_H, CAP_W = 12.0, 2.6, 10.5  # tapas: de |y| = CAP_Y a CAP_Y + CAP_H
WAIST, BULB = 1.4, 8.6                  # medio ancho del cristal en el centro y junto a las tapas
EDGE = 1.7                              # grosor del borde del cristal


def half_width(y):
    """Medio ancho del cristal a la altura y (estrecho en el centro)."""
    t = min(1.0, abs(y) / CAP_Y)
    return WAIST + (BULB - WAIST) * (t ** 0.8)


def sample(x, y):
    # Tapas arriba y abajo, con un filo oscuro para que se lea sobre cualquier fondo
    if CAP_Y <= abs(y) <= CAP_Y + CAP_H:
        if abs(x) <= CAP_W - 0.9 and CAP_Y + 0.6 <= abs(y) <= CAP_Y + CAP_H - 0.6:
            return mix(CAP_TOP, CAP_BOTTOM, (abs(y) - CAP_Y) / CAP_H), 1.0
        if abs(x) <= CAP_W:
            return CAP_EDGE, 1.0
    if abs(y) < CAP_Y:
        w = half_width(y)
        if abs(x) <= w:
            inside = abs(x) <= w - EDGE
            if not inside:
                return GLASS_EDGE, 1.0
            # Arena: un poco arriba, apoyada en el cuello; un montón abajo; el chorro en medio
            if -5.0 <= y < -0.8 or (y >= 4.5 and y >= 11.5 - (w - abs(x)) * 1.6) or (abs(x) <= 0.55 and y > -1.0):
                return mix(SAND_TOP, SAND_BOTTOM, (y + CAP_Y) / (2 * CAP_Y)), 1.0
            return GLASS, 0.35
    return (0, 0, 0), 0.0


def render():
    pixels = []
    for py in range(SIZE):
        for px in range(SIZE):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    x = px + (sx + 0.5) / SS - SIZE / 2
                    y = py + (sy + 0.5) / SS - SIZE / 2
                    (cr, cg, cb), ca = sample(x, y)
                    r, g, b, a = r + cr * ca, g + cg * ca, b + cb * ca, a + ca
            if a > 0:
                r, g, b = r / a, g / a, b / a
            a = a / (SS * SS)
            pixels.append((int(r + 0.5), int(g + 0.5), int(b + 0.5), int(a * 255 + 0.5)))
    return pixels


def main():
    write_tga(OUT, render())
    print("escrito", OUT)


if __name__ == "__main__":
    main()
