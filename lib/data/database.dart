import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base SQLite locale : tout fonctionne sans connexion internet.
class AppDatabase {
  AppDatabase._();
  static Database? _db;

  /// [path] sert aux tests (ex. inMemoryDatabasePath) : base neuve, non mise en cache.
  static Future<Database> open({String? path}) async {
    if (path == null && _db != null) return _db!;
    final dbPath = path ?? p.join(await getDatabasesPath(), 'carnet_chantier.db');
    final db = await openDatabase(
      dbPath,
      version: 3,
      singleInstance: path == null,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await _createSchema(db);
        await _seedLibelles(db);
        await _createPhotos(db);
        await _createParametres(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createPhotos(db);
        if (oldVersion < 3) await _createParametres(db);
      },
    );
    if (path == null) _db = db;
    return db;
  }

  static Future<void> _createSchema(Database db) async {
    final b = db.batch();
    b.execute('''
      CREATE TABLE chantiers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        client TEXT,
        adresse TEXT,
        debut TEXT,
        fin_prevue TEXT,
        budget REAL DEFAULT 0,
        statut TEXT NOT NULL
      )''');
    b.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        titre TEXT,
        contenu TEXT,
        chantier_id INTEGER REFERENCES chantiers(id) ON DELETE SET NULL,
        epinglee INTEGER DEFAULT 0,
        rappel TEXT,
        cree_le TEXT NOT NULL,
        modifie_le TEXT NOT NULL
      )''');
    b.execute('''
      CREATE TABLE taches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chantier_id INTEGER NOT NULL REFERENCES chantiers(id) ON DELETE CASCADE,
        nom TEXT NOT NULL,
        poids INTEGER DEFAULT 1,
        avancement INTEGER DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE ouvriers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT,
        metier TEXT,
        taux_journalier REAL DEFAULT 0,
        actif INTEGER DEFAULT 1
      )''');
    b.execute('''
      CREATE TABLE affectations (
        chantier_id INTEGER NOT NULL REFERENCES chantiers(id) ON DELETE CASCADE,
        ouvrier_id INTEGER NOT NULL REFERENCES ouvriers(id) ON DELETE CASCADE,
        PRIMARY KEY (chantier_id, ouvrier_id)
      )''');
    // Règle : un ouvrier n'est pointé qu'une fois par jour et par chantier.
    b.execute('''
      CREATE TABLE pointages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ouvrier_id INTEGER NOT NULL REFERENCES ouvriers(id) ON DELETE CASCADE,
        chantier_id INTEGER NOT NULL REFERENCES chantiers(id) ON DELETE CASCADE,
        jour TEXT NOT NULL,
        statut TEXT NOT NULL,
        UNIQUE (ouvrier_id, chantier_id, jour)
      )''');
    b.execute('''
      CREATE TABLE paiements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ouvrier_id INTEGER NOT NULL REFERENCES ouvriers(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        montant REAL NOT NULL,
        type TEXT NOT NULL
      )''');
    b.execute('''
      CREATE TABLE libelles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        categorie TEXT NOT NULL,
        unite TEXT NOT NULL,
        unite_pluriel TEXT,
        prix_unitaire REAL DEFAULT 0,
        seuil_alerte REAL DEFAULT 0,
        favori INTEGER DEFAULT 0,
        archive INTEGER DEFAULT 0
      )''');
    // Règle : un libellé utilisé ne se supprime pas (RESTRICT), il s'archive.
    b.execute('''
      CREATE TABLE mouvements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libelle_id INTEGER NOT NULL REFERENCES libelles(id) ON DELETE RESTRICT,
        type TEXT NOT NULL,
        quantite REAL NOT NULL,
        chantier_id INTEGER REFERENCES chantiers(id) ON DELETE SET NULL,
        chantier_dest_id INTEGER REFERENCES chantiers(id) ON DELETE SET NULL,
        ouvrier_id INTEGER REFERENCES ouvriers(id) ON DELETE SET NULL,
        fournisseur TEXT,
        commentaire TEXT,
        date TEXT NOT NULL
      )''');
    b.execute('CREATE INDEX idx_mvt_libelle ON mouvements(libelle_id)');
    b.execute('CREATE INDEX idx_pointage_jour ON pointages(chantier_id, jour)');
    await b.commit(noResult: true);
  }

  /// v2 : photos jointes aux notes (fichiers copiés dans le dossier de l'app).
  static Future<void> _createPhotos(Database db) async {
    await db.execute('''
      CREATE TABLE note_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        chemin TEXT NOT NULL,
        cree_le TEXT NOT NULL
      )''');
    await db.execute('CREATE INDEX idx_photo_note ON note_photos(note_id)');
  }

  /// v3 : réglages de l'application (clé et modèle Gemini…), en clé / valeur.
  static Future<void> _createParametres(Database db) async {
    await db.execute('CREATE TABLE parametres (cle TEXT PRIMARY KEY, valeur TEXT)');
  }

  /// Catalogue de départ : modifiable ensuite dans l'écran Libellés.
  static Future<void> _seedLibelles(Database db) async {
    const rows = [
      // nom, catégorie, unité, pluriel, seuil, favori
      ['Ciment 50 kg', 'materiaux', 'sac', 'sacs', 10, 1],
      ['Sable', 'materiaux', 'm³', 'm³', 4, 1],
      ['Gravier', 'materiaux', 'm³', 'm³', 4, 1],
      ['Fer de 8', 'materiaux', 'barre', 'barres', 30, 0],
      ['Fer de 10', 'materiaux', 'barre', 'barres', 30, 1],
      ['Fer de 12', 'materiaux', 'barre', 'barres', 30, 0],
      ['Briques creuses', 'materiaux', 'pièce', 'pièces', 300, 1],
      ['Planches', 'materiaux', 'pièce', 'pièces', 20, 0],
      ['Fil d\'attache', 'materiaux', 'rouleau', 'rouleaux', 2, 0],
      ['Eau', 'materiaux', 'fût', 'fûts', 2, 0],
      ['Bétonnière', 'outillage', 'pièce', 'pièces', 0, 0],
      ['Brouette', 'outillage', 'pièce', 'pièces', 1, 0],
      ['Échafaudage', 'outillage', 'élément', 'éléments', 0, 0],
      ['Pelle', 'outillage', 'pièce', 'pièces', 2, 0],
      ['Truelle', 'outillage', 'pièce', 'pièces', 2, 0],
      ['Maçon', 'personnel', 'jour', 'jours', 0, 0],
      ['Manœuvre', 'personnel', 'jour', 'jours', 0, 0],
      ['Ferrailleur', 'personnel', 'jour', 'jours', 0, 0],
      ['Électricien', 'personnel', 'jour', 'jours', 0, 0],
      ['Transport', 'services', 'voyage', 'voyages', 0, 0],
      ['Location d\'engin', 'services', 'jour', 'jours', 0, 0],
    ];
    final b = db.batch();
    for (final r in rows) {
      b.insert('libelles', {
        'nom': r[0],
        'categorie': r[1],
        'unite': r[2],
        'unite_pluriel': r[3],
        'seuil_alerte': r[4],
        'favori': r[5],
      });
    }
    await b.commit(noResult: true);
  }
}
