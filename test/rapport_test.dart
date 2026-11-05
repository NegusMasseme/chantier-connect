import 'package:carnet_chantier/data/database.dart';
import 'package:carnet_chantier/data/store.dart';
import 'package:carnet_chantier/models.dart';
import 'package:carnet_chantier/services/rapport_donnees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppStore store;
  late int chantier;
  late int autre;
  late int ciment;
  late int kodjo;

  // Semaine du lundi 2 au dimanche 8 novembre 2026.
  final mardi = DateTime(2026, 11, 3, 9);
  final jeudi = DateTime(2026, 11, 5, 16);
  final semaineSuivante = DateTime(2026, 11, 10, 8);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    store = AppStore(await AppDatabase.open(path: inMemoryDatabasePath));
    await store.load();
    chantier = await store.saveChantier(Chantier(nom: 'Villa Agoè'));
    autre = await store.saveChantier(Chantier(nom: 'Boutique Bè'));
    ciment = store.libelles.firstWhere((l) => l.nom == 'Ciment 50 kg').id!;
    await store.saveOuvrier(Ouvrier(nom: 'Kodjo A', tauxJournalier: 6000), chantierIds: {chantier});
    kodjo = store.ouvriers.first.id!;

    await store.saveNote(Note(type: NoteType.pointDuJour, contenu: 'Coulage dalle', chantierId: chantier, creeLe: mardi));
    await store.saveNote(Note(type: NoteType.idee, contenu: 'Ranger les outils', chantierId: chantier, creeLe: jeudi));
    await store.saveNote(Note(type: NoteType.autre, contenu: 'Note libre', creeLe: jeudi));
    await store.saveNote(Note(type: NoteType.chantier, contenu: 'Autre chantier', chantierId: autre, creeLe: jeudi));
    await store.saveNote(Note(type: NoteType.chantier, contenu: 'Semaine suivante', chantierId: chantier, creeLe: semaineSuivante));
    await store.saveNote(Note(
        type: NoteType.rappel, titre: 'Livraison sable', chantierId: chantier, creeLe: mardi, rappel: DateTime(2026, 11, 10, 9)));

    await store.enregistrerPointage(chantier, mardi, {kodjo: StatutPointage.present});
    await store.enregistrerPointage(chantier, jeudi, {kodjo: StatutPointage.demi});

    await store.ajouterMouvement(Mouvement(libelleId: ciment, type: TypeMouvement.entree, quantite: 50, chantierId: chantier, date: mardi));
    await store.ajouterMouvement(Mouvement(libelleId: ciment, type: TypeMouvement.sortie, quantite: 12, chantierId: chantier, date: jeudi));
    await store.ajouterMouvement(
        Mouvement(libelleId: ciment, type: TypeMouvement.sortie, quantite: 5, chantierId: chantier, date: semaineSuivante));
  });

  test('la semaine va du lundi au dimanche', () {
    final b = bornesPour(PeriodeRapport.semaine, jeudi);
    expect(b.debut, DateTime(2026, 11, 2));
    expect(b.fin, DateTime(2026, 11, 8));
    expect(b.jours.length, 7);
  });

  test('rapport hebdomadaire d\'un chantier', () {
    final d = construireRapport(store, periode: PeriodeRapport.semaine, reference: jeudi, chantierId: chantier);
    expect(d.notes.map((n) => n.contenu), containsAll(['Coulage dalle', 'Ranger les outils']));
    expect(d.notes.any((n) => n.contenu == 'Note libre'), isFalse);
    expect(d.notes.any((n) => n.contenu == 'Semaine suivante'), isFalse);
    expect(d.pointsDuJour.single.contenu, 'Coulage dalle');
    expect(d.notesParJour[DateTime(2026, 11, 3)]!.length, 2);

    final k = d.presences.single;
    expect(k.statuts[1], StatutPointage.present); // mardi
    expect(k.statuts[3], StatutPointage.demi); // jeudi
    expect(k.jours, 1.5);
    expect(d.montantMainOeuvre, 9000);

    final c = d.materiel.single;
    expect(c.entrees, 50);
    expect(c.sorties, 12);
    expect(c.stockFin, 38); // la sortie de la semaine suivante n'est pas comptée

    expect(d.rappelsAVenir.single.titre, 'Livraison sable');
  });

  test('rapport journalier du carnet entier', () {
    final d = construireRapport(store, periode: PeriodeRapport.jour, reference: jeudi);
    expect(d.chantier, isNull);
    expect(d.notes.map((n) => n.contenu), containsAll(['Ranger les outils', 'Note libre', 'Autre chantier']));
    expect(d.notes.length, 3);
    expect(d.presences.single.statuts.single, StatutPointage.demi);
    expect(d.montantMainOeuvre, 3000);
    expect(d.mouvements.single.quantite, 12);
    expect(d.avancementChantiers.length, 2);
  });
}
