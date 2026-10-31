import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../services/rapport.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chantiers_screen.dart';
import 'mouvement_screen.dart';
import 'note_edit_screen.dart';
import 'ouvriers_screen.dart';
import 'pointage_screen.dart';

class ChantierDetailScreen extends StatelessWidget {
  const ChantierDetailScreen({super.key, required this.chantierId});
  final int chantierId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = store.chantier(chantierId);
    if (c == null) return const Scaffold(body: Center(child: Text('Chantier supprimé')));
    final pct = store.avancement(chantierId);
    final presents = store.presentsAujourdhui(chantierId);
    final equipe = store.ouvriersDe(chantierId).length;
    final alertes = store
        .libellesActifs()
        .where((l) => l.categorie.suiviStock && l.seuilAlerte > 0)
        .where((l) => store.mouvements.any((m) => m.libelleId == l.id && (m.chantierId == chantierId || m.chantierDestId == chantierId)))
        .where((l) => store.stock(l.id!, chantierId: chantierId) < l.seuilAlerte)
        .length;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 230,
              backgroundColor: AppColors.aubergine,
              foregroundColor: Colors.white,
              title: Text(c.nom),
              actions: [
                IconButton(
                  tooltip: 'Rapport du jour (PDF / WhatsApp)',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () => partagerRapportJournalier(context, chantierId),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await editerChantier(context, chantier: c);
                    if (v == 'delete' && context.mounted) {
                      final ok = await confirmer(context, 'Supprimer le chantier ?',
                          'Les tâches et pointages de ce chantier seront supprimés. Les mouvements de stock sont conservés.');
                      if (ok && context.mounted) {
                        await StoreScope.read(context).deleteChantier(chantierId);
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 64, 20, 60),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        [c.statut.label, if (c.client.isNotEmpty) 'Client : ${c.client}', if (c.finPrevue != null) 'fin ${dateCourte(c.finPrevue!)}']
                            .join(' · '),
                        style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        _Stat('$pct %', 'Avancement'),
                        const SizedBox(width: 8),
                        _Stat('$presents/$equipe', 'Présents'),
                        const SizedBox(width: 8),
                        _Stat('$alertes', 'Alertes stock'),
                      ]),
                    ]),
                  ),
                ),
              ),
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFFDDD6FE),
                indicatorColor: Colors.white,
                tabs: [Tab(text: 'Tâches'), Tab(text: 'Journal'), Tab(text: 'Ouvriers'), Tab(text: 'Stock')],
              ),
            ),
          ],
          body: TabBarView(children: [
            _TachesTab(chantierId: chantierId),
            _JournalTab(chantierId: chantierId),
            _OuvriersTab(chantierId: chantierId),
            _StockTab(chantierId: chantierId),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('Pointage'),
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => PointageScreen(chantierId: chantierId))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Matériel'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MouvementScreen(type: TypeMouvement.sortie, chantierId: chantierId))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF5B21B6), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 12)),
          ]),
        ),
      );
}

class _TachesTab extends StatelessWidget {
  const _TachesTab({required this.chantierId});
  final int chantierId;

  Future<void> _ajouter(BuildContext context) async {
    final ctrl = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nouvelle tâche'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ex. Fondations, Toiture…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Ajouter')),
        ],
      ),
    );
    if (nom != null && nom.isNotEmpty && context.mounted) {
      await StoreScope.read(context).saveTache(Tache(chantierId: chantierId, nom: nom));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final taches = store.tachesDe(chantierId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final t in taches)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(t.nom, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(t.avancement >= 100 ? 'Terminé' : '${t.avancement} %',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.avancement >= 100 ? const Color(0xFF15803D) : AppColors.violet)),
                    IconButton(
                      tooltip: 'Supprimer la tâche',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => store.deleteTache(t.id!),
                    ),
                  ]),
                  Slider(
                    value: t.avancement.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${t.avancement} %',
                    onChanged: (v) => store.saveTache(t.copyWith(avancement: v.round())),
                  ),
                ]),
              ),
            ),
          ),
        OutlinedButton.icon(onPressed: () => _ajouter(context), icon: const Icon(Icons.add), label: const Text('Ajouter une tâche')),
      ],
    );
  }
}

class _JournalTab extends StatelessWidget {
  const _JournalTab({required this.chantierId});
  final int chantierId;

  @override
  Widget build(BuildContext context) {
    final notes = StoreScope.of(context).notes.where((n) => n.chantierId == chantierId).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.edit_note),
          label: const Text('Écrire le journal du jour'),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => NoteEditScreen(chantierId: chantierId))),
        ),
        const SizedBox(height: 12),
        if (notes.isEmpty)
          const EmptyState(icon: Icons.menu_book_outlined, text: 'Aucune note liée à ce chantier.'),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                title: Text(n.titre.isNotEmpty ? n.titre : n.contenu, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${quand(n.creeLe)} · ${n.type.label}'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditScreen(note: n))),
              ),
            ),
          ),
      ],
    );
  }
}

class _OuvriersTab extends StatelessWidget {
  const _OuvriersTab({required this.chantierId});
  final int chantierId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final equipe = store.ouvriersDe(chantierId);
    final statuts = store.pointageDu(chantierId, DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (equipe.isEmpty)
          const EmptyState(icon: Icons.groups_outlined, text: 'Aucun ouvrier affecté.\nAffectez-les depuis la fiche ouvrier.'),
        for (final o in equipe)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.lavande, child: Text(o.initiales, style: const TextStyle(color: Color(0xFF5B21B6), fontWeight: FontWeight.w700))),
                title: Text(o.nom),
                subtitle: Text(o.metier),
                trailing: Text(statuts[o.id]?.label ?? 'Non pointé', style: const TextStyle(color: AppColors.gris)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: o.id!))),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => editerOuvrier(context, chantierParDefaut: chantierId),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Ajouter un ouvrier'),
        ),
      ],
    );
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.chantierId});
  final int chantierId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final libs = store
        .libellesActifs()
        .where((l) => l.categorie.suiviStock)
        .where((l) => store.mouvements.any((m) => m.libelleId == l.id && (m.chantierId == chantierId || m.chantierDestId == chantierId)))
        .toList();
    if (libs.isEmpty) {
      return const EmptyState(icon: Icons.inventory_2_outlined, text: 'Aucun matériel enregistré sur ce chantier.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: libs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final l = libs[i];
        final s = store.stock(l.id!, chantierId: chantierId);
        final bas = l.seuilAlerte > 0 && s < l.seuilAlerte;
        return Card(
          child: ListTile(
            leading: Icon(iconeCategorie(l.categorie), color: AppColors.violet),
            title: Text(l.nom),
            trailing: Text('${nombre(s)} ${l.uniteFor(s)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: bas ? const Color(0xFFC2410C) : AppColors.encre)),
          ),
        );
      },
    );
  }
}
