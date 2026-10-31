import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme.dart';

final _fcfa = NumberFormat.decimalPattern('fr_FR');
String fcfa(num v) => '${_fcfa.format(v.round())} FCFA';
String nombre(num v) => v == v.roundToDouble() ? _fcfa.format(v) : NumberFormat('#,##0.##', 'fr_FR').format(v);
String dateCourte(DateTime d) => DateFormat('d MMM', 'fr_FR').format(d);
String dateLongue(DateTime d) => DateFormat('EEEE d MMMM', 'fr_FR').format(d);
String heure(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);

/// Libellé de date relatif pour les listes.
String quand(DateTime d) {
  final now = DateTime.now();
  final k = dayKey(d);
  if (k == dayKey(now)) return 'Auj. ${heure(d)}';
  if (k == dayKey(now.subtract(const Duration(days: 1)))) return 'Hier';
  return dateCourte(d);
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  factory Tag.noteType(NoteType t) {
    final (bg, fg) = switch (t) {
      NoteType.pointDuJour => (AppColors.lavande, const Color(0xFF5B21B6)),
      NoteType.idee => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      NoteType.rappel => (const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      NoteType.chantier => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
      NoteType.tache => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      NoteType.autre => (const Color(0xFFF1F5F9), const Color(0xFF334155)),
    };
    return Tag(t.label.toUpperCase(), bg: bg, fg: fg);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.percent, {super.key, this.height = 8, this.color, this.track});
  final int percent;
  final double height;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: percent.clamp(0, 100) / 100,
          minHeight: height,
          backgroundColor: track ?? AppColors.lavande,
          color: color ?? (percent >= 100 ? AppColors.vert : const Color(0xFF7C3AED)),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            if (action != null) action!,
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.lavande, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, color: AppColors.violet, size: 30),
            ),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.gris, fontSize: 15)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      );
}

/// Message « Enregistré » avec bouton Annuler (principe UX n°4).
void showSaved(BuildContext context, {String text = 'Enregistré', VoidCallback? onUndo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Color(0xFF86EFAC)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.encre,
      duration: const Duration(seconds: 5),
      action: onUndo == null
          ? null
          : SnackBarAction(label: 'Annuler', textColor: const Color(0xFFC4B5FD), onPressed: onUndo),
    ));
}

Future<bool> confirmer(BuildContext context, String titre, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titre),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.rouge),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return r ?? false;
}

IconData iconeCategorie(CategorieLibelle c) => switch (c) {
      CategorieLibelle.materiaux => Icons.inventory_2_outlined,
      CategorieLibelle.outillage => Icons.construction,
      CategorieLibelle.personnel => Icons.person_outline,
      CategorieLibelle.services => Icons.local_shipping_outlined,
    };

Color couleurMouvement(TypeMouvement t) => switch (t) {
      TypeMouvement.entree => AppColors.vert,
      TypeMouvement.sortie => AppColors.rouge,
      TypeMouvement.transfert => AppColors.violet,
    };
