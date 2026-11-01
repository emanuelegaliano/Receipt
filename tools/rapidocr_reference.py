"""Output di riferimento del RapidOCR Python, per verificare la porta in Dart.

    python tools/rapidocr_reference.py out.json img1.jpg [img2.jpg ...]
        -> per ogni immagine: righe riconosciute (box, testo, confidenza)

    python tools/rapidocr_reference.py --det-fixture test/fixtures/det img.jpg
        -> salva la mappa del rilevatore (float32, gzip) e i box attesi dal
           post-processing, usati da test/db_postprocess_test.dart
"""

import gzip
import json
import sys
from pathlib import Path

import numpy as np
from rapidocr_onnxruntime import RapidOCR


def reference(paths):
    engine = RapidOCR()
    out = {}
    for p in paths:
        result, _ = engine(p)
        out[Path(p).name] = [
            {"box": [[float(x), float(y)] for x, y in box], "text": text, "score": float(score)}
            for box, text, score in (result or [])
        ]
    return out


def det_fixture(out_dir: Path, image_path: str):
    engine = RapidOCR()
    det = engine.text_det
    img = engine.load_img(image_path)
    img, _, _ = engine.preprocess(img)
    h, w = img.shape[:2]
    pre = det.get_preprocess(max(h, w))(img)
    pred = det.infer(pre)[0]  # [1, 1, H, W]
    boxes, scores = det.postprocess_op(pred, (h, w))

    out_dir.mkdir(parents=True, exist_ok=True)
    with gzip.open(out_dir / "pred.f32.gz", "wb") as f:
        f.write(pred[0, 0].astype("<f4").tobytes())
    meta = {
        "image": Path(image_path).name,
        "map_width": int(pred.shape[3]),
        "map_height": int(pred.shape[2]),
        "dest_width": int(w),
        "dest_height": int(h),
        "boxes": [b.tolist() for b in boxes],
        "scores": [float(s) for s in scores],
    }
    (out_dir / "expected.json").write_text(json.dumps(meta, indent=1))
    print(f"{len(boxes)} box, mappa {meta['map_width']}x{meta['map_height']}")


if __name__ == "__main__":
    if sys.argv[1] == "--det-fixture":
        det_fixture(Path(sys.argv[2]), sys.argv[3])
    else:
        res = reference(sys.argv[2:])
        Path(sys.argv[1]).write_text(json.dumps(res, ensure_ascii=False, indent=1))
        print(f"{len(res)} immagini -> {sys.argv[1]}")
