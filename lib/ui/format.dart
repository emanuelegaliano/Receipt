import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import 'l10n.dart';

/// Euro nel formato della lingua dell'app: "57,46 €", "€57.46".
String formatCents(BuildContext context, int cents) =>
    NumberFormat.currency(locale: context.localeTag, symbol: '€', decimalDigits: 2).format(cents / 100);

/// "12,50", "12.50", "€ 1.234,56" -> centesimi. null se non è un importo.
int? parseCents(String input) {
  var s = input.replaceAll(RegExp(r'[€\s]'), '');
  if (s.isEmpty) return null;
  if (s.contains(',') && s.contains('.')) {
    // Il separatore più a destra è quello dei decimali.
    s = s.lastIndexOf(',') > s.lastIndexOf('.') ? s.replaceAll('.', '').replaceAll(',', '.') : s.replaceAll(',', '');
  } else {
    s = s.replaceAll(',', '.');
  }
  final v = double.tryParse(s);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}

/// Importo da mettere in un campo di testo, col separatore decimale della lingua.
String centsToInput(BuildContext context, int cents) {
  final s = (cents / 100).toStringAsFixed(2);
  return context.localeTag.startsWith('en') ? s : s.replaceAll('.', ',');
}

String formatMonth(BuildContext context, DateTime m) {
  final s = DateFormat.yMMMM(context.localeTag).format(m);
  return s[0].toUpperCase() + s.substring(1);
}

String formatDay(BuildContext context, DateTime d) {
  final today = DateTime.now();
  final day = DateTime(d.year, d.month, d.day);
  final diff = DateTime(today.year, today.month, today.day).difference(day).inDays;
  if (diff == 0) return context.l10n.today;
  if (diff == 1) return context.l10n.yesterday;
  final locale = context.localeTag;
  final s = (d.year == today.year ? DateFormat.MMMMEEEEd(locale) : DateFormat.yMMMMEEEEd(locale)).format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String formatShortDate(BuildContext context, DateTime d) => DateFormat.yMMMd(context.localeTag).format(d);

/// Icone disponibili per le categorie (chiave salvata nel database).
const categoryIcons = <String, IconData>{
  'cart': Icons.shopping_cart_outlined,
  'restaurant': Icons.restaurant_outlined,
  'coffee': Icons.local_cafe_outlined,
  'car': Icons.directions_car_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'train': Icons.train_outlined,
  'home': Icons.home_outlined,
  'bolt': Icons.bolt_outlined,
  'health': Icons.local_hospital_outlined,
  'bag': Icons.shopping_bag_outlined,
  'movie': Icons.movie_outlined,
  'sport': Icons.fitness_center_outlined,
  'travel': Icons.flight_outlined,
  'pets': Icons.pets_outlined,
  'gift': Icons.card_giftcard_outlined,
  'school': Icons.school_outlined,
  'phone': Icons.smartphone_outlined,
  'child': Icons.child_friendly_outlined,
  'beauty': Icons.spa_outlined,
  'other': Icons.category_outlined,
};

const categoryColors = <int>[
  0xFF2E7D32, 0xFFE65100, 0xFF1565C0, 0xFF6A1B9A, 0xFFC62828, 0xFFAD1457,
  0xFF00838F, 0xFF546E7A, 0xFF827717, 0xFF4E342E, 0xFF283593, 0xFFF9A825,
];

IconData iconOf(Category c) => categoryIcons[c.icon] ?? Icons.category_outlined;

IconData accountIcon(AccountKind k) => switch (k) {
      AccountKind.card => Icons.credit_card,
      AccountKind.cash => Icons.payments_outlined,
      AccountKind.other => Icons.account_balance_wallet_outlined,
    };

/// Pallino colorato con l'icona della categoria.
class CategoryAvatar extends StatelessWidget {
  final Category category;
  final double size;
  const CategoryAvatar(this.category, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = Color(category.color);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: dark ? 0.3 : 0.14), shape: BoxShape.circle),
      child: Icon(iconOf(category), size: size * 0.52, color: dark ? Color.lerp(color, Colors.white, 0.45) : color),
    );
  }
}
