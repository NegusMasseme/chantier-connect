import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ouvriers_screen.dart';

class PointageScreen extends StatefulWidget {
  const PointageScreen({super.key, required this.chantierId});
  final int chantierId;

  @override
  State<PointageScreen> createState() => _PointageScreenState();
}

class _PointageScreenState extends State<PointageScreen> {
  late int _chantierId = widget.chantierId;
  DateTime _jour = DateTime.now();
  Map<int, StatutPointage>? _statuts;

  void _charger() {
    _statuts = Map.of(StoreScope.read(context).pointageDu(_chantierId, _jour));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_statuts == null) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final equipe = store.ouvriersDe(_chantierId);
    final statuts = _statuts!;
    int nb(StatutPointage s) => statuts.values.where((v) => v == s).length;
    final montant = equipe.fold<double>(0, (s, o) => s + (statuts[o.id]?.fraction ?? 0) * o.tauxJournalier);
    final nonPointes = equipe.where((o) => !statuts.containsKey(o.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pointage'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.event),
            label: Text(dateCourte(_jour)),
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 1), lastDate: now, initialDate: _jour);
              if (d != null) {
                setState(() {
                  _jour = d;
                  _charger();
                });
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: DropdownButtonFormField<int>(
            initialValue: _chantierId,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.foundation, color: AppColors.violet), fillColor: AppColors.lavandePale),
            items: [for (final c in store.chantiers) DropdownMenuItem(value: c.id, child: Text(c.nom))],
            onChanged: (v) => setState(() {
              _chantierId = v ?? _chantierId;
              _charger();
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: Wrap(spacing: 12, children: [
                Text('${nb(StatutPointage.present) + nb(StatutPointage.retard)} présents',
                    style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                Text('${nb(StatutPointage.demi)} demi-j.', style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                Text('${nb(StatutPointage.absent)} absents', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
              ]),
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: AppColors.lavande),
              onPressed: equipe.isEmpty
                  ? null
                  : () => setState(() {
                        for (final o in equipe) {
                          statuts[o.id!] = StatutPointage.present;
                        }
                      }),
              child: const Text('Tous présents', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Expanded(
          child: equipe.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.groups_outlined,
                    text: 'Aucun ouvrier affecté à ce chantier.',
                    action: OutlinedButton.icon(
                      onPressed: () => editerOuvrier(context, chantierParDefaut: _chantierId),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Ajouter un ouvrier'),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: equipe.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final o = equipe[i];
                    final s = statuts[o.id];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: AppColors.lavande,
                            child: Text(o.initiales, style: const TextStyle(color: Color(0xFF5B21B6), fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${o.metier} · ${fcfa(o.tauxJournalier)}/j', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                            ]),
                          ),
                          _Btn('P', 'Présent', s == StatutPointage.present, AppColors.vert, () => setState(() => statuts[o.id!] = StatutPointage.present)),
                          _Btn('½', 'Demi-journée', s == StatutPointage.demi, AppColors.ambre, () => setState(() => statuts[o.id!] = StatutPointage.demi)),
                          _Btn('A', 'Absent', s == StatutPointage.absent, AppColors.rouge, () => setState(() => statuts[o.id!] = StatutPointage.absent)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.bordure))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Montant du jour : ', style: TextStyle(color: AppColors.gris)),
                TextSpan(text: fcfa(montant), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (nonPointes > 0) TextSpan(text: ' · $nonPointes non pointé${nonPointes > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xFFC2410C))),
              ])),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: statuts.isEmpty
                    ? null
                    : () async {
                        await StoreScope.read(context).enregistrerPointage(_chantierId, _jour, statuts);
                        if (!context.mounted) return;
                        showSaved(context, text: 'Pointage enregistré');
                        Navigator.pop(context);
                      },
                child: const Text('Valider le pointage'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.text, this.tooltip, this.on, this.color, this.onTap);
  final String text;
  final String tooltip;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: on ? color : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: on ? color : const Color(0xFFE4DEF2)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(text,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: on ? Colors.white : const Color(0xFF6B6580))),
                ),
              ),
            ),
          ),
        ),
      );
}
