import 'dart:io';

import 'package:flutter/material.dart';

import '../data/photos.dart';
import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, this.note, this.chantierId});
  final Note? note;
  final int? chantierId;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late NoteType _type;
  late final TextEditingController _titre;
  late final TextEditingController _contenu;
  int? _chantierId;
  DateTime? _rappel;
  bool _epinglee = false;
  final List<String> _nouvellesPhotos = []; // prises mais pas encore enregistrées
  bool _enregistre = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _type = n?.type ?? (widget.chantierId != null ? NoteType.chantier : NoteType.pointDuJour);
    _titre = TextEditingController(text: n?.titre ?? '');
    _contenu = TextEditingController(text: n?.contenu ?? '');
    _chantierId = n?.chantierId ?? widget.chantierId;
    _rappel = n?.rappel;
    _epinglee = n?.epinglee ?? false;
  }

  @override
  void dispose() {
    // Photos prises puis abandonnées (on quitte sans enregistrer) : on nettoie.
    if (!_enregistre) {
      for (final c in _nouvellesPhotos) {
        PhotoService.supprimer(c);
      }
    }
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  Future<void> _ajouterPhoto({required bool camera}) async {
    try {
      if (camera) {
        final c = await PhotoService.camera();
        if (c != null) setState(() => _nouvellesPhotos.add(c));
      } else {
        final cs = await PhotoService.galerie();
        if (cs.isNotEmpty) setState(() => _nouvellesPhotos.addAll(cs));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ajouter la photo : $e')));
    }
  }

  void _voirPhoto(String chemin) {
    showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(children: [
          InteractiveViewer(child: Center(child: Image.file(File(chemin)))),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(c),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _choisirRappel() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _rappel ?? now,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_rappel ?? now));
    if (t == null) return;
    setState(() => _rappel = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _enregistrer() async {
    final store = StoreScope.read(context);
    final aDesPhotos = _nouvellesPhotos.isNotEmpty || store.photosDe(widget.note?.id).isNotEmpty;
    if (_titre.text.trim().isEmpty && _contenu.text.trim().isEmpty && !aDesPhotos) {
      Navigator.pop(context);
      return;
    }
    final id = await store.saveNote(Note(
      id: widget.note?.id,
      type: _type,
      titre: _titre.text.trim(),
      contenu: _contenu.text.trim(),
      chantierId: _chantierId,
      epinglee: _epinglee,
      rappel: _rappel,
      creeLe: widget.note?.creeLe,
    ));
    await store.ajouterPhotos(id, List.of(_nouvellesPhotos));
    _enregistre = true;
    if (!mounted) return;
    showSaved(context, text: 'Note enregistrée');
    Navigator.pop(context);
  }

  Future<void> _supprimer() async {
    final ok = await confirmer(context, 'Supprimer la note ?', 'Cette action est définitive.');
    if (!ok || !mounted) return;
    await StoreScope.read(context).deleteNote(widget.note!.id!);
    if (mounted) Navigator.pop(context);
  }

  Widget _vignette(String chemin, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(children: [
          GestureDetector(
            onTap: () => _voirPhoto(chemin),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(chemin), width: 88, height: 88, fit: BoxFit.cover, cacheWidth: 264,
                  errorBuilder: (_, __, ___) => Container(width: 88, height: 88, color: AppColors.lavande, child: const Icon(Icons.broken_image_outlined))),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 16, color: Colors.white)),
              ),
            ),
          ),
        ]),
      );

  Widget _photos(List<NotePhoto> existantes) {
    final store = StoreScope.read(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _ajouterPhoto(camera: true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Photo'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _ajouterPhoto(camera: false),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galerie'),
          ),
        ),
      ]),
      if (existantes.isNotEmpty || _nouvellesPhotos.isNotEmpty) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final ph in existantes)
              _vignette(ph.chemin, () async {
                final ok = await confirmer(context, 'Supprimer la photo ?', 'Elle sera effacée du téléphone.');
                if (ok) await store.supprimerPhoto(ph);
              }),
            for (final c in _nouvellesPhotos)
              _vignette(c, () {
                setState(() => _nouvellesPhotos.remove(c));
                PhotoService.supprimer(c);
              }),
          ]),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cree = widget.note?.creeLe ?? DateTime.now();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.note == null ? 'Nouvelle note' : 'Modifier la note'),
        actions: [
          IconButton(
            tooltip: _epinglee ? 'Désépingler' : 'Épingler',
            icon: Icon(_epinglee ? Icons.push_pin : Icons.push_pin_outlined, color: AppColors.violet),
            onPressed: () => setState(() => _epinglee = !_epinglee),
          ),
          if (widget.note != null)
            IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: _supprimer),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text('${dateCourte(cree)} · ${heure(cree)}', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in NoteType.values)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      showCheckmark: false,
                      labelStyle: TextStyle(color: _type == t ? Colors.white : AppColors.aubergine, fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _titre,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'Titre (facultatif)',
                    filled: false,
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDD6FE), width: 2)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFDDD6FE), width: 2)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.violet, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contenu,
                  autofocus: widget.note == null,
                  minLines: 8,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Écrivez ce que vous voulez : point de la journée, idée, avancement…',
                    fillColor: AppColors.fond,
                  ),
                ),
                const SizedBox(height: 12),
                _photos(store.photosDe(widget.note?.id)),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  initialValue: _chantierId,
                  decoration: const InputDecoration(
                    labelText: 'Lier à un chantier',
                    prefixIcon: Icon(Icons.foundation, color: AppColors.violet),
                    fillColor: AppColors.lavandePale,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Aucun')),
                    for (final c in store.chantiers) DropdownMenuItem<int?>(value: c.id, child: Text(c.nom)),
                  ],
                  onChanged: (v) => setState(() => _chantierId = v),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _choisirRappel,
                  icon: const Icon(Icons.alarm),
                  label: Text(_rappel == null ? 'Ajouter un rappel' : 'Rappel : ${dateCourte(_rappel!)} à ${heure(_rappel!)}'),
                ),
                if (_rappel != null)
                  TextButton(onPressed: () => setState(() => _rappel = null), child: const Text('Retirer le rappel')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(onPressed: _enregistrer, child: const Text('Enregistrer la note')),
          ),
        ]),
      ),
    );
  }
}
