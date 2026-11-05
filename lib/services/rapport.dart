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
import '../theme.dart';
import 'rapport_donnees.dart';

export 'rapport_donnees.dart' show PeriodeRapport, PeriodeRapportX;

const _violet = PdfColor.fromInt(0xFF6D28D9);
const _aubergine = PdfColor.fromInt(0xFF4C1D95);
const _lavande = PdfColor.fromInt(0xFFEDE9FE);
const _lavandePale = PdfColor.fromInt(0xFFF5F3FF);
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
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('œ', 'oe')
    .replaceAll('Œ', 'OE');

final _nf = NumberFormat.decimalPattern('fr_FR');
String _n(num v) => _t(v == v.roundToDouble() ? _nf.format(v) : NumberFormat('#,##0.##', 'fr_FR').format(v));
String _fcfa(num v) => '${_t(_nf.format(v.round()))} FCFA';
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _jourLong(DateTime d) => _cap(DateFormat('EEEE d MMMM y', 'fr_FR').format(d));
String _jourCourt(DateTime d) => _cap(DateFormat('EEEE d MMMM', 'fr_FR').format(d));

String _libellePeriode(DonneesRapport d) {
  final b = d.bornes;
  if (d.periode == PeriodeRapport.jour) return _jourLong(b.debut);
  final memeMois = b.debut.month == b.fin.month;
  final debut = DateFormat(memeMois ? 'd' : 'd MMMM', 'fr_FR').format(b.debut);
  return 'Semaine du lundi $debut au dimanche ${DateFormat('d MMMM y', 'fr_FR').format(b.fin)}';
}

String _symbole(StatutPointage? s) => switch (s) {
      null => '-',
      StatutPointage.present => 'P',
      StatutPointage.retard => 'R',
      StatutPointage.demi => '½',
      StatutPointage.absent => 'A',
    };

/// Génère le PDF (journalier ou hebdomadaire) et retourne le fichier.
Future<File> genererRapport(
  AppStore store, {
  required PeriodeRapport periode,
  required DateTime reference,
  int? chantierId,
}) async {
  final d = construireRapport(store, periode: periode, reference: reference, chantierId: chantierId);
  final hebdo = periode == PeriodeRapport.semaine;

  // Photos : 6 par note au quotidien, 3 par note sur la semaine, 36 au total.
  final photos = <int, List<pw.MemoryImage>>{};
  var total = 0;
  for (final n in d.notes) {
    final imgs = <pw.MemoryImage>[];
    for (final ph in store.photosDe(n.id).take(hebdo ? 3 : 6)) {
      if (total >= 36) break;
      final f = File(ph.chemin);
      if (await f.exists()) {
        imgs.add(pw.MemoryImage(await f.readAsBytes()));
        total++;
      }
    }
    photos[n.id!] = imgs;
  }

  pw.Widget titre(String s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(_t(s), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _aubergine)),
      );

  pw.Widget tableau(List<String> entetes, List<List<String>> lignes,
          {Map<int, pw.TableColumnWidth>? largeurs, Map<int, pw.Alignment>? alignements}) =>
      pw.TableHelper.fromTextArray(
        headers: entetes.map(_t).toList(),
        data: lignes.map((r) => r.map(_t).toList()).toList(),
        columnWidths: largeurs,
        cellAlignments: alignements,
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _violet),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        oddRowDecoration: const pw.BoxDecoration(color: _lavandePale),
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _bordure, width: 0.5)),
      );

  pw.Widget vide(String s) => pw.Text(_t(s), style: const pw.TextStyle(fontSize: 10, color: _gris));

  pw.Widget note(Note n) {
    final ch = d.chantier == null ? store.chantier(n.chantierId) : null;
    final entete = [
      DateFormat('HH:mm').format(n.creeLe),
      n.type.label,
      if (ch != null) ch.nom,
      if (n.titre.isNotEmpty) n.titre,
    ].join(' · ');
    final imgs = photos[n.id] ?? const <pw.MemoryImage>[];
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(left: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: _bordure, width: 2))),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(_t(entete), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        if (n.contenu.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
            child: pw.Text(_t(n.contenu), style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
          ),
        if (imgs.isNotEmpty)
          pw.Wrap(spacing: 6, runSpacing: 6, children: [
            for (final img in imgs)
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(img, width: hebdo ? 120 : 160, height: hebdo ? 90 : 120, fit: pw.BoxFit.cover),
              ),
          ]),
      ]),
    );
  }

  final repartition = [
    for (final t in NoteType.values)
      if ((d.comptesParType[t] ?? 0) > 0) '${d.comptesParType[t]} ${t.label.toLowerCase()}',
  ].join(' · ');

  final presentsDuJour = d.presences.where((l) => l.statuts.first != null && l.statuts.first != StatutPointage.absent).length;

  final doc = pw.Document(title: '${periode.label} ${d.chantier?.nom ?? 'Carnet'}', author: 'Chantier Connect');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(_t('Chantier Connect · généré le ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
          style: const pw.TextStyle(fontSize: 8, color: _gris)),
      pw.Text('${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: _gris)),
    ]),
    build: (ctx) => [
      // En-tête
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(color: _aubergine, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(hebdo ? 'RAPPORT HEBDOMADAIRE' : 'RAPPORT JOURNALIER',
              style: const pw.TextStyle(fontSize: 9, color: _lavande, letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.Text(_t(d.chantier?.nom ?? 'Carnet complet · tous les chantiers'),
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(
              _t([
                _libellePeriode(d),
                if (d.chantier != null && d.chantier!.client.isNotEmpty) 'Client : ${d.chantier!.client}',
                if (d.chantier != null && d.chantier!.adresse.isNotEmpty) d.chantier!.adresse,
              ].join(' · ')),
              style: const pw.TextStyle(fontSize: 10, color: _lavande)),
        ]),
      ),
      pw.SizedBox(height: 12),

      // Chiffres clés
      pw.Row(children: [
        if (d.chantier != null) ...[_chiffre('${store.avancement(d.chantier!.id!)} %', 'Avancement'), pw.SizedBox(width: 8)],
        _chiffre('${d.notes.length}', 'Notes et journal'),
        pw.SizedBox(width: 8),
        hebdo
            ? _chiffre(_n(d.joursOuvriers), 'Jours-ouvriers')
            : _chiffre('$presentsDuJour / ${d.presences.length}', 'Présents'),
        pw.SizedBox(width: 8),
        _chiffre(_fcfa(d.montantMainOeuvre), hebdo ? 'Main-d\'oeuvre semaine' : 'Main-d\'oeuvre du jour'),
        pw.SizedBox(width: 8),
        _chiffre('${d.mouvements.length}', 'Mouvements de stock'),
      ]),

      // Synthèse tirée des notes
      titre(hebdo ? 'Synthèse de la semaine' : 'Synthèse du jour'),
      if (d.notes.isEmpty)
        vide('Aucune note ni journal sur la période.')
      else ...[
        pw.Text(_t(repartition), style: const pw.TextStyle(fontSize: 10, color: _gris)),
        if (d.pointsDuJour.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          for (final n in d.pointsDuJour)
            pw.Bullet(
              text: _t([
                if (hebdo) _jourCourt(n.creeLe),
                if (n.titre.isNotEmpty) n.titre,
                n.contenu.replaceAll('\n', ' '),
              ].where((s) => s.isNotEmpty).join(' : ')),
              style: const pw.TextStyle(fontSize: 10),
              bulletColor: _violet,
            ),
        ],
      ],

      // Avancement
      titre('Avancement des travaux'),
      if (d.chantier != null) ...[
        if (d.taches.isEmpty)
          vide('Aucune tâche définie.')
        else
          tableau(['Tâche', 'Avancement'],
              [for (final t in d.taches) [t.nom, t.avancement >= 100 ? 'Terminé' : '${t.avancement} %']],
              largeurs: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)}),
      ] else if (d.avancementChantiers.isEmpty)
        vide('Aucun chantier actif.')
      else
        tableau(['Chantier', 'Statut', 'Avancement'],
            [for (final e in d.avancementChantiers.entries) [e.key.nom, e.key.statut.label, '${e.value} %']],
            largeurs: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.2), 2: const pw.FlexColumnWidth(1)}),

      // Présences
      titre('Présences'),
      if (d.presences.isEmpty)
        vide('Aucun ouvrier pointé sur la période.')
      else if (hebdo)
        tableau(
          ['Ouvrier', 'L', 'M', 'M', 'J', 'V', 'S', 'D', 'Jours', 'Montant'],
          [
            for (final l in d.presences)
              [l.ouvrier.nom, ...l.statuts.map(_symbole), _n(l.jours), l.montant == 0 ? '-' : _fcfa(l.montant)],
            ['Total', '', '', '', '', '', '', '', _n(d.joursOuvriers), _fcfa(d.montantMainOeuvre)],
          ],
          largeurs: {
            0: const pw.FlexColumnWidth(2.6),
            for (var i = 1; i <= 7; i++) i: const pw.FlexColumnWidth(0.45),
            8: const pw.FlexColumnWidth(0.8),
            9: const pw.FlexColumnWidth(1.6),
          },
          alignements: {for (var i = 1; i <= 8; i++) i: pw.Alignment.center, 9: pw.Alignment.centerRight},
        )
      else
        tableau(
          ['Ouvrier', 'Métier', 'Statut', 'Montant'],
          [
            for (final l in d.presences)
              [l.ouvrier.nom, l.ouvrier.metier, l.statuts.first?.label ?? 'Non pointé', l.montant == 0 ? '-' : _fcfa(l.montant)],
          ],
          alignements: {3: pw.Alignment.centerRight},
        ),
      if (hebdo && d.presences.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: vide('P présent · R retard · ½ demi-journée · A absent · - non pointé'),
        ),

      // Matériel
      titre('Matériel'),
      if (d.mouvements.isEmpty)
        vide('Aucun mouvement de stock sur la période.')
      else if (hebdo)
        tableau(
          ['Libellé', 'Entrées', 'Sorties', 'Transferts', 'Stock fin'],
          [
            for (final m in d.materiel)
              [
                m.libelle.nom,
                m.entrees == 0 ? '-' : '${_n(m.entrees)} ${m.libelle.uniteFor(m.entrees)}',
                m.sorties == 0 ? '-' : '${_n(m.sorties)} ${m.libelle.uniteFor(m.sorties)}',
                m.transferts == 0 ? '-' : '${_n(m.transferts)} ${m.libelle.uniteFor(m.transferts)}',
                m.stockFin == null ? 'non suivi' : '${_n(m.stockFin!)} ${m.libelle.uniteFor(m.stockFin!)}',
              ],
          ],
          largeurs: {0: const pw.FlexColumnWidth(2)},
          alignements: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
        )
      else
        tableau(
          ['Heure', 'Type', 'Libellé', 'Quantité', 'Détail'],
          [
            for (final m in d.mouvements)
              () {
                final l = store.libelle(m.libelleId);
                final dest = store.chantier(m.chantierDestId);
                return [
                  DateFormat('HH:mm').format(m.date),
                  m.type.label,
                  l?.nom ?? '?',
                  '${_n(m.quantite)} ${l?.uniteFor(m.quantite) ?? ''}',
                  [
                    if (d.chantier == null && store.chantier(m.chantierId) != null) store.chantier(m.chantierId)!.nom,
                    if (m.type == TypeMouvement.transfert && dest != null) 'vers ${dest.nom}',
                    if (m.fournisseur.isNotEmpty) m.fournisseur,
                    if (m.ouvrierId != null) 'remis à ${store.ouvrier(m.ouvrierId)?.nom ?? ''}',
                    if (m.commentaire.isNotEmpty) m.commentaire,
                  ].join(' · '),
                ];
              }(),
          ],
          largeurs: {
            0: const pw.FlexColumnWidth(0.7),
            1: const pw.FlexColumnWidth(0.9),
            2: const pw.FlexColumnWidth(1.6),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(2),
          },
        ),

      // Rappels à venir
      if (d.rappelsAVenir.isNotEmpty) ...[
        titre('À prévoir dans les 7 jours'),
        for (final n in d.rappelsAVenir)
          pw.Bullet(
            text: _t('${DateFormat('EEE d MMM HH:mm', 'fr_FR').format(n.rappel!)} : ${n.titre.isNotEmpty ? n.titre : n.contenu.split('\n').first}'),
            style: const pw.TextStyle(fontSize: 10),
            bulletColor: _violet,
          ),
      ],

      // Journal détaillé
      titre(hebdo ? 'Journal de la semaine' : 'Journal et photos'),
      if (d.notes.isEmpty) vide('Aucune note sur la période.'),
      if (hebdo)
        for (final e in d.notesParJour.entries)
          if (e.value.isNotEmpty) ...[
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 6, bottom: 6),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(color: _lavande, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(_t(_jourCourt(e.key)),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _aubergine)),
            ),
            for (final n in e.value) note(n),
          ],
      if (!hebdo) for (final n in d.notes) note(n),
    ],
  ));

  final dir = await getTemporaryDirectory();
  final nom = (d.chantier?.nom ?? 'Carnet').replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final suffixe = hebdo ? 'semaine_${dayKey(d.bornes.debut)}' : dayKey(d.bornes.debut);
  final file = File(p.join(dir.path, 'Rapport_${nom}_$suffixe.pdf'));
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

/// Demande journalier ou hebdomadaire, puis le jour, génère le PDF et ouvre le partage.
/// [chantierId] null : rapport du carnet entier.
Future<void> partagerRapport(BuildContext context, {int? chantierId}) async {
  final store = StoreScope.read(context);
  final periode = await showModalBottomSheet<PeriodeRapport>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              chantierId == null ? 'Rapport PDF du carnet' : 'Rapport PDF du chantier',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          _ChoixPeriode(
            icon: Icons.today_outlined,
            titre: 'Rapport journalier',
            detail: 'Notes, journal, présences et matériel d\'un jour',
            onTap: () => Navigator.pop(sheet, PeriodeRapport.jour),
          ),
          const SizedBox(height: 8),
          _ChoixPeriode(
            icon: Icons.date_range_outlined,
            titre: 'Rapport hebdomadaire',
            detail: 'Du lundi au dimanche : synthèse, journal jour par jour, totaux',
            onTap: () => Navigator.pop(sheet, PeriodeRapport.semaine),
          ),
        ]),
      ),
    ),
  );
  if (periode == null || !context.mounted) return;

  final now = DateTime.now();
  final jour = await showDatePicker(
    context: context,
    helpText: periode == PeriodeRapport.jour ? 'Rapport de quel jour ?' : 'Choisir un jour de la semaine',
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
    final file = await genererRapport(store, periode: periode, reference: jour, chantierId: chantierId);
    fermerAttente();
    final b = bornesPour(periode, jour);
    final quoi = store.chantier(chantierId)?.nom ?? 'Carnet';
    final quand = periode == PeriodeRapport.jour
        ? 'du ${DateFormat('dd/MM/yyyy').format(b.debut)}'
        : 'semaine du ${DateFormat('dd/MM').format(b.debut)} au ${DateFormat('dd/MM/yyyy').format(b.fin)}';
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${periode.label} $quoi $quand',
      text: '${periode.label} $quoi $quand',
    ));
  } catch (e) {
    fermerAttente();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapport impossible : $e')));
  }
}

class _ChoixPeriode extends StatelessWidget {
  const _ChoixPeriode({required this.icon, required this.titre, required this.detail, required this.onTap});
  final IconData icon;
  final String titre;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.lavandePale,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDDD6FE)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.violet, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(fontSize: 13, color: AppColors.gris)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.violet),
            ]),
          ),
        ),
      );
}
