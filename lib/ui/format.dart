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
  // Spesa e cibo
  'cart': Icons.shopping_cart_outlined,
  'grocery': Icons.local_grocery_store_outlined,
  'bakery': Icons.bakery_dining_outlined,
  'restaurant': Icons.restaurant_outlined,
  'pizza': Icons.local_pizza_outlined,
  'coffee': Icons.local_cafe_outlined,
  'drinks': Icons.local_bar_outlined,
  'wine': Icons.wine_bar_outlined,
  // Trasporti
  'car': Icons.directions_car_outlined,
  'fuel': Icons.local_gas_station_outlined,
  'parking': Icons.local_parking_outlined,
  'taxi': Icons.local_taxi_outlined,
  'bus': Icons.directions_bus_outlined,
  'train': Icons.train_outlined,
  'bike': Icons.pedal_bike_outlined,
  'travel': Icons.flight_outlined,
  'hotel': Icons.hotel_outlined,
  'beach': Icons.beach_access_outlined,
  // Casa e bollette
  'home': Icons.home_outlined,
  'bolt': Icons.bolt_outlined,
  'water': Icons.water_drop_outlined,
  'wifi': Icons.wifi_outlined,
  'phone': Icons.smartphone_outlined,
  'furniture': Icons.chair_outlined,
  'repairs': Icons.build_outlined,
  'cleaning': Icons.cleaning_services_outlined,
  'laundry': Icons.local_laundry_service_outlined,
  'garden': Icons.yard_outlined,
  // Salute e cura di sé
  'health': Icons.local_hospital_outlined,
  'pharmacy': Icons.local_pharmacy_outlined,
  'medication': Icons.medication_outlined,
  'insurance': Icons.health_and_safety_outlined,
  'beauty': Icons.spa_outlined,
  'haircut': Icons.content_cut_outlined,
  'sport': Icons.fitness_center_outlined,
  // Acquisti e svago
  'bag': Icons.shopping_bag_outlined,
  'clothes': Icons.checkroom_outlined,
  'electronics': Icons.devices_outlined,
  'movie': Icons.movie_outlined,
  'tv': Icons.tv_outlined,
  'music': Icons.music_note_outlined,
  'games': Icons.sports_esports_outlined,
  'books': Icons.menu_book_outlined,
  'party': Icons.celebration_outlined,
  'smoking': Icons.smoking_rooms_outlined,
  // Famiglia e altro
  'child': Icons.child_friendly_outlined,
  'school': Icons.school_outlined,
  'pets': Icons.pets_outlined,
  'gift': Icons.card_giftcard_outlined,
  'charity': Icons.volunteer_activism_outlined,
  'work': Icons.work_outline,
  'bank': Icons.account_balance_outlined,
  'savings': Icons.savings_outlined,
  'bills': Icons.receipt_long_outlined,
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
