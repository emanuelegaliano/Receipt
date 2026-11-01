import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/receipt/categorizer.dart';
import 'package:receipt_app/receipt/date_normalizer.dart';

void main() {
  final now = DateTime(2026, 11, 1);

  group('normalizeReceiptDate', () {
    test('formati giorno/mese/anno', () {
      expect(normalizeReceiptDate('15/01/2019', now: now), DateTime(2019, 1, 15));
      expect(normalizeReceiptDate('25.12.2023', now: now), DateTime(2023, 12, 25));
      expect(normalizeReceiptDate('03-04-24', now: now), DateTime(2024, 4, 3));
      expect(normalizeReceiptDate('2024-11-15', now: now), DateTime(2024, 11, 15));
    });
    test('mese/giorno solo se obbligato', () {
      expect(normalizeReceiptDate('05/26/2016', now: now), DateTime(2016, 5, 26));
      expect(normalizeReceiptDate('05/06/2016', now: now), DateTime(2016, 6, 5));
    });
    test('mesi in lettere', () {
      expect(normalizeReceiptDate('15 Jan 2019', now: now), DateTime(2019, 1, 15));
      expect(normalizeReceiptDate('Mar 3, 2018', now: now), DateTime(2018, 3, 3));
      expect(normalizeReceiptDate('7 ott 2025', now: now), DateTime(2025, 10, 7));
    });
    test('date impossibili o future', () {
      expect(normalizeReceiptDate('31/02/2024', now: now), isNull);
      expect(normalizeReceiptDate('01/01/2030', now: now), isNull);
      expect(normalizeReceiptDate('', now: now), isNull);
    });
  });

  group('esercente', () {
    test('merchantKey toglie forma societaria e numeri', () {
      expect(merchantKey('CONAD SUPERSTORE S.R.L. 0123'), 'CONAD SUPERSTORE');
      expect(merchantKey('OJC MARKETING SDN BHD'), 'OJC MARKETING');
      expect(merchantKey('Caffè Rossi & Figli'), 'CAFFE ROSSI AND FIGLI');
    });
    test('displayMerchant', () {
      expect(displayMerchant('*** SUPERMERCATO MILANO ***'), 'Supermercato Milano');
      expect(displayMerchant('UNKNOWN'), '');
      expect(displayMerchant('ESSELUNGA S.P.A.'), 'Esselunga S.P.A.');
    });
  });

  group('suggestCategory', () {
    final cats = [
      for (var i = 0; i < defaultCategories.length; i++) CategoryKeywords.parse(i + 1, defaultCategories[i].keywords),
    ];
    int idOf(String name) => defaultCategories.indexWhere((c) => c.name == name) + 1;

    test('regola imparata esatta e con errori di OCR', () {
      final rules = {'BAR DA MARIO': idOf('Svago')};
      expect(suggestCategory(merchant: 'Bar da Mario', rules: rules, categories: cats).categoryId, idOf('Svago'));
      final fuzzy = suggestCategory(merchant: 'BAR DA MAR1O', rules: rules, categories: cats);
      expect(fuzzy.categoryId, idOf('Svago'));
      expect(fuzzy.source, SuggestionSource.learned);
    });

    test('parole chiave nel nome', () {
      expect(suggestCategory(merchant: 'FARMACIA CENTRALE', rules: {}, categories: cats).categoryId, idOf('Salute'));
      expect(suggestCategory(merchant: 'Esselunga Spa', rules: {}, categories: cats).categoryId, idOf('Spesa'));
      expect(suggestCategory(merchant: "McDonald's Petronas", rules: {}, categories: cats).categoryId,
          idOf('Ristoranti e bar'));
    });

    test('parole chiave nel corpo se il nome non basta', () {
      final s = suggestCategory(
          merchant: 'Rossi Srl', ocrText: 'ROSSI SRL\nGASOLIO 40,00\nTOTALE 40,00', rules: {}, categories: cats);
      expect(s.categoryId, idOf('Trasporti'));
    });

    test('nessun indizio', () {
      expect(suggestCategory(merchant: 'XYZ', rules: {}, categories: cats).source, SuggestionSource.none);
    });
  });
}
