import 'dart:convert';

import 'package:carnet_chantier/data/database.dart';
import 'package:carnet_chantier/data/store.dart';
import 'package:carnet_chantier/models.dart';
import 'package:carnet_chantier/services/gemini.dart';
import 'package:carnet_chantier/services/rapport_donnees.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppStore store;
  late DonneesRapport donnees;
  final jeudi = DateTime(2026, 11, 5, 16);

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('fr_FR');
  });

  setUp(() async {
    store = AppStore(await AppDatabase.open(path: inMemoryDatabasePath));
    await store.load();
    final c = await store.saveChantier(Chantier(nom: 'Villa Agoè', client: 'M. Amouzou'));
    await store.saveOuvrier(Ouvrier(nom: 'Kodjo A', metier: 'Maçon', tauxJournalier: 6000), chantierIds: {c});
    await store.enregistrerPointage(c, jeudi, {store.ouvriers.first.id!: StatutPointage.present});
    await store.saveNote(Note(type: NoteType.pointDuJour, contenu: 'Coulage de la dalle terminé', chantierId: c, creeLe: jeudi));
    donnees = construireRapport(store, periode: PeriodeRapport.jour, reference: jeudi, chantierId: c);
  });

  http.Response reponse(Object corps, [int code = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(corps)), code, headers: {'content-type': 'application/json; charset=utf-8'});

  test('le contexte envoyé à l\'IA contient les données du rapport', () {
    final t = contextePourIA(store, donnees);
    expect(t, contains('Villa Agoè'));
    expect(t, contains('M. Amouzou'));
    expect(t, contains('Coulage de la dalle terminé'));
    expect(t, contains('Kodjo A (Maçon) : Présent'));
    expect(t, contains('rapport journalier'));
  });

  test('lit une réponse JSON, même entourée de ```json', () {
    final cr = lireReponse('```json\n{"resume":"Dalle coulée.","points_attention":["Stock bas"],"prochaines_etapes":"Décoffrage"}\n```');
    expect(cr.resume, 'Dalle coulée.');
    expect(cr.pointsAttention, ['Stock bas']);
    expect(cr.prochainesEtapes, ['Décoffrage']);
  });

  test('appelle generateContent avec la clé et le modèle, et ignore les « pensées »', () async {
    late http.Request envoyee;
    final client = MockClient((req) async {
      envoyee = req;
      return reponse({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'réflexion interne', 'thought': true},
                {'text': '{"resume":"Journée productive : dalle coulée.","travaux":"Coulage de la dalle."}'},
              ]
            }
          }
        ]
      });
    });
    final g = GeminiService(cleApi: 'CLE-TEST', modele: 'gemini-3.8-flash', client: client);
    final cr = await g.redigerCompteRendu(store, donnees);

    expect(envoyee.url.toString(), endsWith('/models/gemini-3.8-flash:generateContent'));
    expect(envoyee.headers['x-goog-api-key'], 'CLE-TEST');
    final corps = jsonDecode(envoyee.body) as Map;
    expect(jsonEncode(corps['contents']), contains('Coulage de la dalle'));
    expect(cr.resume, 'Journée productive : dalle coulée.');
    expect(cr.travaux, 'Coulage de la dalle.');
    expect(cr.modele, 'gemini-3.8-flash');
  });

  test('erreurs traduites en message clair', () async {
    final g = GeminiService(
      cleApi: 'MAUVAISE',
      client: MockClient((_) async => reponse({'error': {'message': 'API key not valid'}}, 400)),
    );
    expect(
      () => g.redigerCompteRendu(store, donnees),
      throwsA(isA<GeminiException>().having((e) => e.message, 'message', contains('Clé API Gemini invalide'))),
    );
    final quota = GeminiService(cleApi: 'X', client: MockClient((_) async => reponse({'error': {}}, 429)));
    expect(() => quota.tester(), throwsA(isA<GeminiException>().having((e) => e.message, 'message', contains('Quota'))));
  });

  test('sans clé, l\'IA n\'est pas configurée ; avec clé, elle l\'est', () async {
    expect(GeminiService.estConfigure(store), isFalse);
    await store.setParametre(ParamIA.cle, 'AIza-test');
    expect(GeminiService.estConfigure(store), isTrue);
    expect(GeminiService.depuisReglages(store)!.modele, modeleGeminiParDefaut);
  });
}
