"""Disegna l'icona dell'app e genera le risorse Android.

Uso: python tools/make_icon.py   (serve Pillow; il simbolo € usa Arial Bold di macOS)

Produce:
  - icona adattiva (Android 8+): sfondo, primo piano e versione monocromatica
    per le icone a tema di Android 13+;
  - icone classiche ic_launcher.png per i launcher più vecchi;
  - docs/icon/icon.png (1024 px) come anteprima.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

N = 2048  # disegno in alta risoluzione, poi ridimensiono (antialias)
S = N / 1024  # le coordinate sotto sono su una tela di 1024 = 108 dp

BG_TOP = (52, 145, 105)
BG_BOTTOM = (25, 92, 66)
PAPER = (255, 255, 255)
INK = (196, 212, 205)
TOTAL = (31, 107, 76)
COIN = (247, 189, 64)
COIN_DARK = (214, 146, 22)

# Tutto il disegno resta nel cerchio "sicuro" di 66 dp (raggio ~313 px):
# i launcher ritagliano l'icona adattiva con forme diverse.
RECEIPT = (352, 262, 632, 730)
COIN_C, COIN_R, COIN_GAP = (630, 676), 100, 22


def sc(*v):
    return [x * S for x in v]


def receipt_mask():
    """Scontrino con il bordo inferiore a zig-zag e angoli superiori arrotondati."""
    x0, y0, x1, y1 = RECEIPT
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle(sc(x0, y0, x1, y1 - 20), radius=28 * S, fill=255)
    teeth = 7
    w = (x1 - x0) / teeth
    pts = [(x0, y1 - 40)]
    for i in range(teeth):
        pts += [(x0 + w * (i + 0.5), y1), (x0 + w * (i + 1), y1 - 40)]
    pts += [(x1, y1 - 60), (x0, y1 - 60)]
    d.polygon([(x * S, y * S) for x, y in pts], fill=255)
    return m


def lines(d, fill_ink, fill_total):
    x0, _, x1, _ = RECEIPT
    left = x0 + 40
    for y, right in [(330, x1 - 40), (382, x1 - 90), (434, x1 - 60), (486, x1 - 110)]:
        d.rounded_rectangle(sc(left, y, right, y + 22), radius=11 * S, fill=fill_ink)
    for x in range(int(left), int(x1 - 40), 26):  # tratteggio prima del totale
        d.rounded_rectangle(sc(x, 540, x + 14, 548), radius=4 * S, fill=fill_ink)
    d.rounded_rectangle(sc(left, 580, left + 90, 610), radius=15 * S, fill=fill_total)
    d.rounded_rectangle(sc(left + 120, 580, x1 - 40, 610), radius=15 * S, fill=fill_total)


def circle(d, c, r, fill):
    d.ellipse(sc(c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=fill)


def euro(d, fill):
    font = ImageFont.truetype(FONT, int(130 * S))
    d.text((COIN_C[0] * S, COIN_C[1] * S + 4 * S), "€", font=font, fill=fill, anchor="mm")


def coin_gap_mask():
    m = Image.new("L", (N, N), 0)
    circle(ImageDraw.Draw(m), COIN_C, COIN_R + COIN_GAP, 255)
    return m


def foreground():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    paper = receipt_mask()
    paper = ImageChops.subtract(paper, coin_gap_mask())

    # Ombra morbida sotto lo scontrino.
    shadow = Image.new("RGBA", (N, N), (0, 30, 15, 0))
    shadow.putalpha(paper.point(lambda a: a * 70 // 255).filter(ImageFilter.GaussianBlur(18 * S)))
    img.alpha_composite(shadow, (0, int(10 * S)))

    layer = Image.new("RGBA", (N, N), PAPER + (255,))
    layer.putalpha(paper)
    img.alpha_composite(layer)

    d = ImageDraw.Draw(img)
    lines(d, INK, TOTAL)
    circle(d, COIN_C, COIN_R, COIN_DARK)
    circle(d, COIN_C, COIN_R - 12, COIN)
    euro(d, (255, 255, 255))
    return img.resize((1024, 1024), Image.LANCZOS)


def monochrome():
    """Solo la sagoma (canale alfa): il sistema la colora secondo il tema."""
    m = ImageChops.subtract(receipt_mask(), coin_gap_mask())
    d = ImageDraw.Draw(m)
    lines(d, 0, 0)
    circle(d, COIN_C, COIN_R, 255)
    circle(d, COIN_C, COIN_R - 12, 0)
    circle(d, COIN_C, COIN_R - 22, 255)
    euro(d, 0)
    img = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    img.putalpha(m)
    return img.resize((1024, 1024), Image.LANCZOS)


def background():
    img = Image.new("RGB", (1024, 1024))
    d = ImageDraw.Draw(img)
    for y in range(1024):
        t = y / 1023
        d.line([(0, y), (1023, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return img.convert("RGBA")


def legacy(fg, bg):
    """Icona classica: il centro visibile (72 su 108 dp) in un quadrato arrotondato."""
    full = bg.copy()
    full.alpha_composite(fg)
    crop = full.crop((171, 171, 853, 853)).resize((1024, 1024), Image.LANCZOS)
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, N - 1, N - 1), radius=230 * S, fill=255)
    crop.putalpha(mask.resize((1024, 1024), Image.LANCZOS))
    return crop


DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
"""


def main():
    fg, bg, mono = foreground(), background(), monochrome()
    icon = legacy(fg, bg)
    for name, k in DENSITIES.items():
        out = RES / f"mipmap-{name}"
        out.mkdir(exist_ok=True)
        icon.resize((round(48 * k),) * 2, Image.LANCZOS).save(out / "ic_launcher.png")
        layer = round(108 * k)
        for suffix, img in [("foreground", fg), ("background", bg), ("monochrome", mono)]:
            img.resize((layer, layer), Image.LANCZOS).save(out / f"ic_launcher_{suffix}.png")
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_XML)
    preview = ROOT / "docs/icon"
    preview.mkdir(parents=True, exist_ok=True)
    icon.save(preview / "icon.png")
    full = bg.copy()
    full.alpha_composite(fg)
    full.save(preview / "adaptive_full.png")


if __name__ == "__main__":
    main()
