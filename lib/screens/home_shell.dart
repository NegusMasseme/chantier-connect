import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import 'accueil_screen.dart';
import 'chantiers_screen.dart';
import 'mouvement_screen.dart';
import 'note_edit_screen.dart';
import 'notes_screen.dart';
import 'pointage_screen.dart';
import 'stock_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      AccueilScreen(onGoTo: goTo),
      const NotesScreen(),
      const ChantiersScreen(),
      const StockScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvelle saisie',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => ouvrirSaisieRapide(context),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 72,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _NavItem(icon: Icons.home_outlined, active: Icons.home, label: 'Accueil', selected: _index == 0, onTap: () => goTo(0)),
            _NavItem(icon: Icons.sticky_note_2_outlined, active: Icons.sticky_note_2, label: 'Notes', selected: _index == 1, onTap: () => goTo(1)),
            const SizedBox(width: 72),
            _NavItem(icon: Icons.foundation_outlined, active: Icons.foundation, label: 'Chantiers', selected: _index == 2, onTap: () => goTo(2)),
            _NavItem(icon: Icons.inventory_2_outlined, active: Icons.inventory_2, label: 'Stock', selected: _index == 3, onTap: () => goTo(3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.active, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final IconData active;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.violet : const Color(0xFF6B6580);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? active : icon, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille du bouton « + » : les 4 saisies les plus fréquentes.
Future<void> ouvrirSaisieRapide(BuildContext context) async {
  final store = StoreScope.read(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) {
      Widget tile(IconData icon, Color bg, Color fg, String label, VoidCallback onTap) => Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.pop(sheet);
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
                    child: Icon(icon, color: fg, size: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text('Nouvelle saisie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Row(children: [
                tile(Icons.edit_note, AppColors.lavande, AppColors.violet, 'Note', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditScreen()));
                }),
                tile(Icons.how_to_reg_outlined, AppColors.lavande, AppColors.violet, 'Pointage', () {
                  final actifs = store.chantiersActifs;
                  if (actifs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Créez d\'abord un chantier.')),
                    );
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PointageScreen(chantierId: actifs.first.id!)));
                }),
                tile(Icons.south, const Color(0xFFDCFCE7), const Color(0xFF15803D), 'Entrée', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MouvementScreen(type: TypeMouvement.entree)));
                }),
                tile(Icons.north, const Color(0xFFFEE2E2), const Color(0xFFB91C1C), 'Sortie', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MouvementScreen(type: TypeMouvement.sortie)));
                }),
              ]),
            ],
          ),
        ),
      );
    },
  );
}
