import 'package:carnet_chantier/data/database.dart';
import 'package:carnet_chantier/data/store.dart';
import 'package:carnet_chantier/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    store = AppStore(db);
    await store.load();
  });

  test('les libellés de départ sont créés', () {
    expect(store.libelles.any((l) => l.nom == 'Ciment 50 kg'), isTrue);
  });

  test('le stock est la somme des mouvements, par chantier et global', () async {
    final a = await store.saveChantier(Chantier(nom: 'A'));
    final b = await store.saveChantier(Chantier(nom: 'B'));
    final ciment = store.libelles.firstWhere((l) => l.nom == 'Ciment 50 kg').id!;

    await store.ajouterMouvement(Mouvement(libelleId: ciment, type: TypeMouvement.entree, quantite: 50, chantierId: a));
    await store.ajouterMouvement(Mouvement(libelleId: ciment, type: TypeMouvement.sortie, quantite: 12, chantierId: a));
    await store.ajouterMouvement(
        Mouvement(libelleId: ciment, type: TypeMouvement.transfert, quantite: 30, chantierId: a, chantierDestId: b));

    expect(store.stock(ciment, chantierId: a), 8);
    expect(store.stock(ciment, chantierId: b), 30);
    expect(store.stock(ciment), 38);
    expect(store.alertesStock().any((l) => l.id == ciment), isFalse); // 38 >= seuil 10
  });

  test('montant dû = jours pointés × taux − paiements', () async {
    final c = await store.saveChantier(Chantier(nom: 'C'));
    await store.saveOuvrier(Ouvrier(nom: 'Kodjo A', tauxJournalier: 6000), chantierIds: {c});
    final o = store.ouvriers.first.id!;
    await store.enregistrerPointage(c, DateTime(2026, 10, 29), {o: StatutPointage.present});
    await store.enregistrerPointage(c, DateTime(2026, 10, 30), {o: StatutPointage.demi});
    // Re-pointer le même jour remplace, ne double pas.
    await store.enregistrerPointage(c, DateTime(2026, 10, 30), {o: StatutPointage.demi});
    await store.ajouterPaiement(Paiement(ouvrierId: o, date: DateTime(2026, 10, 30), montant: 2000));

    expect(store.joursTravailles(o), 1.5);
    expect(store.soldeOuvrier(o), 7000);
  });

  test('avancement pondéré des tâches', () async {
    final c = await store.saveChantier(Chantier(nom: 'D'));
    await store.saveTache(Tache(chantierId: c, nom: 'Fondations', avancement: 100));
    await store.saveTache(Tache(chantierId: c, nom: 'Toiture', avancement: 0));
    expect(store.avancement(c), 50);
  });
}
