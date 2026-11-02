#!/usr/bin/env python3
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "wallpapers" / "patterns"

STROKE = 1.3


def fmt(value):
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


_samples = None


def _sample(points):
    if _samples is not None:
        _samples.extend(points)


def _arc_points(start, end, r, large, sweep, steps=24):
    x1, y1 = start
    x2, y2 = end
    hx, hy = (x1 - x2) / 2, (y1 - y2) / 2
    d2 = hx * hx + hy * hy
    if d2 == 0:
        return []
    r = max(r, math.sqrt(d2))
    coef = math.sqrt(max(0.0, (r * r - d2) / d2))
    sign = -1 if large == sweep else 1
    cx = sign * coef * hy + (x1 + x2) / 2
    cy = -sign * coef * hx + (y1 + y2) / 2
    a1 = math.atan2(y1 - cy, x1 - cx)
    a2 = math.atan2(y2 - cy, x2 - cx)
    delta = a2 - a1
    if sweep and delta < 0:
        delta += 2 * math.pi
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    return [
        (cx + r * math.cos(a1 + delta * k / steps), cy + r * math.sin(a1 + delta * k / steps))
        for k in range(steps + 1)
    ]


class Path2:
    def __init__(self, scale):
        self.s = scale
        self.parts = []
        self.pen = (0.0, 0.0)

    def _p(self, x, y):
        return f"{fmt(x * self.s)} {fmt(y * self.s)}"

    def _to(self, x, y):
        self.pen = (x * self.s, y * self.s)
        _sample([self.pen])

    def move(self, x, y):
        self.parts.append("M" + self._p(x, y))
        self._to(x, y)
        return self

    def line(self, x, y):
        self.parts.append("L" + self._p(x, y))
        self._to(x, y)
        return self

    def quad(self, cx, cy, x, y):
        p0, s = self.pen, self.s
        _sample([
            (
                (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * cx * s + t * t * x * s,
                (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * cy * s + t * t * y * s,
            )
            for t in (k / 10 for k in range(11))
        ])
        self.parts.append("Q" + self._p(cx, cy) + " " + self._p(x, y))
        self._to(x, y)
        return self

    def cubic(self, x1, y1, x2, y2, x, y):
        p0, s = self.pen, self.s
        _sample([
            (
                (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * x1 * s
                + 3 * (1 - t) * t * t * x2 * s + t**3 * x * s,
                (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * y1 * s
                + 3 * (1 - t) * t * t * y2 * s + t**3 * y * s,
            )
            for t in (k / 12 for k in range(13))
        ])
        self.parts.append(
            "C" + self._p(x1, y1) + " " + self._p(x2, y2) + " " + self._p(x, y)
        )
        self._to(x, y)
        return self

    def arc(self, r, x, y, large=0, sweep=1, ry=None):
        ry = r if ry is None else ry
        _sample(_arc_points(self.pen, (x * self.s, y * self.s), r * self.s, large, sweep))
        self.parts.append(
            f"A{fmt(r * self.s)} {fmt(ry * self.s)} 0 {large} {sweep} "
            + self._p(x, y)
        )
        self._to(x, y)
        return self

    def close(self):
        self.parts.append("Z")
        return self

    def poly(self, points, closed=False):
        first, *rest = points
        self.move(*first)
        for point in rest:
            self.line(*point)
        if closed:
            self.close()
        return self

    def smooth(self, points, closed=False, tension=0.5):
        n = len(points)
        if n < 3:
            return self.poly(points, closed)
        pts = points + points[:2] if closed else points
        self.move(*pts[0])
        count = n if closed else n - 1
        for i in range(count):
            p0 = pts[i - 1] if (i > 0 or closed) else pts[i]
            p1 = pts[i]
            p2 = pts[(i + 1) % len(pts)] if closed else pts[i + 1]
            p3 = (
                pts[(i + 2) % len(pts)]
                if closed
                else (pts[i + 2] if i + 2 < n else pts[i + 1])
            )
            c1 = (
                p1[0] + (p2[0] - p0[0]) * tension / 3,
                p1[1] + (p2[1] - p0[1]) * tension / 3,
            )
            c2 = (
                p2[0] - (p3[0] - p1[0]) * tension / 3,
                p2[1] - (p3[1] - p1[1]) * tension / 3,
            )
            self.cubic(*c1, *c2, *p2)
        if closed:
            self.close()
        return self

    def svg(self):
        return f'<path d="{"".join(self.parts)}"/>'


def circle(cx, cy, r, s, filled=False):
    _sample([polar(cx * s, cy * s, r * s, a) for a in range(0, 360, 15)])
    extra = ' fill="#fff" stroke="none"' if filled else ""
    return f'<circle cx="{fmt(cx * s)}" cy="{fmt(cy * s)}" r="{fmt(r * s)}"{extra}/>'


def polar(cx, cy, r, degrees):
    a = math.radians(degrees)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def sparkle_path(s, size=1.0, cx=0.0, cy=0.0):
    r = 5 * size
    pinch = 1.1 * size
    p = Path2(s).move(cx, cy - r)
    p.quad(cx + pinch, cy - pinch, cx + r, cy)
    p.quad(cx + pinch, cy + pinch, cx, cy + r)
    p.quad(cx - pinch, cy + pinch, cx - r, cy)
    p.quad(cx - pinch, cy - pinch, cx, cy - r)
    return p.close().svg()


# Every motif draws around (0, 0) inside a circle of radius ~50 units;
# the scale turns units into pixels so the stroke stays one width.


def comet(s):
    head, radius = (13, -13), 10.5
    ux, uy = math.cos(math.radians(-45)), math.sin(math.radians(-45))
    nx, ny = -uy, ux
    out = [circle(head[0], head[1], radius, s)]
    out.append(
        Path2(s)
        .move(*polar(*head, 6.2, 190))
        .arc(6.2, *polar(*head, 6.2, 250), 0, 1)
        .svg()
    )
    tails = (
        (1, 46, 5.5),
        (0, 30, 2.0),
        (-1, 38, -4.5),
    )
    for side, length, bend in tails:
        if side == 0:
            start = (head[0] - ux * radius, head[1] - uy * radius)
        else:
            start = (head[0] + nx * radius * side, head[1] + ny * radius * side)
        end = (start[0] - ux * length, start[1] - uy * length)
        mid = (
            (start[0] + end[0]) / 2 + nx * bend,
            (start[1] + end[1]) / 2 + ny * bend,
        )
        out.append(Path2(s).move(*start).quad(*mid, *end).svg())
    return out

def crescent_path(s, r_out, r_in, shift):
    d = math.hypot(*shift)
    a = (r_out**2 - r_in**2 + d**2) / (2 * d)
    h = math.sqrt(r_out**2 - a**2)
    ux, uy = shift[0] / d, shift[1] / d
    bx, by = ux * a, uy * a
    p1 = (bx - uy * h, by + ux * h)
    p2 = (bx + uy * h, by - ux * h)
    return Path2(s).move(*p1).arc(r_out, *p2, 1, 1).arc(r_in, *p1, 1, 0).close()


def crescent(s):
    out = [crescent_path(s, 27, 22, (11, -7)).svg()]
    out.append(circle(-13, 3, 3.4, s))
    out.append(circle(-7, 15, 2.1, s))
    out.append(circle(-17, -9, 1.6, s))
    out.append(sparkle_path(s, 0.75, 22, -20))
    return out

def ringed_planet(s):
    r = 17
    tilt = math.radians(-20)
    rx, ry = 36, 9.5
    gap = 2.6

    def ring_point(t):
        x, y = rx * math.cos(t), ry * math.sin(t)
        return (
            x * math.cos(tilt) - y * math.sin(tilt),
            x * math.sin(tilt) + y * math.cos(tilt),
        )

    def runs(samples):
        result, current = [], []
        for point, visible in samples:
            if visible:
                current.append(point)
            elif current:
                result.append(current)
                current = []
        if current:
            result.append(current)
        return result

    ring = []
    for i in range(0, 360, 2):
        t = math.radians(i)
        point = ring_point(t)
        front = math.sin(t) > 0
        hidden = not front and math.hypot(*point) < r + gap
        ring.append((point, not hidden))
    if ring[0][1] and ring[-1][1]:
        k = next(i for i, (_, visible) in enumerate(ring) if not visible)
        ring = ring[k:] + ring[:k]
    front_points = [
        ring_point(math.radians(i)) for i in range(0, 181, 1)
    ]

    def near_front(point):
        return min(math.dist(point, q) for q in front_points) < gap

    planet = []
    for i in range(0, 360, 2):
        point = polar(0, 0, r, i)
        planet.append((point, not near_front(point)))
    if planet[0][1] and planet[-1][1]:
        k = next(i for i, (_, visible) in enumerate(planet) if not visible)
        planet = planet[k:] + planet[:k]

    out = []
    for run in runs(ring) + runs(planet):
        if len(run) > 2:
            out.append(Path2(s).smooth(run[::2] + [run[-1]]).svg())
    out.append(
        Path2(s).move(*polar(0, 0, r, 215)).quad(-2, -11, *polar(0, 0, r, 305)).svg()
    )
    return out

def telescope(s):
    out = []
    tube = Path2(s).move(-28, 6).line(18, -12).line(22, -2).line(-24, 16).close()
    out.append(tube.svg())
    out.append(Path2(s).move(18, -12).line(24, -14.5).line(28.5, -3).line(22, -2).svg())
    out.append(Path2(s).move(-28, 6).line(-34, 8.5).line(-31, 16.5).line(-24, 16).svg())
    out.append(Path2(s).move(-4, -3).line(-1, 5).svg())
    pivot = (0, 10)
    out.append(circle(*pivot, 2.6, s))
    for foot in ((-16, 40), (1, 42), (17, 39)):
        start = (pivot[0] + (foot[0] - pivot[0]) * 0.09, pivot[1] + 2.6)
        out.append(Path2(s).move(*start).line(*foot).svg())
    out.append(Path2(s).move(-10, 28).line(10, 27).svg())
    return out


def satellite(s):
    out = []
    out.append(Path2(s).poly([(-8, -9), (8, -9), (8, 9), (-8, 9)], closed=True).svg())
    out.append(Path2(s).move(-8, -2).line(8, -2).svg())
    for side in (-1, 1):
        x0 = side * 8
        x1 = side * 13
        out.append(Path2(s).move(x0, 0).line(x1, 0).svg())
        xa, xb = side * 13, side * 39
        lo, hi = min(xa, xb), max(xa, xb)
        out.append(Path2(s).poly([(lo, -8), (hi, -8), (hi, 8), (lo, 8)], closed=True).svg())
        for frac in (1 / 3, 2 / 3):
            x = lo + (hi - lo) * frac
            out.append(Path2(s).move(x, -8).line(x, 8).svg())
        out.append(Path2(s).move(lo, 0).line(hi, 0).svg())
    out.append(Path2(s).move(0, -9).line(0, -15).svg())
    out.append(Path2(s).move(-7, -15).quad(0, -24, 7, -15).close().svg())
    out.append(circle(0, -19.5, 1.2, s, filled=True))
    return out


def observatory(s):
    out = []
    out.append(Path2(s).poly([(-26, 6), (26, 6), (26, 30), (-26, 30)], closed=True).svg())
    out.append(Path2(s).move(-22, 6).arc(22, 22, 6, 0, 1).svg())
    out.append(Path2(s).move(-4.5, -15.4).line(-4.5, 6).svg())
    out.append(Path2(s).move(4.5, -15.4).line(4.5, 6).svg())
    out.append(Path2(s).move(-1.8, -15.9).line(12, -33).line(17.5, -29).line(4.5, -12).svg())
    out.append(
        Path2(s).move(-5, 30).line(-5, 21).arc(5, 5, 21, 0, 1).line(5, 30).svg()
    )
    out.append(Path2(s).move(-31, 30).line(31, 30).svg())
    out.append(circle(-15, 17, 2.4, s))
    out.append(circle(15, 17, 2.4, s))
    return out

def asteroid(s, seed):
    rnd = random.Random(seed)
    points = []
    for i in range(8):
        angle = i * 45 + rnd.uniform(-12, 12)
        radius = 15 * rnd.uniform(0.82, 1.1)
        points.append(polar(0, 0, radius, angle))
    out = [Path2(s).smooth(points, closed=True, tension=0.9).svg()]
    out.append(circle(-4, -3, 3.4, s))
    out.append(circle(5, 5, 2.2, s))
    out.append(circle(6, -6, 1.3, s))
    return out


def moon_phases(s):
    out = []
    radius = 5.6
    step = 15.5
    for i, bulge in enumerate((0.62, 0.0, -0.62, None)):
        cx = -step * 1.5 + i * step
        out.append(circle(cx, 0, radius, s))
        top, bottom = (cx, -radius), (cx, radius)
        if bulge is None:
            out.append(circle(cx - 1.8, -1.4, 1.5, s))
            out.append(circle(cx + 2.2, 2.2, 1.0, s))
        elif bulge == 0:
            out.append(Path2(s).move(*top).line(*bottom).svg())
        else:
            out.append(
                Path2(s).move(*top).quad(cx + bulge * radius * 2.0, 0, *bottom).svg()
            )
    return out

CONSTELLATIONS = (
    (
        [(-28, -6), (-14, -16), (0, -10), (12, -18), (26, -4), (14, 12)],
        [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 2)],
    ),
    (
        [(-30, -8), (-16, 10), (-2, -4), (12, 12), (28, -6)],
        [(0, 1), (1, 2), (2, 3), (3, 4)],
    ),
    (
        [(-18, -22), (16, -20), (-6, -2), (2, 0), (10, 2), (-20, 22), (18, 20), (6, 12)],
        [(0, 2), (1, 4), (2, 3), (3, 4), (2, 5), (4, 6), (3, 7)],
    ),
)


def constellation(s, variant):
    stars, links = CONSTELLATIONS[variant]
    rnd = random.Random(variant * 31 + 5)
    stars = [(x + rnd.uniform(-1.5, 1.5), y + rnd.uniform(-1.5, 1.5)) for x, y in stars]
    out = [Path2(s).move(*stars[a]).line(*stars[b]).svg() for a, b in links]
    degree = [sum(i in link for link in links) for i in range(len(stars))]
    for i, (x, y) in enumerate(stars):
        out.append(circle(x, y, 2.1 if degree[i] >= 2 and i % 2 else 1.6, s, filled=True))
    return out

def orbit(s):
    rx, ry = 24, 9
    moon_t = math.radians(-35)
    moon = (rx * math.cos(moon_t), ry * math.sin(moon_t))
    moon_r = 3
    points = []
    for i in range(0, 361, 3):
        t = math.radians(i)
        points.append((rx * math.cos(t), ry * math.sin(t)))
    runs, current = [], []
    for point in points:
        if math.dist(point, moon) < moon_r + 2.2:
            if current:
                runs.append(current)
                current = []
        else:
            current.append(point)
    if current:
        runs.append(current)
    if len(runs) > 1:
        runs[0] = runs[-1] + runs[0]
        runs.pop()
    out = [circle(0, 0, 6.5, s), circle(*moon, moon_r, s)]
    for run in runs:
        out.append(Path2(s).smooth(run[::2] + [run[-1]]).svg())
    return out

def rocket(s):
    out = []
    body = Path2(s).move(0, -30).cubic(9, -20, 9.5, 2, 7, 16).line(-7, 16)
    body.cubic(-9.5, 2, -9, -20, 0, -30).close()
    out.append(body.svg())
    out.append(circle(0, -10, 3.6, s))
    out.append(Path2(s).move(7.6, 4).quad(15, 9, 14, 20).line(7, 16).svg())
    out.append(Path2(s).move(-7.6, 4).quad(-15, 9, -14, 20).line(-7, 16).svg())
    out.append(Path2(s).move(-3.5, 19.5).quad(-2, 26, 0, 30).quad(2, 26, 3.5, 19.5).svg())
    return out


def shooting_star(s):
    star = (6, -6)
    ux, uy = math.cos(math.radians(-45)), math.sin(math.radians(-45))
    nx, ny = -uy, ux
    out = [sparkle_path(s, 0.95, *star)]
    for side, length in ((1, 15), (-1, 10)):
        start = (
            star[0] - ux * 6.5 + nx * 2.4 * side,
            star[1] - uy * 6.5 + ny * 2.4 * side,
        )
        end = (start[0] - ux * length, start[1] - uy * length)
        out.append(Path2(s).move(*start).line(*end).svg())
    return out

def star5(s):
    points = []
    for i in range(10):
        radius = 5 if i % 2 == 0 else 2.3
        points.append(polar(0, 0, radius, -90 + i * 36))
    return [Path2(s).poly(points, closed=True).svg()]


def sparkle(s):
    return [sparkle_path(s, 1.0)]


def dot(s):
    return [circle(0, 0, 1.5, s, filled=True)]


def ring(s):
    return [circle(0, 0, 2.6, s)]


def plus(s):
    return [Path2(s).move(-3, 0).line(3, 0).svg(), Path2(s).move(0, -3).line(0, 3).svg()]


def tiny_crescent(s):
    return [crescent_path(s, 5.2, 4.2, (2.2, -1.4)).svg()]

MOTIFS = {
    "comet": (comet, 42),
    "crescent": (crescent, 30),
    "ringed_planet": (ringed_planet, 38),
    "telescope": (telescope, 44),
    "satellite": (satellite, 40),
    "observatory": (observatory, 38),
    "asteroid_a": (lambda s: asteroid(s, 7), 17),
    "asteroid_b": (lambda s: asteroid(s, 19), 17),
    "asteroid_c": (lambda s: asteroid(s, 42), 17),
    "moon_phases": (moon_phases, 27),
    "constellation_a": (lambda s: constellation(s, 0), 30),
    "constellation_b": (lambda s: constellation(s, 1), 30),
    "constellation_c": (lambda s: constellation(s, 2), 30),
    "orbit": (orbit, 26),
    "rocket": (rocket, 32),
    "shooting_star": (shooting_star, 17),
    "star5": (star5, 5.5),
    "sparkle": (sparkle, 5.5),
    "dot": (dot, 2),
    "ring": (ring, 3),
    "plus": (plus, 3.5),
    "tiny_crescent": (tiny_crescent, 5.5),
}


def group(elements, x, y, angle, mirror=False):
    body = "".join(elements)
    flip = " scale(-1 1)" if mirror else ""
    return (
        f'<g transform="translate({fmt(x)} {fmt(y)}) rotate({fmt(angle)}){flip}">'
        f"{body}</g>"
    )


def svg_document(width, height, body, background=None, color="#fff"):
    bg = f'<rect width="{width}" height="{height}" fill="{background}" stroke="none"/>' if background else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" fill="none" stroke="{color}" '
        f'stroke-width="{STROKE}" stroke-linecap="round" stroke-linejoin="round">'
        f"{bg}{body}</svg>"
    )


def motif_sheet(scale=2.2):
    names = list(MOTIFS)
    cols = 5
    cell = 130
    rows = math.ceil(len(names) / cols)
    body = []
    for i, name in enumerate(names):
        fn, _ = MOTIFS[name]
        cx = (i % cols) * cell + cell / 2
        cy = (i // cols) * cell + cell / 2
        size = scale if MOTIFS[name][1] > 12 else scale * 2.4
        body.append(group(fn(size * 0.5), cx, cy, 0))
    return svg_document(cols * cell, rows * cell, "".join(body), background="#15171a", color="#c8d0da")


TILE = 900
UNIT = 1.2
MEDIUM_UNIT = 1.12
FILLER_UNIT = 1.1

MIRRORABLE = {
    "comet",
    "telescope",
    "observatory",
    "crescent",
    "rocket",
    "ringed_planet",
    "constellation_a",
    "constellation_b",
    "constellation_c",
    "asteroid_a",
    "asteroid_b",
    "asteroid_c",
}


class Piece:
    def __init__(self, name, count, rotate, unit=UNIT, gap=6.0):
        self.name = name
        self.count = count
        self.rotate = rotate
        self.unit = unit
        self.gap = gap


KOMET_PIECES = [
    Piece("comet", 7, 20, gap=4.0),
    Piece("crescent", 7, 40, gap=4.0),
    Piece("ringed_planet", 7, 28, gap=4.0),
    Piece("telescope", 3, 14, gap=4.0),
    Piece("observatory", 2, 8, gap=4.0),
    Piece("satellite", 4, 35, unit=UNIT * 0.85, gap=4.0),
    Piece("rocket", 6, 35, gap=4.0),
    Piece("comet", 10, 20, unit=UNIT * 0.65, gap=3.5),
    Piece("moon_phases", 3, 20, unit=MEDIUM_UNIT * 1.1, gap=3.5),
    Piece("constellation_a", 5, 180, unit=MEDIUM_UNIT, gap=3.5),
    Piece("constellation_b", 5, 180, unit=MEDIUM_UNIT, gap=3.5),
    Piece("constellation_c", 4, 180, unit=MEDIUM_UNIT, gap=3.5),
    Piece("orbit", 11, 35, unit=MEDIUM_UNIT, gap=3.5),
    Piece("asteroid_a", 6, 180, unit=MEDIUM_UNIT, gap=3.0),
    Piece("asteroid_b", 6, 180, unit=MEDIUM_UNIT, gap=3.0),
    Piece("asteroid_c", 5, 180, unit=MEDIUM_UNIT, gap=3.0),
    Piece("shooting_star", 32, 30, unit=MEDIUM_UNIT, gap=3.0),
    Piece("tiny_crescent", 22, 180, unit=FILLER_UNIT, gap=3.0),
    Piece("star5", 12, 180, unit=FILLER_UNIT, gap=3.0),
    Piece("sparkle", 26, 25, unit=FILLER_UNIT, gap=3.0),
    Piece("ring", 34, 0, unit=FILLER_UNIT, gap=2.5),
    Piece("plus", 26, 45, unit=FILLER_UNIT, gap=2.5),
    Piece("dot", 90, 0, unit=FILLER_UNIT, gap=2.0),
]


def measured_radius(name):
    global _samples
    _samples = []
    try:
        MOTIFS[name][0](1.0)
        points = _samples
    finally:
        _samples = None
    return max(math.hypot(x, y) for x, y in points) + STROKE / 2


SAME_MOTIF_SPACING = 70
FILLERS = {"star5", "sparkle", "dot", "ring", "plus", "tiny_crescent"}


def _kin(name):
    if name in FILLERS:
        return None
    return name.rsplit("_", 1)[0] if name[-2:] in ("_a", "_b", "_c") else name


def torus_distance(a, b, size):
    dx = abs(a[0] - b[0])
    dy = abs(a[1] - b[1])
    return math.hypot(min(dx, size - dx), min(dy, size - dy))


def compose(pieces, size, seed, candidates=140):
    rnd = random.Random(seed)
    placed = []
    for piece in pieces:
        nominal = measured_radius(piece.name)
        for _ in range(piece.count):
            jitter = rnd.uniform(0.92, 1.08)
            scale = piece.unit * jitter
            radius = nominal * scale
            best, best_clearance = None, -1e9
            kin = _kin(piece.name)
            for _ in range(candidates):
                point = (rnd.uniform(0, size), rnd.uniform(0, size))
                clearance = min(
                    (
                        torus_distance(point, other[0], size)
                        - radius
                        - other[1]
                        - (SAME_MOTIF_SPACING if kin and kin == _kin(other[2]) else 0)
                        for other in placed
                    ),
                    default=size,
                )
                if clearance > best_clearance:
                    best, best_clearance = point, clearance
            if best_clearance < piece.gap:
                continue
            angle = rnd.uniform(-piece.rotate, piece.rotate)
            mirror = piece.name in MIRRORABLE and rnd.random() < 0.5
            placed.append((best, radius, piece.name, scale, angle, mirror))
    return placed


def tile_body(placed, size):
    body = []
    for (x, y), radius, name, scale, angle, mirror in placed:
        elements = MOTIFS[name][0](scale)
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                cx, cy = x + ox, y + oy
                if cx + radius < 0 or cx - radius > size:
                    continue
                if cy + radius < 0 or cy - radius > size:
                    continue
                body.append(group(elements, cx, cy, angle, mirror))
    return "".join(body)


def tile_svg(pieces, seed):
    placed = compose(pieces, TILE, seed)
    return svg_document(TILE, TILE, tile_body(placed, TILE)), placed


def preview(tile, width=412, height=892, theme=None):
    theme = theme or KOMET_THEME
    inner = tile[tile.index(">") + 1 : tile.rindex("</svg>")]
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{theme['bg'][0]}"/><stop offset="1" stop-color="{theme['bg'][1]}"/>
  </linearGradient>
  <linearGradient id="ink" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{theme['ink'][0]}"/><stop offset="1" stop-color="{theme['ink'][1]}"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.9" cy="0.14" r="0.6">
    <stop offset="0" stop-color="{theme['glow']}" stop-opacity="1"/><stop offset="1" stop-color="{theme['glow']}" stop-opacity="0"/>
  </radialGradient>
  <pattern id="tile" width="{TILE}" height="{TILE}" patternUnits="userSpaceOnUse"
    x="{(width - TILE) / 2}" y="{(height - TILE) / 2}">
    <g fill="none" stroke="#fff" stroke-width="{STROKE}" stroke-linecap="round" stroke-linejoin="round">{inner}</g>
  </pattern>
  <mask id="lines"><rect width="{width}" height="{height}" fill="url(#tile)"/></mask>
</defs>
<rect width="{width}" height="{height}" fill="url(#bg)"/>
<g mask="url(#lines)">
  <rect width="{width}" height="{height}" fill="url(#ink)"/>
  <rect width="{width}" height="{height}" fill="url(#glow)"/>
</g>
</svg>"""


PATTERNS = {
    "komet": (KOMET_PIECES, 1),
}


KOMET_THEME = {
    "bg": ("#111214", "#222326"),
    "ink": ("#33363B", "#44474D"),
    "glow": "#6A6F78",
}


def single(name, scale=6.0):
    fn, _ = MOTIFS[name]
    return svg_document(
        700, 700, group(fn(scale), 350, 350, 0), background="#15171a", color="#c8d0da"
    )


def main(argv):
    if len(argv) > 1 and argv[1] == "sheet":
        sys.stdout.write(motif_sheet())
        return
    if len(argv) > 2 and argv[1] == "single":
        sys.stdout.write(single(argv[2]))
        return
    if len(argv) > 1 and argv[1] == "mosaic":
        tile, _ = tile_svg(KOMET_PIECES, 1)
        inner = tile[tile.index(">") + 1 : tile.rindex("</svg>")]
        cells = "".join(
            f'<g transform="translate({x * TILE} {y * TILE})">{inner}</g>'
            for x in (0, 1)
            for y in (0, 1)
        )
        seams = (
            f'<path d="M{TILE} 0V{2 * TILE}M0 {TILE}H{2 * TILE}" stroke="#d04040" '
            f'stroke-width="1" stroke-dasharray="4 6"/>'
        )
        body = f'<g stroke="#c8d0da">{cells}</g>{seams}'
        sys.stdout.write(svg_document(2 * TILE, 2 * TILE, body, background="#15171a", color="#c8d0da"))
        return
    if len(argv) > 1 and argv[1] == "preview":
        seed = int(argv[2]) if len(argv) > 2 else 1
        tile, placed = tile_svg(KOMET_PIECES, seed)
        sys.stderr.write(f"placed {len(placed)} of {sum(p.count for p in KOMET_PIECES)}\n")
        sys.stdout.write(preview(tile))
        return
    if len(argv) > 1:
        raise SystemExit(
            "usage: make_wallpaper_patterns.py [sheet | single NAME | mosaic | preview SEED]"
        )
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (pieces, seed) in PATTERNS.items():
        tile, placed = tile_svg(pieces, seed)
        target = OUT_DIR / f"{name}.svg"
        target.write_text(tile + "\n", encoding="utf-8")
        print(f"{target.relative_to(ROOT)}: {len(placed)} motifs, {len(tile) // 1024} KB")


if __name__ == "__main__":
    main(sys.argv)
