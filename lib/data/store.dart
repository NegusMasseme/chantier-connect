import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';

/// État de l'application : charge tout en mémoire (volumes faibles)
/// et écrit chaque changement dans SQLite.
class AppStore extends ChangeNotifier {
  AppStore(this._db);
  final Database _db;

  List<Note> notes = [];
  List<Chantier> chantiers = [];
  List<Tache> taches = [];
  List<Ouvrier> ouvriers = [];
  List<Pointage> pointages = [];
  List<Paiement> paiements = [];
  List<Libelle> libelles = [];
  List<Mouvement> mouvements = [];
  List<NotePhoto> photos = [];
  final Map<String, String> _parametres = {};
  final Map<int, Set<int>> _affectations = {}; // chantierId -> ouvrierIds

  Future<void> load() async {
    notes = (await _db.query('notes', orderBy: 'epinglee DESC, modifie_le DESC')).map(Note.fromMap).toList();
    chantiers = (await _db.query('chantiers', orderBy: 'id DESC')).map(Chantier.fromMap).toList();
    taches = (await _db.query('taches', orderBy: 'id')).map(Tache.fromMap).toList();
    ouvriers = (await _db.query('ouvriers', orderBy: 'nom COLLATE NOCASE')).map(Ouvrier.fromMap).toList();
    pointages = (await _db.query('pointages')).map(Pointage.fromMap).toList();
    paiements = (await _db.query('paiements', orderBy: 'date DESC')).map(Paiement.fromMap).toList();
    libelles = (await _db.query('libelles', orderBy: 'favori DESC, nom COLLATE NOCASE')).map(Libelle.fromMap).toList();
    mouvements = (await _db.query('mouvements', orderBy: 'date DESC')).map(Mouvement.fromMap).toList();
    photos = (await _db.query('note_photos', orderBy: 'id')).map(NotePhoto.fromMap).toList();
    _parametres
      ..clear()
      ..addEntries((await _db.query('parametres')).map((r) => MapEntry(r['cle'] as String, (r['valeur'] as String?) ?? '')));
    _affectations.clear();
    for (final r in await _db.query('affectations')) {
      _affectations.putIfAbsent(r['chantier_id'] as int, () => {}).add(r['ouvrier_id'] as int);
    }
    notifyListeners();
  }

  // ---------- Paramètres ----------

  String? parametre(String cle) => _parametres[cle];

  Future<void> setParametre(String cle, String? valeur) async {
    if (valeur == null || valeur.isEmpty) {
      await _db.delete('parametres', where: 'cle = ?', whereArgs: [cle]);
      _parametres.remove(cle);
    } else {
      await _db.insert('parametres', {'cle': cle, 'valeur': valeur}, conflictAlgorithm: ConflictAlgorithm.replace);
      _parametres[cle] = valeur;
    }
    notifyListeners();
  }

  // ---------- Notes ----------

  /// Enregistre la note et retourne son id.
  Future<int> saveNote(Note n) async {
    final map = n.toMap()..['modifie_le'] = DateTime.now().toIso8601String();
    int id;
    if (n.id == null) {
      map.remove('id');
      id = await _db.insert('notes', map);
    } else {
      id = n.id!;
      await _db.update('notes', map, where: 'id = ?', whereArgs: [id]);
    }
    await _reloadNotes();
    return id;
  }

  Future<void> deleteNote(int id) async {
    for (final p in photosDe(id)) {
      await _supprimerFichier(p.chemin);
    }
    await _db.delete('notes', where: 'id = ?', whereArgs: [id]);
    photos.removeWhere((p) => p.noteId == id);
    await _reloadNotes();
  }

  // ---------- Photos des notes ----------

  List<NotePhoto> photosDe(int? noteId) => noteId == null ? [] : photos.where((p) => p.noteId == noteId).toList();

  Future<void> ajouterPhotos(int noteId, List<String> chemins) async {
    if (chemins.isEmpty) return;
    final b = _db.batch();
    for (final c in chemins) {
      b.insert('note_photos', NotePhoto(noteId: noteId, chemin: c).toMap()..remove('id'));
    }
    await b.commit(noResult: true);
    photos = (await _db.query('note_photos', orderBy: 'id')).map(NotePhoto.fromMap).toList();
    notifyListeners();
  }

  Future<void> supprimerPhoto(NotePhoto p) async {
    await _db.delete('note_photos', where: 'id = ?', whereArgs: [p.id]);
    await _supprimerFichier(p.chemin);
    photos.removeWhere((x) => x.id == p.id);
    notifyListeners();
  }

  Future<void> _supprimerFichier(String chemin) async {
    try {
      final f = File(chemin);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Fichier déjà absent : rien à faire.
    }
  }

  Future<int> togglePin(Note n) => saveNote(Note(
        id: n.id,
        type: n.type,
        titre: n.titre,
        contenu: n.contenu,
        chantierId: n.chantierId,
        epinglee: !n.epinglee,
        rappel: n.rappel,
        creeLe: n.creeLe,
      ));

  Future<void> _reloadNotes() async {
    notes = (await _db.query('notes', orderBy: 'epinglee DESC, modifie_le DESC')).map(Note.fromMap).toList();
    notifyListeners();
  }

  List<Note> notesDuJour() {
    final k = dayKey(DateTime.now());
    return notes.where((n) => dayKey(n.creeLe) == k || dayKey(n.modifieLe) == k).toList();
  }

  // ---------- Chantiers & tâches ----------

  Chantier? chantier(int? id) => id == null ? null : chantiers.where((c) => c.id == id).firstOrNull;

  List<Chantier> get chantiersActifs =>
      chantiers.where((c) => c.statut == StatutChantier.enCours || c.statut == StatutChantier.preparation).toList();

  Future<int> saveChantier(Chantier c) async {
    int id;
    if (c.id == null) {
      final map = c.toMap()..remove('id');
      id = await _db.insert('chantiers', map);
    } else {
      id = c.id!;
      await _db.update('chantiers', c.toMap(), where: 'id = ?', whereArgs: [id]);
    }
    await load();
    return id;
  }

  Future<void> deleteChantier(int id) async {
    await _db.delete('chantiers', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  List<Tache> tachesDe(int chantierId) => taches.where((t) => t.chantierId == chantierId).toList();

  Future<void> saveTache(Tache t) async {
    if (t.id == null) {
      await _db.insert('taches', t.toMap()..remove('id'));
    } else {
      await _db.update('taches', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
    }
    taches = (await _db.query('taches', orderBy: 'id')).map(Tache.fromMap).toList();
    notifyListeners();
  }

  Future<void> deleteTache(int id) async {
    await _db.delete('taches', where: 'id = ?', whereArgs: [id]);
    taches.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Avancement = moyenne des tâches pondérée par leur poids (0..100).
  int avancement(int chantierId) {
    final ts = tachesDe(chantierId);
    final totalPoids = ts.fold<int>(0, (s, t) => s + t.poids);
    if (totalPoids == 0) return 0;
    final v = ts.fold<int>(0, (s, t) => s + t.avancement * t.poids) / totalPoids;
    return v.round();
  }

  // ---------- Ouvriers, affectations, pointage, paiements ----------

  Ouvrier? ouvrier(int? id) => id == null ? null : ouvriers.where((o) => o.id == id).firstOrNull;

  Future<void> saveOuvrier(Ouvrier o, {Set<int>? chantierIds}) async {
    int id;
    if (o.id == null) {
      id = await _db.insert('ouvriers', o.toMap()..remove('id'));
    } else {
      id = o.id!;
      await _db.update('ouvriers', o.toMap(), where: 'id = ?', whereArgs: [id]);
    }
    if (chantierIds != null) {
      await _db.delete('affectations', where: 'ouvrier_id = ?', whereArgs: [id]);
      for (final c in chantierIds) {
        await _db.insert('affectations', {'chantier_id': c, 'ouvrier_id': id});
      }
    }
    await load();
  }

  Future<void> deleteOuvrier(int id) async {
    await _db.delete('ouvriers', where: 'id = ?', whereArgs: [id]);
    await load();
  }

  Set<int> chantiersDe(int ouvrierId) =>
      {for (final e in _affectations.entries) if (e.value.contains(ouvrierId)) e.key};

  List<Ouvrier> ouvriersDe(int chantierId) {
    final ids = _affectations[chantierId] ?? {};
    return ouvriers.where((o) => o.actif && ids.contains(o.id)).toList();
  }

  Map<int, StatutPointage> pointageDu(int chantierId, DateTime jour) {
    final k = dayKey(jour);
    return {
      for (final p in pointages)
        if (p.chantierId == chantierId && dayKey(p.jour) == k) p.ouvrierId: p.statut,
    };
  }

  Future<void> enregistrerPointage(int chantierId, DateTime jour, Map<int, StatutPointage> statuts) async {
    final k = dayKey(jour);
    final b = _db.batch();
    statuts.forEach((ouvrierId, statut) {
      b.insert(
        'pointages',
        {'ouvrier_id': ouvrierId, 'chantier_id': chantierId, 'jour': k, 'statut': statut.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await b.commit(noResult: true);
    pointages = (await _db.query('pointages')).map(Pointage.fromMap).toList();
    notifyListeners();
  }

  int presentsAujourdhui(int chantierId) => pointageDu(chantierId, DateTime.now())
      .values
      .where((s) => s != StatutPointage.absent)
      .length;

  double joursTravailles(int ouvrierId, {DateTime? du, DateTime? au}) {
    return pointages
        .where((p) =>
            p.ouvrierId == ouvrierId &&
            (du == null || !p.jour.isBefore(DateTime(du.year, du.month, du.day))) &&
            (au == null || !p.jour.isAfter(DateTime(au.year, au.month, au.day))))
        .fold<double>(0, (s, p) => s + p.statut.fraction);
  }

  List<Paiement> paiementsDe(int ouvrierId) => paiements.where((p) => p.ouvrierId == ouvrierId).toList();

  /// Montant dû = jours pointés × taux journalier − paiements versés.
  double soldeOuvrier(int ouvrierId) {
    final o = ouvrier(ouvrierId);
    if (o == null) return 0;
    final du = joursTravailles(ouvrierId) * o.tauxJournalier;
    final verse = paiementsDe(ouvrierId).fold<double>(0, (s, p) => s + p.montant);
    return du - verse;
  }

  Future<void> ajouterPaiement(Paiement p) async {
    await _db.insert('paiements', p.toMap()..remove('id'));
    paiements = (await _db.query('paiements', orderBy: 'date DESC')).map(Paiement.fromMap).toList();
    notifyListeners();
  }

  // ---------- Libellés & stock ----------

  Libelle? libelle(int? id) => id == null ? null : libelles.where((l) => l.id == id).firstOrNull;

  List<Libelle> libellesActifs({CategorieLibelle? categorie, String recherche = ''}) {
    final q = recherche.trim().toLowerCase();
    return libelles
        .where((l) => !l.archive)
        .where((l) => categorie == null || l.categorie == categorie)
        .where((l) => q.isEmpty || l.nom.toLowerCase().contains(q))
        .toList();
  }

  Future<int> saveLibelle(Libelle l) async {
    int id;
    if (l.id == null) {
      id = await _db.insert('libelles', l.toMap()..remove('id'));
    } else {
      id = l.id!;
      await _db.update('libelles', l.toMap(), where: 'id = ?', whereArgs: [id]);
    }
    libelles = (await _db.query('libelles', orderBy: 'favori DESC, nom COLLATE NOCASE')).map(Libelle.fromMap).toList();
    notifyListeners();
    return id;
  }

  bool libelleUtilise(int id) => mouvements.any((m) => m.libelleId == id);

  /// Supprime si jamais utilisé, sinon archive.
  Future<void> retirerLibelle(Libelle l) async {
    if (libelleUtilise(l.id!)) {
      await saveLibelle(Libelle(
        id: l.id,
        nom: l.nom,
        categorie: l.categorie,
        unite: l.unite,
        unitePluriel: l.unitePluriel,
        prixUnitaire: l.prixUnitaire,
        seuilAlerte: l.seuilAlerte,
        favori: l.favori,
        archive: true,
      ));
    } else {
      await _db.delete('libelles', where: 'id = ?', whereArgs: [l.id]);
      libelles.removeWhere((x) => x.id == l.id);
      notifyListeners();
    }
  }

  Future<int> ajouterMouvement(Mouvement m) async {
    final id = await _db.insert('mouvements', m.toMap()..remove('id'));
    mouvements = (await _db.query('mouvements', orderBy: 'date DESC')).map(Mouvement.fromMap).toList();
    notifyListeners();
    return id;
  }

  Future<void> supprimerMouvement(int id) async {
    await _db.delete('mouvements', where: 'id = ?', whereArgs: [id]);
    mouvements.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  /// Stock = somme des mouvements (jamais saisi directement).
  /// Sans [chantierId] : stock global (les transferts s'annulent).
  double stock(int libelleId, {int? chantierId}) => stockAu(libelleId, null, chantierId: chantierId);

  /// Stock tel qu'il était juste avant [avant] (null = maintenant).
  double stockAu(int libelleId, DateTime? avant, {int? chantierId}) {
    double s = 0;
    for (final m in mouvements.where((m) => m.libelleId == libelleId && (avant == null || m.date.isBefore(avant)))) {
      if (chantierId == null) {
        if (m.type == TypeMouvement.entree) s += m.quantite;
        if (m.type == TypeMouvement.sortie) s -= m.quantite;
      } else {
        switch (m.type) {
          case TypeMouvement.entree:
            if (m.chantierId == chantierId) s += m.quantite;
          case TypeMouvement.sortie:
            if (m.chantierId == chantierId) s -= m.quantite;
          case TypeMouvement.transfert:
            if (m.chantierId == chantierId) s -= m.quantite;
            if (m.chantierDestId == chantierId) s += m.quantite;
        }
      }
    }
    return s;
  }

  /// Libellés suivis en stock passés sous leur seuil (stock global).
  List<Libelle> alertesStock() => libelles
      .where((l) => !l.archive && l.categorie.suiviStock && l.seuilAlerte > 0)
      .where((l) => mouvements.any((m) => m.libelleId == l.id) && stock(l.id!) < l.seuilAlerte)
      .toList();
}
