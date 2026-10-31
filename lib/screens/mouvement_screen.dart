import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'libelles_screen.dart';

/// Saisie d'un mouvement en 3 touches :
/// 1) Entrée / Sortie / Transfert, 2) toucher un libellé, 3) la quantité.
class MouvementScreen extends StatefulWidget {
  const MouvementScreen({super.key, this.type = TypeMouvement.sortie, this.chantierId});
  final TypeMouvement type;
  final int? chantierId;

  @override
  State<MouvementScreen> createState() => _MouvementScreenState();
}

class _MouvementScreenState extends State<MouvementScreen> {
  late TypeMouvement _type = widget.type;
  int? _chantierId;
  int? _chantierDestId;
  CategorieLibelle _cat = CategorieLibelle.materiaux;
  String _recherche = '';
  int? _libelleId;
  double _qte = 1;
  bool _details = false;
  final _fournisseur = TextEditingController();
  final _commentaire = TextEditingController();
  int? _ouvrierId;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final store = StoreScope.read(context);
    final actifs = store.chantiersActifs;
    _chantierId = widget.chantierId ?? (actifs.isNotEmpty ? actifs.first.id : null);
  }

  @override
  void dispose() {
    _fournisseur.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  void _setQte(double v) => setState(() => _qte = v < 1 ? 1 : v);

  Future<void> _enregistrer() async {
    final store = StoreScope.read(context);
    final l = store.libelle(_libelleId);
    if (l == null) return;
    if (_type == TypeMouvement.transfert && (_chantierId == null || _chantierDestId == null || _chantierId == _chantierDestId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez deux chantiers différents pour un transfert.')));
      return;
    }
    final id = await store.ajouterMouvement(Mouvement(
      libelleId: l.id!,
      type: _type,
      quantite: _qte,
      chantierId: _chantierId,
      chantierDestId: _type == TypeMouvement.transfert ? _chantierDestId : null,
      ouvrierId: _ouvrierId,
      fournisseur: _fournisseur.text.trim(),
      commentaire: _commentaire.text.trim(),
    ));
    if (!mounted) return;
    showSaved(
      context,
      text: '${_type.label} : ${nombre(_qte)} ${l.uniteFor(_qte)} de ${l.nom}',
      onUndo: () => store.supprimerMouvement(id),
    );
    setState(() {
      _qte = 1;
      _fournisseur.clear();
      _commentaire.clear();
      _ouvrierId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final libs = store.libellesActifs(categorie: _recherche.isEmpty ? _cat : null, recherche: _recherche);
    final sel = store.libelle(_libelleId);
    final stockSel = sel == null ? 0.0 : store.stock(sel.id!, chantierId: _chantierId);
    final depasse = sel != null &&
        sel.categorie.suiviStock &&
        (_type == TypeMouvement.sortie || _type == TypeMouvement.transfert) &&
        _qte > stockSel;

    return Scaffold(
      appBar: AppBar(title: const Text('Mouvement de stock')),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              SegmentedButton<TypeMouvement>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                  backgroundColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? couleurMouvement(_type) : AppColors.lavande),
                  foregroundColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.aubergine),
                  textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
                ),
                segments: [for (final t in TypeMouvement.values) ButtonSegment(value: t, label: Text(t.label))],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              _chantierPicker(_type == TypeMouvement.transfert ? 'Depuis le chantier' : 'Chantier', _chantierId,
                  (v) => setState(() => _chantierId = v)),
              if (_type == TypeMouvement.transfert) ...[
                const SizedBox(height: 8),
                _chantierPicker('Vers le chantier', _chantierDestId, (v) => setState(() => _chantierDestId = v)),
              ],
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Chercher un libellé…', isDense: true),
                onChanged: (v) => setState(() => _recherche = v),
              ),
              const SizedBox(height: 10),
              if (_recherche.isEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final c in CategorieLibelle.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c.label),
                          selected: _cat == c,
                          showCheckmark: false,
                          selectedColor: AppColors.aubergine,
                          labelStyle: TextStyle(color: _cat == c ? Colors.white : AppColors.aubergine, fontWeight: FontWeight.w600),
                          onSelected: (_) => setState(() => _cat = c),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: [
                  for (final l in libs) _tuile(l),
                  _nouveauLibelle(),
                ],
              ),
              if (sel != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _details = !_details),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Text('Plus de détails (facultatif)', style: TextStyle(color: AppColors.violet, fontWeight: FontWeight.w600)),
                      Icon(_details ? Icons.expand_less : Icons.expand_more, color: AppColors.violet),
                    ]),
                  ),
                ),
                if (_details) ...[
                  if (_type == TypeMouvement.entree)
                    TextField(controller: _fournisseur, decoration: const InputDecoration(labelText: 'Fournisseur')),
                  if (_type == TypeMouvement.sortie)
                    DropdownButtonFormField<int?>(
                      initialValue: _ouvrierId,
                      decoration: const InputDecoration(labelText: 'Remis à (ouvrier)'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('—')),
                        for (final o in (_chantierId == null ? store.ouvriers : store.ouvriersDe(_chantierId!)))
                          DropdownMenuItem<int?>(value: o.id, child: Text(o.nom)),
                      ],
                      onChanged: (v) => setState(() => _ouvrierId = v),
                    ),
                  const SizedBox(height: 10),
                  TextField(controller: _commentaire, decoration: const InputDecoration(labelText: 'Commentaire')),
                ],
              ],
            ],
          ),
        ),
        if (sel != null) _panneauQuantite(sel, stockSel, depasse),
      ]),
    );
  }

  Widget _chantierPicker(String label, int? value, ValueChanged<int?> onChanged) {
    final chantiers = StoreScope.of(context).chantiers;
    return DropdownButtonFormField<int?>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: const Icon(Icons.foundation, color: AppColors.violet),
        fillColor: AppColors.lavandePale,
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Magasin / sans chantier')),
        for (final c in chantiers) DropdownMenuItem<int?>(value: c.id, child: Text(c.nom)),
      ],
      onChanged: onChanged,
    );
  }

  Widget _tuile(Libelle l) {
    final s = StoreScope.of(context);
    final on = _libelleId == l.id;
    final stock = s.stock(l.id!, chantierId: _chantierId);
    final bas = l.categorie.suiviStock && l.seuilAlerte > 0 && stock < l.seuilAlerte;
    final info = l.categorie.suiviStock ? '${bas ? 'Bas · ' : ''}${nombre(stock)} ${l.uniteFor(stock)}' : 'par ${l.unite}';
    return Material(
      color: on ? AppColors.lavandePale : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: on ? AppColors.violet : AppColors.bordure, width: on ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _libelleId = l.id;
          _qte = 1;
        }),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.lavande, borderRadius: BorderRadius.circular(10)),
                child: Icon(iconeCategorie(l.categorie), size: 19, color: AppColors.violet),
              ),
              const Spacer(),
              if (l.favori) const Icon(Icons.star, size: 14, color: AppColors.mauve),
            ]),
            const Spacer(),
            Text(l.nom, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 2),
            Text(info,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: bas ? const Color(0xFFC2410C) : AppColors.gris)),
          ]),
        ),
      ),
    );
  }

  Widget _nouveauLibelle() => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFDDD6FE)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final id = await editerLibelle(context, categorie: _cat, nomInitial: _recherche);
            if (id != null && mounted) {
              setState(() {
                _libelleId = id;
                _qte = 1;
              });
            }
          },
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_circle_outline, color: AppColors.violet),
              SizedBox(height: 6),
              Text('Nouveau\nlibellé', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.violet)),
            ]),
          ),
        ),
      );

  Widget _panneauQuantite(Libelle l, double stock, bool depasse) {
    final verbe = switch (_type) {
      TypeMouvement.entree => 'l\'entrée',
      TypeMouvement.sortie => 'la sortie',
      TypeMouvement.transfert => 'le transfert',
    };
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x1F4C1D95), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                    l.categorie.suiviStock ? 'Stock actuel : ${nombre(stock)} ${l.uniteFor(stock)}' : 'Main-d\'œuvre / service (non stocké)',
                    style: const TextStyle(fontSize: 12, color: AppColors.gris),
                  ),
                ]),
              ),
              Tag(_type.label, bg: couleurMouvement(_type), fg: Colors.white),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _stepBtn(Icons.remove, 'Moins', () => _setQte(_qte - 1), filled: false),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.fond,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.violet, width: 2),
                  ),
                  child: InkWell(
                    onTap: _saisirQuantite,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(nombre(_qte), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text(l.uniteFor(_qte), style: const TextStyle(color: AppColors.gris)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _stepBtn(Icons.add, 'Plus', () => _setQte(_qte + 1)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              for (final n in [1, 5, 10, 20])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        side: const BorderSide(color: Color(0xFFE4DEF2)),
                        foregroundColor: AppColors.aubergine,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _setQte(_qte + n),
                      child: Text('+$n'),
                    ),
                  ),
                ),
            ]),
            if (depasse)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Attention : la quantité dépasse le stock disponible.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFC2410C))),
              ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _enregistrer,
              child: Text('Enregistrer $verbe · ${nombre(_qte)} ${l.uniteFor(_qte)}'),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _saisirQuantite() async {
    final ctrl = TextEditingController(text: nombre(_qte).replaceAll(' ', '').replaceAll(' ', ''));
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quantité'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(c, double.tryParse(ctrl.text.replaceAll(',', '.').replaceAll(' ', ''))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v != null && v > 0) setState(() => _qte = v);
  }

  Widget _stepBtn(IconData icon, String label, VoidCallback onTap, {bool filled = true}) => SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: filled ? AppColors.violet : AppColors.lavandePale,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: filled ? BorderSide.none : const BorderSide(color: Color(0xFFDDD6FE)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Tooltip(message: label, child: Icon(icon, color: filled ? Colors.white : AppColors.aubergine)),
          ),
        ),
      );
}
