import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../data/store_scope.dart';
import '../models.dart';

const _violet = PdfColor.fromInt(0xFF6D28D9);
const _aubergine = PdfColor.fromInt(0xFF4C1D95);
const _lavande = PdfColor.fromInt(0xFFEDE9FE);
const _gris = PdfColor.fromInt(0xFF5B5670);
const _bordure = PdfColor.fromInt(0xFFDDD6FE);

/// Les polices PDF de base ne connaissent que l'alphabet latin simple :
/// on remplace les quelques caractères qu'elles ne savent pas afficher.
String _t(String s) => s
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ')
    .replaceAll('−', '-')
    .replaceAll('’', "'")
    .replaceAll('…', '...')
    .replaceAll('→', '->')
    .replaceAll('œ', 'oe')
    .replaceAll('Œ', 'OE');

final _nf = NumberFormat.decimalPattern('fr_FR');
String _n(num v) => _t(v == v.roundToDouble() ? _nf.format(v) : NumberFormat('#,##0.##', 'fr_FR').format(v));
String _fcfa(num v) => '${_t(_nf.format(v.round()))} FCFA';

/// Génère le rapport journalier d'un chantier et retourne le fichier PDF.
Future<File> genererRapportJournalier(AppStore store, int chantierId, DateTime jour) async {
  final c = store.chantier(chantierId)!;
  final k = dayKey(jour);
  final dateTxt = DateFormat('EEEE d MMMM y', 'fr_FR').format(jour);
  final dateCap = dateTxt[0].toUpperCase() + dateTxt.substring(1);

  // Présences
  final statuts = store.pointageDu(chantierId, jour);
  final equipe = store.ouvriersDe(chantierId);
  final pointes = [
    ...equipe,
    // ouvriers pointés ce jour mais plus affectés
    ...store.ouvriers.where((o) => statuts.containsKey(o.id) && !equipe.any((e) => e.id == o.id)),
  ];
  double montant = 0;
  int presents = 0;
  final lignesPresence = <List<String>>[];
  for (final o in pointes) {
    final s = statuts[o.id];
    final m = (s?.fraction ?? 0) * o.tauxJournalier;
    montant += m;
    if (s != null && s != StatutPointage.absent) presents++;
    lignesPresence.add([o.nom, o.metier, s?.label ?? 'Non pointé', m == 0 ? '-' : _fcfa(m)]);
  }

  // Matériel du jour
  final mvts = store.mouvements
      .where((m) => dayKey(m.date) == k && (m.chantierId == chantierId || m.chantierDestId == chantierId))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final lignesMvt = [
    for (final m in mvts)
      () {
        final l = store.libelle(m.libelleId);
        final dest = store.chantier(m.chantierDestId);
        final detail = [
          if (m.type == TypeMouvement.transfert && dest != null) 'vers ${dest.nom}',
          if (m.fournisseur.isNotEmpty) m.fournisseur,
          if (m.ouvrierId != null) 'remis à ${store.ouvrier(m.ouvrierId)?.nom ?? ''}',
          if (m.commentaire.isNotEmpty) m.commentaire,
        ].join(' · ');
        return [
          DateFormat('HH:mm').format(m.date),
          m.type.label,
          l?.nom ?? '?',
          '${_n(m.quantite)} ${l?.uniteFor(m.quantite) ?? ''}',
          detail,
        ];
      }(),
  ];

  // Notes et photos du jour
  final notes = store.notes.where((n) => n.chantierId == chantierId && dayKey(n.creeLe) == k).toList()
    ..sort((a, b) => a.creeLe.compareTo(b.creeLe));
  final photosParNote = <int, List<pw.MemoryImage>>{};
  for (final n in notes) {
    final imgs = <pw.MemoryImage>[];
    for (final ph in store.photosDe(n.id).take(6)) {
      final f = File(ph.chemin);
      if (await f.exists()) imgs.add(pw.MemoryImage(await f.readAsBytes()));
    }
    photosParNote[n.id!] = imgs;
  }

  final taches = store.tachesDe(chantierId);
  final doc = pw.Document(title: 'Rapport ${c.nom} $k', author: 'Chantier Connect');

  pw.Widget titre(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(_t(s), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _aubergine)),
      );

  pw.Widget tableau(List<String> entetes, List<List<String>> lignes, {Map<int, pw.TableColumnWidth>? largeurs}) =>
      pw.TableHelper.fromTextArray(
        headers: entetes.map(_t).toList(),
        data: lignes.map((r) => r.map(_t).toList()).toList(),
        columnWidths: largeurs,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _violet),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F3FF)),
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _bordure, width: 0.5)),
      );

  pw.Widget vide(String s) => pw.Text(_t(s), style: const pw.TextStyle(fontSize: 10, color: _gris));

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(_t('Chantier Connect · généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
          style: const pw.TextStyle(fontSize: 8, color: _gris)),
      pw.Text('${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _gris)),
    ]),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(color: _aubergine, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('RAPPORT JOURNALIER', style: const pw.TextStyle(fontSize: 9, color: _lavande, letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.Text(_t(c.nom), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(_t([dateCap, if (c.client.isNotEmpty) 'Client : ${c.client}', if (c.adresse.isNotEmpty) c.adresse].join(' · ')),
              style: const pw.TextStyle(fontSize: 10, color: _lavande)),
        ]),
      ),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        _chiffre('${store.avancement(chantierId)} %', 'Avancement'),
        pw.SizedBox(width: 8),
        _chiffre('$presents / ${pointes.length}', 'Présents'),
        pw.SizedBox(width: 8),
        _chiffre(_fcfa(montant), 'Main-d\'oeuvre du jour'),
        pw.SizedBox(width: 8),
        _chiffre('${mvts.length}', 'Mouvements de stock'),
      ]),
      titre('Avancement des travaux'),
      if (taches.isEmpty)
        vide('Aucune tâche définie.')
      else
        tableau(['Tâche', 'Avancement'], [for (final t in taches) [t.nom, t.avancement >= 100 ? 'Terminé' : '${t.avancement} %']],
            largeurs: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)}),
      titre('Présences'),
      if (lignesPresence.isEmpty)
        vide('Aucun ouvrier affecté ni pointé.')
      else
        tableau(['Ouvrier', 'Métier', 'Statut', 'Montant'], lignesPresence),
      titre('Matériel'),
      if (lignesMvt.isEmpty)
        vide('Aucun mouvement de stock ce jour.')
      else
        tableau(['Heure', 'Type', 'Libellé', 'Quantité', 'Détail'], lignesMvt, largeurs: {
          0: const pw.FlexColumnWidth(0.7),
          1: const pw.FlexColumnWidth(0.9),
          2: const pw.FlexColumnWidth(1.6),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(2),
        }),
      titre('Journal et photos'),
      if (notes.isEmpty) vide('Aucune note pour ce chantier ce jour.'),
      for (final n in notes) ...[
        pw.Text(_t('${DateFormat('HH:mm').format(n.creeLe)} · ${n.type.label}${n.titre.isNotEmpty ? ' · ${n.titre}' : ''}'),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        if (n.contenu.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
            child: pw.Text(_t(n.contenu), style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
          ),
        if ((photosParNote[n.id] ?? []).isNotEmpty)
          pw.Wrap(spacing: 6, runSpacing: 6, children: [
            for (final img in photosParNote[n.id]!)
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(img, width: 160, height: 120, fit: pw.BoxFit.cover),
              ),
          ]),
        pw.SizedBox(height: 10),
      ],
    ],
  ));

  final dir = await getTemporaryDirectory();
  final nomFichier = 'Rapport_${c.nom.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_$k.pdf';
  final file = File(p.join(dir.path, nomFichier));
  await file.writeAsBytes(await doc.save());
  return file;
}

pw.Widget _chiffre(String valeur, String label) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: _lavande, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_t(valeur), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _aubergine)),
          pw.Text(_t(label), style: const pw.TextStyle(fontSize: 8, color: _gris)),
        ]),
      ),
    );

/// Demande le jour, génère le PDF puis ouvre le partage (WhatsApp, e-mail…).
Future<void> partagerRapportJournalier(BuildContext context, int chantierId) async {
  final store = StoreScope.read(context);
  final now = DateTime.now();
  final jour = await showDatePicker(
    context: context,
    helpText: 'Rapport de quel jour ?',
    firstDate: DateTime(now.year - 2),
    lastDate: now,
    initialDate: now,
  );
  if (jour == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  var attenteOuverte = true;
  void fermerAttente() {
    if (attenteOuverte && context.mounted) Navigator.of(context, rootNavigator: true).pop();
    attenteOuverte = false;
  }

  try {
    final file = await genererRapportJournalier(store, chantierId, jour);
    fermerAttente();
    final c = store.chantier(chantierId);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Rapport ${c?.nom ?? ''} du ${DateFormat('dd/MM/yyyy').format(jour)}',
      text: 'Rapport journalier ${c?.nom ?? ''} du ${DateFormat('dd/MM/yyyy').format(jour)}',
    ));
  } catch (e) {
    fermerAttente();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapport impossible : $e')));
  }
}
