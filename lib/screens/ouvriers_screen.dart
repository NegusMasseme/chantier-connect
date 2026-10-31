import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OuvriersScreen extends StatelessWidget {
  const OuvriersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ouvriers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editerOuvrier(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Ajouter'),
      ),
      body: store.ouvriers.isEmpty
          ? const Center(child: EmptyState(icon: Icons.groups_outlined, text: 'Ajoutez vos ouvriers une seule fois,\npuis pointez-les chaque jour.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: store.ouvriers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final o = store.ouvriers[i];
                final solde = store.soldeOuvrier(o.id!);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lavande,
                      child: Text(o.initiales, style: const TextStyle(color: Color(0xFF5B21B6), fontWeight: FontWeight.w700)),
                    ),
                    title: Text(o.nom, style: TextStyle(color: o.actif ? AppColors.encre : AppColors.gris)),
                    subtitle: Text('${o.metier.isEmpty ? 'Métier ?' : o.metier} · ${fcfa(o.tauxJournalier)}/j'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Reste dû', style: TextStyle(fontSize: 11, color: AppColors.gris)),
                        Text(fcfa(solde), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: o.id!))),
                  ),
                );
              },
            ),
    );
  }
}

const metiersCourants = ['Maçon', 'Manœuvre', 'Ferrailleur', 'Coffreur', 'Électricien', 'Plombier', 'Carreleur', 'Peintre', 'Menuisier', 'Soudeur'];

Future<void> editerOuvrier(BuildContext context, {Ouvrier? ouvrier, int? chantierParDefaut}) async {
  final store = StoreScope.read(context);
  final nom = TextEditingController(text: ouvrier?.nom ?? '');
  final tel = TextEditingController(text: ouvrier?.telephone ?? '');
  final metier = TextEditingController(text: ouvrier?.metier ?? '');
  final taux = TextEditingController(text: ouvrier == null || ouvrier.tauxJournalier == 0 ? '' : ouvrier.tauxJournalier.toStringAsFixed(0));
  var actif = ouvrier?.actif ?? true;
  final chantiers = ouvrier == null ? <int>{if (chantierParDefaut != null) chantierParDefaut} : store.chantiersDe(ouvrier.id!);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sheet).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(ouvrier == null ? 'Nouvel ouvrier' : 'Modifier l\'ouvrier', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: nom, autofocus: ouvrier == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom *')),
            const SizedBox(height: 12),
            TextField(controller: tel, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
            const SizedBox(height: 12),
            TextField(controller: metier, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Métier')),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in metiersCourants)
                ActionChip(label: Text(m), onPressed: () => setLocal(() => metier.text = m)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: taux, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Taux journalier (FCFA)')),
            const SizedBox(height: 12),
            if (store.chantiers.isNotEmpty) ...[
              const Text('Chantiers', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in store.chantiers)
                  FilterChip(
                    label: Text(c.nom),
                    selected: chantiers.contains(c.id),
                    labelStyle: TextStyle(color: chantiers.contains(c.id) ? Colors.white : AppColors.aubergine),
                    onSelected: (v) => setLocal(() => v ? chantiers.add(c.id!) : chantiers.remove(c.id)),
                  ),
              ]),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actif'),
              value: actif,
              onChanged: (v) => setLocal(() => actif = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                if (nom.text.trim().isEmpty) return;
                await store.saveOuvrier(
                  Ouvrier(
                    id: ouvrier?.id,
                    nom: nom.text.trim(),
                    telephone: tel.text.trim(),
                    metier: metier.text.trim(),
                    tauxJournalier: double.tryParse(taux.text.replaceAll(' ', '')) ?? 0,
                    actif: actif,
                  ),
                  chantierIds: chantiers,
                );
                if (sheet.mounted) Navigator.pop(sheet);
              },
              child: const Text('Enregistrer'),
            ),
          ]),
        ),
      ),
    ),
  );
}

class OuvrierDetailScreen extends StatelessWidget {
  const OuvrierDetailScreen({super.key, required this.ouvrierId});
  final int ouvrierId;

  Future<void> _paiement(BuildContext context) async {
    final montant = TextEditingController();
    var type = 'avance';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Enregistrer un paiement'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: montant, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant (FCFA)')),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'avance', label: Text('Avance')),
                ButtonSegment(value: 'solde', label: Text('Solde')),
              ],
              selected: {type},
              onSelectionChanged: (s) => setLocal(() => type = s.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    final v = double.tryParse(montant.text.replaceAll(' ', ''));
    if (ok == true && v != null && v > 0 && context.mounted) {
      await StoreScope.read(context).ajouterPaiement(Paiement(ouvrierId: ouvrierId, date: DateTime.now(), montant: v, type: type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final o = store.ouvrier(ouvrierId);
    if (o == null) return const Scaffold(body: Center(child: Text('Ouvrier supprimé')));
    final jours = store.joursTravailles(ouvrierId);
    final now = DateTime.now();
    final debutMois = DateTime(now.year, now.month, 1);
    final joursMois = store.joursTravailles(ouvrierId, du: debutMois, au: now);
    final paiements = store.paiementsDe(ouvrierId);
    final verse = paiements.fold<double>(0, (s, p) => s + p.montant);

    return Scaffold(
      appBar: AppBar(
        title: Text(o.nom),
        actions: [
          IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => editerOuvrier(context, ouvrier: o)),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmer(context, 'Supprimer ${o.nom} ?', 'Ses pointages et paiements seront aussi supprimés.');
              if (ok && context.mounted) {
                await StoreScope.read(context).deleteOuvrier(ouvrierId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${o.metier} · ${fcfa(o.tauxJournalier)} par jour${o.telephone.isNotEmpty ? ' · ${o.telephone}' : ''}',
              style: const TextStyle(color: AppColors.gris)),
          const SizedBox(height: 16),
          Row(children: [
            _Box('Ce mois', '${nombre(joursMois)} j'),
            const SizedBox(width: 8),
            _Box('Total', '${nombre(jours)} j'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _Box('Gagné', fcfa(jours * o.tauxJournalier)),
            const SizedBox(width: 8),
            _Box('Versé', fcfa(verse)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.aubergine, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Expanded(child: Text('Reste à payer', style: TextStyle(color: Color(0xFFDDD6FE), fontWeight: FontWeight.w600))),
              Text(fcfa(store.soldeOuvrier(ouvrierId)), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => _paiement(context), icon: const Icon(Icons.payments_outlined), label: const Text('Enregistrer un paiement')),
          const SectionTitle('Paiements'),
          if (paiements.isEmpty) const Text('Aucun paiement.', style: TextStyle(color: AppColors.gris)),
          for (final p in paiements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined, color: AppColors.violet),
              title: Text(fcfa(p.montant)),
              subtitle: Text('${p.type == 'avance' ? 'Avance' : 'Solde'} · ${dateCourte(p.date)} ${p.date.year}'),
            ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}
