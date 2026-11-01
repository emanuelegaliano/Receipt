"""Genera scontrini italiani sintetici nel formato SROIE (img/ + entities/).

Servono a provare il percorso italiano (lingua "it") finché non ci sono foto
vere: impaginazione da documento commerciale, font termici, leggera rotazione,
sfocatura, rumore e compressione JPEG.

    python tools/make_italian_samples.py datasets/italian_synthetic 30
"""

import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTS = [
    "/System/Library/Fonts/Supplemental/Courier New.ttf",
    "/System/Library/Fonts/Supplemental/Andale Mono.ttf",
    "/System/Library/Fonts/Menlo.ttc",
    "/System/Library/Fonts/Supplemental/Courier New Bold.ttf",
]

STORES = [
    ("CONAD SUPERSTORE", "Via Etnea 120 - Catania", ["LATTE PS 1L", "PANE CASERECCIO", "MOZZARELLA", "PASTA BARILLA 500G", "POMODORI PELATI", "BANANE KG", "ACQUA NAT 6X1,5L", "CAFFE MACINATO", "YOGURT BIANCO"]),
    ("ESSELUNGA S.P.A.", "Viale Monza 25 - Milano", ["INSALATA MISTA", "PROSCIUTTO COTTO", "PARMIGIANO", "BISCOTTI", "OLIO EVO 1L", "UOVA X6", "MELE GOLDEN"]),
    ("BAR PASTICCERIA ROMA", "Piazza Duomo 3 - Catania", ["CAFFE", "CORNETTO", "CAPPUCCINO", "SPREMUTA", "ARANCINO", "GRANITA"]),
    ("FARMACIA CENTRALE", "Corso Italia 44 - Acireale", ["TACHIPIRINA 500MG", "CEROTTI", "ACQUA OSSIGENATA", "VITAMINA C", "SPRAY NASALE"]),
    ("ENI STATION 1234", "SS114 km 12 - Messina", ["GASOLIO SELF", "BENZINA SELF"]),
    ("TRATTORIA DA PINO", "Via dei Crociferi 8 - Catania", ["COPERTO", "PASTA ALLA NORMA", "PESCE SPADA", "VINO DELLA CASA", "ACQUA", "DOLCE"]),
    ("DECATHLON ITALIA SRL", "Centro Comm. Etnapolis", ["CALZE SPORT", "BORRACCIA", "MAGLIA RUNNING", "PALLONE"]),
    ("LIDL ITALIA S.R.L.", "Via Palermo 200 - Catania", ["FARINA 00", "ZUCCHERO 1KG", "DETERSIVO", "CARTA IGIENICA", "PATATINE", "BIRRA X3"]),
]


def money(v):
    return f"{v:.2f}".replace(".", ",")


def receipt(rng: random.Random):
    store, address, catalog = rng.choice(STORES)
    n = rng.randint(1, min(6, len(catalog)))
    items = [(name, round(rng.uniform(0.8, 25.0), 2)) for name in rng.sample(catalog, n)]
    total = round(sum(p for _, p in items), 2)
    day, month, year = rng.randint(1, 28), rng.randint(1, 12), rng.choice([2024, 2025, 2026])
    if year == 2026:
        month = min(month, 10)
    date_fmt = rng.choice(["{d:02d}-{m:02d}-{y}", "{d:02d}/{m:02d}/{y}", "{d:02d}/{m:02d}/{yy:02d}"])
    date = date_fmt.format(d=day, m=month, y=year, yy=year % 100)
    cash = rng.random() < 0.4
    vat = round(total - total / 1.1, 2)

    lines = [("c", store), ("c", address), ("c", f"P.IVA {rng.randint(10**10, 10**11 - 1)}"), ("", ""),
             ("c", "DOCUMENTO COMMERCIALE"), ("c", "di vendita o prestazione"), ("", ""),
             ("lr", ("DESCRIZIONE", "IVA  Prezzo(€)"))]
    for name, price in items:
        lines.append(("lr", (name, f"10%  {money(price)}")))
    lines.append(("", ""))
    total_label = rng.choice(["TOTALE COMPLESSIVO", "TOTALE EURO", "TOTALE"])
    lines.append(("lrb", (total_label, money(total))))
    lines.append(("lr", ("di cui IVA", money(vat))))
    if cash:
        paid = float(int(total) + rng.choice([1, 5, 10, 20]))
        lines.append(("lr", ("Pagamento contante", money(paid))))
        lines.append(("lr", ("Resto", money(round(paid - total, 2)))))
    else:
        lines.append(("lr", ("Pagamento elettronico", money(total))))
    lines.append(("lr", ("Importo pagato", money(total))))
    lines.append(("", ""))
    lines.append(("lr", (f"{date} {rng.randint(7, 21):02d}:{rng.randint(0, 59):02d}", f"DOC.N. {rng.randint(1, 9999):04d}-{rng.randint(1, 999):04d}")))
    lines.append(("c", f"RT {rng.choice(['80E', '99M', '72I'])}{rng.randint(10000, 99999)}"))
    lines.append(("c", "GRAZIE E ARRIVEDERCI"))
    gt = {"company": store, "date": date, "total": f"{total:.2f}", "address": address}
    return lines, gt


def render(lines, rng: random.Random):
    font_path = rng.choice(FONTS)
    size = rng.randint(22, 28)
    font = ImageFont.truetype(font_path, size)
    bold = ImageFont.truetype(font_path, int(size * 1.15))
    width, line_h, margin = 560, int(size * 1.45), 30
    img = Image.new("L", (width, margin * 2 + line_h * len(lines)), color=rng.randint(235, 252))
    d = ImageDraw.Draw(img)
    ink = rng.randint(10, 60)
    y = margin
    for kind, content in lines:
        if kind == "c":
            w = d.textlength(content, font=font)
            d.text(((width - w) / 2, y), content, fill=ink, font=font)
        elif kind in ("lr", "lrb"):
            f = bold if kind == "lrb" else font
            left, right = content
            d.text((margin, y), left, fill=ink, font=f)
            d.text((width - margin - d.textlength(right, font=f), y), right, fill=ink, font=f)
        y += line_h

    # Foto su sfondo scuro, leggermente ruotata e sfocata.
    bg = Image.new("L", (img.width + 160, img.height + 160), color=rng.randint(60, 120))
    bg.paste(img, (80, 80))
    bg = bg.rotate(rng.uniform(-3, 3), resample=Image.BICUBIC, fillcolor=rng.randint(60, 120), expand=False)
    bg = bg.filter(ImageFilter.GaussianBlur(rng.uniform(0.3, 1.0)))
    noise = Image.effect_noise(bg.size, rng.uniform(4, 12))
    bg = Image.blend(bg, noise, 0.08)
    return bg.convert("RGB")


def main(out: Path, n: int):
    rng = random.Random(42)
    (out / "img").mkdir(parents=True, exist_ok=True)
    (out / "entities").mkdir(parents=True, exist_ok=True)
    for i in range(n):
        lines, gt = receipt(rng)
        name = f"IT{i:04d}"
        render(lines, rng).save(out / "img" / f"{name}.jpg", quality=rng.randint(70, 90))
        (out / "entities" / f"{name}.txt").write_text(json.dumps(gt, ensure_ascii=False, indent=1))
    print(f"{n} scontrini in {out}")


if __name__ == "__main__":
    main(Path(sys.argv[1]), int(sys.argv[2]) if len(sys.argv) > 2 else 30)
