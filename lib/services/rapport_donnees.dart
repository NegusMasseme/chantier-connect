import '../data/store.dart';
import '../models.dart';

/// Période couverte par un rapport.
enum PeriodeRapport { jour, semaine }

extension PeriodeRapportX on PeriodeRapport {
  String get label => switch (this) {
        PeriodeRapport.jour => 'Rapport journalier',
        PeriodeRapport.semaine => 'Rapport hebdomadaire',
      };
}

/// Début (inclus) et fin (incluse) d'une période, à la journée.
class Bornes {
  const Bornes(this.debut, this.fin);
  final DateTime debut;
  final DateTime fin;

  /// Les jours de la période, du premier au dernier.
  List<DateTime> get jours => [
        for (var d = debut; !d.isAfter(fin); d = DateTime(d.year, d.month, d.day + 1)) d,
      ];

  bool contient(DateTime t) {
    final j = DateTime(t.year, t.month, t.day);
    return !j.isBefore(debut) && !j.isAfter(fin);
  }
}

/// Jour seul, ou semaine du lundi au dimanche contenant [reference].
Bornes bornesPour(PeriodeRapport periode, DateTime reference) {
  final j = DateTime(reference.year, reference.month, reference.day);
  if (periode == PeriodeRapport.jour) return Bornes(j, j);
  final lundi = DateTime(j.year, j.month, j.day - (j.weekday - DateTime.monday));
  return Bornes(lundi, DateTime(lundi.year, lundi.month, lundi.day + 6));
}

/// Une ligne de présence : un ouvrier sur la période.
class LignePresence {
  LignePresence({required this.ouvrier, required this.statuts, required this.jours, required this.montant});
  final Ouvrier ouvrier;

  /// Statut par jour de la période (null = non pointé).
  final List<StatutPointage?> statuts;
  final double jours;
  final double montant;
}

/// Une ligne de matériel : un libellé sur la période.
class LigneMateriel {
  LigneMateriel({
    required this.libelle,
    required this.entrees,
    required this.sorties,
    required this.transferts,
    required this.stockFin,
  });
  final Libelle libelle;
  final double entrees;
  final double sorties;
  final double transferts;

  /// Stock à la fin de la période (null si le libellé n'est pas suivi en stock).
  final double? stockFin;
}

/// Tout ce qu'un rapport contient, calculé sans aucune dépendance au PDF :
/// c'est ce qui est testé, puis mis en page par `rapport.dart`.
class DonneesRapport {
  DonneesRapport({
    required this.periode,
    required this.bornes,
    required this.chantier,
    required this.notes,
    required this.notesParJour,
    required this.comptesParType,
    required this.pointsDuJour,
    required this.presences,
    required this.joursOuvriers,
    required this.montantMainOeuvre,
    required this.materiel,
    required this.mouvements,
    required this.taches,
    required this.avancementChantiers,
    required this.rappelsAVenir,
  });

  final PeriodeRapport periode;
  final Bornes bornes;

  /// Null = rapport du carnet entier (tous chantiers et notes libres).
  final Chantier? chantier;

  /// Notes de la période, de la plus ancienne à la plus récente.
  final List<Note> notes;
  final Map<DateTime, List<Note>> notesParJour;
  final Map<NoteType, int> comptesParType;

  /// Notes « Point du jour » de la période : le résumé écrit sur le terrain.
  final List<Note> pointsDuJour;

  final List<LignePresence> presences;
  final double joursOuvriers;
  final double montantMainOeuvre;
  final List<LigneMateriel> materiel;
  final List<Mouvement> mouvements;

  /// Tâches du chantier (rapport de chantier uniquement).
  final List<Tache> taches;

  /// Avancement de chaque chantier actif (rapport du carnet entier).
  final Map<Chantier, int> avancementChantiers;

  /// Rappels prévus dans les 7 jours qui suivent la période.
  final List<Note> rappelsAVenir;
}

/// Rassemble les notes, le journal, les présences et le matériel d'une période.
/// [chantierId] null : tout le carnet (notes libres comprises) et tous les chantiers.
DonneesRapport construireRapport(
  AppStore store, {
  required PeriodeRapport periode,
  required DateTime reference,
  int? chantierId,
}) {
  final b = bornesPour(periode, reference);
  final chantier = store.chantier(chantierId);
  bool duPerimetre(int? cid) => chantierId == null || cid == chantierId;

  // Notes et journal
  final notes = store.notes.where((n) => b.contient(n.creeLe) && duPerimetre(n.chantierId)).toList()
    ..sort((a, c) => a.creeLe.compareTo(c.creeLe));
  final notesParJour = <DateTime, List<Note>>{
    for (final j in b.jours) j: notes.where((n) => dayKey(n.creeLe) == dayKey(j)).toList(),
  };
  final comptes = <NoteType, int>{};
  for (final n in notes) {
    comptes[n.type] = (comptes[n.type] ?? 0) + 1;
  }

  // Présences : une ligne par ouvrier pointé (ou affecté au chantier)
  final jours = b.jours;
  final pointages = store.pointages.where((p) => b.contient(p.jour) && duPerimetre(p.chantierId)).toList();
  final ouvrierIds = <int>{
    ...pointages.map((p) => p.ouvrierId),
    if (chantierId != null) ...store.ouvriersDe(chantierId).map((o) => o.id!),
  };
  final presences = <LignePresence>[];
  for (final id in ouvrierIds) {
    final o = store.ouvrier(id);
    if (o == null) continue;
    final siens = pointages.where((p) => p.ouvrierId == id).toList();
    final statuts = [
      for (final j in jours)
        () {
          final duJour = siens.where((p) => dayKey(p.jour) == dayKey(j)).toList();
          if (duJour.isEmpty) return null;
          // Plusieurs chantiers le même jour (carnet entier) : on garde le meilleur statut.
          duJour.sort((x, y) => y.statut.fraction.compareTo(x.statut.fraction));
          return duJour.first.statut;
        }(),
    ];
    final nbJours = siens.fold<double>(0, (s, p) => s + p.statut.fraction);
    presences.add(LignePresence(ouvrier: o, statuts: statuts, jours: nbJours, montant: nbJours * o.tauxJournalier));
  }
  presences.sort((x, y) => x.ouvrier.nom.toLowerCase().compareTo(y.ouvrier.nom.toLowerCase()));

  // Matériel
  final mouvements = store.mouvements
      .where((m) => b.contient(m.date) && (chantierId == null || m.chantierId == chantierId || m.chantierDestId == chantierId))
      .toList()
    ..sort((x, y) => x.date.compareTo(y.date));
  final finPeriode = DateTime(b.fin.year, b.fin.month, b.fin.day + 1);
  final materiel = <LigneMateriel>[];
  for (final lid in {...mouvements.map((m) => m.libelleId)}) {
    final l = store.libelle(lid);
    if (l == null) continue;
    final siens = mouvements.where((m) => m.libelleId == lid);
    double somme(TypeMouvement t) => siens.where((m) => m.type == t).fold<double>(0, (s, m) => s + m.quantite);
    materiel.add(LigneMateriel(
      libelle: l,
      entrees: somme(TypeMouvement.entree),
      sorties: somme(TypeMouvement.sortie),
      transferts: somme(TypeMouvement.transfert),
      stockFin: l.categorie.suiviStock ? store.stockAu(lid, finPeriode, chantierId: chantierId) : null,
    ));
  }
  materiel.sort((x, y) => x.libelle.nom.toLowerCase().compareTo(y.libelle.nom.toLowerCase()));

  // Rappels des 7 jours suivants
  final apres = DateTime(b.fin.year, b.fin.month, b.fin.day + 8);
  final rappels = store.notes
      .where((n) => n.rappel != null && !n.rappel!.isBefore(finPeriode) && n.rappel!.isBefore(apres))
      .where((n) => duPerimetre(n.chantierId))
      .toList()
    ..sort((x, y) => x.rappel!.compareTo(y.rappel!));

  return DonneesRapport(
    periode: periode,
    bornes: b,
    chantier: chantier,
    notes: notes,
    notesParJour: notesParJour,
    comptesParType: comptes,
    pointsDuJour: notes.where((n) => n.type == NoteType.pointDuJour).toList(),
    presences: presences,
    joursOuvriers: presences.fold<double>(0, (s, l) => s + l.jours),
    montantMainOeuvre: presences.fold<double>(0, (s, l) => s + l.montant),
    materiel: materiel,
    mouvements: mouvements,
    taches: chantierId == null ? const [] : store.tachesDe(chantierId),
    avancementChantiers: chantierId == null ? {for (final c in store.chantiersActifs) c: store.avancement(c.id!)} : const {},
    rappelsAVenir: rappels,
  );
}
