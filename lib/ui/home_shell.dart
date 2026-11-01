import 'package:flutter/material.dart';

import 'categories_screen.dart';
import 'dashboard_screen.dart';
import 'expense_form_screen.dart';
import 'expenses_screen.dart';
import 'l10n.dart';
import 'scan_flow.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _openAddSheet() {
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddOption(
                icon: Icons.photo_camera_outlined,
                title: l.addScanTitle,
                subtitle: l.addScanSubtitle,
                onTap: () {
                  Navigator.pop(ctx);
                  startScan(context, fromCamera: true);
                },
              ),
              _AddOption(
                icon: Icons.photo_library_outlined,
                title: l.addGalleryTitle,
                subtitle: l.addGallerySubtitle,
                onTap: () {
                  Navigator.pop(ctx);
                  startScan(context, fromCamera: false);
                },
              ),
              _AddOption(
                icon: Icons.edit_outlined,
                title: l.addManualTitle,
                subtitle: l.addManualSubtitle,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(onSeeAll: () => setState(() => _tab = 1)),
          const ExpensesScreen(),
          const CategoriesScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: Text(l.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline), selectedIcon: const Icon(Icons.pie_chart), label: l.navSummary),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: l.navTransactions),
          NavigationDestination(
              icon: const Icon(Icons.category_outlined), selectedIcon: const Icon(Icons.category), label: l.navCategories),
        ],
      ),
    );
  }
}

class _AddOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AddOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
