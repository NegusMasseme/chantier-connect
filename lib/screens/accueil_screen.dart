import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chantier_detail_screen.dart';
import 'mouvement_screen.dart';
import 'note_edit_screen.dart';
import 'pointage_screen.dart';
import 'reglages_ia_screen.dart';

class AccueilScreen extends StatelessWidget {
  const AccueilScreen({super.key, required this.onGoTo});
  final void Function(int index) onGoTo;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final actifs = store.chantiersActifs;
    final alertes = store.alertesStock();
    final notesJour = store.notesDuJour();
    final aujourdhui = dateLongue(DateTime.now());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/logo/icon.png', width: 44, height: 44, semanticLabel: 'Chantier Connect'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(aujourdhui[0].toUpperCase() + aujourdhui.substring(1),
                    style: const TextStyle(fontSize: 13, color: AppColors.gris)),
                const Text('Chantier Connect', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
            IconButton(
              tooltip: 'IA Gemini (rédaction des rapports)',
              icon: const Icon(Icons.auto_awesome, color: AppColors.violet),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReglagesIAScreen())),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            _Quick(icon: Icons.edit_note, label: 'Note', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteEditScreen()));
            }),
            _Quick(
              icon: Icons.how_to_reg_outlined,
              label: 'Pointage',
              onTap: actifs.isEmpty
                  ? () => onGoTo(2)
                  : () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => PointageScreen(chantierId: actifs.first.id!))),
            ),
            _Quick(
              icon: Icons.south,
              label: 'Entrée',
              bg: const Color(0xFFDCFCE7),
              fg: const Color(0xFF15803D),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MouvementScreen(type: TypeMouvement.entree))),
            ),
            _Quick(
              icon: Icons.north,
              label: 'Sortie',
              bg: const Color(0xFFFEE2E2),
              fg: const Color(0xFFB91C1C),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const MouvementScreen(type: TypeMouvement.sortie))),
            ),
          ]),
          const SizedBox(height: 20),
          if (actifs.isEmpty)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.foundation, color: AppColors.violet),
                title: const Text('Aucun chantier en cours'),
                subtitle: const Text('Créez votre premier chantier pour suivre ouvriers et matériel.'),
                onTap: () => onGoTo(2),
              ),
            )
          else
            for (final c in actifs.take(3)) ...[
              _ChantierCard(chantier: c),
              const SizedBox(height: 12),
            ],
          for (final l in alertes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: const Color(0xFFFFF7ED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFFED7AA)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC2410C)),
                  title: Text('Stock bas : ${l.nom}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${nombre(store.stock(l.id!))} ${l.uniteFor(store.stock(l.id!))} restants · seuil ${nombre(l.seuilAlerte)}'),
                  onTap: () => onGoTo(3),
                ),
              ),
            ),
          SectionTitle('Notes du jour', action: TextButton(onPressed: () => onGoTo(1), child: const Text('Tout voir'))),
          if (notesJour.isEmpty)
            const Text('Rien encore aujourd\'hui. Touchez + pour écrire.', style: TextStyle(color: AppColors.gris))
          else
            for (final n in notesJour.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditScreen(note: n))),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Tag.noteType(n.type), const Spacer(), Text(heure(n.creeLe), style: const TextStyle(fontSize: 12, color: AppColors.gris))]),
                        const SizedBox(height: 6),
                        Text(n.titre.isNotEmpty ? n.titre : n.contenu, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap, this.bg = AppColors.lavande, this.fg = AppColors.violet});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _ChantierCard extends StatelessWidget {
  const _ChantierCard({required this.chantier});
  final Chantier chantier;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pct = store.avancement(chantier.id!);
    final presents = store.presentsAujourdhui(chantier.id!);
    final total = store.ouvriersDe(chantier.id!).length;
    return Material(
      color: AppColors.aubergine,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ChantierDetailScreen(chantierId: chantier.id!))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('CHANTIER ACTIF',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: Color(0xFFDDD6FE))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(999)),
                child: Text(chantier.statut.label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(chantier.nom, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('$presents présent${presents > 1 ? 's' : ''} sur $total aujourd\'hui',
                style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 13)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: ProgressBar(pct, height: 10, track: AppColors.violet, color: const Color(0xFFC4B5FD))),
              const SizedBox(width: 12),
              Text('$pct %', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
      ),
    );
  }
}
