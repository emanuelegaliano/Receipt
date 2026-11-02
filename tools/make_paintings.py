"""Genera assets/art/paintings.json, l'elenco dei quadri del giorno.

    python tools/make_paintings.py cache_dir assets/art/paintings.json

Nessun testo è scritto a mano: tutto viene da fonti aperte, citate nell'app.

- Wikidata (CC0): i dipinti con un ID del Metropolitan Museum of Art (P3634)
  e un'immagine (P18), con titolo e descrizione breve in italiano e inglese
  e le voci di Wikipedia collegate.
- Wikimedia Commons: misure vere dell'immagine, licenza e una miniatura
  larga 1280 px (0,3-0,8 MB), che il telefono scarica al posto
  dell'originale. Quasi tutte sono le foto Open Access del Met.
- Open Access del Met (MetObjects.csv su GitHub, CC0): pubblico dominio,
  autore, data, tecnica, misure, credit line e pagina dell'opera.
- Wikipedia (CC BY-SA 4.0): l'introduzione della voce sul quadro, in
  italiano e in inglese, dove c'è.

Restano i quadri di pubblico dominio per il Met, con un'immagine CC0 o di
pubblico dominio, alta almeno 1,2 volte la larghezza: stanno bene come
sfondo del telefono. Prima quelli con una voce su Wikipedia, poi gli
highlights del Met, fino a MAX. L'ordine dei giorni è mescolato con un seme
fisso, senza due quadri dello stesso autore di fila.

I download stanno in cache_dir: rilanciando si riparte da lì.
"""

import csv
import json
import random
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

UA = "ReceiptApp/0.3.2 (https://github.com/emanuelegaliano/Receipt)"
MET_CSV = "https://media.githubusercontent.com/media/metmuseum/openaccess/master/MetObjects.csv"
MAX = 600
MIN_RATIO = 1.2
THUMB = 1280
LICENSES = {"CC0", "Public domain"}

SPARQL = """SELECT ?item ?met ?img ?itLabel ?enLabel ?itDesc ?enDesc ?itwiki ?enwiki WHERE {
 ?item wdt:P3634 ?met; wdt:P31 wd:Q3305213; wdt:P18 ?img.
 OPTIONAL {?item rdfs:label ?itLabel FILTER(lang(?itLabel)="it")}
 OPTIONAL {?item rdfs:label ?enLabel FILTER(lang(?enLabel)="en")}
 OPTIONAL {?item schema:description ?itDesc FILTER(lang(?itDesc)="it")}
 OPTIONAL {?item schema:description ?enDesc FILTER(lang(?enDesc)="en")}
 OPTIONAL {?itwiki schema:about ?item; schema:isPartOf <https://it.wikipedia.org/>}
 OPTIONAL {?enwiki schema:about ?item; schema:isPartOf <https://en.wikipedia.org/>}
}"""


def get(url, tries=4):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read()
        except Exception as e:
            err = e
            time.sleep(2 + 3 * attempt)
    raise RuntimeError(f"{url}: {err}")


def cached(path: Path, make):
    if not path.exists():
        path.write_text(json.dumps(make(), ensure_ascii=False))
    return json.loads(path.read_text())


def wikidata():
    url = "https://query.wikidata.org/sparql?" + urllib.parse.urlencode({"query": SPARQL, "format": "json"})
    return json.loads(get(url))


def file_name(row):
    v = row["img"]["value"]
    return urllib.parse.unquote(v.split("Special:FilePath/")[1]) if "Special:FilePath/" in v else None


def commons(names):
    """Misure, licenza e miniatura delle immagini, 50 per richiesta."""

    def batch(chunk):
        q = urllib.parse.urlencode({
            "action": "query", "format": "json", "prop": "imageinfo", "iiprop": "size|url|extmetadata",
            "iiurlwidth": THUMB, "iiextmetadatafilter": "LicenseShortName|Credit",
            "titles": "|".join("File:" + n for n in chunk),
        })
        d = json.loads(get("https://commons.wikimedia.org/w/api.php?" + q))
        norm = {n["to"]: n["from"] for n in d["query"].get("normalized", [])}
        out = {}
        for page in d["query"]["pages"].values():
            ii = (page.get("imageinfo") or [None])[0]
            if not ii:
                continue
            em = ii.get("extmetadata", {})
            out[norm.get(page["title"], page["title"])[5:]] = dict(
                w=ii["width"], h=ii["height"], bytes=ii["size"], thumb=ii.get("thumburl"),
                tw=ii.get("thumbwidth"), th=ii.get("thumbheight"), page=ii["descriptionurl"],
                license=em.get("LicenseShortName", {}).get("value"), credit=em.get("Credit", {}).get("value", "")[:300])
        return out

    names = sorted(names)
    res = {}
    with ThreadPoolExecutor(3) as ex:
        for r in ex.map(batch, [names[i:i + 50] for i in range(0, len(names), 50)]):
            res.update(r)
    return res


def met_rows(cache: Path):
    path = cache / "MetObjects.csv"
    if not path.exists():
        path.write_bytes(get(MET_CSV))
    csv.field_size_limit(10 ** 9)
    with open(path, encoding="utf-8-sig") as f:
        return {r["Object ID"]: r for r in csv.DictReader(f)}


def wikipedia(pick):
    """Introduzione delle voci di Wikipedia, per lingua."""

    def one(job):
        oid, lang, url = job
        title = url.rsplit("/wiki/", 1)[1]
        try:
            d = json.loads(get(f"https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}", tries=3))
        except RuntimeError:
            return oid, lang, None
        return oid, lang, dict(title=d["title"], url=d["content_urls"]["desktop"]["page"], extract=d.get("extract", ""))

    jobs = [(x["id"], lang, x[lang + "wiki"]) for x in pick for lang in ("it", "en") if x[lang + "wiki"]]
    out = {}
    with ThreadPoolExecutor(4) as ex:
        for oid, lang, d in ex.map(one, jobs):
            if d and d["extract"]:
                out.setdefault(oid, {})[lang] = d
    return out


def day_order(paintings, seed=2026):
    """Mescola e poi sposta avanti chi ha lo stesso autore del precedente."""
    rest = paintings[:]
    random.Random(seed).shuffle(rest)
    out = []
    while rest:
        pick = next((p for p in rest if not out or p["artist"] != out[-1]["artist"]), rest[0])
        rest.remove(pick)
        out.append(pick)
    return out


def main(cache: Path, dst: Path):
    cache.mkdir(parents=True, exist_ok=True)
    rows = cached(cache / "wikidata.json", wikidata)["results"]["bindings"]
    images = cached(cache / "commons.json", lambda: commons({n for r in rows if (n := file_name(r))}))
    met = met_rows(cache)

    cands = {}
    for r in rows:
        name, m = file_name(r), met.get(r["met"]["value"])
        c = images.get(name) if name else None
        if not c or not m or not c.get("thumb") or m["Is Public Domain"] != "True" or c["license"] not in LICENSES:
            continue
        if c["h"] / c["w"] < MIN_RATIO or c["w"] < THUMB:
            continue
        g = lambda k: r[k]["value"] if k in r else None
        cands.setdefault(m["Object ID"], dict(
            id=m["Object ID"], met=m, image=c, wikidata=g("item"), itLabel=g("itLabel"),
            itDesc=g("itDesc"), enDesc=g("enDesc"), itwiki=g("itwiki"), enwiki=g("enwiki")))
    pool = list(cands.values())
    random.Random(2026).shuffle(pool)
    pool.sort(key=lambda x: (bool(x["itwiki"] or x["enwiki"]), x["met"]["Is Highlight"] == "True",
                             x["met"]["Is Timeline Work"] == "True"), reverse=True)
    pick = pool[:MAX]
    wiki = cached(cache / f"wikipedia-{len(pick)}.json", lambda: wikipedia(pick))

    paintings = []
    for x in pick:
        m, c = x["met"], x["image"]
        texts = {}
        for lang in ("it", "en"):
            t = {}
            if lang == "it" and x["itLabel"]:
                t["title"] = x["itLabel"]
            if x[lang + "Desc"]:
                t["summary"] = x[lang + "Desc"]
            if lang in wiki.get(x["id"], {}):
                t["wikipedia"] = wiki[x["id"]][lang]
            texts[lang] = t
        paintings.append({
            "id": int(m["Object ID"]),
            "title": m["Title"],
            "artist": m["Artist Display Name"].split("|")[0],
            "artistBio": m["Artist Display Bio"].split("|")[0],
            "date": m["Object Date"],
            "medium": m["Medium"],
            "dimensions": m["Dimensions"],
            "credit": m["Credit Line"],
            "page": m["Link Resource"],
            "image": c["thumb"],
            "imagePage": c["page"],
            "imageLicense": c["license"],
            "wikidata": x["wikidata"],
            "texts": texts,
        })
    out = {
        "sources": [
            "The Metropolitan Museum of Art, Open Access (CC0): https://www.metmuseum.org/hubs/open-access",
            "Wikidata (CC0): https://www.wikidata.org",
            "Wikimedia Commons: https://commons.wikimedia.org",
            "Wikipedia (CC BY-SA 4.0): https://www.wikipedia.org",
        ],
        "paintings": day_order(paintings),
    }
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n")
    with_wiki = sum(1 for p in paintings if any("wikipedia" in t for t in p["texts"].values()))
    print(f"{len(cands)} candidati, {len(paintings)} quadri -> {dst} ({dst.stat().st_size // 1024} KB), "
          f"{with_wiki} con Wikipedia")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
