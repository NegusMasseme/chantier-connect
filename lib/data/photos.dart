import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Prise de photos et copie dans le dossier privé de l'application.
/// Les photos sont réduites (1600 px, qualité 70) : environ 200 à 400 Ko chacune.
class PhotoService {
  PhotoService._();
  static final _picker = ImagePicker();

  static Future<Directory> _dossier() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> _copier(XFile f) async {
    final dir = await _dossier();
    final ext = p.extension(f.path).isEmpty ? '.jpg' : p.extension(f.path);
    final dest = p.join(dir.path, 'photo_${DateTime.now().microsecondsSinceEpoch}$ext');
    await File(f.path).copy(dest);
    return dest;
  }

  /// Prend une photo avec l'appareil. Retourne le chemin enregistré ou null si annulé.
  static Future<String?> camera() async {
    final f = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 70);
    return f == null ? null : _copier(f);
  }

  /// Choisit une ou plusieurs photos dans la galerie.
  static Future<List<String>> galerie() async {
    final fs = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 70);
    final out = <String>[];
    for (final f in fs) {
      out.add(await _copier(f));
    }
    return out;
  }

  /// Supprime un fichier photo qui n'a finalement pas été enregistré.
  static Future<void> supprimer(String chemin) async {
    try {
      final f = File(chemin);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
