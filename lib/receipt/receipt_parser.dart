import 'dart:math' as math;

/// Riga OCR nel formato di PyReceipt: testo e box [x0, y0, x1, y1].
class OcrBox {
  final String text;
  final List<int> box;
  final double conf;
  const OcrBox(this.text, this.box, [this.conf = 1.0]);

  factory OcrBox.fromJson(Map<String, dynamic> j) => OcrBox(
        j['text'] as String,
        [for (final v in j['box'] as List) (v as num).toInt()],
        (j['conf'] as num?)?.toDouble() ?? 1.0,
      );
}

/// Risultato del parser, come `Receipt` di PyReceipt (senza categoria).
class ParsedReceipt {
  final String company;
  final String date; // stringa trovata sullo scontrino, es. "15/01/2019"
  final double total;
  const ParsedReceipt(this.company, this.date, this.total);

  @override
  String toString() => 'ParsedReceipt($company, $date, $total)';
}

/// Configurazione di lingua (config/langs/{it,en}.json di PyReceipt).
class LangConfig {
  final String code;
  final List<String> totalAnchors;
  final List<String> excludeAnchors;
  final List<String> headerExclusions;
  final List<String> datePatterns;
  final List<String> cashKeywords;
  final List<String> changeKeywords;
  final List<String> taxKeywords;
  final List<String> subtotalKeywords;

  const LangConfig({
    required this.code,
    this.totalAnchors = const [],
    this.excludeAnchors = const [],
    this.headerExclusions = const [],
    this.datePatterns = const [],
    this.cashKeywords = const [],
    this.changeKeywords = const [],
    this.taxKeywords = const [],
    this.subtotalKeywords = const [],
  });

  factory LangConfig.fromJson(Map<String, dynamic> j) {
    List<String> l(String k) => [for (final v in (j[k] as List? ?? const [])) v as String];
    return LangConfig(
      code: j['language'] as String,
      totalAnchors: l('total_anchors'),
      excludeAnchors: l('exclude_anchors'),
      headerExclusions: l('header_exclusions'),
      datePatterns: l('date_patterns'),
      cashKeywords: l('cash_keywords'),
      changeKeywords: l('change_keywords'),
      taxKeywords: l('tax_keywords'),
      subtotalKeywords: l('subtotal_keywords'),
    );
  }
}

List<String> _dedup(Iterable<String> items) => {...items}.toList();

/// re.escape di Python, sufficiente per le ancore dei JSON.
String _escape(String s) => s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\/\-#&~\s]'), (m) => '\\${m[0]}');

/// Porta di `Spatial2DBoxParser` di PyReceipt: raggruppa i box in righe,
/// cerca le ancore del totale con un punteggio geometrico e verifica
/// l'aritmetica (contanti - resto = totale, subtotale + IVA = totale).
class Spatial2DParser {
  final LangConfig config;
  final double yTol;

  /// true = comportamento identico a PyReceipt (usato dal test di parità).
  /// false = con le correzioni di questa app: le esclusioni dell'intestazione
  /// valgono a parola intera ("tel" non scarta più "HOTEL").
  final bool strict;

  late final RegExp _totalKeyword;
  late final List<String> _taxExclusion;
  late final List<String> _cash;
  late final List<String> _change;
  late final List<String> _subtotal;
  late final RegExp _headerExclusion;
  late final List<RegExp> _datePatterns;

  static const _defaultTotalAnchors = [
    r'[TO0][O0][TAFLI1][A4][LI1]', 'JUMLAH', 'GRAND TOTAL', 'NETT TOTAL', 'NET TOTAL',
    'AMOUNT DUE', 'AMOUNT PAYABLE', 'BALANCE DUE', 'TOTAL ROUNDED', 'TOTAL INCL',
    'TOTAL RM', 'TOTAL AMOUNT', 'TOTAL SALES', 'TOTAL PAYABLE', 'TOTAL BILL',
    'RINGKASAN', 'TOTAL PAID', 'TOTAL PRICE', 'TOTALE COMPLESSIVO', 'TOTALE EURO',
    'TOTALE €', 'TOTALE', 'IMPORTO COMPLESSIVO', 'IMPORTO NETTO', 'IMPORTO',
  ];

  static const _defaultTaxKeywords = [
    'TAX TOTAL', 'GST TOTAL', 'TOTAL TAX', 'TOTAL GST', 'TAX AMOUNT', 'GST AMOUNT',
    'GST (6%)', 'SR @', 'ZR @', 'SR@', 'ZR@', 'GST SUMMARY', 'TAX (RM)', 'TAX INVOICE',
    'GST REG', 'AMOUNT EXCL', 'TOTAL EXCL', 'TOTAL DISCOUNT', 'TOTAL SAVINGS', 'TOTAL SAVING',
    'TOTAL ITEM', 'TOTAL ITEMS', 'TOTAL QTY', 'TOTAL PIECES', 'TOTAL PCS', 'TOTAL UNIT',
    'SUBTOTAL', 'SUB-TOTAL', 'SUB TOTAL', 'SERVICE TAX', 'TAXABLE AMOUNT', 'EXCLUDING GST',
    'EXCL GST', 'AMOUNT (EXCL', 'GSTANALYSIS', 'GST ANALYSIS', 'TAX/AMT', 'TAXABLE',
    'DI CUI IVA', 'IVA', 'IMPOSTA', 'ESENTE IVA',
  ];

  static const _paymentNegative = [
    'CASH', 'TUNAI', 'CHANGE', 'BAKI', 'KEMBALI', 'ROUNDING', 'ROUNDED ADJ',
    'ROUNDING ADJ', 'VISA', 'MASTER', 'CREDIT CARD', 'DEBIT CARD', 'CARD NO',
    'APPROVAL', 'TEL', 'FAX', 'MEMBER', 'POINTS', 'VOUCHER', 'DISCOUNT',
    'CONTANTE', 'RESTO', 'CARTE DI PAGAMENTO', 'PAGAMENTO ELETTRONICO',
  ];

  static const _defaultCash = [
    'CASH', 'TUNAI', 'CASH TENDERED', 'TENDERED', 'BAYAR', 'CASH RECEIVED',
    'PAID', 'TENDER', 'CONTANTE', 'CONTANTI', 'PAGAMENTO CONTANTE', 'PAGAMENTO CONTANTI',
  ];
  static const _defaultChange = [
    'CHANGE', 'BAKI', 'KEMBALI', 'BALANCE RETURN', 'CHANGE DUE', 'RESTO', 'RESTO DOVUTO',
  ];
  static const _defaultSubtotal = [
    'SUBTOTAL', 'SUB-TOTAL', 'SUB TOTAL', 'AMOUNT EXCL', 'TAXABLE', 'SUBTOTALE', 'PARZIALE', 'IMPONIBILE',
  ];

  static final _fallbackDatePatterns = [
    RegExp(r'(\b\d{1,2}[/-]\d{1,2}[/-](?:20\d{2}|19\d{2}|\d{2}))'),
    RegExp(r'(\b(?:20\d{2}|19\d{2})[/-]\d{1,2}[/-]\d{1,2})'),
    RegExp(r'(\b\d{1,2}\s*[-/]?\s*(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s*[-/]?\s*(?:20\d{2}|19\d{2}|\d{2}))',
        caseSensitive: false),
    RegExp(r'(\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+(?:20\d{2}|19\d{2}|\d{2}))',
        caseSensitive: false),
    RegExp(r'(\b\d{1,2}[.]\d{1,2}[.](?:20\d{2}|19\d{2}|\d{2}))'),
    RegExp(r'(\b(?:20\d{2}|19\d{2})[.]\d{1,2}[.]\d{1,2})'),
  ];

  /// Forma societaria in fondo o in mezzo al nome: "CONAD S.R.L.", "OJC SDN BHD".
  static final _legalEntity = RegExp(
    r'(?<![A-Za-z])(S\.?\s?R\.?\s?L\.?S?|S\.?\s?P\.?\s?A\.?|S\.?\s?N\.?\s?C\.?|S\.?\s?A\.?\s?S\.?|SOC\.?\s?COOP|'
    r'S[DN][ND]\.?\s?BHD|BHD|S/B|LTD|LIMITED|INC\.?|GMBH|LLC|PLT)(?![A-Za-z])',
    caseSensitive: false,
  );

  /// Righe che sembrano un indirizzo.
  static final _addressLike = RegExp(
    r'^\s*(VIA|V\.\s?LE|VIALE|CORSO|C\.\s?SO|PIAZZA|P\.\s?ZZA|P\.\s?ZA|LARGO|VICOLO|STRADA|LOC\.|LOCALIT|'
    r'JALAN|JLN|LORONG|LOT\s?\d|NO\.?\s?\d|\d+\s*[,/-])',
    caseSensitive: false,
  );

  static final _pricePattern = RegExp(r"(?:^|[^\d])([0-9]{1,5}\s*[\.,:']\s*[0-9]{2})(?=[^\d]|$)");
  static final _priceHyphenPattern = RegExp(r'(?:^|[^\d])([0-9]{1,5}\s*[-–]\s*[0-9]{2})(?=[^\d]|$)');

  static const _defaultHeaderExclusions = [
    'tax invoice', 'receipt', 'welcome', 'bill', 'tel', 'fax', 'date', 'table',
    'documento commerciale', 'documento di riferimento', 'scontrino fiscale', 'ricevuta fiscale',
    'copia cliente', 'copia esercente', 'emesso per annullamento', 'descrizione', 'prezzo', 'iva',
    'operatore', 'codice fiscale', 'partita iva', 'p.iva', 'p. iva', 'mod. online', 'aut.', 'stan',
    'tml', 'transazione', 'data', 'ora', 'numero', 'cass.', 'grazie', 'arrivederci',
    'n.', 'no.', 'doc.', 'appl.', 'a.id', 'tur', 'iad', 'mod.', 'art.', 'b.c.icc', 'visacredit',
  ];

  Spatial2DParser(this.config, {this.yTol = 0.45, this.strict = false}) {
    final anchors = _dedup([...config.totalAnchors, ..._defaultTotalAnchors]);
    _totalKeyword = RegExp(
      '(?:${anchors.map((a) => a.contains('[') || a.contains(r'\') ? a : _escape(a)).join('|')})',
      caseSensitive: false,
    );
    _taxExclusion = _dedup([...config.taxKeywords, ...config.excludeAnchors, ..._defaultTaxKeywords]);
    _cash = _dedup([...config.cashKeywords, ..._defaultCash]);
    _change = _dedup([...config.changeKeywords, ..._defaultChange]);
    _subtotal = _dedup([...config.subtotalKeywords, ..._defaultSubtotal]);
    final hdr = [...config.headerExclusions, ..._defaultHeaderExclusions];
    String hdrPattern(String h) {
      if (h.contains('[') || h.contains(r'\')) return h;
      final e = _escape(h);
      if (strict) return e;
      // Niente lettere subito prima, né subito dopo se la voce finisce con una lettera.
      final endsWithLetter = RegExp(r'[A-Za-z]$').hasMatch(h);
      return '(?<![A-Za-z])$e${endsWithLetter ? '(?![A-Za-z])' : ''}';
    }

    _headerExclusion = RegExp('(?:${hdr.map(hdrPattern).join('|')})', caseSensitive: false);
    _datePatterns = [for (final p in config.datePatterns) RegExp(p), ..._fallbackDatePatterns];
  }

  static double _cleanPrice(String s) {
    var c = s
        .replaceAll(' ', '')
        .replaceAll(':', '.')
        .replaceAll("'", '.')
        .replaceAll(',', '.')
        .replaceAll('-', '.')
        .replaceAll('–', '.');
    c = c.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(c) ?? 0.0;
  }

  List<List<OcrBox>> _clusterRows(List<OcrBox> boxes) {
    final sorted = [...boxes]
      ..sort((a, b) => a.box[1] != b.box[1] ? a.box[1].compareTo(b.box[1]) : a.box[0].compareTo(b.box[0]));
    final rows = <List<OcrBox>>[];
    for (final b in sorted) {
      final mid = (b.box[1] + b.box[3]) / 2.0;
      final h = math.max(b.box[3] - b.box[1], 10);
      List<OcrBox>? matched;
      for (final row in rows) {
        final rowMid = row.fold(0.0, (s, it) => s + (it.box[1] + it.box[3]) / 2.0) / row.length;
        final rowH = row.fold(0.0, (s, it) => s + it.box[3] - it.box[1]) / row.length;
        final tol = math.max(h.toDouble(), rowH) * yTol;
        if ((mid - rowMid).abs() <= tol) {
          matched = row;
          break;
        }
      }
      if (matched != null) {
        matched.add(b);
      } else {
        rows.add([b]);
      }
    }
    for (final row in rows) {
      row.sort((a, b) => a.box[0].compareTo(b.box[0]));
    }
    // Ordinamento stabile come sorted() di Python.
    final indexed = rows.asMap().entries.toList()
      ..sort((a, b) {
        final c = a.value[0].box[1].compareTo(b.value[0].box[1]);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  List<double> _pricesFromRow(List<OcrBox> row) {
    final prices = <double>[];
    for (final item in row.reversed) {
      var found = [for (final m in _pricePattern.allMatches(item.text)) m.group(1)!];
      if (found.isEmpty) found = [for (final m in _priceHyphenPattern.allMatches(item.text)) m.group(1)!];
      for (final p in found.reversed) {
        final v = _cleanPrice(p);
        if (v > 0 && v < 50000) prices.add(v);
      }
    }
    return prices;
  }

  bool _isTaxRow(String upper) {
    for (final kw in _taxExclusion) {
      if (upper.contains(kw) && !['INCL', 'INCLUSIVE'].any(upper.contains)) return true;
    }
    return false;
  }

  static String _rowText(List<OcrBox> row) => row.map((i) => i.text).join(' ');

  ParsedReceipt parse(List<OcrBox> boxes) {
    if (boxes.isEmpty) return const ParsedReceipt('UNKNOWN', '', 0.0);
    final rows = _clusterRows(boxes);
    final total = rows.length;

    // 1. Esercente: prima riga "pulita" tra le prime 8. Fuori da strict si
    // saltano gli indirizzi e si preferisce una riga con forma societaria.
    var company = 'UNKNOWN';
    String? legalEntity;
    for (final row in rows.take(math.min(8, total))) {
      final text = _rowText(row).trim();
      final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
      if (letters >= 3 && !_headerExclusion.hasMatch(text)) {
        if (!RegExp(r'^[\d\W*]+$').hasMatch(text) &&
            !['TOTAL', 'SUBTOTAL', 'IMPORTO'].any(text.toUpperCase().contains)) {
          if (_pricesFromRow(row).isEmpty) {
            if (strict) {
              company = text;
              break;
            }
            if (_addressLike.hasMatch(text)) continue;
            if (company == 'UNKNOWN') company = text;
            if (_legalEntity.hasMatch(text)) {
              legalEntity = text;
              break;
            }
          }
        }
      }
    }
    // "CASH TIME / DI SHADA SAS": la riga con "di" è il titolare, non il
    // negozio. Si tiene l'insegna, che è quella che l'utente riconosce.
    final ownerLine = legalEntity != null && RegExp(r'^\s*DI\s', caseSensitive: false).hasMatch(legalEntity);
    if (legalEntity != null && !(ownerLine && company != legalEntity)) company = legalEntity;

    // 2. Data: prima vicino a un'ancora "data", poi ovunque.
    var date = '';
    final dateAnchor = RegExp(r'(date|tarikh|time|inv\s*date|dated|dt|data)', caseSensitive: false);
    for (final row in rows) {
      final text = _rowText(row);
      if (dateAnchor.hasMatch(text)) {
        for (final p in _datePatterns) {
          final m = p.firstMatch(text);
          if (m != null) {
            date = m.group(1)!.trim();
            break;
          }
        }
      }
      if (date.isNotEmpty) break;
    }
    if (date.isEmpty) {
      final full = rows.expand((r) => r).map((i) => i.text).join(' ');
      for (final p in _datePatterns) {
        final m = p.firstMatch(full);
        if (m != null) {
          date = m.group(1)!.trim();
          break;
        }
      }
    }

    // 3. Importi di contesto per la verifica aritmetica.
    final cashList = <double>[], changeList = <double>[], subtotalList = <double>[], taxList = <double>[];
    for (final row in rows) {
      final text = _rowText(row).toUpperCase();
      final prices = _pricesFromRow(row);
      if (prices.isEmpty) continue;
      final v = prices[0];
      if (_change.any(text.contains)) {
        changeList.add(v);
      } else if (_cash.any(text.contains) && !['TOTAL', 'SUBTOTAL'].any(text.contains)) {
        cashList.add(v);
      } else if (_subtotal.any(text.contains)) {
        subtotalList.add(v);
      } else if (_taxExclusion.any(text.contains) && !['INCL', 'INCLUSIVE'].any(text.contains)) {
        taxList.add(v);
      }
    }

    // 4. Candidati totale con punteggio geometrico.
    final candidates = <(double, double, String)>[];
    for (var i = 0; i < total; i++) {
      final row = rows[i];
      final text = _rowText(row);
      final upper = text.toUpperCase();
      final relY = i / math.max(total, 1);
      final isTax = _isTaxRow(upper);
      final isAnchor = _totalKeyword.hasMatch(upper);
      final hasNegative = _paymentNegative.any(upper.contains);
      if (!isAnchor || isTax) continue;

      final prices = _pricesFromRow(row);
      if (prices.isNotEmpty) {
        var score = 100.0 + relY * 30.0;
        if (['GRAND TOTAL', 'NETT TOTAL', 'NET TOTAL', 'TOTALE COMPLESSIVO', 'TOTALE EURO'].any(upper.contains)) {
          score += 50;
        }
        if (['ROUNDED', 'TOTAL ROUNDED'].any(upper.contains)) score += 35;
        if (['INCL', 'INCLUSIVE'].any(upper.contains)) score += 25;
        if (['AMOUNT DUE', 'AMOUNT PAYABLE', 'TOTAL PAYABLE', 'TOTALE DOVUTO', 'IMPORTO DOVUTO'].any(upper.contains)) {
          score += 40;
        }
        if (hasNegative) score -= 20;
        candidates.add((score, prices[0], text));
      } else {
        for (final step in [1, 2]) {
          if (i + step < total) {
            final next = rows[i + step];
            final nextPrices = _pricesFromRow(next);
            if (nextPrices.isNotEmpty) {
              candidates.add((85.0 + relY * 10.0 - step * 5.0, nextPrices[0], '$text ${_rowText(next)}'));
              break;
            }
          }
        }
      }
    }

    // 5. Candidati certificati: contanti - resto.
    for (final cash in cashList) {
      for (final change in changeList) {
        final diff = ((cash - change) * 100).round() / 100;
        if (diff > 0 && diff < 50000) candidates.add((250.0, diff, 'ARITHMETIC_CERTIFIED_CASH_MINUS_CHANGE'));
      }
    }

    // 6. Bonus/penalità dalla verifica aritmetica.
    final validated = <(double, double)>[];
    for (final (score, v, _) in candidates) {
      var adj = score;
      for (final cash in cashList) {
        for (final change in changeList) {
          if (((cash - change) - v).abs() < 0.02) adj += 150;
        }
      }
      for (final sub in subtotalList) {
        for (final tax in taxList) {
          if (((sub + tax) - v).abs() < 0.02) adj += 100;
        }
      }
      if (changeList.isNotEmpty &&
          changeList.any((c) => (v - c).abs() < 0.01) &&
          !cashList.any((c) => (v - c).abs() < 0.01)) {
        adj -= 80;
      }
      validated.add((adj, v));
    }

    var totalValue = 0.0;
    if (validated.isNotEmpty) {
      // sort(reverse=True) di Python è stabile: a parità vince il primo.
      var best = validated.first;
      for (final c in validated.skip(1)) {
        if (c.$1 > best.$1) best = c;
      }
      totalValue = best.$2;
    }

    // 7. Fallback: primo prezzo dal basso nella parte inferiore.
    if (totalValue <= 0) {
      for (final row in rows.sublist((total * 0.35).toInt()).reversed) {
        final text = _rowText(row).toUpperCase();
        if (['CASH', 'TUNAI', 'CHANGE', 'BAKI', 'SUBTOTAL', 'TAX', 'GST', 'DISCOUNT'].any(text.contains)) continue;
        final found = _pricesFromRow(row);
        if (found.isNotEmpty) {
          totalValue = found[0];
          break;
        }
      }
    }

    return ParsedReceipt(company, date, totalValue);
  }
}
