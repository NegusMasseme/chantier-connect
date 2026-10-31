// Modèles de données de l'application.

enum NoteType { pointDuJour, idee, rappel, chantier, tache, autre }

extension NoteTypeX on NoteType {
  String get label => switch (this) {
        NoteType.pointDuJour => 'Point du jour',
        NoteType.idee => 'Idée',
        NoteType.rappel => 'Rappel',
        NoteType.chantier => 'Chantier',
        NoteType.tache => 'Tâche',
        NoteType.autre => 'Autre',
      };
}

class Note {
  final int? id;
  final NoteType type;
  final String titre;
  final String contenu;
  final int? chantierId;
  final bool epinglee;
  final DateTime? rappel;
  final DateTime creeLe;
  final DateTime modifieLe;

  Note({
    this.id,
    required this.type,
    this.titre = '',
    this.contenu = '',
    this.chantierId,
    this.epinglee = false,
    this.rappel,
    DateTime? creeLe,
    DateTime? modifieLe,
  })  : creeLe = creeLe ?? DateTime.now(),
        modifieLe = modifieLe ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'titre': titre,
        'contenu': contenu,
        'chantier_id': chantierId,
        'epinglee': epinglee ? 1 : 0,
        'rappel': rappel?.toIso8601String(),
        'cree_le': creeLe.toIso8601String(),
        'modifie_le': modifieLe.toIso8601String(),
      };

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int?,
        type: NoteType.values.byName(m['type'] as String),
        titre: (m['titre'] as String?) ?? '',
        contenu: (m['contenu'] as String?) ?? '',
        chantierId: m['chantier_id'] as int?,
        epinglee: (m['epinglee'] as int? ?? 0) == 1,
        rappel: m['rappel'] == null ? null : DateTime.parse(m['rappel'] as String),
        creeLe: DateTime.parse(m['cree_le'] as String),
        modifieLe: DateTime.parse(m['modifie_le'] as String),
      );
}

enum StatutChantier { preparation, enCours, pause, termine }

extension StatutChantierX on StatutChantier {
  String get label => switch (this) {
        StatutChantier.preparation => 'En préparation',
        StatutChantier.enCours => 'En cours',
        StatutChantier.pause => 'En pause',
        StatutChantier.termine => 'Terminé',
      };
}

class Chantier {
  final int? id;
  final String nom;
  final String client;
  final String adresse;
  final DateTime? debut;
  final DateTime? finPrevue;
  final double budget;
  final StatutChantier statut;

  Chantier({
    this.id,
    required this.nom,
    this.client = '',
    this.adresse = '',
    this.debut,
    this.finPrevue,
    this.budget = 0,
    this.statut = StatutChantier.enCours,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nom': nom,
        'client': client,
        'adresse': adresse,
        'debut': debut?.toIso8601String(),
        'fin_prevue': finPrevue?.toIso8601String(),
        'budget': budget,
        'statut': statut.name,
      };

  factory Chantier.fromMap(Map<String, Object?> m) => Chantier(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        client: (m['client'] as String?) ?? '',
        adresse: (m['adresse'] as String?) ?? '',
        debut: m['debut'] == null ? null : DateTime.parse(m['debut'] as String),
        finPrevue: m['fin_prevue'] == null ? null : DateTime.parse(m['fin_prevue'] as String),
        budget: (m['budget'] as num?)?.toDouble() ?? 0,
        statut: StatutChantier.values.byName(m['statut'] as String),
      );
}

class Tache {
  final int? id;
  final int chantierId;
  final String nom;
  final int poids;
  final int avancement; // 0..100

  Tache({this.id, required this.chantierId, required this.nom, this.poids = 1, this.avancement = 0});

  Map<String, Object?> toMap() => {
        'id': id,
        'chantier_id': chantierId,
        'nom': nom,
        'poids': poids,
        'avancement': avancement,
      };

  factory Tache.fromMap(Map<String, Object?> m) => Tache(
        id: m['id'] as int?,
        chantierId: m['chantier_id'] as int,
        nom: m['nom'] as String,
        poids: m['poids'] as int? ?? 1,
        avancement: m['avancement'] as int? ?? 0,
      );

  Tache copyWith({int? avancement}) =>
      Tache(id: id, chantierId: chantierId, nom: nom, poids: poids, avancement: avancement ?? this.avancement);
}

class Ouvrier {
  final int? id;
  final String nom;
  final String telephone;
  final String metier;
  final double tauxJournalier;
  final bool actif;

  Ouvrier({
    this.id,
    required this.nom,
    this.telephone = '',
    this.metier = '',
    this.tauxJournalier = 0,
    this.actif = true,
  });

  String get initiales {
    final parts = nom.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'nom': nom,
        'telephone': telephone,
        'metier': metier,
        'taux_journalier': tauxJournalier,
        'actif': actif ? 1 : 0,
      };

  factory Ouvrier.fromMap(Map<String, Object?> m) => Ouvrier(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        telephone: (m['telephone'] as String?) ?? '',
        metier: (m['metier'] as String?) ?? '',
        tauxJournalier: (m['taux_journalier'] as num?)?.toDouble() ?? 0,
        actif: (m['actif'] as int? ?? 1) == 1,
      );
}

enum StatutPointage { present, demi, absent, retard }

extension StatutPointageX on StatutPointage {
  String get label => switch (this) {
        StatutPointage.present => 'Présent',
        StatutPointage.demi => 'Demi-journée',
        StatutPointage.absent => 'Absent',
        StatutPointage.retard => 'Retard',
      };

  /// Fraction de journée payée.
  double get fraction => switch (this) {
        StatutPointage.present => 1,
        StatutPointage.retard => 1,
        StatutPointage.demi => 0.5,
        StatutPointage.absent => 0,
      };
}

class Pointage {
  final int? id;
  final int ouvrierId;
  final int chantierId;
  final DateTime jour;
  final StatutPointage statut;

  Pointage({this.id, required this.ouvrierId, required this.chantierId, required this.jour, required this.statut});

  Map<String, Object?> toMap() => {
        'id': id,
        'ouvrier_id': ouvrierId,
        'chantier_id': chantierId,
        'jour': dayKey(jour),
        'statut': statut.name,
      };

  factory Pointage.fromMap(Map<String, Object?> m) => Pointage(
        id: m['id'] as int?,
        ouvrierId: m['ouvrier_id'] as int,
        chantierId: m['chantier_id'] as int,
        jour: DateTime.parse(m['jour'] as String),
        statut: StatutPointage.values.byName(m['statut'] as String),
      );
}

class Paiement {
  final int? id;
  final int ouvrierId;
  final DateTime date;
  final double montant;
  final String type; // 'avance' | 'solde'

  Paiement({this.id, required this.ouvrierId, required this.date, required this.montant, this.type = 'avance'});

  Map<String, Object?> toMap() => {
        'id': id,
        'ouvrier_id': ouvrierId,
        'date': date.toIso8601String(),
        'montant': montant,
        'type': type,
      };

  factory Paiement.fromMap(Map<String, Object?> m) => Paiement(
        id: m['id'] as int?,
        ouvrierId: m['ouvrier_id'] as int,
        date: DateTime.parse(m['date'] as String),
        montant: (m['montant'] as num).toDouble(),
        type: m['type'] as String? ?? 'avance',
      );
}

enum CategorieLibelle { materiaux, outillage, personnel, services }

extension CategorieLibelleX on CategorieLibelle {
  String get label => switch (this) {
        CategorieLibelle.materiaux => 'Matériaux',
        CategorieLibelle.outillage => 'Outillage',
        CategorieLibelle.personnel => 'Personnel',
        CategorieLibelle.services => 'Services',
      };

  /// Le stock n'est suivi que pour les biens physiques.
  bool get suiviStock => this == CategorieLibelle.materiaux || this == CategorieLibelle.outillage;
}

/// Un libellé = un élément pré-enregistré qu'on choisit au lieu de le taper.
class Libelle {
  final int? id;
  final String nom;
  final CategorieLibelle categorie;
  final String unite;
  final String unitePluriel;
  final double prixUnitaire;
  final double seuilAlerte;
  final bool favori;
  final bool archive;

  Libelle({
    this.id,
    required this.nom,
    required this.categorie,
    required this.unite,
    String? unitePluriel,
    this.prixUnitaire = 0,
    this.seuilAlerte = 0,
    this.favori = false,
    this.archive = false,
  }) : unitePluriel = unitePluriel ?? unite;

  String uniteFor(num q) => q > 1 ? unitePluriel : unite;

  Map<String, Object?> toMap() => {
        'id': id,
        'nom': nom,
        'categorie': categorie.name,
        'unite': unite,
        'unite_pluriel': unitePluriel,
        'prix_unitaire': prixUnitaire,
        'seuil_alerte': seuilAlerte,
        'favori': favori ? 1 : 0,
        'archive': archive ? 1 : 0,
      };

  factory Libelle.fromMap(Map<String, Object?> m) => Libelle(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        categorie: CategorieLibelle.values.byName(m['categorie'] as String),
        unite: m['unite'] as String,
        unitePluriel: m['unite_pluriel'] as String?,
        prixUnitaire: (m['prix_unitaire'] as num?)?.toDouble() ?? 0,
        seuilAlerte: (m['seuil_alerte'] as num?)?.toDouble() ?? 0,
        favori: (m['favori'] as int? ?? 0) == 1,
        archive: (m['archive'] as int? ?? 0) == 1,
      );
}

enum TypeMouvement { entree, sortie, transfert }

extension TypeMouvementX on TypeMouvement {
  String get label => switch (this) {
        TypeMouvement.entree => 'Entrée',
        TypeMouvement.sortie => 'Sortie',
        TypeMouvement.transfert => 'Transfert',
      };
}

class Mouvement {
  final int? id;
  final int libelleId;
  final TypeMouvement type;
  final double quantite;
  final int? chantierId; // chantier source (sortie / transfert) ou destination (entrée)
  final int? chantierDestId; // pour un transfert
  final int? ouvrierId;
  final String fournisseur;
  final String commentaire;
  final DateTime date;

  Mouvement({
    this.id,
    required this.libelleId,
    required this.type,
    required this.quantite,
    this.chantierId,
    this.chantierDestId,
    this.ouvrierId,
    this.fournisseur = '',
    this.commentaire = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'libelle_id': libelleId,
        'type': type.name,
        'quantite': quantite,
        'chantier_id': chantierId,
        'chantier_dest_id': chantierDestId,
        'ouvrier_id': ouvrierId,
        'fournisseur': fournisseur,
        'commentaire': commentaire,
        'date': date.toIso8601String(),
      };

  factory Mouvement.fromMap(Map<String, Object?> m) => Mouvement(
        id: m['id'] as int?,
        libelleId: m['libelle_id'] as int,
        type: TypeMouvement.values.byName(m['type'] as String),
        quantite: (m['quantite'] as num).toDouble(),
        chantierId: m['chantier_id'] as int?,
        chantierDestId: m['chantier_dest_id'] as int?,
        ouvrierId: m['ouvrier_id'] as int?,
        fournisseur: (m['fournisseur'] as String?) ?? '',
        commentaire: (m['commentaire'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
      );
}

/// Clé AAAA-MM-JJ d'un jour (sans l'heure).
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Photo jointe à une note (fichier local dans le dossier de l'application).
class NotePhoto {
  final int? id;
  final int noteId;
  final String chemin;
  final DateTime creeLe;

  NotePhoto({this.id, required this.noteId, required this.chemin, DateTime? creeLe}) : creeLe = creeLe ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'note_id': noteId,
        'chemin': chemin,
        'cree_le': creeLe.toIso8601String(),
      };

  factory NotePhoto.fromMap(Map<String, Object?> m) => NotePhoto(
        id: m['id'] as int?,
        noteId: m['note_id'] as int,
        chemin: m['chemin'] as String,
        creeLe: DateTime.parse(m['cree_le'] as String),
      );
}
