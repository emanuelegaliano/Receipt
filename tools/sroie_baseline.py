"""Baseline Python su SROIE: RapidOCR + Spatial2DBoxParser di PyReceipt.

    python tools/sroie_baseline.py /percorso/SROIE2019/test out_dir [lingua]

Scrive in out_dir:
- ocr_boxes.json : per ogni immagine le righe OCR nel formato PyReceipt
                   ({"text", "box": [x0, y0, x1, y1], "conf"}) più il riquadro
                   ruotato ("poly"), usate dai test del parser Dart
- baseline.json  : risultato del parser per immagine e accuratezza
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "reference" / "PyReceipt"))

from pyreceipt.adapters.spatial_2d_parser import Spatial2DBoxParser  # noqa: E402
from rapidocr_onnxruntime import RapidOCR  # noqa: E402


def gt_of(path: Path):
    d = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
    try:
        total = float(str(d.get("total", "0")).replace(",", "").replace("$", "").replace("RM", "").strip())
    except ValueError:
        total = 0.0
    return {"company": d.get("company", "").strip(), "date": d.get("date", "").strip(), "total": total}


def date_ok(p, g):
    if not g:
        return True
    pn, gn = re.sub(r"[^\d]", "", p), re.sub(r"[^\d]", "", g)
    return pn == gn if (pn and gn) else p == g


def norm_company(s):
    return re.sub(r"[^A-Z0-9]", "", s.upper())


def main(split: Path, out: Path, lang: str = "en"):
    out.mkdir(parents=True, exist_ok=True)
    engine = RapidOCR()
    parser = Spatial2DBoxParser(lang_code=lang, config_dir=ROOT / "reference" / "PyReceipt" / "config" / "langs")
    boxes_out, results = {}, {}
    ok = {"total": 0, "date": 0, "company": 0}
    imgs = sorted(split.glob("img/*.jpg"))
    for i, img in enumerate(imgs):
        res, _ = engine(str(img))
        boxes = []
        for poly, text, score in res or []:
            xs = [int(p[0]) for p in poly]
            ys = [int(p[1]) for p in poly]
            if text.strip():
                boxes.append({"text": text.strip(), "box": [min(xs), min(ys), max(xs), max(ys)], "conf": float(score),
                              "poly": [[float(x), float(y)] for x, y in poly]})
        boxes.sort(key=lambda b: (b["box"][1], b["box"][0]))
        boxes_out[img.name] = boxes

        r = parser.parse(boxes)
        gt = gt_of(split / "entities" / (img.stem + ".txt"))
        m = {
            "total": gt["total"] <= 0 or abs(r.total - gt["total"]) < 0.01,
            "date": date_ok(r.date, gt["date"]),
            "company": norm_company(r.company) == norm_company(gt["company"]),
        }
        for k in ok:
            ok[k] += m[k]
        results[img.name] = {"pred": {"company": r.company, "date": r.date, "total": r.total}, "gt": gt, "ok": m}
        if (i + 1) % 50 == 0:
            print(f"{i + 1}/{len(imgs)}", flush=True)

    n = len(imgs)
    acc = {k: round(100 * v / n, 1) for k, v in ok.items()}
    (out / "ocr_boxes.json").write_text(json.dumps(boxes_out, ensure_ascii=False))
    (out / "baseline.json").write_text(json.dumps({"accuracy": acc, "n": n, "results": results}, ensure_ascii=False, indent=1))
    print(f"n={n} accuratezza %: {acc}")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3] if len(sys.argv) > 3 else "en")
