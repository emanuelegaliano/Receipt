"""Compatta l'output di tools/sroie_baseline.py in una fixture per i test Dart.

    python tools/make_parser_fixture.py out_dir test/fixtures/nome.json.gz
"""

import gzip
import json
import sys
from pathlib import Path


def main(src: Path, dst: Path):
    boxes = json.loads((src / "ocr_boxes.json").read_text())
    base = json.loads((src / "baseline.json").read_text())
    out = {k: {"boxes": boxes[k], "pred": base["results"][k]["pred"], "gt": base["results"][k]["gt"]} for k in boxes}
    with gzip.open(dst, "wt", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    print(f"{len(out)} scontrini -> {dst} ({dst.stat().st_size // 1024} KB), baseline {base['accuracy']}")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
