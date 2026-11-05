import 'package:flutter/material.dart';

import '../services/gemini.dart';
import '../theme.dart';

/// Relecture du compte rendu rédigé par l'IA avant la création du PDF.
/// Retourne le compte rendu corrigé, ou null si l'utilisateur abandonne.
/// [regenerer] relance la rédaction.
class CompteRenduScreen extends StatefulWidget {
  const CompteRenduScreen({super.key, required this.initial, required this.titre, required this.regenerer});
  final CompteRendu initial;
  final String titre;
  final Future<CompteRendu> Function() regenerer;

  @override
  State<CompteRenduScreen> createState() => _CompteRenduScreenState();
}

class _CompteRenduScreenState extends State<CompteRenduScreen> {
  final _resume = TextEditingController();
  final _travaux = TextEditingController();
  final _mainOeuvre = TextEditingController();
  final _materiel = TextEditingController();
  final _attention = TextEditingController();
  final _etapes = TextEditingController();
  late String _modele;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _remplir(widget.initial);
  }

  void _remplir(CompteRendu c) {
    _resume.text = c.resume;
    _travaux.text = c.travaux;
    _mainOeuvre.text = c.mainOeuvre;
    _materiel.text = c.materiel;
    _attention.text = c.pointsAttention.join('\n');
    _etapes.text = c.prochainesEtapes.join('\n');
    _modele = c.modele;
  }

  @override
  void dispose() {
    for (final c in [_resume, _travaux, _mainOeuvre, _materiel, _attention, _etapes]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lignes(TextEditingController c) =>
      c.text.split('\n').map((l) => l.replaceFirst(RegExp(r'^\s*[-•*]\s*'), '').trim()).where((l) => l.isNotEmpty).toList();

  CompteRendu get _resultat => CompteRendu(
        resume: _resume.text.trim(),
        travaux: _travaux.text.trim(),
        mainOeuvre: _mainOeuvre.text.trim(),
        materiel: _materiel.text.trim(),
        pointsAttention: _lignes(_attention),
        prochainesEtapes: _lignes(_etapes),
        modele: _modele,
      );

  Future<void> _regenerer() async {
    setState(() => _enCours = true);
    try {
      final c = await widget.regenerer();
      if (mounted) setState(() => _remplir(c));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _enCours = false);
  }

  Widget _champ(String label, TextEditingController c, {String? aide, int lignes = 3}) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.aubergine)),
          if (aide != null) Text(aide, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            minLines: lignes,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15, height: 1.45),
            decoration: const InputDecoration(fillColor: AppColors.fond),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Relire le compte rendu'),
        actions: [
          TextButton.icon(
            onPressed: _enCours ? null : _regenerer,
            icon: _enCours
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Régénérer'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: AbsorbPointer(
              absorbing: _enCours,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.lavandePale, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome, color: AppColors.violet, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${widget.titre}\nRédigé par Gemini à partir de vos notes. Vérifiez et corrigez avant d\'envoyer.',
                            style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ]),
                  ),
                  _champ('Résumé', _resume, lignes: 3),
                  _champ('Travaux réalisés', _travaux, lignes: 4),
                  _champ('Main-d\'œuvre', _mainOeuvre),
                  _champ('Matériel', _materiel),
                  _champ('Points d\'attention', _attention, aide: 'Un point par ligne', lignes: 2),
                  _champ('Prochaines étapes', _etapes, aide: 'Une étape par ligne', lignes: 2),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton.icon(
              onPressed: _enCours ? null : () => Navigator.pop(context, _resultat),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Créer le PDF'),
            ),
          ),
        ]),
      ),
    );
  }
}
