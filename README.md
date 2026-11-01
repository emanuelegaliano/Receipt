# ReceiptApp

App Android (Flutter) per tenere traccia delle spese con carta e contanti,
tutto sul telefono. Gli scontrini si leggono con **RapidOCR** (gli stessi
modelli PP-OCRv4 di [PyReceipt](https://github.com/emanuelegaliano/PyReceipt))
portato in Dart, e il parser di PyReceipt (`Spatial2DBoxParser`) ricava
esercente, data e totale.

## Cosa fa

- **Riepilogo del mese**: totale speso, confronto col mese prima, carta vs
  contanti, grafico per categoria, ultimi movimenti.
- **Movimenti** raggruppati per giorno, con ricerca, filtri per conto e
  categoria, swipe per eliminare (con "Annulla").
- **Scansione**: foto o galleria → OCR → modulo precompilato con importo,
  data, esercente, categoria suggerita e metodo di pagamento (dal testo:
  "pagamento elettronico", "contanti", ...). Si controlla e si salva.
- **Inserimento a mano** per le spese senza scontrino.
- **Categorie** modificabili (nome, icona, colore, parole chiave). La categoria
  si impara: quando salvi una spesa, l'esercente viene associato alla
  categoria scelta e la volta dopo è già suggerita (anche con piccoli errori
  di OCR nel nome).
- **Conti**: Carta e Contanti di base, se ne possono aggiungere.

## Struttura

```
lib/ocr/          porta di RapidOCR 1.4.4 (pipeline, DBNet, Clipper, cv2)
lib/receipt/      parser PyReceipt, date, esercente/categoria, pagamento
lib/data/         database SQLite (drift): conti, categorie, spese, regole
lib/ui/           schermate
lib/screens/      "Prova il lettore" (diagnostica OCR, dalle impostazioni)
assets/models/    modelli ONNX + dizionario (tools/export_models.py)
assets/parser/    config lingua di PyReceipt (it, en)
tools/            script Python di riferimento, benchmark, dati sintetici
test/             test sul Mac (parità con OpenCV/RapidOCR/PyReceipt, logica, DB)
integration_test/ OCR e benchmark sull'emulatore
reference/        copia di PyReceipt, solo da consultare (ignorata da git)
datasets/         dati locali, es. scontrini italiani sintetici (ignorata da git)
```

## Avvio

```bash
flutter emulators --launch Medium_Phone_API_37.0
flutter run
```

Dopo aver modificato `lib/data/database.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Test

```bash
flutter test
```

Benchmark end-to-end sull'emulatore (OCR + parser Dart):

```bash
(cd /Users/manu/Datasets/SROIE2019/test && python3 -m http.server 8765 --bind 127.0.0.1) &
adb reverse tcp:8765 tcp:8765
flutter test integration_test/sroie_benchmark_test.dart -d emulator-5554 > sroie.log
grep SROIE_SUMMARY sroie.log
```

Con `--dart-define=LANG=it` e servendo `datasets/italian_synthetic` si provano
gli scontrini italiani sintetici (`python tools/make_italian_samples.py datasets/italian_synthetic 30`).

Baseline Python (RapidOCR + PyReceipt) e fixture per i test del parser:

```bash
python tools/sroie_baseline.py /percorso/SROIE2019/test out en
python tools/make_parser_fixture.py out test/fixtures/sroie_parser.json.gz
```

Serve un ambiente Python 3.12 con `rapidocr_onnxruntime==1.4.4`, `onnx`,
`pytesseract` e `psutil` (questi ultimi due solo perché PyReceipt li importa).
