import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_services.dart';
import '../ui/format.dart';
import '../ui/l10n.dart';
import 'catalog.dart';
import 'island_service.dart';
import 'rules.dart';
import 'scene.dart';

/// L'icona dell'isola nella barra del Riepilogo, con un pallino quando c'è
/// qualcosa da piantare.
class IslandButton extends StatelessWidget {
  const IslandButton({super.key});

  @override
  Widget build(BuildContext context) {
    final island = AppServices.of(context).island;
    return ListenableBuilder(
      listenable: island,
      builder: (context, _) => IconButton(
        tooltip: context.l10n.islandTooltip,
        icon: Badge(isLabelVisible: island.pendingCount > 0, smallSize: 9, child: const Icon(Icons.park_outlined)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IslandScreen())),
      ),
    );
  }
}

String plantName(String key, AppLocalizations l) => switch (key) {
  'oak' => l.plantOak,
  'olive' => l.plantOlive,
  'maple' => l.plantMaple,
  'birch' => l.plantBirch,
  'willow' => l.plantWillow,
  'stonePine' => l.plantStonePine,
  'lemon' => l.plantLemon,
  'orange' => l.plantOrange,
  'apple' => l.plantApple,
  'cherry' => l.plantCherry,
  'almond' => l.plantAlmond,
  'fig' => l.plantFig,
  'fir' => l.plantFir,
  'cypress' => l.plantCypress,
  'datePalm' => l.plantDatePalm,
  'fanPalm' => l.plantFanPalm,
  'lavender' => l.plantLavender,
  'rosemary' => l.plantRosemary,
  'oleander' => l.plantOleander,
  'hydrangea' => l.plantHydrangea,
  'bougainvillea' => l.plantBougainvillea,
  'sunflower' => l.plantSunflower,
  'poppy' => l.plantPoppy,
  'daisy' => l.plantDaisy,
  'tulip' => l.plantTulip,
  'rose' => l.plantRose,
  'iris' => l.plantIris,
  'jasmine' => l.plantJasmine,
  'pricklyPear' => l.plantPricklyPear,
  'agave' => l.plantAgave,
  'aloe' => l.plantAloe,
  'cactus' => l.plantCactus,
  _ => key,
};

String centerpieceName(String key, AppLocalizations l) => switch (key) {
  'lighthouse' => l.centerpieceLighthouse,
  'fountain' => l.centerpieceFountain,
  'temple' => l.centerpieceTemple,
  'statue' => l.centerpieceStatue,
  _ => l.centerpieceObelisk,
};

String _groupName(PlantShape s, AppLocalizations l) => switch (s) {
  PlantShape.tree => l.islandGroupTree,
  PlantShape.fruitTree => l.islandGroupFruitTree,
  PlantShape.conifer => l.islandGroupConifer,
  PlantShape.palm => l.islandGroupPalm,
  PlantShape.shrub => l.islandGroupShrub,
  PlantShape.flower => l.islandGroupFlower,
  PlantShape.succulent => l.islandGroupSucculent,
};

/// "ottobre", "October": il nome del mese, senza anno.
String _monthName(BuildContext context, int month) => DateFormat.MMMM(context.localeTag).format(monthStart(month));

String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Quando fiorisce o fa i frutti, per il catalogo.
String _season(BuildContext context, PlantSpecies s) {
  final l = context.l10n;
  String range((int, int) r) {
    final f = DateFormat.MMMM(context.localeTag);
    final a = f.format(DateTime(2000, r.$1)), b = f.format(DateTime(2000, r.$2));
    return r.$1 == r.$2 ? a : '$a–$b';
  }

  final bloom = monthRange(s.bloom), fruit = monthRange(s.fruit);
  if (bloom != null) return l.islandBlooms(range(bloom));
  if (s.fruit.length == 12) return l.islandFruitsAllYear;
  if (fruit != null) return l.islandFruits(range(fruit));
  return s.deciduous ? l.islandDeciduous : l.islandEvergreen;
}

/// Prima di salvare un limite cambiato dopo il 5: avvisa che per l'isola
/// vale dal mese dopo. false se si annulla.
Future<bool> confirmLimitChangeForIsland(BuildContext context, DateTime now) async {
  if (now.day <= limitChangeDays) return true;
  final l = context.l10n;
  final next = _monthName(context, addMonths(monthKey(now), 1));
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.park_outlined),
      title: Text(l.islandLimitChangeTitle(next)),
      content: Text(l.islandLimitChangeBody(_monthName(context, monthKey(now)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
      ],
    ),
  );
  return ok ?? false;
}

class IslandScreen extends StatefulWidget {
  const IslandScreen({super.key});

  @override
  State<IslandScreen> createState() => _IslandScreenState();
}

class _IslandScreenState extends State<IslandScreen> with SingleTickerProviderStateMixin {
  PageController? _pages;
  int _page = 0;

  /// Mentre si sceglie il posto: il mese e la pianta.
  int? _placingMonth;
  String? _placingPlant;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    // Lo stato può essere di ieri (o del mese scorso): si ricalcola.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppServices.of(context).island.refresh();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pages?.dispose();
    super.dispose();
  }

  Future<void> _choose(IslandState s, int month) async {
    final key = await showPlantPicker(context);
    if (key == null || !mounted) return;
    setState(() {
      _placingMonth = month;
      _placingPlant = key;
    });
    _pulse.repeat(reverse: true);
    final page = s.years.indexWhere((y) => y.year == month ~/ 100);
    if (page >= 0 && page != _page) {
      await _pages?.animateToPage(page, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  void _stopPlacing() {
    _pulse.stop();
    setState(() {
      _placingMonth = null;
      _placingPlant = null;
    });
  }

  Future<void> _tap(IslandState s, IslandYear year, int slot) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final month = _placingMonth, plant = _placingPlant;
    if (month != null && plant != null && month ~/ 100 == year.year) {
      if (year.bySlot.containsKey(slot)) return;
      try {
        await AppServices.of(context).island.plant(month, plant, slot);
      } on PlantingException {
        // Lo stato è cambiato nel frattempo (es. una spesa tolta): si ricomincia.
      }
      if (!mounted) return;
      _stopPlacing();
      messenger.showSnackBar(SnackBar(content: Text(l.islandPlaced(plantName(plant, l)))));
      return;
    }
    final p = year.bySlot[slot];
    if (p == null) return;
    final when = formatMonth(context, monthStart(p.month));
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('${plantName(p.plant, l)} · $when${p.gift ? ' · ${l.islandGiftLabel}' : ''}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final island = AppServices.of(context).island;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: island,
      builder: (context, _) {
        final s = island.state;
        if (s == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (_pages == null) {
          _page = s.years.length - 1;
          _pages = PageController(initialPage: _page);
        }
        _page = _page.clamp(0, s.years.length - 1);
        return Scaffold(
          appBar: AppBar(
            title: Text(l.islandTitle('${s.years[_page].year}')),
            actions: [
              IconButton(
                tooltip: l.islandHowTitle,
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHowItWorks(context),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pages,
            itemCount: s.years.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _IslandPage(
              state: s,
              year: s.years[i],
              placingMonth: _placingMonth,
              placingPlant: _placingPlant,
              pulse: _pulse,
              onChoose: (m) => _choose(s, m),
              onCancelPlacing: _stopPlacing,
              onTapSlot: (slot) => _tap(s, s.years[i], slot),
            ),
          ),
        );
      },
    );
  }
}

class _IslandPage extends StatelessWidget {
  final IslandState state;
  final IslandYear year;
  final int? placingMonth;
  final String? placingPlant;
  final Animation<double> pulse;
  final void Function(int month) onChoose;
  final VoidCallback onCancelPlacing;
  final void Function(int slot) onTapSlot;

  const _IslandPage({
    required this.state,
    required this.year,
    required this.placingMonth,
    required this.placingPlant,
    required this.pulse,
    required this.onChoose,
    required this.onCancelPlacing,
    required this.onTapSlot,
  });

  bool get _placingHere => placingMonth != null && placingMonth! ~/ 100 == year.year;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isCurrentYear = year.year == state.currentMonth ~/ 100;
    final now = AppServices.of(context).db.clock();
    // All'ora: la luna cambia piano, e così il disegno non si rifà a ogni build.
    final drawnAt = DateTime(now.year, now.month, now.day, now.hour);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, box) {
              // Pixel interi sullo schermo: la larghezza del disegno si adatta.
              final fit = PixelFit.forWidth(box.maxWidth, MediaQuery.devicePixelRatioOf(context));
              final spec = IslandSceneSpec(
                width: fit.width,
                slots: year.slots,
                plants: {for (final e in year.bySlot.entries) e.key: (e.value.plant, e.value.month)},
                centerpiece: year.rewardEarned ? year.centerpiece : null,
                now: drawnAt,
                night: Theme.of(context).brightness == Brightness.dark,
                seed: year.year,
              );
              final geometry = IslandGeometry(fit.width, year.slots);
              return GestureDetector(
                onTapUp: (d) {
                  final slot = geometry.slotAt(d.localPosition.dx / fit.scale, d.localPosition.dy / fit.scale,
                      among: _placingHere ? year.freeSlots.toSet() : null);
                  if (slot != null) onTapSlot(slot);
                },
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => CustomPaint(
                    size: Size(box.maxWidth, fit.height),
                    painter: IslandPainter(
                      spec: spec,
                      scale: fit.scale,
                      highlight: _placingHere ? year.freeSlots.toSet() : const {},
                      pulse: _placingHere ? pulse.value : 0,
                      highlightColor: scheme.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (placingMonth != null && placingPlant != null)
          _PlacingCard(plant: placingPlant!, onCancel: onCancelPlacing)
        else if (state.pending.isNotEmpty)
          _PendingCard(state: state, onChoose: onChoose),
        if (isCurrentYear) ...[const SizedBox(height: 12), _CurrentMonthCard(state: state)],
        const SizedBox(height: 12),
        _RewardLine(year: year),
        const SizedBox(height: 8),
        for (final m in year.months.reversed)
          if (m <= state.currentMonth) _MonthTile(state: state, year: year, month: m),
        if (!state.hasLimits && !isCurrentYear) ...[
          const SizedBox(height: 12),
          Text(l.islandNoLimits, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  final IslandState state;
  final void Function(int month) onChoose;
  const _PendingCard({required this.state, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final month = state.pending.first;
    final name = _monthName(context, month);
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.islandPendingCount(state.pending.length),
              style: text.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
            ),
            if (month == state.gift) ...[
              const SizedBox(height: 4),
              Text(l.islandGiftNote(name), style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onChoose(month),
              icon: const Icon(Icons.yard_outlined),
              label: Text(l.islandChoosePlant(name)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacingCard extends StatelessWidget {
  final String plant;
  final VoidCallback onCancel;
  const _PlacingCard({required this.plant, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final species = speciesByKey(plant);
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            if (species != null)
              SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(
                  painter: PlantThumbnailPainter(species, devicePixelRatio: MediaQuery.devicePixelRatioOf(context)),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.islandTapSpot,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer),
              ),
            ),
            TextButton(onPressed: onCancel, child: Text(l.cancel)),
          ],
        ),
      ),
    );
  }
}

class _CurrentMonthCard extends StatelessWidget {
  final IslandState state;
  const _CurrentMonthCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = state.current;
    if (!r.hasLimits) {
      return Card(
        child: ListTile(leading: const Icon(Icons.info_outline), title: Text(l.islandNoLimits)),
      );
    }
    final over = !r.withinLimits;
    final rec = r.recording;
    final String recording;
    if (!rec.noLongGap) {
      recording = l.islandCurrentGap(rec.longestGap, rec.gapAllowed.floor());
    } else {
      recording = l.islandCurrentOk;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.islandCurrentMonth(
                _capitalized(_monthName(context, r.month)),
                formatCents(context, r.spent),
                formatCents(context, r.limit),
              ),
              style: text.titleSmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (r.spent / r.limit).clamp(0, 1).toDouble(),
                minHeight: 8,
                color: over ? scheme.error : scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              over ? l.islandCurrentOver : recording,
              style: text.bodyMedium?.copyWith(color: over || !rec.noLongGap ? scheme.error : scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  final IslandYear year;
  const _RewardLine({required this.year});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final String message;
    if (year.rewardEarned) {
      message = l.islandRewardEarned(centerpieceName(year.centerpiece, l));
    } else if (year.over) {
      message = l.islandRewardMissed(year.needed);
    } else if (year.planted >= year.needed) {
      message = l.islandRewardReady;
    } else {
      message = l.islandRewardProgress(year.planted, year.needed);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          year.rewardEarned ? Icons.emoji_events_outlined : Icons.auto_awesome_outlined,
          size: 20,
          color: scheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(year.complete ? '$message ${l.islandComplete}' : message, style: text.bodyMedium)),
      ],
    );
  }
}

class _MonthTile extends StatelessWidget {
  final IslandState state;
  final IslandYear year;
  final int month;
  const _MonthTile({required this.state, required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final planting = year.plantingOf(month);
    final species = planting == null ? null : speciesByKey(planting.plant);
    final Widget leading;
    final String subtitle;
    if (planting != null) {
      leading = species == null
          ? const Icon(Icons.park_outlined)
          : CustomPaint(
              painter: PlantThumbnailPainter(species, devicePixelRatio: MediaQuery.devicePixelRatioOf(context)),
              size: const Size(40, 40),
            );
      subtitle = '${plantName(planting.plant, l)}${planting.gift ? ' · ${l.islandGiftLabel}' : ''}';
    } else if (month == state.currentMonth) {
      leading = Icon(Icons.hourglass_empty, color: scheme.onSurfaceVariant);
      subtitle = l.islandMonthInProgress;
    } else if (state.pending.contains(month)) {
      leading = Icon(Icons.yard_outlined, color: scheme.primary);
      subtitle = l.islandMonthPending;
    } else {
      leading = Icon(Icons.remove_circle_outline, color: scheme.onSurfaceVariant);
      final r = state.results[month];
      if (r == null || !r.hasLimits) {
        subtitle = l.islandMonthNoLimits;
      } else if (!r.withinLimits) {
        subtitle = l.islandMonthOver(formatCents(context, r.spent), formatCents(context, r.limit));
      } else if (r.recording.records == 0) {
        subtitle = l.islandMonthNoRecords;
      } else if (!r.recording.noLongGap) {
        subtitle = l.islandMonthGap(r.recording.longestGap);
      } else {
        subtitle = l.islandMonthFew(r.recording.records, r.recording.minimum);
      }
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(width: 40, height: 40, child: Center(child: leading)),
      title: Text(_capitalized(_monthName(context, month))),
      subtitle: Text(subtitle),
    );
  }
}

void _showHowItWorks(BuildContext context) {
  final l = context.l10n;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.islandHowTitle, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(l.islandHowBody, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(height: 1.45)),
        ],
      ),
    ),
  );
}

/// Il catalogo: restituisce la chiave della pianta scelta, null se si chiude.
Future<String?> showPlantPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (ctx, controller) => _PlantPicker(controller: controller),
    ),
  );
}

class _PlantPicker extends StatelessWidget {
  final ScrollController controller;
  const _PlantPicker({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          sliver: SliverToBoxAdapter(child: Text(l.islandPickerTitle, style: text.titleLarge)),
        ),
        for (final shape in PlantShape.values) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(_groupName(shape, l), style: text.titleSmall?.copyWith(color: scheme.primary)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
              children: [
                for (final s in plantCatalog.where((s) => s.shape == shape))
                  Material(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, s.key),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            Expanded(
                              child: CustomPaint(
                                painter: PlantThumbnailPainter(
                                  s,
                                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                                ),
                                size: Size.infinite,
                              ),
                            ),
                            Text(
                              plantName(s.key, l),
                              style: text.labelLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _season(context, s),
                              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
