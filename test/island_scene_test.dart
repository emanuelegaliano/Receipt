import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/data/demo_data.dart';
import 'package:receipt_app/island/catalog.dart';
import 'package:receipt_app/island/island_service.dart';
import 'package:receipt_app/island/pixel.dart';
import 'package:receipt_app/island/rules.dart';
import 'package:receipt_app/island/scene.dart';
import 'package:receipt_app/island/sprites.dart';

int count(Px p, bool Function(int c) test) => p.data.where(test).length;

void main() {
  test('ogni pianta si disegna in ogni mese, con e senza neve, appoggiata a terra', () {
    for (final s in plantCatalog) {
      for (var m = 1; m <= 12; m++) {
        for (final weather in [true, false]) {
          final sprite = plantSprite(s, month: m, seed: 202600 + m, weather: weather);
          final b = sprite.px.bounds();
          expect(b, isNotNull, reason: '${s.key} $m');
          final (x0, _, x1, y1) = b!;
          expect(y1, greaterThanOrEqualTo(sprite.baseY), reason: '${s.key} $m tocca terra');
          expect(x0 <= sprite.baseX && x1 >= sprite.baseX, isTrue, reason: '${s.key} $m');
        }
      }
    }
    for (final k in centerpieces) {
      expect(centerpieceSprite(k).px.bounds(), isNotNull, reason: k);
    }
  });

  test('la stagione cambia le piante: spoglie d\'inverno, mandorlo in fiore a febbraio, neve solo se c\'è il tempo', () {
    int white(Sprite s) => count(s.px, (c) => c == 0xFFF4F8FF);
    final oak = speciesByKey('oak')!;
    final leaves = ramp(0xFF4F7F3A).toSet();
    expect(count(plantSprite(oak, month: 7, seed: 1).px, leaves.contains), greaterThan(300));
    expect(count(plantSprite(oak, month: 1, seed: 1).px, leaves.contains), 0, reason: 'spoglia');
    expect(count(plantSprite(oak, month: 10, seed: 1).px, leaves.contains), 0, reason: 'colori d\'autunno');
    expect(white(plantSprite(oak, month: 1, seed: 1)), greaterThan(0));
    expect(white(plantSprite(oak, month: 1, seed: 1, weather: false)), 0);
    expect(white(plantSprite(oak, month: 7, seed: 1)), 0);
    final almond = speciesByKey('almond')!;
    bool blossom(int c) => c == 0xFFFFF1F4 || c == 0xFFF7C4D2;
    expect(count(plantSprite(almond, month: 2, seed: 1, weather: false).px, blossom), greaterThan(10));
    expect(count(plantSprite(almond, month: 7, seed: 1).px, blossom), 0);
    // Due ulivi piantati in mesi diversi non sono uguali.
    final olive = speciesByKey('olive')!;
    expect(plantSprite(olive, month: 6, seed: 202601).px.data, isNot(plantSprite(olive, month: 6, seed: 202602).px.data));
  });

  test('le isole di ogni stagione, di giorno e di notte', () {
    final keys = plantCatalog.map((s) => s.key).toList();
    for (final night in [false, true]) {
      for (final month in [1, 4, 7, 10]) {
        for (final slots in [3, 12]) {
          final spec = IslandSceneSpec(
            width: 210,
            slots: slots,
            plants: {for (var i = 0; i < slots; i++) i: (keys[(i * 3 + month) % keys.length], 202600 + i)},
            centerpiece: slots == 12 ? 'lighthouse' : null,
            now: DateTime(2026, month, 15, 21),
            night: night,
            seed: 2026,
          );
          final p = renderIsland(spec);
          expect((p.w, p.h), (210, sceneHeight));
          expect(count(p, (c) => c == 0), 0, reason: 'nessun buco trasparente');
          final sky = p.get(5, 2);
          final brightness = ((sky >> 16) & 0xFF) + ((sky >> 8) & 0xFF) + (sky & 0xFF);
          expect(brightness, night ? lessThan(200) : greaterThan(400), reason: 'cielo $month $night');
        }
      }
    }
    // D'inverno il prato è neve.
    final g = IslandGeometry(210, 12);
    final winter = renderIsland(IslandSceneSpec(
        width: 210, slots: 12, plants: const {}, centerpiece: null, now: DateTime(2027, 1, 10), night: false, seed: 1));
    final grass = winter.get(g.cx.round() + 30, g.cy.round());
    expect((grass >> 16) & 0xFF, greaterThan(200));
  });

  test('i posti si toccano dove sono disegnati e non si sovrappongono', () {
    for (final slots in [1, 3, 7, 12]) {
      final g = IslandGeometry(200, slots);
      for (var i = 0; i < slots; i++) {
        final (x, y) = g.slot(i);
        final all = {for (var k = 0; k < slots; k++) k};
        expect(g.slotAt(x, y, among: all), i, reason: 'scegliendo il posto');
        expect(g.slotAt(x + 2, y - 12, among: all), i, reason: 'toccando il "+"');
        // Toccando la pianta vince quella più avanti che copre il punto.
        final hit = g.slotAt(x + 1, y - 20)!;
        expect(g.slot(hit).$2, greaterThanOrEqualTo(y));
        for (var j = 0; j < i; j++) {
          final (ox, oy) = g.slot(j);
          expect((ox - x).abs() > 10 || (oy - y).abs() > 6, isTrue, reason: '$slots: $i e $j');
        }
      }
      expect(g.slotAt(g.cx, g.cy + g.ry * 0.95), isNull, reason: 'davanti al centro il passaggio è libero');
    }
  });

  test('i pixel del disegno sono sempre un numero intero di pixel dello schermo', () {
    for (final (width, dpr) in [(328.0, 2.625), (360.0, 3.0), (411.0, 2.0), (600.0, 1.0), (150.0, 1.0)]) {
      final fit = PixelFit.forWidth(width, dpr);
      final k = fit.scale * dpr;
      expect((k - k.round()).abs(), lessThan(1e-9));
      expect(fit.width, greaterThanOrEqualTo(sceneMinWidth));
      expect(fit.width * fit.scale, greaterThanOrEqualTo(width - 1e-9));
    }
  });

  test('l\'isola di prova riempie il 2025 e i posti liberi del 2026', () async {
    final db = AppDatabase(NativeDatabase.memory(), clock: () => DateTime(2026, 11, 8));
    await IslandService.load(db);
    await db.addPlanting(PlantingsCompanion.insert(month: const Value(202610), plant: 'olive', slot: 1));
    await loadDemoIsland(db);
    final s = await IslandService.load(db);
    expect(s.years.map((y) => y.year), [2025, 2026]);
    expect((s.years.first.complete, s.years.first.rewardEarned, s.years.first.centerpiece), (true, true, 'lighthouse'));
    final y2026 = s.years.last;
    expect(y2026.planted, 10);
    expect(y2026.bySlot[1]!.plant, 'olive', reason: 'la pianta vera resta al suo posto');
    expect(y2026.bySlot.values.map((p) => p.slot).toSet().length, 10);
    await db.close();
  });
}
