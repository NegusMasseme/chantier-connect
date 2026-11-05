import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../services/gemini.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Réglages de la rédaction des rapports par l'IA Gemini.
class ReglagesIAScreen extends StatefulWidget {
  const ReglagesIAScreen({super.key});

  @override
  State<ReglagesIAScreen> createState() => _ReglagesIAScreenState();
}

class _ReglagesIAScreenState extends State<ReglagesIAScreen> {
  final _cle = TextEditingController();
  final _modele = TextEditingController();
  bool _voirCle = false;
  bool _test = false;
  String? _resultat;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    _cle.text = store.parametre(ParamIA.cle) ?? '';
    _modele.text = store.parametre(ParamIA.modele) ?? modeleGeminiParDefaut;
  }

  @override
  void dispose() {
    _cle.dispose();
    _modele.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final store = StoreScope.read(context);
    await store.setParametre(ParamIA.cle, _cle.text.trim());
    final m = _modele.text.trim();
    await store.setParametre(ParamIA.modele, m == modeleGeminiParDefaut ? null : m);
    if (mounted) showSaved(context, text: 'Réglages IA enregistrés');
  }

  Future<void> _tester() async {
    final cle = _cle.text.trim();
    if (cle.isEmpty) {
      setState(() {
        _ok = false;
        _resultat = 'Collez d\'abord votre clé API.';
      });
      return;
    }
    setState(() {
      _test = true;
      _resultat = null;
    });
    try {
      final m = _modele.text.trim();
      await GeminiService(cleApi: cle, modele: m.isEmpty ? modeleGeminiParDefaut : m).tester();
      _ok = true;
      _resultat = 'Connexion réussie : Gemini répond.';
    } on GeminiException catch (e) {
      _ok = false;
      _resultat = e.message;
    } catch (e) {
      _ok = false;
      _resultat = 'Échec du test : $e';
    }
    if (mounted) setState(() => _test = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final active = GeminiService.estConfigure(store);
    return Scaffold(
      appBar: AppBar(title: const Text('IA Gemini')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.lavandePale, borderRadius: BorderRadius.circular(16)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome, color: AppColors.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  active
                      ? 'L\'IA est prête. Au moment de créer un rapport PDF, cochez « Compte rendu rédigé par l\'IA ».'
                      : 'Gemini rédige le compte rendu des rapports journaliers et hebdomadaires à partir de vos notes, '
                          'du journal, des présences et du matériel. Vous relisez et corrigez le texte avant le PDF.',
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Clé API Gemini', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const SelectableText(
            'Créez-la gratuitement sur aistudio.google.com (menu « Get API key »), puis collez-la ici.',
            style: TextStyle(color: AppColors.gris, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cle,
            obscureText: !_voirCle,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'AIza…',
              suffixIcon: IconButton(
                tooltip: _voirCle ? 'Masquer la clé' : 'Afficher la clé',
                icon: Icon(_voirCle ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _voirCle = !_voirCle),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Modèle', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _modele, autocorrect: false, decoration: const InputDecoration(hintText: modeleGeminiParDefaut)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in modelesGemini)
              ChoiceChip(
                label: Text(m),
                selected: _modele.text.trim() == m,
                showCheckmark: false,
                labelStyle: TextStyle(color: _modele.text.trim() == m ? Colors.white : AppColors.aubergine),
                onSelected: (_) => setState(() => _modele.text = m),
              ),
          ]),
          const SizedBox(height: 24),
          FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _test ? null : _tester,
            icon: _test
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('Tester la connexion'),
          ),
          if (_resultat != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(_ok ? Icons.check_circle : Icons.error_outline, color: _ok ? AppColors.vert : AppColors.rouge),
              const SizedBox(width: 8),
              Expanded(child: Text(_resultat!)),
            ]),
          ],
          if (active) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                final ok = await confirmer(context, 'Supprimer la clé ?', 'La rédaction par l\'IA sera désactivée.');
                if (!ok || !context.mounted) return;
                await StoreScope.read(context).setParametre(ParamIA.cle, null);
                _cle.clear();
              },
              child: const Text('Supprimer la clé'),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Confidentialité : quand vous demandez une rédaction, les notes, le journal, les noms des ouvriers, '
            'les présences et le matériel de la période sont envoyés à Google (Gemini). Les photos ne sont pas envoyées. '
            'Sans clé, les rapports restent créés entièrement sur le téléphone.',
            style: TextStyle(color: AppColors.gris, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
