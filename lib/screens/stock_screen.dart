import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'libelles_screen.dart';
import 'mouvement_screen.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  int? _chantierId; // null = stock global
  bool _historique = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibellesScreen())),
            icon: const Icon(Icons.label_outline),
            label: const Text('Libellés'),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DropdownButtonFormField<int?>(
            initialValue: _chantierId,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.foundation, color: AppColors.violet), isDense: true, fillColor: AppColors.lavandePale),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tous les chantiers (global)')),
              for (final c in store.chantiers) DropdownMenuItem<int?>(value: c.id, child: Text(c.nom)),
            ],
            onChanged: (v) => setState(() => _chantierId = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Disponible')),
              ButtonSegment(value: true, label: Text('Historique')),
            ],
            selected: {_historique},
            onSelectionChanged: (s) => setState(() => _historique = s.first),
          ),
        ),
        Expanded(child: _historique ? _Historique(chantierId: _chantierId) : _Disponible(chantierId: _chantierId)),
      ]),
    );
  }
}

class _Disponible extends StatelessWidget {
  const _Disponible({required this.chantierId});
  final int? chantierId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final libs = store
        .libellesActifs()
        .where((l) => l.categorie.suiviStock)
        .where((l) => store.mouvements.any((m) =>
            m.libelleId == l.id && (chantierId == null || m.chantierId == chantierId || m.chantierDestId == chantierId)))
        .toList();
    if (libs.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.inventory_2_outlined,
          text: 'Aucun mouvement de stock.\nCommencez par une entrée de matériel.',
          action: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            icon: const Icon(Icons.south),
            label: const Text('Entrée de stock'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MouvementScreen(type: TypeMouvement.entree, chantierId: chantierId))),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: libs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final l = libs[i];
        final s = store.stock(l.id!, chantierId: chantierId);
        final bas = l.seuilAlerte > 0 && s < l.seuilAlerte;
        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.lavande, borderRadius: BorderRadius.circular(12)),
              child: Icon(iconeCategorie(l.categorie), color: AppColors.violet),
            ),
            title: Text(l.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: bas
                ? Text('Sous le seuil (${nombre(l.seuilAlerte)})', style: const TextStyle(color: Color(0xFFC2410C)))
                : null,
            trailing: Text('${nombre(s)} ${l.uniteFor(s)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: bas ? const Color(0xFFC2410C) : AppColors.encre)),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => MouvementScreen(type: TypeMouvement.sortie, chantierId: chantierId))),
          ),
        );
      },
    );
  }
}

class _Historique extends StatelessWidget {
  const _Historique({required this.chantierId});
  final int? chantierId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final mvts = store.mouvements
        .where((m) => chantierId == null || m.chantierId == chantierId || m.chantierDestId == chantierId)
        .toList();
    if (mvts.isEmpty) {
      return const Center(child: EmptyState(icon: Icons.history, text: 'Aucun mouvement.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: mvts.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.bordure),
      itemBuilder: (context, i) {
        final m = mvts[i];
        final l = store.libelle(m.libelleId);
        final c = store.chantier(m.chantierId);
        final dest = store.chantier(m.chantierDestId);
        final signe = switch (m.type) {
          TypeMouvement.entree => '+',
          TypeMouvement.sortie => '−',
          TypeMouvement.transfert => '⇄',
        };
        return Dismissible(
          key: ValueKey('mvt-${m.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: const Color(0xFFFEE2E2),
            child: const Icon(Icons.delete_outline, color: AppColors.rouge),
          ),
          confirmDismiss: (_) => confirmer(context, 'Supprimer ce mouvement ?', 'Le stock sera recalculé.'),
          onDismissed: (_) => store.supprimerMouvement(m.id!),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: CircleAvatar(
              backgroundColor: couleurMouvement(m.type).withValues(alpha: 0.12),
              child: Text(signe, style: TextStyle(color: couleurMouvement(m.type), fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            title: Text('${nombre(m.quantite)} ${l?.uniteFor(m.quantite) ?? ''} · ${l?.nom ?? 'Libellé supprimé'}'),
            subtitle: Text([
              '${m.type.label} ${quand(m.date)}',
              if (c != null) c.nom,
              if (dest != null) '→ ${dest.nom}',
              if (m.fournisseur.isNotEmpty) m.fournisseur,
              if (m.commentaire.isNotEmpty) m.commentaire,
            ].join(' · ')),
          ),
        );
      },
    );
  }
}
