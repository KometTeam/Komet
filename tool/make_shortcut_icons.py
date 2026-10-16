import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import make_morph_icons as glyphs

RES_DIR = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src',
                       'main', 'res')

BACKGROUND = '@color/ic_launcher_background'
GLYPH_COLOR = '#FFFFFFFF'

LEGACY_SIZE = 48
LEGACY_GLYPH = 24
ADAPTIVE_SIZE = 108
ADAPTIVE_GLYPH = 36

SPECS = [
    dict(name='ic_shortcut_saved', codepoint=0xE8E7, fill=1.0),
    dict(name='ic_shortcut_search', codepoint=0xEF7A),
]


def _num(value):
    text = f'{value:.3f}'.rstrip('0').rstrip('.')
    return '0' if text in ('-0', '') else text


def _point(x, y, size):
    return (x / glyphs.UPM * size, (1 - y / glyphs.UPM) * size)


def _pair(point):
    return f'{_num(point[0])},{_num(point[1])}'


def path_data(codepoint, fill, size):
    commands = []
    for contour in glyphs._font.contours(codepoint, fill):
        segments = glyphs.to_cubic(contour)
        if not segments:
            continue
        start = _point(*segments[0][0], size)
        commands.append(f'M{_pair(start)}')
        for p0, c1, c2, p1 in segments:
            end = _point(*p1, size)
            if c1 == p0 and c2 == p1:
                commands.append(f'L{_pair(end)}')
            else:
                commands.append(
                    f'C{_pair(_point(*c1, size))} '
                    f'{_pair(_point(*c2, size))} {_pair(end)}'
                )
        commands.append('Z')
    return ''.join(commands)


def _circle(size):
    r = size / 2 - 2
    c = size / 2
    return (f'M{_num(c)},{_num(c - r)}'
            f'A{_num(r)},{_num(r)} 0 1,1 {_num(c)},{_num(c + r)}'
            f'A{_num(r)},{_num(r)} 0 1,1 {_num(c)},{_num(c - r)}Z')


def _vector(size, body):
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:width="{size}dp"\n'
        f'    android:height="{size}dp"\n'
        f'    android:viewportWidth="{size}"\n'
        f'    android:viewportHeight="{size}">\n'
        f'{body}'
        '</vector>\n'
    )


def _glyph_path(data, offset):
    return (
        f'    <group android:translateX="{_num(offset)}" '
        f'android:translateY="{_num(offset)}">\n'
        f'        <path\n'
        f'            android:fillColor="{GLYPH_COLOR}"\n'
        f'            android:pathData="{data}" />\n'
        f'    </group>\n'
    )


def legacy(spec):
    data = path_data(spec['codepoint'], spec.get('fill', 0.0), LEGACY_GLYPH)
    body = (
        f'    <path\n'
        f'        android:fillColor="{BACKGROUND}"\n'
        f'        android:pathData="{_circle(LEGACY_SIZE)}" />\n'
        + _glyph_path(data, (LEGACY_SIZE - LEGACY_GLYPH) / 2)
    )
    return _vector(LEGACY_SIZE, body)


def foreground(spec):
    data = path_data(spec['codepoint'], spec.get('fill', 0.0), ADAPTIVE_GLYPH)
    return _vector(
        ADAPTIVE_SIZE,
        _glyph_path(data, (ADAPTIVE_SIZE - ADAPTIVE_GLYPH) / 2),
    )


def adaptive(spec):
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f'    <background android:drawable="{BACKGROUND}" />\n'
        f'    <foreground android:drawable="@drawable/{spec["name"]}_foreground" />\n'
        '</adaptive-icon>\n'
    )


def _write(folder, name, text):
    directory = os.path.join(RES_DIR, folder)
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, name + '.xml')
    with open(path, 'w') as fh:
        fh.write(text)
    print(os.path.relpath(path))


def main():
    for spec in SPECS:
        _write('drawable', spec['name'], legacy(spec))
        _write('drawable', spec['name'] + '_foreground', foreground(spec))
        _write('drawable-anydpi-v26', spec['name'], adaptive(spec))


if __name__ == '__main__':
    main()
