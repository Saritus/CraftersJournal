"""Genera el ? grande de la ayuda del asistente (Assistant.lua, cabecera de la
ventana de ayuda): como el ? amarillo de las misiones, pero a 64 px y nítido. El del
juego (GossipFrame\\ActiveQuestIcon) es pequeño y a 40 px se pixelaba; el de
INV_Misc_QuestionMark no gustaba.

Sale en Media/Assistant/HelpBig.tga, 64x64 sin compresión, con alfa.

    python tools/gen_help_icon.py
"""
import math
import struct
from pathlib import Path

from gen_assistant_buttons import SS, mix

OUT = Path(__file__).resolve().parent.parent / "Media" / "Assistant" / "HelpBig.tga"
SIZE = 64

FILL_TOP, FILL_BOTTOM = (255, 232, 110), (232, 160, 24)
EDGE = (48, 26, 4)
HALF = 5.2      # medio grosor del trazo
OUTLINE = 2.4   # filo oscuro alrededor, para que se lea sobre cualquier fondo

# El gancho: un arco (centro, radio, de un ángulo a otro, en grados; y hacia abajo),
# luego baja en recto hasta el cuello; el punto, aparte
ARC_C, ARC_R = (0.0, -10.0), 11.5
ARC_FROM, ARC_TO = 165.0, 420.0
NECK = [(ARC_C[0] + ARC_R * math.cos(math.radians(ARC_TO)), ARC_C[1] + ARC_R * math.sin(math.radians(ARC_TO))),
        (0.0, 4.5), (0.0, 7.0)]
DOT, DOT_R = (0.0, 21.5), 5.2


def seg_dist(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def arc_dist(px, py):
    cx, cy = ARC_C
    ang = math.degrees(math.atan2(py - cy, px - cx))
    while ang < ARC_FROM:
        ang += 360.0
    if ang <= ARC_TO:
        return abs(math.hypot(px - cx, py - cy) - ARC_R)
    ends = [(cx + ARC_R * math.cos(math.radians(a)), cy + ARC_R * math.sin(math.radians(a))) for a in (ARC_FROM, ARC_TO)]
    return min(math.hypot(px - ex, py - ey) for ex, ey in ends)


def stroke_dist(x, y):
    d = arc_dist(x, y)
    for i in range(len(NECK) - 1):
        d = min(d, seg_dist(x, y, NECK[i], NECK[i + 1]))
    return d - HALF


def sample(x, y):
    d = min(stroke_dist(x, y), math.hypot(x - DOT[0], y - DOT[1]) - DOT_R)
    if d <= 0:
        return mix(FILL_TOP, FILL_BOTTOM, max(0.0, min(1.0, (y + 24.0) / 50.0))), 1.0
    if d <= OUTLINE:
        return EDGE, 1.0
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


def write_tga(path, pixels):
    # (la de gen_assistant_buttons es de 32x32: esta, de SIZE) Sin compresión, 32 bits,
    # origen arriba a la izquierda
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    body = bytearray()
    for r, g, b, a in pixels:
        body += bytes((b, g, r, a))
    path.write_bytes(header + bytes(body))


def main():
    write_tga(OUT, render())
    print("escrito", OUT)


if __name__ == "__main__":
    main()
