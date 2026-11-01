"""Confronta l'OCR Dart (log del test di integrazione) con RapidOCR Python.

    python tools/compare_ocr.py riferimento.json log_test.txt
"""

import difflib
import json
import re
import sys


def center(box):
    return (sum(p[0] for p in box) / 4, sum(p[1] for p in box) / 4)


def main(ref_path, log_path):
    ref = json.load(open(ref_path))
    dart = {}
    for line in open(log_path, encoding="utf-8"):
        m = re.search(r"OCR_RESULT (\{.*\})\s*$", line)
        if m:
            r = json.loads(m.group(1))
            dart[r["image"]] = r

    tot_ref = tot_exact = 0
    sims = []
    for name in sorted(ref):
        if name not in dart:
            print(f"{name}: mancante nel log Dart")
            continue
        r_lines, d_lines = ref[name], dart[name]["lines"]
        exact = 0
        diffs = []
        for rl in r_lines:
            rc = center(rl["box"])
            best = min(d_lines, key=lambda dl: (center(dl["box"])[0] - rc[0]) ** 2 + (center(dl["box"])[1] - rc[1]) ** 2, default=None)
            if best is None:
                sims.append(0)
                continue
            s = difflib.SequenceMatcher(None, rl["text"], best["text"]).ratio()
            sims.append(s)
            if rl["text"] == best["text"]:
                exact += 1
            else:
                diffs.append((rl["text"], best["text"]))
        tot_ref += len(r_lines)
        tot_exact += exact
        t = dart[name]["timings"]
        print(f"{name}: righe py {len(r_lines)} / dart {len(d_lines)}, testo identico {exact}/{len(r_lines)}, "
              f"tempo dart {sum(t.values())} ms {t}")
        for a, b in diffs[:5]:
            print(f"    py  : {a!r}\n    dart: {b!r}")

    if sims:
        print(f"\nTOTALE: righe identiche {tot_exact}/{tot_ref} ({100 * tot_exact / tot_ref:.1f}%), "
              f"similarità media caratteri {100 * sum(sims) / len(sims):.2f}%")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
