import 'package:flutter/material.dart';

/// Chi detiene il copyright di Receipt e dove sta il codice sorgente.
const receiptCopyright = '© 2026 Emanuele Galiano';
const receiptSource = 'github.com/emanuelegaliano/Receipt';

/// La pagina delle licenze di Flutter. Le voci vengono dal file NOTICES nella
/// radice del progetto, che Flutter legge al posto di LICENSE (Receipt con la
/// GPL e il codice o le librerie di terzi che non arrivano da pub: RapidOCR,
/// i modelli PP-OCRv4, Clipper, ONNX Runtime, SQLite3MultipleCiphers), più le
/// licenze dei pacchetti pub, raccolte da Flutter da solo.
void showReceiptLicenses(BuildContext context, String? version) => showLicensePage(
      context: context,
      applicationName: 'Receipt',
      applicationVersion: version,
      applicationLegalese: '$receiptCopyright\nGNU GPL v3\n$receiptSource',
    );
