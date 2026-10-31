import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chantier_detail_screen.dart';
import 'ouvriers_screen.dart';

class ChantiersScreen extends StatelessWidget {
  const ChantiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chantiers'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OuvriersScreen())),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Ouvriers'),
          ),
          IconButton(tooltip: 'Nouveau chantier', icon: const Icon(Icons.add_circle_outline), onPressed: () => editerChantier(context)),
        ],
      ),
      body: store.chantiers.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.foundation,
                text: 'Aucun chantier pour l\'instant.',
                action: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
                  onPressed: () => editerChantier(context),
                  child: const Text('Créer un chantier'),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: store.chantiers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = store.chantiers[i];
                final pct = store.avancement(c.id!);
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ChantierDetailScreen(chantierId: c.id!))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(c.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                          _StatutPill(c.statut),
                        ]),
                        if (c.client.isNotEmpty || c.adresse.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text([c.client, c.adresse].where((s) => s.isNotEmpty).join(' · '),
                              style: const TextStyle(fontSize: 13, color: AppColors.gris)),
                        ],
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: ProgressBar(pct)),
                          const SizedBox(width: 10),
                          Text('$pct %', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.violet)),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatutPill extends StatelessWidget {
  const _StatutPill(this.statut);
  final StatutChantier statut;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (statut) {
      StatutChantier.preparation => (const Color(0xFFF1F5F9), const Color(0xFF334155)),
      StatutChantier.enCours => (AppColors.lavande, const Color(0xFF5B21B6)),
      StatutChantier.pause => (const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      StatutChantier.termine => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
    };
    return Tag(statut.label, bg: bg, fg: fg);
  }
}

/// Formulaire de création / modification d'un chantier.
Future<void> editerChantier(BuildContext context, {Chantier? chantier}) async {
  final store = StoreScope.read(context);
  final nom = TextEditingController(text: chantier?.nom ?? '');
  final client = TextEditingController(text: chantier?.client ?? '');
  final adresse = TextEditingController(text: chantier?.adresse ?? '');
  final budget = TextEditingController(text: chantier == null || chantier.budget == 0 ? '' : chantier.budget.toStringAsFixed(0));
  var statut = chantier?.statut ?? StatutChantier.enCours;
  DateTime? fin = chantier?.finPrevue;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sheet).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(chantier == null ? 'Nouveau chantier' : 'Modifier le chantier',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: nom, autofocus: chantier == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nom du chantier *')),
            const SizedBox(height: 12),
            TextField(controller: client, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Client')),
            const SizedBox(height: 12),
            TextField(controller: adresse, decoration: const InputDecoration(labelText: 'Adresse / quartier')),
            const SizedBox(height: 12),
            TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget (FCFA)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<StatutChantier>(
              initialValue: statut,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: [for (final s in StatutChantier.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setLocal(() => statut = v ?? statut),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(fin == null ? 'Date de fin prévue' : 'Fin prévue : ${dateCourte(fin!)} ${fin!.year}'),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                    context: sheet, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 10), initialDate: fin ?? now);
                if (d != null) setLocal(() => fin = d);
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                if (nom.text.trim().isEmpty) return;
                await store.saveChantier(Chantier(
                  id: chantier?.id,
                  nom: nom.text.trim(),
                  client: client.text.trim(),
                  adresse: adresse.text.trim(),
                  debut: chantier?.debut ?? DateTime.now(),
                  finPrevue: fin,
                  budget: double.tryParse(budget.text.replaceAll(' ', '')) ?? 0,
                  statut: statut,
                ));
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
