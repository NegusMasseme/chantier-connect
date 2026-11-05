import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../models.dart';
import 'rapport_donnees.dart';

/// Clés des réglages enregistrés dans la table `parametres`.
class ParamIA {
  static const cle = 'gemini_cle';
  static const modele = 'gemini_modele';
}

/// Modèle par défaut (recommandé par Google pour les nouveaux projets en 2026).
const modeleGeminiParDefaut = 'gemini-3.8-flash';

/// Modèles proposés dans les réglages (texte libre accepté aussi).
const modelesGemini = ['gemini-3.8-flash', 'gemini-3.6-flash', 'gemini-3.5-flash-lite'];

/// Clé fournie au moment de la compilation, si on ne veut pas la saisir dans l'app :
/// `flutter build apk --dart-define=GEMINI_API_KEY=xxxx`
const _cleCompilee = String.fromEnvironment('GEMINI_API_KEY');

/// Compte rendu rédigé par l'IA, puis relu et corrigé par l'utilisateur.
class CompteRendu {
  CompteRendu({
    this.resume = '',
    this.travaux = '',
    this.mainOeuvre = '',
    this.materiel = '',
    List<String>? pointsAttention,
    List<String>? prochainesEtapes,
    this.modele = '',
  })  : pointsAttention = pointsAttention ?? [],
        prochainesEtapes = prochainesEtapes ?? [];

  String resume;
  String travaux;
  String mainOeuvre;
  String materiel;
  List<String> pointsAttention;
  List<String> prochainesEtapes;

  /// Modèle Gemini qui a produit le texte.
  String modele;

  bool get estVide =>
      [resume, travaux, mainOeuvre, materiel].every((s) => s.trim().isEmpty) &&
      pointsAttention.isEmpty &&
      prochainesEtapes.isEmpty;

  factory CompteRendu.fromJson(Map<String, dynamic> j, {String modele = ''}) {
    String s(String k) => (j[k] is String) ? (j[k] as String).trim() : '';
    List<String> l(String k) => (j[k] is List)
        ? (j[k] as List).map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
        : (j[k] is String && (j[k] as String).trim().isNotEmpty ? [(j[k] as String).trim()] : <String>[]);
    return CompteRendu(
      resume: s('resume'),
      travaux: s('travaux'),
      mainOeuvre: s('main_oeuvre'),
      materiel: s('materiel'),
      pointsAttention: l('points_attention'),
      prochainesEtapes: l('prochaines_etapes'),
      modele: modele,
    );
  }
}

/// Erreur lisible par un utilisateur non technicien.
class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _consignes = '''
Tu es conducteur de travaux sur des chantiers de construction en Afrique de l'Ouest (montants en FCFA).
À partir UNIQUEMENT des données fournies (notes de terrain, journal, présences, matériel, tâches),
rédige le compte rendu professionnel de la période, en français, clair et factuel.

Règles :
- N'invente aucun fait, chiffre, nom, date ni quantité. Utilise seulement ce qui figure dans les données.
- Si une rubrique n'a aucune donnée, laisse-la vide ("" ou []).
- Phrases courtes, ton neutre et professionnel, sans formules creuses ni emoji.
- Regroupe et reformule les notes au lieu de les recopier ; cite les chiffres utiles (jours-ouvriers, montants, quantités).
- Pour une semaine, fais ressortir l'évolution d'un jour à l'autre.

Réponds UNIQUEMENT avec un objet JSON valide, sans texte autour, de la forme :
{
  "resume": "2 à 4 phrases : l'essentiel de la période",
  "travaux": "travaux réalisés et avancement",
  "main_oeuvre": "effectifs, présences et coût de main-d'œuvre",
  "materiel": "entrées, sorties, consommations et stocks notables",
  "points_attention": ["problème, retard, risque ou stock bas relevé dans les données"],
  "prochaines_etapes": ["action prévue ou rappel à venir mentionné dans les données"]
}
''';

final _nf = NumberFormat.decimalPattern('fr_FR');
String _n(num v) => v == v.roundToDouble() ? _nf.format(v) : NumberFormat('#,##0.##', 'fr_FR').format(v);

/// Texte envoyé à Gemini : toutes les données du rapport, lisibles et compactes.
/// Fonction pure (pas d'accès réseau) : testée à part.
String contextePourIA(AppStore store, DonneesRapport d, {int maxCaracteres = 30000}) {
  final b = StringBuffer();
  final f = DateFormat('EEEE d MMMM y', 'fr_FR');
  b.writeln(d.periode == PeriodeRapport.jour
      ? 'TYPE : rapport journalier du ${f.format(d.bornes.debut)}'
      : 'TYPE : rapport hebdomadaire du ${f.format(d.bornes.debut)} au ${f.format(d.bornes.fin)}');
  if (d.chantier != null) {
    final c = d.chantier!;
    b.writeln('CHANTIER : ${c.nom}${c.client.isNotEmpty ? ' (client : ${c.client})' : ''}'
        '${c.adresse.isNotEmpty ? ', ${c.adresse}' : ''} · statut : ${c.statut.label} · avancement global : ${store.avancement(c.id!)} %');
  } else {
    b.writeln('PÉRIMÈTRE : carnet complet, tous les chantiers et notes libres');
  }

  b.writeln('\nCHIFFRES : ${d.notes.length} notes · ${_n(d.joursOuvriers)} jours-ouvriers · '
      'main-d\'œuvre ${_n(d.montantMainOeuvre.round())} FCFA · ${d.mouvements.length} mouvements de stock');

  if (d.taches.isNotEmpty) {
    b.writeln('\nTÂCHES (avancement actuel) :');
    for (final t in d.taches) {
      b.writeln('- ${t.nom} : ${t.avancement} %');
    }
  }
  if (d.avancementChantiers.isNotEmpty) {
    b.writeln('\nCHANTIERS ACTIFS :');
    for (final e in d.avancementChantiers.entries) {
      b.writeln('- ${e.key.nom} : ${e.value} % (${e.key.statut.label})');
    }
  }

  if (d.presences.isNotEmpty) {
    b.writeln('\nPRÉSENCES :');
    for (final l in d.presences) {
      final detail = d.periode == PeriodeRapport.jour
          ? (l.statuts.first?.label ?? 'non pointé')
          : '${_n(l.jours)} jour(s) sur la semaine';
      b.writeln('- ${l.ouvrier.nom}${l.ouvrier.metier.isNotEmpty ? ' (${l.ouvrier.metier})' : ''} : $detail, '
          '${_n(l.montant.round())} FCFA');
    }
  }

  if (d.materiel.isNotEmpty) {
    b.writeln('\nMATÉRIEL :');
    for (final m in d.materiel) {
      final u = m.libelle.unitePluriel;
      b.writeln('- ${m.libelle.nom} : entrées ${_n(m.entrees)} $u, sorties ${_n(m.sorties)} $u, '
          'transferts ${_n(m.transferts)} $u'
          '${m.stockFin != null ? ', stock en fin de période ${_n(m.stockFin!)} $u' : ''}'
          '${m.stockFin != null && m.libelle.seuilAlerte > 0 && m.stockFin! < m.libelle.seuilAlerte ? ' (SOUS LE SEUIL de ${_n(m.libelle.seuilAlerte)})' : ''}');
    }
  }

  if (d.rappelsAVenir.isNotEmpty) {
    b.writeln('\nRAPPELS À VENIR :');
    for (final n in d.rappelsAVenir) {
      b.writeln('- ${DateFormat('EEEE d MMMM HH:mm', 'fr_FR').format(n.rappel!)} : '
          '${n.titre.isNotEmpty ? n.titre : n.contenu.split('\n').first}');
    }
  }

  b.writeln('\nNOTES ET JOURNAL :');
  if (d.notes.isEmpty) b.writeln('(aucune note)');
  for (final n in d.notes) {
    final ch = d.chantier == null ? store.chantier(n.chantierId)?.nom : null;
    b.writeln('[${DateFormat('EEE d MMM HH:mm', 'fr_FR').format(n.creeLe)} · ${n.type.label}'
        '${ch != null ? ' · $ch' : ''}${n.titre.isNotEmpty ? ' · ${n.titre}' : ''}]');
    if (n.contenu.isNotEmpty) b.writeln(n.contenu.trim());
    final nb = store.photosDe(n.id).length;
    if (nb > 0) b.writeln('($nb photo${nb > 1 ? 's' : ''} jointe${nb > 1 ? 's' : ''})');
  }

  final s = b.toString();
  return s.length <= maxCaracteres ? s : '${s.substring(0, maxCaracteres)}\n[… données tronquées]';
}

/// Extrait l'objet JSON de la réponse (tolère un bloc ```json … ``` autour).
CompteRendu lireReponse(String texte, {String modele = ''}) {
  var t = texte.trim();
  final debut = t.indexOf('{');
  final fin = t.lastIndexOf('}');
  if (debut < 0 || fin <= debut) {
    throw GeminiException('Réponse de l\'IA illisible. Réessayez.');
  }
  t = t.substring(debut, fin + 1);
  try {
    final j = jsonDecode(t);
    if (j is! Map<String, dynamic>) throw const FormatException();
    final cr = CompteRendu.fromJson(j, modele: modele);
    if (cr.estVide) throw GeminiException('L\'IA n\'a rien rédigé. Ajoutez des notes à la période puis réessayez.');
    return cr;
  } on FormatException {
    throw GeminiException('Réponse de l\'IA illisible. Réessayez.');
  }
}

/// Appel à l'API Gemini (generateContent).
class GeminiService {
  GeminiService({required this.cleApi, this.modele = modeleGeminiParDefaut, http.Client? client})
      : _client = client ?? http.Client();

  final String cleApi;
  final String modele;
  final http.Client _client;

  /// Service configuré depuis les réglages (ou la clé de compilation). Null si aucune clé.
  static GeminiService? depuisReglages(AppStore store, {http.Client? client}) {
    final cle = (store.parametre(ParamIA.cle) ?? '').trim();
    final k = cle.isNotEmpty ? cle : _cleCompilee;
    if (k.isEmpty) return null;
    final m = (store.parametre(ParamIA.modele) ?? '').trim();
    return GeminiService(cleApi: k, modele: m.isEmpty ? modeleGeminiParDefaut : m, client: client);
  }

  static bool estConfigure(AppStore store) =>
      (store.parametre(ParamIA.cle) ?? '').trim().isNotEmpty || _cleCompilee.isNotEmpty;

  Uri get _url => Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modele:generateContent');

  Future<String> _appeler(String consignes, String texte, {double temperature = 0.3, bool json = true}) async {
    final corps = {
      'systemInstruction': {
        'parts': [
          {'text': consignes}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': texte}
          ]
        }
      ],
      'generationConfig': {
        'temperature': temperature,
        if (json) 'responseMimeType': 'application/json',
      },
    };
    final http.Response r;
    try {
      r = await _client
          .post(_url,
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': cleApi}, body: jsonEncode(corps))
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw GeminiException('Gemini met trop de temps à répondre. Vérifiez la connexion et réessayez.');
    } on SocketException {
      throw GeminiException('Pas de connexion internet. La rédaction par l\'IA a besoin du réseau.');
    } on http.ClientException {
      throw GeminiException('Pas de connexion internet. La rédaction par l\'IA a besoin du réseau.');
    }

    if (r.statusCode != 200) {
      String detail = '';
      try {
        detail = ((jsonDecode(r.body) as Map)['error'] as Map?)?['message']?.toString() ?? '';
      } catch (_) {}
      throw GeminiException(switch (r.statusCode) {
        400 when detail.toLowerCase().contains('api key') => 'Clé API Gemini invalide. Vérifiez-la dans les réglages IA.',
        401 || 403 => 'Clé API Gemini refusée. Vérifiez-la dans les réglages IA.',
        404 => 'Modèle « $modele » introuvable. Choisissez un autre modèle dans les réglages IA.',
        429 => 'Quota Gemini atteint. Patientez une minute ou vérifiez votre forfait Google AI Studio.',
        >= 500 => 'Service Gemini indisponible pour le moment. Réessayez plus tard.',
        _ => 'Erreur Gemini (${r.statusCode})${detail.isNotEmpty ? ' : $detail' : ''}',
      });
    }

    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final candidats = (j['candidates'] as List?) ?? const [];
    if (candidats.isEmpty) {
      final raison = (j['promptFeedback'] as Map?)?['blockReason'];
      throw GeminiException(raison != null
          ? 'Gemini a refusé de répondre ($raison).'
          : 'Gemini n\'a renvoyé aucune réponse. Réessayez.');
    }
    final parts = (((candidats.first as Map)['content'] as Map?)?['parts'] as List?) ?? const [];
    // On ignore les éventuelles parties de « réflexion » du modèle.
    final texteReponse = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text'] as String? ?? '')
        .join();
    if (texteReponse.trim().isEmpty) throw GeminiException('Gemini n\'a renvoyé aucun texte. Réessayez.');
    return texteReponse;
  }

  /// Rédige le compte rendu d'une période à partir des données du rapport.
  Future<CompteRendu> redigerCompteRendu(AppStore store, DonneesRapport d) async {
    final texte = await _appeler(_consignes, contextePourIA(store, d));
    return lireReponse(texte, modele: modele);
  }

  /// Petit appel pour vérifier la clé et le modèle depuis les réglages.
  Future<void> tester() async {
    await _appeler('Réponds uniquement par le mot OK.', 'Test de connexion.', temperature: 0, json: false);
  }
}
