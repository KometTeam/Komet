"""Собирает lottie-морфы иконок прямо из шрифта Material Symbols.

Контуры глифов берутся из MaterialSymbolsOutlined.ttf (инстанс по умолчанию —
FILL 0, GRAD 0, opsz 24, wght 400, то есть ровно то, что рисует Icon в приложении),
разбиваются на равное число безье-сегментов и попарно сопоставляются, чтобы
lottie мог интерполировать один глиф в другой. Спекам с fill=1 контуры считаются
по FILL=1 — для кнопок, которые рисуют Icon(..., fill: 1).

SPECS — морфы композера (ComposerMorphIcon), проигрываются вперёд.
SLASH_SPECS — переключатели «обычная/перечёркнутая» (LottieSlashIcon): оба глифа
лежат статикой, а перечёркивание рисуется бегущей по диагонали маской, поэтому
одного ассета хватает на оба направления.

    python3 tool/make_morph_icons.py

Пересобирать нужно после обновления material_symbols_icons.
"""

import json
import math
import os
import struct

class Font:
    def __init__(self, path):
        self.data = open(path, 'rb').read()
        self.tables = {}
        num_tables = struct.unpack('>H', self.data[4:6])[0]
        for i in range(num_tables):
            off = 12 + i * 16
            tag = self.data[off:off + 4].decode('latin1')
            t_off, t_len = struct.unpack('>II', self.data[off + 8:off + 16])
            self.tables[tag] = (t_off, t_len)

        head_off = self.tables['head'][0]
        self.units_per_em = struct.unpack(
            '>H', self.data[head_off + 18:head_off + 20])[0]
        self.index_to_loc = struct.unpack(
            '>h', self.data[head_off + 50:head_off + 52])[0]
        maxp_off = self.tables['maxp'][0]
        self.num_glyphs = struct.unpack(
            '>H', self.data[maxp_off + 4:maxp_off + 6])[0]
        self._read_loca()
        self._read_cmap()
        self._read_fvar()
        self._read_gvar()

    def _read_loca(self):
        off, _ = self.tables['loca']
        n = self.num_glyphs + 1
        if self.index_to_loc == 0:
            raw = struct.unpack('>%dH' % n, self.data[off:off + 2 * n])
            self.loca = [v * 2 for v in raw]
        else:
            self.loca = list(struct.unpack('>%dI' % n, self.data[off:off + 4 * n]))

    def _read_cmap(self):
        off, _ = self.tables['cmap']
        n = struct.unpack('>H', self.data[off + 2:off + 4])[0]
        best = None
        for i in range(n):
            rec = off + 4 + i * 8
            pid, eid, sub = struct.unpack('>HHI', self.data[rec:rec + 8])
            fmt = struct.unpack('>H', self.data[off + sub:off + sub + 2])[0]
            if fmt in (4, 12):
                if best is None or fmt == 12:
                    best = (fmt, off + sub)
        fmt, sub = best
        self.cmap = {}
        if fmt == 4:
            seg_x2 = struct.unpack('>H', self.data[sub + 6:sub + 8])[0]
            seg = seg_x2 // 2
            base = sub + 14
            ends = struct.unpack('>%dH' % seg, self.data[base:base + seg_x2])
            base += seg_x2 + 2
            starts = struct.unpack('>%dH' % seg, self.data[base:base + seg_x2])
            base += seg_x2
            deltas = struct.unpack('>%dh' % seg, self.data[base:base + seg_x2])
            range_off_pos = base + seg_x2
            offsets = struct.unpack(
                '>%dH' % seg, self.data[range_off_pos:range_off_pos + seg_x2])
            for i in range(seg):
                for c in range(starts[i], min(ends[i], 0xFFFF) + 1):
                    if offsets[i] == 0:
                        gid = (c + deltas[i]) & 0xFFFF
                    else:
                        p = range_off_pos + i * 2 + offsets[i] + (c - starts[i]) * 2
                        gid = struct.unpack('>H', self.data[p:p + 2])[0]
                        if gid:
                            gid = (gid + deltas[i]) & 0xFFFF
                    if gid:
                        self.cmap[c] = gid
        else:
            n_groups = struct.unpack('>I', self.data[sub + 12:sub + 16])[0]
            for i in range(n_groups):
                p = sub + 16 + i * 12
                s, e, g = struct.unpack('>III', self.data[p:p + 12])
                for c in range(s, e + 1):
                    self.cmap[c] = g + (c - s)

    def _read_fvar(self):
        off, _ = self.tables['fvar']
        axes_off, _, axis_count, axis_size = struct.unpack(
            '>HHHH', self.data[off + 4:off + 12])
        self.axes = []
        for i in range(axis_count):
            p = off + axes_off + i * axis_size
            self.axes.append(self.data[p:p + 4].decode('latin1'))

    def _read_gvar(self):
        off, _ = self.tables['gvar']
        axis_count, shared_count, shared_off, glyph_count, flags, data_off = (
            struct.unpack('>HHIHHI', self.data[off + 4:off + 20]))
        base = off + 20
        if flags & 1:
            raw = struct.unpack(
                '>%dI' % (glyph_count + 1), self.data[base:base + 4 * (glyph_count + 1)])
            offsets = list(raw)
        else:
            raw = struct.unpack(
                '>%dH' % (glyph_count + 1), self.data[base:base + 2 * (glyph_count + 1)])
            offsets = [v * 2 for v in raw]
        shared = []
        p = off + shared_off
        for i in range(shared_count):
            step = 2 * axis_count
            shared.append(struct.unpack('>%dh' % axis_count,
                                        self.data[p + i * step:p + (i + 1) * step]))
        self.gvar = {
            'axis_count': axis_count,
            'shared': shared,
            'offsets': offsets,
            'data': off + data_off,
        }

    def _axis_deltas(self, gid, axis, contours):
        """Deltas that move the glyph to the `axis`=1 instance.

        Only tuples peaking on `axis` alone contribute: every other tuple is
        multiplied by an axis coordinate that stays at its default zero.
        """
        gvar = self.gvar
        start = gvar['data'] + gvar['offsets'][gid]
        end = gvar['data'] + gvar['offsets'][gid + 1]
        if end <= start:
            return None

        d = self.data[start:end]
        axis_count = gvar['axis_count']
        index = self.axes.index(axis)
        n_points = sum(len(c) for c in contours) + 4

        tuple_count, cursor = struct.unpack('>HH', d[0:4])
        shared_points = None
        if tuple_count & 0x8000:
            shared_points, cursor = _packed_points(d, cursor)

        total = [(0.0, 0.0)] * n_points
        applied = False
        p = 4
        for _ in range(tuple_count & 0x0FFF):
            var_size, tuple_index = struct.unpack('>HH', d[p:p + 4])
            p += 4
            if tuple_index & 0x8000:
                peak = struct.unpack('>%dh' % axis_count, d[p:p + 2 * axis_count])
                p += 2 * axis_count
            else:
                peak = gvar['shared'][tuple_index & 0x0FFF]
            if tuple_index & 0x4000:
                p += 4 * axis_count
            block, cursor = cursor, cursor + var_size

            if peak[index] <= 0 or any(
                    v for i, v in enumerate(peak) if i != index):
                continue

            q = block
            points = shared_points
            if tuple_index & 0x2000:
                points, q = _packed_points(d, q)
            size = n_points if points is None else len(points)
            xs, q = _packed_deltas(d, q, size)
            ys, _ = _packed_deltas(d, q, size)

            scale = 16384.0 / peak[index]
            sparse = [None] * n_points
            for k, point in enumerate(range(size) if points is None else points):
                if point < n_points:
                    sparse[point] = (xs[k] * scale, ys[k] * scale)
            _infer_deltas(contours, sparse)
            total = [(a[0] + b[0], a[1] + b[1]) for a, b in zip(total, sparse)]
            applied = True

        return total if applied else None

    def contours(self, codepoint, fill=0.0):
        gid = self.cmap[codepoint]
        contours = self._glyph_contours(gid)
        if fill <= 0:
            return contours
        if self._is_composite(gid):
            raise SystemExit('fill=1 не поддержан для составного глифа %04X'
                             % codepoint)

        deltas = self._axis_deltas(gid, 'FILL', contours)
        if deltas is None:
            return contours

        out = []
        index = 0
        for contour in contours:
            shifted = []
            for x, y, on in contour:
                dx, dy = deltas[index]
                index += 1
                shifted.append((x + dx * fill, y + dy * fill, on))
            out.append(shifted)
        return out

    def _is_composite(self, gid):
        goff, _ = self.tables['glyf']
        start, end = self.loca[gid], self.loca[gid + 1]
        if start == end:
            return False
        return struct.unpack('>h', self.data[goff + start:goff + start + 2])[0] < 0

    def _glyph_contours(self, gid, depth=0):
        goff, _ = self.tables['glyf']
        start, end = self.loca[gid], self.loca[gid + 1]
        if start == end:
            return []
        d = self.data[goff + start:goff + end]
        n_contours = struct.unpack('>h', d[0:2])[0]
        if n_contours < 0:
            return self._composite(d, depth)

        end_pts = struct.unpack('>%dH' % n_contours, d[10:10 + 2 * n_contours])
        n_points = end_pts[-1] + 1
        p = 10 + 2 * n_contours
        instr_len = struct.unpack('>H', d[p:p + 2])[0]
        p += 2 + instr_len

        flags = []
        while len(flags) < n_points:
            f = d[p]
            p += 1
            flags.append(f)
            if f & 8:
                rep = d[p]
                p += 1
                flags.extend([f] * rep)
        flags = flags[:n_points]

        xs, x = [], 0
        for f in flags:
            if f & 2:
                dx = d[p]
                p += 1
                x += dx if f & 16 else -dx
            elif not f & 16:
                dx = struct.unpack('>h', d[p:p + 2])[0]
                p += 2
                x += dx
            xs.append(x)

        ys, y = [], 0
        for f in flags:
            if f & 4:
                dy = d[p]
                p += 1
                y += dy if f & 32 else -dy
            elif not f & 32:
                dy = struct.unpack('>h', d[p:p + 2])[0]
                p += 2
                y += dy
            ys.append(y)

        out, first = [], 0
        for e in end_pts:
            pts = [(xs[i], ys[i], bool(flags[i] & 1)) for i in range(first, e + 1)]
            if pts:
                out.append(pts)
            first = e + 1
        return out

    def _composite(self, d, depth):
        if depth > 4:
            return []
        out = []
        p = 10
        while True:
            flags, glyph_index = struct.unpack('>HH', d[p:p + 4])
            p += 4
            if flags & 1:
                a1, a2 = struct.unpack('>hh', d[p:p + 4])
                p += 4
            else:
                a1, a2 = struct.unpack('>bb', d[p:p + 2])
                p += 2
            sx = sy = 1.0
            s01 = s10 = 0.0
            if flags & 8:
                sx = sy = _f2dot14(d, p)
                p += 2
            elif flags & 0x40:
                sx = _f2dot14(d, p)
                sy = _f2dot14(d, p + 2)
                p += 4
            elif flags & 0x80:
                sx = _f2dot14(d, p)
                s01 = _f2dot14(d, p + 2)
                s10 = _f2dot14(d, p + 4)
                sy = _f2dot14(d, p + 6)
                p += 8
            dx, dy = (a1, a2) if flags & 2 else (0, 0)
            for contour in self._glyph_contours(glyph_index, depth + 1):
                out.append([
                    (x * sx + y * s10 + dx, x * s01 + y * sy + dy, on)
                    for x, y, on in contour
                ])
            if not flags & 0x20:
                break
        return out


def _f2dot14(d, p):
    return struct.unpack('>h', d[p:p + 2])[0] / 16384.0


def _packed_points(d, p):
    """gvar packed point numbers; None means «все точки глифа»."""
    count = d[p]
    p += 1
    if count == 0:
        return None, p
    if count & 0x80:
        count = ((count & 0x7F) << 8) | d[p]
        p += 1
    points, value = [], 0
    while len(points) < count:
        control = d[p]
        p += 1
        run = (control & 0x7F) + 1
        for _ in range(run):
            if control & 0x80:
                value += struct.unpack('>H', d[p:p + 2])[0]
                p += 2
            else:
                value += d[p]
                p += 1
            points.append(value)
    return points[:count], p


def _packed_deltas(d, p, count):
    out = []
    while len(out) < count:
        control = d[p]
        p += 1
        run = (control & 0x3F) + 1
        if control & 0x80:
            out.extend([0] * run)
        elif control & 0x40:
            for _ in range(run):
                out.append(struct.unpack('>h', d[p:p + 2])[0])
                p += 2
        else:
            for _ in range(run):
                out.append(struct.unpack('>b', d[p:p + 1])[0])
                p += 1
    return out[:count], p


def _interpolate(v, v1, d1, v2, d2):
    if v1 > v2:
        v1, d1, v2, d2 = v2, d2, v1, d1
    if v1 == v2:
        return d1 if d1 == d2 else 0.0
    if v <= v1:
        return d1
    if v >= v2:
        return d2
    return d1 + (d2 - d1) * (v - v1) / (v2 - v1)


def _infer_deltas(contours, deltas):
    """IUP: точки, которых нет в тапле, тянутся за соседними опорными."""
    first = 0
    for contour in contours:
        last = first + len(contour) - 1
        refs = [i for i in range(first, last + 1) if deltas[i] is not None]
        if not refs:
            for i in range(first, last + 1):
                deltas[i] = (0.0, 0.0)
        elif len(refs) == 1:
            for i in range(first, last + 1):
                deltas[i] = deltas[refs[0]]
        else:
            for k, a in enumerate(refs):
                b = refs[(k + 1) % len(refs)]
                i = first if a == last else a + 1
                while i != b:
                    deltas[i] = (
                        _interpolate(contour[i - first][0],
                                     contour[a - first][0], deltas[a][0],
                                     contour[b - first][0], deltas[b][0]),
                        _interpolate(contour[i - first][1],
                                     contour[a - first][1], deltas[a][1],
                                     contour[b - first][1], deltas[b][1]),
                    )
                    i = first if i == last else i + 1
        first = last + 1
    for i, value in enumerate(deltas):
        if value is None:
            deltas[i] = (0.0, 0.0)


def to_cubic(contour):
    """TrueType quadratic contour -> list of cubic segments [(p0,c1,c2,p1), ...]."""
    pts = []
    for x, y, on in contour:
        pts.append((float(x), float(y), on))

    if not pts[0][2]:
        if pts[-1][2]:
            pts = [pts[-1]] + pts[:-1]
        else:
            mx = (pts[0][0] + pts[-1][0]) / 2
            my = (pts[0][1] + pts[-1][1]) / 2
            pts = [(mx, my, True)] + pts

    expanded = []
    for i, (x, y, on) in enumerate(pts):
        nx, ny, non = pts[(i + 1) % len(pts)]
        expanded.append((x, y, on))
        if not on and not non:
            expanded.append(((x + nx) / 2, (y + ny) / 2, True))

    segments = []
    i = 0
    n = len(expanded)
    while i < n:
        x0, y0, on0 = expanded[i]
        assert on0
        x1, y1, on1 = expanded[(i + 1) % n]
        if on1:
            segments.append(((x0, y0), (x0, y0), (x1, y1), (x1, y1)))
            i += 1
        else:
            x2, y2, _ = expanded[(i + 2) % n]
            c1 = (x0 + 2 / 3 * (x1 - x0), y0 + 2 / 3 * (y1 - y0))
            c2 = (x2 + 2 / 3 * (x1 - x2), y2 + 2 / 3 * (y1 - y2))
            segments.append(((x0, y0), c1, c2, (x2, y2)))
            i += 2
    return segments



def _find_font():
    root = os.path.expanduser('~/.pub-cache/hosted/pub.dev')
    candidates = sorted(
        name for name in os.listdir(root)
        if name.startswith('material_symbols_icons-')
    )
    if not candidates:
        raise SystemExit('material_symbols_icons не найден в pub-cache')
    return os.path.join(root, candidates[-1], 'lib', 'fonts',
                        'MaterialSymbolsOutlined.ttf')

FONT = os.environ.get('MATERIAL_SYMBOLS_TTF') or _find_font()


UPM = 960.0
CANVAS = 600.0
MIN_AREA = 500.0

_font = Font(FONT)


def _bezier(seg, t):
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = seg
    mt = 1 - t
    x = mt ** 3 * x0 + 3 * mt * mt * t * x1 + 3 * mt * t * t * x2 + t ** 3 * x3
    y = mt ** 3 * y0 + 3 * mt * mt * t * y1 + 3 * mt * t * t * y2 + t ** 3 * y3
    return x, y


def _split_cubic(seg, t):
    p0, c1, c2, p3 = seg

    def mid(a, b, k):
        return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)

    a = mid(p0, c1, t)
    b = mid(c1, c2, t)
    c = mid(c2, p3, t)
    d = mid(a, b, t)
    e = mid(b, c, t)
    f = mid(d, e, t)
    return (p0, a, d, f), (f, e, c, p3)


def _seg_metrics(seg, steps=64):
    pts = [_bezier(seg, i / steps) for i in range(steps + 1)]
    acc = [0.0]
    total = 0.0
    for i in range(steps):
        total += math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1])
        acc.append(total)
    return acc, total, steps


def _t_at_length(metrics, target):
    acc, total, steps = metrics
    if total <= 0:
        return 0.0
    for i in range(steps):
        if acc[i + 1] >= target:
            span = acc[i + 1] - acc[i]
            k = 0.0 if span <= 0 else (target - acc[i]) / span
            return (i + k) / steps
    return 1.0


def _canvas_segments(contour):
    out = []
    for seg in to_cubic(contour):
        out.append(tuple(
            (x / UPM * CANVAS, (1 - y / UPM) * CANVAS) for x, y in seg
        ))
    return out


def _exact_path(contour, count):
    """Subdivide the original beziers: geometry stays bit-for-bit the glyph."""
    segments = _canvas_segments(contour)
    metrics = [_seg_metrics(s) for s in segments]
    lengths = [m[1] for m in metrics]
    total = sum(lengths)
    if total <= 0:
        return []

    quota = [max(1, int(round(count * length / total))) for length in lengths]
    while sum(quota) > count and max(quota) > 1:
        idx = max(range(len(quota)), key=lambda i: (quota[i], lengths[i]))
        quota[idx] -= 1
    while sum(quota) < count:
        idx = max(range(len(quota)), key=lambda i: lengths[i] / quota[i])
        quota[idx] += 1

    pieces = []
    for seg, metric, parts in zip(segments, metrics, quota):
        rest = seg
        consumed = 0.0
        length = metric[1]
        for k in range(parts - 1):
            t_abs = _t_at_length(metric, length * (k + 1) / parts)
            span = 1.0 - consumed
            t_local = 0.0 if span <= 0 else (t_abs - consumed) / span
            t_local = min(max(t_local, 1e-4), 1 - 1e-4)
            head, rest = _split_cubic(rest, t_local)
            pieces.append(head)
            consumed = t_abs
        pieces.append(rest)

    path = []
    n = len(pieces)
    for i, (p0, c1, _, _) in enumerate(pieces):
        prev_c2 = pieces[(i - 1) % n][2]
        path.append((
            p0,
            (prev_c2[0] - p0[0], prev_c2[1] - p0[1]),
            (c1[0] - p0[0], c1[1] - p0[1]),
        ))
    return path


def _area(path):
    area = 0.0
    n = len(path)
    for i in range(n):
        x0, y0 = path[i][0]
        x1, y1 = path[(i + 1) % n][0]
        area += x0 * y1 - x1 * y0
    return area / 2


def glyph_paths(codepoint, count, fill=0.0):
    out = []
    for contour in _font.contours(codepoint, fill):
        path = _exact_path(contour, count)
        if not path:
            continue
        area = _area(path)
        if abs(area) < MIN_AREA:
            continue
        out.append((area, path))
    return out


def _centroid(path):
    return (sum(p[0][0] for p in path) / len(path),
            sum(p[0][1] for p in path) / len(path))


def _collapsed(path):
    cx, cy = _centroid(path)
    return [((cx, cy), (0.0, 0.0), (0.0, 0.0))] * len(path)


def _rotate(path, shift):
    return path[shift:] + path[:shift]


def _align(src, dst):
    n = len(src)
    best, best_cost = 0, None
    for shift in range(n):
        cost = 0.0
        for i in range(n):
            x0, y0 = src[i][0]
            x1, y1 = dst[(i + shift) % n][0]
            cost += (x0 - x1) ** 2 + (y0 - y1) ** 2
        if best_cost is None or cost < best_cost:
            best, best_cost = shift, cost
    return _rotate(dst, best)


def outer_sign(shapes):
    """The biggest contour is always an outline: its winding defines 'outer'."""
    biggest = max(shapes, key=lambda s: abs(s[0]))
    return 1.0 if biggest[0] > 0 else -1.0


def pair_glyphs(from_cp, to_cp, count, fill=0.0):
    """[(path_from, path_to), ...] with matching vertex counts and winding."""
    src = glyph_paths(from_cp, count, fill)
    dst = glyph_paths(to_cp, count, fill)
    src_sign = outer_sign(src)
    dst_sign = outer_sign(dst)

    pairs = []
    for outer in (True, False):
        a = sorted([s for s in src if (s[0] * src_sign > 0) == outer],
                   key=lambda s: -abs(s[0]))
        b = sorted([s for s in dst if (s[0] * dst_sign > 0) == outer],
                   key=lambda s: -abs(s[0]))
        for i in range(max(len(a), len(b))):
            if i < len(a) and i < len(b):
                pairs.append((a[i][1], _align(a[i][1], b[i][1])))
            elif i < len(a):
                pairs.append((a[i][1], _collapsed(a[i][1])))
            else:
                pairs.append((_collapsed(b[i][1]), b[i][1]))
    return pairs



MIC = 0xE31D
MIC_OFF = 0xE02B
CAM = 0xE04B
CAM_OFF = 0xE04C
SEND = 0xE163
VOLUME_UP = 0xE050
VOLUME_OFF = 0xE04F
FLASH_ON = 0xE3E7
FLASH_OFF = 0xE3E6

POINTS = 56
FPS = 60
DUR = 24
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), 'assets', 'lottie')

EASE_OUT = {'x': 0.2, 'y': 0}
EASE_IN = {'x': 0.0, 'y': 1.0}
EASE_OUT_V = {'x': [0.2], 'y': [0]}
EASE_IN_V = {'x': [0.0], 'y': [1.0]}
EASE_SOFT_OUT_V = {'x': [0.33], 'y': [0]}
EASE_SOFT_IN_V = {'x': [0.25], 'y': [1.0]}


def r2(value):
    return round(value, 2)


def path_value(path):
    return {
        'i': [[r2(p[1][0]), r2(p[1][1])] for p in path],
        'o': [[r2(p[2][0]), r2(p[2][1])] for p in path],
        'v': [[r2(p[0][0]), r2(p[0][1])] for p in path],
        'c': True,
    }


COLLAPSE_END = 10
GROW_START = 12


def _is_point(path):
    first = path[0][0]
    return all(abs(p[0][0] - first[0]) < 0.01 and abs(p[0][1] - first[1]) < 0.01
               for p in path)


def shape_item(index, path_from, path_to):
    start, end = 0, DUR
    if _is_point(path_to):
        end = COLLAPSE_END
    elif _is_point(path_from):
        start = GROW_START
    return {
        'ind': index,
        'ty': 'sh',
        'ix': index + 1,
        'ks': {
            'a': 1,
            'k': [
                {'i': EASE_IN, 'o': EASE_OUT, 't': start,
                 's': [path_value(path_from)]},
                {'t': end, 's': [path_value(path_to)]},
            ],
            'ix': 2,
        },
        'nm': 'Path %d' % (index + 1),
        'mn': 'ADBE Vector Shape - Group',
        'hd': False,
    }


def _group(items, name):
    items = list(items)
    items.append({
        'ty': 'fl',
        'c': {'a': 0, 'k': [1, 1, 1, 1], 'ix': 4},
        'o': {'a': 0, 'k': 100, 'ix': 5},
        'r': 1,
        'bm': 0,
        'nm': 'Fill',
        'mn': 'ADBE Vector Graphic - Fill',
        'hd': False,
    })
    items.append({
        'ty': 'tr',
        'p': {'a': 0, 'k': [0, 0], 'ix': 2},
        'a': {'a': 0, 'k': [0, 0], 'ix': 1},
        's': {'a': 0, 'k': [100, 100], 'ix': 3},
        'r': {'a': 0, 'k': 0, 'ix': 6},
        'o': {'a': 0, 'k': 100, 'ix': 7},
        'sk': {'a': 0, 'k': 0, 'ix': 4},
        'sa': {'a': 0, 'k': 0, 'ix': 5},
        'nm': 'Transform',
    })
    return {
        'ty': 'gr',
        'it': items,
        'nm': name,
        'np': len(items),
        'cix': 2,
        'bm': 0,
        'ix': 1,
        'mn': 'ADBE Vector Group',
        'hd': False,
    }


def static_shape(index, path):
    return {
        'ind': index,
        'ty': 'sh',
        'ix': index + 1,
        'ks': {'a': 0, 'k': path_value(path), 'ix': 2},
        'nm': 'Path %d' % (index + 1),
        'mn': 'ADBE Vector Shape - Group',
        'hd': False,
    }


def keyframes(stops, vector):
    out = []
    for i, (frame, value) in enumerate(stops):
        entry = {'t': frame, 's': value if isinstance(value, list) else [value]}
        if i < len(stops) - 1:
            if vector:
                entry['i'] = EASE_IN_V if i == 0 else EASE_SOFT_IN_V
                entry['o'] = EASE_OUT_V if i == 0 else EASE_SOFT_OUT_V
            else:
                entry['i'] = EASE_IN
                entry['o'] = EASE_OUT
        out.append(entry)
    return out


def transform(rotation=None, scale=None, offset_x=None):
    half = CANVAS / 2
    ks = {
        'o': {'a': 0, 'k': 100, 'ix': 11},
        'r': {'a': 0, 'k': 0, 'ix': 10},
        'p': {'a': 0, 'k': [half, half, 0], 'ix': 2},
        'a': {'a': 0, 'k': [half, half, 0], 'ix': 1},
        's': {'a': 0, 'k': [100, 100, 100], 'ix': 6},
    }
    if rotation:
        ks['r'] = {'a': 1, 'k': keyframes(rotation, vector=False), 'ix': 10}
    if scale:
        stops = [(f, [v, v, 100]) for f, v in scale]
        ks['s'] = {'a': 1, 'k': keyframes(stops, vector=True), 'ix': 6}
    if offset_x:
        stops = [(f, [half + dx, half, 0]) for f, dx in offset_x]
        ks['p'] = {'a': 1, 'k': keyframes(stops, vector=True), 'ix': 2}
    return ks


def build(name, from_cp, to_cp, rotation=None, scale=None, offset_x=None,
          fill=0.0):
    pairs = pair_glyphs(from_cp, to_cp, POINTS, fill)
    items = [shape_item(i, a, b) for i, (a, b) in enumerate(pairs)]

    return {
        'v': '5.12.1',
        'fr': FPS,
        'ip': 0,
        'op': DUR,
        'w': int(CANVAS),
        'h': int(CANVAS),
        'nm': name,
        'ddd': 0,
        'assets': [],
        'layers': [{
            'ddd': 0,
            'ind': 1,
            'ty': 4,
            'nm': name,
            'sr': 1,
            'ks': transform(rotation, scale, offset_x),
            'ao': 0,
            'shapes': [_group(items, 'Group 1')],
            'ip': 0,
            'op': DUR,
            'st': 0,
            'bm': 0,
        }],
        'markers': [],
    }


def _wipe_quad(cut, ahead):
    """Половина плоскости по обе стороны от диагонали x + y = cut."""
    reach = CANVAS * 1.5
    mid = (cut / 2, cut / 2)
    along = (reach / math.sqrt(2), -reach / math.sqrt(2))
    depth = reach * math.sqrt(2) * (1 if ahead else -1)
    corners = [
        (mid[0] + along[0], mid[1] + along[1]),
        (mid[0] - along[0], mid[1] - along[1]),
        (mid[0] - along[0] + depth, mid[1] - along[1] + depth),
        (mid[0] + along[0] + depth, mid[1] + along[1] + depth),
    ]
    return {
        'i': [[0, 0]] * 4,
        'o': [[0, 0]] * 4,
        'v': [[r2(x), r2(y)] for x, y in corners],
        'c': True,
    }


def wipe_mask(span, ahead):
    start, end = span
    return [{
        'inv': False,
        'mode': 'a',
        'pt': {
            'a': 1,
            'k': [
                {'i': EASE_IN, 'o': EASE_OUT, 't': 0,
                 's': [_wipe_quad(start, ahead)]},
                {'t': DUR, 's': [_wipe_quad(end, ahead)]},
            ],
            'ix': 1,
        },
        'o': {'a': 0, 'k': 100, 'ix': 3},
        'x': {'a': 0, 'k': 0, 'ix': 4},
        'nm': 'Wipe',
    }]


def _diagonal_span(*glyphs):
    values = [v[0][0] + v[0][1] for paths in glyphs for _, path in paths
              for v in path]
    margin = CANVAS * 0.04
    return min(values) - margin, max(values) + margin


def build_slash(name, plain_cp, slashed_cp, fill=0.0, scale=None):
    """Кадр 0 — обычный глиф, последний — перечёркнутый.

    Оба глифа лежат статичными слоями, а по диагонали (перпендикулярно самой
    перечёркивающей линии) едет маска: перечёркнутый слой открывается ровно там,
    где обычный закрывается, поэтому линия выглядит нарисованной поверх иконки.
    """
    plain = glyph_paths(plain_cp, POINTS, fill)
    slashed = glyph_paths(slashed_cp, POINTS, fill)
    span = _diagonal_span(plain, slashed)

    def layer(index, paths, ahead, title):
        items = [static_shape(i, path) for i, (_, path) in enumerate(paths)]
        return {
            'ddd': 0,
            'ind': index,
            'ty': 4,
            'nm': title,
            'sr': 1,
            'ks': transform(scale=scale),
            'ao': 0,
            'hasMask': True,
            'masksProperties': wipe_mask(span, ahead),
            'shapes': [_group(items, title)],
            'ip': 0,
            'op': DUR,
            'st': 0,
            'bm': 0,
        }

    return {
        'v': '5.12.1',
        'fr': FPS,
        'ip': 0,
        'op': DUR,
        'w': int(CANVAS),
        'h': int(CANVAS),
        'nm': name,
        'ddd': 0,
        'assets': [],
        'layers': [
            layer(1, slashed, False, 'slashed'),
            layer(2, plain, True, 'plain'),
        ],
        'markers': [],
    }


SPECS = [
    dict(
        name='ic_mic_to_videocam',
        from_cp=MIC, to_cp=CAM,
        rotation=[(0, 0), (10, -14), (DUR, 0)],
        scale=[(0, 100), (10, 88), (DUR, 100)],
    ),
    dict(
        name='ic_videocam_to_mic',
        from_cp=CAM, to_cp=MIC,
        rotation=[(0, 0), (11, 14), (DUR, 0)],
        scale=[(0, 100), (11, 111), (DUR, 100)],
    ),
    dict(
        name='ic_mic_to_send',
        from_cp=MIC, to_cp=SEND,
        scale=[(0, 100), (9, 90), (DUR, 100)],
        offset_x=[(0, 0), (9, -34), (19, 12), (DUR, 0)],
    ),
    dict(
        name='ic_videocam_to_send',
        from_cp=CAM, to_cp=SEND,
        rotation=[(0, 0), (9, 10), (DUR, 0)],
        scale=[(0, 100), (9, 92), (DUR, 100)],
        offset_x=[(0, 0), (9, -26), (19, 10), (DUR, 0)],
    ),
    dict(
        name='ic_send_to_mic',
        from_cp=SEND, to_cp=MIC,
        rotation=[(0, 0), (10, 9), (DUR, 0)],
        scale=[(0, 100), (10, 91), (DUR, 100)],
        offset_x=[(0, 0), (10, 30), (19, -10), (DUR, 0)],
    ),
    dict(
        name='ic_send_to_videocam',
        from_cp=SEND, to_cp=CAM,
        rotation=[(0, 0), (10, -11), (DUR, 0)],
        scale=[(0, 100), (10, 90), (DUR, 100)],
        offset_x=[(0, 0), (10, 24), (19, -8), (DUR, 0)],
    ),
]


SLASH_SPECS = [
    dict(
        name='ic_flash_on_to_off',
        plain_cp=FLASH_ON, slashed_cp=FLASH_OFF,
        fill=1.0,
        scale=[(0, 100), (11, 92), (DUR, 100)],
    ),
    dict(
        name='ic_volume_on_to_off',
        plain_cp=VOLUME_UP, slashed_cp=VOLUME_OFF,
        fill=1.0,
        scale=[(0, 100), (11, 92), (DUR, 100)],
    ),
    dict(
        name='ic_mic_on_to_off',
        plain_cp=MIC, slashed_cp=MIC_OFF,
        fill=1.0,
        scale=[(0, 100), (11, 92), (DUR, 100)],
    ),
    dict(
        name='ic_videocam_on_to_off',
        plain_cp=CAM, slashed_cp=CAM_OFF,
        fill=1.0,
        scale=[(0, 100), (11, 92), (DUR, 100)],
    ),
]


def _write(name, data):
    path = os.path.join(OUT_DIR, name + '.json')
    with open(path, 'w') as fh:
        json.dump(data, fh, separators=(',', ':'))
    print(f'{name:24s} {os.path.getsize(path) // 1024:3d} KB  '
          f'layers={len(data["layers"])}')


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for spec in SPECS:
        _write(spec['name'], build(**spec))
    for spec in SLASH_SPECS:
        _write(spec['name'], build_slash(**spec))


if __name__ == '__main__':
    main()
