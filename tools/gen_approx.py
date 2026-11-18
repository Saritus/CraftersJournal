"""Genera el signo de "aproximado" (≈) que sustituye a "~" en las filas de la ruta
(ProfessionUI.lua, ES.APPROX): dos ondas claras con un filo oscuro para que se lean
sobre cualquier fondo. La fuente del juego no tiene ≈ y "~104" parecía un error.

Sale en Media/Assistant/Approx.tga, 32x32 sin compresión, con alfa.

    python tools/gen_approx.py
"""
import math
from pathlib import Path

from gen_assistant_buttons import SS, write_tga

OUT = Path(__file__).resolve().parent.parent / "Media" / "Assistant" / "Approx.tga"
SIZE = 32

CORE = (235, 235, 235)
EDGE = (20, 20, 20)

HALF_LEN = 11.0      # medio largo de cada onda
AMP = 2.4            # altura de la onda
PERIOD = 22.0        # una onda entera a lo largo
GAP = 5.0            # separación de cada onda al centro
STROKE = 1.7         # medio grosor del trazo
OUTLINE = 1.1        # grosor del filo


def wave_distance(x, y, cy):
    """Distancia aproximada del punto a la onda centrada en cy (con puntas redondas)."""
    k = 2 * math.pi / PERIOD
    cx = max(-HALF_LEN, min(HALF_LEN, x))
    wy = cy + AMP * math.sin(k * cx)  # (y hacia abajo: sube a la izquierda, como "~")
    if cx != x:  # más allá de la punta: distancia al extremo
        return math.hypot(x - cx, y - wy)
    slope = AMP * k * math.cos(k * cx)
    return abs(y - wy) / math.sqrt(1 + slope * slope)


def sample(x, y):
    d = min(wave_distance(x, y, -GAP), wave_distance(x, y, GAP))
    if d <= STROKE:
        return CORE, 1.0
    if d <= STROKE + OUTLINE:
        return EDGE, 0.85
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
