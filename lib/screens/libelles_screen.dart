import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Catalogue des libellés : on les crée une fois, ensuite on les choisit.
class LibellesScreen extends StatelessWidget {
  const LibellesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Libellés')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editerLibelle(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau libellé'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          for (final cat in CategorieLibelle.values) ...[
            SectionTitle(cat.label),
            for (final l in store.libellesActifs(categorie: cat))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Icon(iconeCategorie(cat), color: AppColors.violet),
                    title: Text(l.nom),
                    subtitle: Text([
                      'Unité : ${l.unite}',
                      if (l.seuilAlerte > 0) 'seuil ${nombre(l.seuilAlerte)}',
                      if (l.prixUnitaire > 0) fcfa(l.prixUnitaire),
                    ].join(' · ')),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: l.favori ? 'Retirer des favoris' : 'Mettre en favori',
                        icon: Icon(l.favori ? Icons.star : Icons.star_border, color: l.favori ? AppColors.violet : AppColors.gris),
                        onPressed: () => store.saveLibelle(_copie(l, favori: !l.favori)),
                      ),
                      IconButton(
                        tooltip: 'Retirer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final utilise = store.libelleUtilise(l.id!);
                          final ok = await confirmer(
                            context,
                            'Retirer « ${l.nom} » ?',
                            utilise
                                ? 'Ce libellé a déjà des mouvements : il sera archivé (l\'historique reste intact).'
                                : 'Ce libellé n\'a jamais servi : il sera supprimé.',
                          );
                          if (ok) await store.retirerLibelle(l);
                        },
                      ),
                    ]),
                    onTap: () => editerLibelle(context, libelle: l),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Libelle _copie(Libelle l, {bool? favori}) => Libelle(
      id: l.id,
      nom: l.nom,
      categorie: l.categorie,
      unite: l.unite,
      unitePluriel: l.unitePluriel,
      prixUnitaire: l.prixUnitaire,
      seuilAlerte: l.seuilAlerte,
      favori: favori ?? l.favori,
      archive: l.archive,
    );

/// Crée ou modifie un libellé. Retourne son id (null si annulé).
Future<int?> editerLibelle(BuildContext context, {Libelle? libelle, CategorieLibelle? categorie, String nomInitial = ''}) async {
  final store = StoreScope.read(context);
  final nom = TextEditingController(text: libelle?.nom ?? nomInitial);
  final unite = TextEditingController(text: libelle?.unite ?? '');
  final pluriel = TextEditingController(text: libelle?.unitePluriel ?? '');
  final prix = TextEditingController(text: libelle == null || libelle.prixUnitaire == 0 ? '' : libelle.prixUnitaire.toStringAsFixed(0));
  final seuil = TextEditingController(
      text: libelle == null || libelle.seuilAlerte == 0 ? '' : libelle.seuilAlerte.toStringAsFixed(libelle.seuilAlerte % 1 == 0 ? 0 : 2));
  var cat = libelle?.categorie ?? categorie ?? CategorieLibelle.materiaux;
  var favori = libelle?.favori ?? false;
  int? id;

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
            Text(libelle == null ? 'Nouveau libellé' : 'Modifier le libellé', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in CategorieLibelle.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: cat == c,
                  showCheckmark: false,
                  labelStyle: TextStyle(color: cat == c ? Colors.white : AppColors.aubergine, fontWeight: FontWeight.w600),
                  onSelected: (_) => setLocal(() => cat = c),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: nom, autofocus: libelle == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nom *  (ex. Ciment 50 kg)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: unite, decoration: const InputDecoration(labelText: 'Unité * (sac, m³, jour…)'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: pluriel, decoration: const InputDecoration(labelText: 'Pluriel (sacs…)'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: prix, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix unitaire (FCFA)'))),
              const SizedBox(width: 10),
              if (cat.suiviStock)
                Expanded(child: TextField(controller: seuil, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Seuil d\'alerte'))),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Favori (affiché en premier)'),
              value: favori,
              onChanged: (v) => setLocal(() => favori = v),
            ),
            FilledButton(
              onPressed: () async {
                if (nom.text.trim().isEmpty || unite.text.trim().isEmpty) return;
                id = await store.saveLibelle(Libelle(
                  id: libelle?.id,
                  nom: nom.text.trim(),
                  categorie: cat,
                  unite: unite.text.trim(),
                  unitePluriel: pluriel.text.trim().isEmpty ? null : pluriel.text.trim(),
                  prixUnitaire: double.tryParse(prix.text.replaceAll(' ', '')) ?? 0,
                  seuilAlerte: cat.suiviStock ? double.tryParse(seuil.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0 : 0,
                  favori: favori,
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
  return id;
}
