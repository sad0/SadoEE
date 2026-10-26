"""Camp merchant page backgrounds: a wooden notice board with worn notices pinned on it (John 2026-10-23).

    python build_gm_board.py compose     -> gm/base.png (board + scraps + worn papers), gm/PSXGMBA.png (+ pencil lines)
    python build_gm_board.py ai          -> gm/PSXGMBB.png (base redrawn by SwarmUI img2img, same layout, + pencil lines)
    python build_gm_board.py title       -> ../PSXGMTEN.BAM, ../PSXGMTFR.BAM (the title in charcoal, one per language)
    python build_gm_board.py mos         -> ../PSXGMBA.MOS, ../PSXGMBB.MOS (build_art.to_mos)

Pieces in gm/ come from the local SwarmUI: board (nb_board2), three blank papers, a brass pin, an iron nail, a wax
seal, a twine knot (Z-Image Turbo, shot on black and keyed out here), the title lettering (Qwen Image, black on white:
title_en / title_fr). ZONES follow build_gm_menu.py (864 x 710): each notice sits under one part of the page.
Wear (John): every sheet gets its own corners (dog-ear, torn off, curled or intact), stains (mug rings, ink, water),
scorched edges, old pin holes, small tears, cross folds; scraps of older notices stay nailed on the wood underneath.
Pencil lines are drawn after the img2img pass so both boards keep the same structure: tree ruling, a frame around
the grid, underlines, boxes around the tickets.
"""
import base64
import io
import json
import math
import os
import random
import sys
import urllib.parse
import urllib.request

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
GM = os.path.join(HERE, 'gm')
W, H = 864, 710
# build_gm_menu.py geometry
GX, GY, PITCH, CELL, COLS, ROWS = 236, 104, 54, 52, 8, 7
RX, RW = 684, 160
QY = GY + 184

# name: (x, y, w, h, paper, fixing, angle)
ZONES = {
    'tree': (16, 46, 202, 620, 'paper1', 'pin', -0.6),
    'list': (226, 10, 454, 516, 'paper2', 'nail', 0.0),
    'card': (684, 26, 170, 264, 'paper3', 'wax', 0.8),
    'qty': (690, 280, 156, 74, 'paper1', 'twine', -1.2),
    'buy': (702, 354, 126, 96, 'paper2', 'pin', 1.0),
    'msg': (232, 530, 440, 58, 'paper1', 'pin', -0.4),
    'done': (682, 552, 170, 98, 'paper2', 'nail', -0.8),
}
# corner treatment per sheet (tl, tr, br, bl): dog = dog-ear, torn = torn off, curl = curled, None = intact
CORNERS = {
    'tree': (None, None, 'dog', 'torn'),
    'list': (None, None, 'curl', None),
    'card': (None, 'torn', None, None),
    'qty': (None, None, None, 'dog'),
    'buy': (None, None, 'curl', None),
    'msg': (None, None, None, None),
    'done': ('dog', None, None, 'torn'),
}
# older notices left on the board, mostly covered: (x, y, w, h, angle)
SCRAPS = [(150, 600, 150, 100, -7), (440, 584, 190, 110, 4), (628, 430, 120, 150, -5), (812, 470, 70, 120, 8),
          (190, 6, 70, 60, 12)]
TONE = {'paper1': (0.86, 0.78, 0.62), 'paper2': (0.92, 0.86, 0.72), 'paper3': (1.0, 0.97, 0.92),
        'scrap': (0.70, 0.62, 0.48)}


def load(name):
    return Image.open(os.path.join(GM, 'nb_%s.png' % name)).convert('RGB')


def board():
    b = load('board2')
    bw, bh = b.size
    m = 0.045  # keep only a thin strip of the frame
    b = b.crop((int(bw * m), int(bh * m * 1.1), int(bw * (1 - m)), int(bh * (1 - m * 1.1)))).resize((W, H), Image.LANCZOS)
    # older, darker wood: the papers must stand out and the game's light text must stay readable on the wood
    b = Image.blend(b, ImageOps.grayscale(b).convert('RGB'), 0.25)
    b = ImageChops.multiply(b, Image.new('RGB', (W, H), (150, 118, 92)))
    vign = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(vign)
    for i in range(60):
        d.rectangle((i, i, W - 1 - i, H - 1 - i), outline=int(255 * (1 - i / 60) * 0.55))
    return Image.composite(Image.new('RGB', (W, H), 'black'), b, vign.filter(ImageFilter.GaussianBlur(12)))


def keyed(name, size):
    """A piece shot on black, as RGBA (alpha from brightness), scaled to `size` px wide."""
    im = load(name)
    alpha = ImageOps.grayscale(im).point(lambda v: 0 if v < 18 else min(255, (v - 18) * 6))
    im.putalpha(alpha)
    im = im.crop(alpha.getbbox())
    r = size / im.width
    return im.resize((size, max(1, int(im.height * r))), Image.LANCZOS)


def walk(rnd, n, lo=0.0, hi=6.0, step=1.2, start=2.0):
    v, out = start, []
    for _ in range(n):
        v = min(hi, max(lo, v + rnd.uniform(-step, step)))
        out.append(v)
    return out


def ragged_edges(d, w, h, rnd, depth):
    """Eats a random walk into each side (torn paper)."""
    for x, k in enumerate(walk(rnd, w, hi=depth)):
        d.line((x, 0, x, int(k)), fill=0)
    for x, k in enumerate(walk(rnd, w, hi=depth)):
        d.line((x, h - 1 - int(k), x, h - 1), fill=0)
    for y, k in enumerate(walk(rnd, h, hi=depth)):
        d.line((0, y, int(k), y), fill=0)
    for y, k in enumerate(walk(rnd, h, hi=depth)):
        d.line((w - 1 - int(k), y, w - 1, y), fill=0)


def corner_xy(w, h, which):
    return {0: (0, 0, 1, 1), 1: (w, 0, -1, 1), 2: (w, h, -1, -1), 3: (0, h, 1, -1)}[which]


def wear(sheet, rnd, corners, torn_edges):
    """Corners, stains, scorch, holes, tears, folds on an RGBA sheet."""
    w, h = sheet.size
    mask = sheet.getchannel('A')
    md = ImageDraw.Draw(mask)
    if torn_edges:
        ragged_edges(md, w, h, rnd, 6)
    else:
        ragged_edges(md, w, h, rnd, 0.9)  # even cut paper is never a perfect line
    over = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(over)
    for i, kind in enumerate(corners):
        if not kind:
            continue
        cx, cy, sx, sy = corner_xy(w, h, i)
        c = int(min(w, h) * rnd.uniform(0.10, 0.20))
        if kind == 'dog':  # folded over: the corner is gone and its back lies on the sheet, darker
            md.polygon([(cx, cy), (cx + sx * c, cy), (cx, cy + sy * c)], fill=0)
            tilt = rnd.uniform(0.75, 1.15)
            od.polygon([(cx + sx * c, cy), (cx, cy + sy * int(c * tilt)), (cx + sx * c * 0.95, cy + sy * c * tilt * 0.95)],
                       fill=(150, 126, 92, 255))
            od.line([(cx + sx * c, cy), (cx, cy + sy * int(c * tilt))], fill=(90, 70, 45, 160), width=1)
        elif kind == 'torn':  # torn off along a jagged line
            pts = [(cx + sx * c * rnd.uniform(1.0, 1.5), cy)]
            n = 7
            for k in range(1, n):
                t = k / n
                pts.append((cx + sx * (c * (1 - t) + rnd.uniform(-4, 4)), cy + sy * (c * t + rnd.uniform(-4, 4))))
            pts.append((cx, cy + sy * c * rnd.uniform(1.0, 1.5)))
            md.polygon([(cx, cy)] + pts, fill=0)
        elif kind == 'curl':  # rolled up: a shaded band along the diagonal
            g = Image.new('L', (w, h), 0)
            gd = ImageDraw.Draw(g)
            for k in range(c, 0, -1):
                gd.line([(cx + sx * k, cy), (cx, cy + sy * k)], fill=int(150 * (1 - k / c) ** 0.7), width=2)
            over = Image.alpha_composite(over, Image.merge('RGBA', [Image.new('L', (w, h), 60)] * 3 + [g]))
            od = ImageDraw.Draw(over)
    # mug rings, ink blots, water marks
    for _ in range(rnd.randint(1, 3)):
        kind = rnd.choice(('ring', 'ring', 'ink', 'water'))
        r = rnd.randint(14, 34) if kind != 'ink' else rnd.randint(3, 8)
        x, y = rnd.randint(r, max(r + 1, w - r)), rnd.randint(r, max(r + 1, h - r))
        if kind == 'ring':
            a0 = rnd.uniform(0, 360)
            for k in range(3):
                od.arc((x - r - k, y - r - k, x + r + k, y + r + k), a0, a0 + rnd.uniform(200, 320), fill=(110, 75, 35, 28 - k * 8), width=2)
        elif kind == 'ink':
            od.ellipse((x - r, y - r, x + r, y + r), fill=(25, 20, 30, 170))
            for _ in range(5):
                dx, dy = rnd.randint(-3 * r, 3 * r), rnd.randint(-3 * r, 3 * r)
                s = rnd.randint(1, 3)
                od.ellipse((x + dx - s, y + dy - s, x + dx + s, y + dy + s), fill=(25, 20, 30, 150))
        else:
            od.ellipse((x - r * 2, y - r, x + r * 2, y + r), outline=(120, 95, 60, 26), width=3)
    # scorched edge on one side for some sheets
    if rnd.random() < 0.5:
        g = Image.new('L', (w, h), 0)
        gd = ImageDraw.Draw(g)
        side = rnd.randint(0, 3)
        depth = rnd.randint(10, 22)
        for k in range(depth):
            a = int(200 * (1 - k / depth) ** 1.8)
            if side == 0:
                gd.line((0, k, w, k), fill=a)
            elif side == 1:
                gd.line((w - 1 - k, 0, w - 1 - k, h), fill=a)
            elif side == 2:
                gd.line((0, h - 1 - k, w, h - 1 - k), fill=a)
            else:
                gd.line((k, 0, k, h), fill=a)
        g = ImageChops.multiply(g, Image.effect_noise((w, h), 90).point(lambda v: min(255, v + 120)))
        over = Image.alpha_composite(over, Image.merge('RGBA', [Image.new('L', (w, h), 35)] * 3 + [g]))
        od = ImageDraw.Draw(over)
    # old pin holes near the top, a small tear on one side
    for _ in range(rnd.randint(1, 3)):
        x, y = rnd.randint(8, w - 8), rnd.randint(4, 16)
        md.ellipse((x - 1, y - 1, x + 1, y + 1), fill=0)
        od.ellipse((x - 3, y - 3, x + 3, y + 3), outline=(90, 70, 45, 110))
    if rnd.random() < 0.7:
        y = rnd.randint(h // 4, h * 3 // 4)
        side = rnd.choice((0, w - 1))
        ln = rnd.randint(6, 14)
        sx = 1 if side == 0 else -1
        md.polygon([(side, y - 2), (side + sx * ln, y + rnd.randint(-2, 2)), (side, y + 2)], fill=0)
    # folds: a cross for big sheets, one line for small ones
    folds = [('h', rnd.uniform(0.35, 0.65))]
    if h > 200:
        folds.append(('v', rnd.uniform(0.4, 0.6)))
    for axis, t in folds:
        if axis == 'h':
            y = int(h * t)
            dy = rnd.randint(-3, 3)
            od.line((0, y, w, y + dy), fill=(80, 60, 35, 60), width=2)
            od.line((0, y + 2, w, y + 2 + dy), fill=(255, 245, 220, 60), width=1)
        else:
            x = int(w * t)
            dx = rnd.randint(-3, 3)
            od.line((x, 0, x + dx, h), fill=(80, 60, 35, 50), width=2)
            od.line((x + 2, 0, x + 2 + dx, h), fill=(255, 245, 220, 55), width=1)
    sheet = Image.alpha_composite(sheet, over)
    sheet.putalpha(ImageChops.multiply(sheet.getchannel('A'), mask))
    return sheet


def paper(w, h, kind, rnd, tone=None):
    tex = load('paper3' if kind == 'scrap' else kind)
    tw, th = tex.size
    inset = 0.0 if kind in ('paper3', 'scrap') else 0.06
    tex = tex.crop((int(tw * inset), int(th * inset), int(tw * (1 - inset)), int(th * (1 - inset))))
    # a random part of the texture, so two sheets of the same paper differ
    sx, sy = rnd.uniform(0, 0.15), rnd.uniform(0, 0.15)
    tw, th = tex.size
    tex = tex.crop((int(tw * sx), int(th * sy), int(tw * (sx + 0.85)), int(th * (sy + 0.85)))).resize((w, h), Image.LANCZOS)
    tex = ImageChops.multiply(tex, Image.new('RGB', (w, h), tuple(int(255 * t) for t in (tone or TONE[kind]))))
    # mottled ageing and darker edges
    blot = Image.effect_noise((max(2, w // 40), max(2, h // 40)), 40).resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
    tex = ImageChops.multiply(tex, Image.merge('RGB', [blot.point(lambda v: 228 + v // 9)] * 3))
    edge = Image.new('L', (w, h), 0)
    de = ImageDraw.Draw(edge)
    for i in range(14):
        de.rectangle((i, i, w - 1 - i, h - 1 - i), outline=int(110 * (1 - i / 14)))
    tex = Image.composite(Image.new('RGB', (w, h), (95, 70, 40)), tex, edge.filter(ImageFilter.GaussianBlur(3)))
    sheet = tex.convert('RGBA')
    sheet.putalpha(Image.new('L', (w, h), 255))
    return sheet


def place(out, sheet, x, y, angle, pad=14):
    w, h = sheet.size
    layer = Image.new('RGBA', (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    layer.paste(sheet, (pad, pad), sheet)
    layer = layer.rotate(angle, resample=Image.BICUBIC)
    shadow = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel('A').point(lambda a: a * 150 // 255).filter(ImageFilter.GaussianBlur(5)))
    out.alpha_composite(shadow, (x - pad + 4, y - pad + 5))
    out.alpha_composite(layer, (x - pad, y - pad))


def fix(out, kind, cx, cy):
    size = {'pin': 20, 'nail': 18, 'wax': 30, 'twine': 46}[kind]
    piece = keyed(kind, size)
    px, py = cx - piece.width // 2, cy - piece.height // 2
    sh = Image.new('RGBA', piece.size, (0, 0, 0, 0))
    sh.putalpha(piece.getchannel('A').point(lambda a: a * 170 // 255).filter(ImageFilter.GaussianBlur(2)))
    out.alpha_composite(sh, (px + 3, py + 3))
    out.alpha_composite(piece, (px, py))


def compose_base():
    rnd = random.Random(7)
    out = board().convert('RGBA')
    for x, y, w, h, angle in SCRAPS:  # older notices under the new ones
        s = wear(paper(w, h, 'scrap', rnd), rnd, (rnd.choice((None, 'torn')), 'torn', None, 'torn'), True)
        place(out, s, x, y, angle)
        fix(out, rnd.choice(('nail', 'pin')), x + w // 2 + rnd.randint(-20, 20), y + 8)
    for name, (x, y, w, h, kind, fixing, angle) in ZONES.items():
        s = wear(paper(w, h, kind, rnd), rnd, CORNERS[name], name in ('card', 'msg'))
        place(out, s, x, y, angle)
        spots = [x + w // 2 + rnd.randint(-10, 10)] if w < 300 else [x + 24, x + w - 24]
        for sx in spots:
            fix(out, fixing, sx, y + (6 if fixing != 'twine' else 2))
    return out.convert('RGB')


# --- pencil / charcoal lines -------------------------------------------------------------------------------------

def stroke(d, pts, rnd, width=2, alpha=150, wobble=1.2):
    """A hand-drawn line through pts: a slow wobble (not jitter), uneven pressure along the line, a second lighter pass."""
    for p in range(2):
        path = []
        off = 0.0
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            ln = math.hypot(x1 - x0, y1 - y0)
            n = max(2, int(ln / 6))
            nx, ny = (-(y1 - y0) / ln, (x1 - x0) / ln) if ln else (0, 0)
            for k in range(n):
                t = k / n
                off = max(-wobble, min(wobble, off + rnd.uniform(-0.35, 0.35)))
                path.append((x0 + (x1 - x0) * t + nx * off, y0 + (y1 - y0) * t + ny * off))
        path.append(pts[-1])
        a = alpha * (1.0 if p == 0 else 0.45)
        pressure = rnd.uniform(0.75, 1.0)
        for i, (u, v) in enumerate(zip(path, path[1:])):
            pressure = max(0.55, min(1.0, pressure + rnd.uniform(-0.06, 0.06)))
            d.line([u, v], fill=(40, 34, 30, int(a * pressure)), width=max(1, width - p))


def box(d, x, y, w, h, rnd, **kw):
    o = 3  # strokes overshoot the corners a little
    stroke(d, [(x - o, y), (x + w + o, y + rnd.uniform(-1, 1))], rnd, **kw)
    stroke(d, [(x + w, y - o), (x + w + rnd.uniform(-1, 1), y + h + o)], rnd, **kw)
    stroke(d, [(x + w + o, y + h), (x - o, y + h + rnd.uniform(-1, 1))], rnd, **kw)
    stroke(d, [(x, y + h + o), (x + rnd.uniform(-1, 1), y - o)], rnd, **kw)


def lines(img):
    rnd = random.Random(11)
    S = 4  # drawn 4x larger then reduced: smooth, unbroken strokes

    class Scaled:
        def __init__(self, draw):
            self.draw = draw

        def line(self, pts, fill, width=1):
            self.draw.line([(x * S, y * S) for x, y in pts], fill=fill, width=max(1, int(width * S * 0.8)))

    layer = Image.new('RGBA', (W * S, H * S), (0, 0, 0, 0))
    d = Scaled(ImageDraw.Draw(layer))
    # tree ruling: one line under each 26 px row of the list (area 26 68 184 580)
    y = 68 + 25
    while y < 646:
        stroke(d, [(30, y), (206, y + rnd.uniform(-1.5, 1.5))], rnd, width=1, alpha=110)
        y += 26
    # title underline (thick charcoal), line under the search row, frame around the grid, line over the pager
    stroke(d, [(GX + 70, 57), (GX + COLS * PITCH - 70, 58)], rnd, width=4, alpha=200, wobble=1.6)
    stroke(d, [(GX, 97), (GX + COLS * PITCH, 97 + rnd.uniform(-1, 1))], rnd, width=1, alpha=120)
    box(d, GX - 5, GY - 5, COLS * PITCH + 8, ROWS * PITCH + 8, rnd, width=2, alpha=170)
    stroke(d, [(GX, GY + ROWS * PITCH + 38), (GX + COLS * PITCH, GY + ROWS * PITCH + 38)], rnd, width=1, alpha=100)
    # item card: line under the icon area and under the name
    stroke(d, [(RX + 18, GY + 124), (RX + RW - 18, GY + 125)], rnd, width=2, alpha=150)
    # tickets: boxes around the quantity, Buy, sell and done; underline the total
    box(d, RX + 12, QY - 2, RW - 24, 32, rnd, width=1, alpha=140)
    stroke(d, [(RX + 30, QY + 60), (RX + RW - 30, QY + 61)], rnd, width=1, alpha=110)
    box(d, RX + 26, 360, RW - 52, 32, rnd, width=2, alpha=160)
    box(d, RX + 6, 564, RW - 12, 34, rnd, width=1, alpha=130)
    box(d, RX + 30, 604, RW - 60, 34, rnd, width=2, alpha=150)
    layer = layer.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.3))
    out = img.convert('RGBA')
    out.alpha_composite(layer)
    return out.convert('RGB')


def compose():
    os.makedirs(GM, exist_ok=True)
    base = compose_base()
    base.save(os.path.join(GM, 'base.png'))
    lines(base).save(os.path.join(GM, 'PSXGMBA.png'))
    print('written gm/base.png, gm/PSXGMBA.png')


def ai(creativity=0.6, seed=5):
    api = 'http://localhost:7801/API/'

    def post(name, body):
        req = urllib.request.Request(api + name, json.dumps(body).encode(), {'Content-Type': 'application/json'})
        return json.loads(urllib.request.urlopen(req, timeout=900).read())

    src = Image.open(os.path.join(GM, 'base.png')).resize((1728, 1408), Image.LANCZOS)
    buf = io.BytesIO()
    src.save(buf, 'PNG')
    sid = post('GetNewSession', {})['session_id']
    r = post('GenerateText2Image', {
        'session_id': sid, 'images': 1, 'model': 'ZImage/SwarmUI_Z-Image-Turbo-FP8Mix', 'width': 1728, 'height': 1408,
        'steps': 8, 'cfgscale': 1, 'seed': seed,
        'prompt': 'front view of a rustic wooden tavern notice board covered with old worn blank parchment notices, '
                  'torn corners, dog-eared corners, mug stains, scorched edges, a torn wanted poster with a red wax seal, '
                  'scraps of older torn notices nailed underneath, brass pins, iron nails, twine, warm candle light, '
                  'medieval fantasy, highly detailed painting',
        'negativeprompt': 'text, letters, writing, words, watermark, logo, people',
        'initimage': 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode(),
        'initimagecreativity': creativity})
    img = (r.get('images') or [None])[0]
    if not img:
        sys.exit('SwarmUI: %s' % r.get('error'))
    with urllib.request.urlopen('http://localhost:7801/' + urllib.parse.quote(img), timeout=120) as f:
        b = Image.open(io.BytesIO(f.read())).convert('RGB').resize((W, H), Image.LANCZOS)
    lines(b).save(os.path.join(GM, 'PSXGMBB.png'))
    print('written gm/PSXGMBB.png')


def charcoal(src, size):
    """Black-on-white lettering -> RGBA charcoal: thicker, rough edges, dry grain, a light smudge."""
    g = ImageOps.grayscale(Image.open(src))
    ink = ImageOps.invert(g).point(lambda v: 255 if v > 90 else 0)
    ink = ink.crop(ink.getbbox())
    ink = ink.filter(ImageFilter.MaxFilter(7))  # thick stick
    r = min(size[0] / ink.width, size[1] / ink.height)
    ink = ink.resize((int(ink.width * r), int(ink.height * r)), Image.LANCZOS)
    w, h = ink.size
    # solid black in the middle of the strokes, dry grain only on their edges (John: fuller letters)
    core = ink.filter(ImageFilter.MinFilter(5))
    grain = Image.effect_noise((w, h), 70).point(lambda v: 255 if v > 55 else 0)
    edge = ImageChops.multiply(ink, grain)
    rough = ink.filter(ImageFilter.GaussianBlur(1.0)).point(lambda v: 255 if v > 110 else 0)
    alpha = ImageChops.lighter(core, ImageChops.multiply(edge, rough))
    smudge = ink.filter(ImageFilter.GaussianBlur(4)).point(lambda v: v * 70 // 255)
    alpha = ImageChops.lighter(alpha, ImageChops.offset(smudge, 2, 3))
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    col = Image.new('RGBA', (w, h), (28, 24, 22, 255))
    col.putalpha(alpha)
    out.alpha_composite(col, ((size[0] - w) // 2, (size[1] - h) // 2))
    return out


def title():
    sys.argv = sys.argv[:1]
    import build_art
    # PSXGMTEN / PSXGMTFR: the camp merchant in each language; PSXGMTC: "Codex" (Decard's page, the same word in
    # English and French; John 2026-10-24)
    for key, bam in (('en', 'PSXGMTEN'), ('fr', 'PSXGMTFR'), ('codex', 'PSXGMTC')):
        img = charcoal(os.path.join(GM, 'title_%s.png' % key), (340, 42))
        img.save(os.path.join(GM, 'title_%s_charcoal.png' % key))
        # BAM V1 is 1-bit transparent: keep the solid strokes, drop the faint smudge
        img.putalpha(img.getchannel('A').point(lambda a: 255 if a > 100 else 0))
        build_art.write_bam(img, os.path.join(HERE, '..', bam + '.BAM'))
        print('written', bam + '.BAM')


# --- buttons ------------------------------------------------------------------------------------------------------
# Paper tickets in the same pencil look (John 2026-10-23), game buttons with the usual frames: 0 up, 1 pressed,
# 2 selected (= up), 3 disabled. name: (w, h, shape)
BUTTONS = {
    'PSXGMBN1': (116, 32, 'ticket'),  # Buy
    'PSXGMBN2': (144, 32, 'ticket'),  # sell, done, sort
    'PSXGMBN3': (30, 30, 'disc'),     # - + < >
    'PSXGMBN4': (196, 28, 'tag'),     # board swap, on the wood
}


def button_frames(w, h, shape, rnd):
    S = 4
    base = paper(w * S, h * S, 'paper2', rnd).convert('RGBA')
    base = base.resize((w * S, h * S))
    m = Image.new('L', (w * S, h * S), 0)
    md = ImageDraw.Draw(m)
    if shape == 'disc':
        md.ellipse((2 * S, 2 * S, (w - 2) * S, (h - 2) * S), fill=255)
    else:
        # a slightly irregular ticket: corners cut at random, the tag gets a punched hole on the left
        cut = [rnd.randint(1, 4) * S for _ in range(4)]
        md.polygon([(cut[0], 0), (w * S - cut[1], 0), (w * S, cut[1]), (w * S, h * S - cut[2]),
                    (w * S - cut[2], h * S), (cut[3], h * S), (0, h * S - cut[3]), (0, cut[0])], fill=255)
        if shape == 'tag':
            md.ellipse((5 * S, (h // 2 - 3) * S, 11 * S, (h // 2 + 3) * S), fill=0)
    layer = Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))

    class Big:
        def __init__(self, draw):
            self.draw = draw

        def line(self, pts, fill, width=1):
            self.draw.line([(x * S, y * S) for x, y in pts], fill=fill, width=max(1, int(width * S * 0.8)))

    d = Big(ImageDraw.Draw(layer))
    if shape == 'disc':
        pts = [(w / 2 + (w / 2 - 4) * math.cos(a / 20 * 2 * math.pi) + rnd.uniform(-0.6, 0.6),
                h / 2 + (h / 2 - 4) * math.sin(a / 20 * 2 * math.pi) + rnd.uniform(-0.6, 0.6)) for a in range(22)]
        stroke(d, pts, rnd, width=1, alpha=170, wobble=0.5)
    else:
        box(d, 4, 4, w - 8, h - 8, rnd, width=1, alpha=170, wobble=0.6)
    sheet = base.copy()
    sheet.alpha_composite(layer)
    sheet.putalpha(ImageChops.multiply(sheet.getchannel('A'), m))
    up = sheet.resize((w, h), Image.LANCZOS)
    # pressed: darker, pushed 1 px down-right; disabled: faded and greyer
    down = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dk = ImageChops.multiply(up, Image.new('RGBA', (w, h), (205, 190, 165, 255)))
    down.paste(dk.crop((0, 0, w - 1, h - 1)), (1, 1))
    off = up.copy()
    grey = Image.blend(off.convert('RGB'), ImageOps.grayscale(off).convert('RGB'), 0.6)
    off = Image.merge('RGBA', grey.split() + (off.getchannel('A').point(lambda a: a * 200 // 255),))
    for f in (up, down, off):  # 1-bit edges in the palette's alpha: keep them clean
        f.putalpha(f.getchannel('A').point(lambda a: 0 if a < 90 else a))
    return [up, down, up, off]


def circle_frames(w=180, h=26):
    """Tree selection: frame 0 empty, frame 1 a quick pencil loop around the row."""
    rnd = random.Random(23)
    S = 4
    layer = Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))

    class Big:
        def __init__(self, draw):
            self.draw = draw

        def line(self, pts, fill, width=1):
            self.draw.line([(x * S, y * S) for x, y in pts], fill=fill, width=max(1, int(width * S * 0.8)))

    d = Big(ImageDraw.Draw(layer))
    n = 40
    pts = []
    for k in range(n + 6):  # a little more than one turn: the loop overlaps where it started
        a = k / n * 2 * math.pi - 2.4
        pts.append((w / 2 + (w / 2 - 4) * math.cos(a) * rnd.uniform(0.98, 1.02),
                    h / 2 + (h / 2 - 3) * math.sin(a) * rnd.uniform(0.94, 1.04)))
    stroke(d, pts, rnd, width=2, alpha=200, wobble=0.8)
    on = layer.resize((w, h), Image.LANCZOS)
    on.putalpha(on.getchannel('A').point(lambda a: 0 if a < 40 else min(255, a * 2)))
    return [Image.new('RGBA', (w, h), (0, 0, 0, 0)), on]


def buttons():
    sys.argv = sys.argv[:1]
    import build_art
    rnd = random.Random(31)
    for name, (w, h, shape) in BUTTONS.items():
        frames = button_frames(w, h, shape, rnd)
        build_art.write_bam_v1(frames, [[0, 1, 2, 3]], os.path.join(HERE, '..', name + '.BAM'))
        prev = Image.new('RGBA', (w * 4 + 12, h), (60, 40, 25, 255))
        for i, f in enumerate(frames):
            prev.alpha_composite(f, (i * (w + 4), 0))
        prev.save(os.path.join(GM, 'prev_%s.png' % name))
    build_art.write_bam_v1(circle_frames(), [[0, 1]], os.path.join(HERE, '..', 'PSXGMCIR.BAM'))


def mos():
    sys.argv = sys.argv[:1]  # build_art reads argv[2] for the game
    import build_art
    for n in ('PSXGMBA', 'PSXGMBB'):
        build_art.to_mos(os.path.join(GM, n + '.png'), os.path.join(HERE, '..', n + '.MOS'))
        print('written', n + '.MOS')


if __name__ == '__main__':
    {'compose': compose, 'ai': ai, 'title': title, 'buttons': buttons, 'mos': mos}[sys.argv[1]]()
