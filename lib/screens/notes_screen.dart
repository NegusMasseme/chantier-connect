import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'note_edit_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  NoteType? _filtre;
  String _recherche = '';
  bool _cherche = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _recherche.toLowerCase();
    final notes = store.notes
        .where((n) => _filtre == null || n.type == _filtre)
        .where((n) => q.isEmpty || n.titre.toLowerCase().contains(q) || n.contenu.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: _cherche
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Rechercher dans le carnet', filled: false, border: InputBorder.none),
                onChanged: (v) => setState(() => _recherche = v),
              )
            : const Text('Mon carnet'),
        actions: [
          IconButton(
            tooltip: _cherche ? 'Fermer la recherche' : 'Rechercher',
            icon: Icon(_cherche ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _cherche = !_cherche;
              _recherche = '';
            }),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip('Toutes', _filtre == null, () => setState(() => _filtre = null)),
              for (final t in NoteType.values) _chip(t.label, _filtre == t, () => setState(() => _filtre = t)),
            ],
          ),
        ),
        Expanded(
          child: notes.isEmpty
              ? const Center(child: EmptyState(icon: Icons.sticky_note_2_outlined, text: 'Aucune note ici.\nTouchez + pour écrire ce que vous voulez.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _NoteCard(note: notes[i]),
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          labelStyle: TextStyle(color: on ? Colors.white : AppColors.aubergine, fontWeight: FontWeight.w600),
          onSelected: (_) => onTap(),
        ),
      );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final chantier = store.chantier(note.chantierId);
    final nbPhotos = store.photosDe(note.id).length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteEditScreen(note: note))),
        onLongPress: () => store.togglePin(note),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Tag.noteType(note.type),
              if (note.epinglee) ...[
                const SizedBox(width: 8),
                const Icon(Icons.push_pin, size: 16, color: AppColors.violet),
              ],
              const Spacer(),
              Text(quand(note.modifieLe), style: const TextStyle(fontSize: 12, color: AppColors.gris)),
            ]),
            if (note.titre.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(note.titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
            if (note.contenu.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(note.contenu,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4A4560))),
            ],
            if (chantier != null || note.rappel != null || nbPhotos > 0) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 12, children: [
                if (nbPhotos > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.gris),
                    const SizedBox(width: 4),
                    Text('$nbPhotos', style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                  ]),
                if (chantier != null)
                  Text(chantier.nom, style: const TextStyle(fontSize: 12, color: AppColors.gris)),
                if (note.rappel != null)
                  Text('Rappel ${dateCourte(note.rappel!)} ${heure(note.rappel!)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
