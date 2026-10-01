import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/local/note.dart';
import '../providers/app_providers.dart';
import '../widgets/sync_badge.dart';

/// Halaman tulis/edit. Memakai `id` dari route: `new` membuat catatan baru,
/// angka lain membuka catatan yang ada.
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  Note? _existing;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future<void>(() => _load());
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.noteId);
    if (id == null) {
      // Catatan baru: form kosong, badge muncul setelah disimpan.
      _existing = null;
      _loading = false;
      if (mounted) setState(() {});
      return;
    }
    final note = await ref.read(noteRepositoryProvider).fetchNoteById(id);
    _existing = note;
    if (note != null) {
      _title.text = note.title;
      _body.text = note.body;
    }
    _loading = false;
    if (mounted) {
      setState(() {});
      _titleFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);

    final controller = ref.read(notesControllerProvider.notifier);
    final existing = _existing;
    if (existing == null) {
      await controller.addNote(title: title, body: _body.text.trim());
    } else {
      await controller.editNote(
        existing.copyWith(title: title, body: _body.text.trim()),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final creating = _existing == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(creating ? 'Catatan baru' : 'Edit catatan'),
        actions: [
          if (!creating) SyncBadge(note: _existing!),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _loading || _saving ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Simpan'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  focusNode: _titleFocus,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _body,
                  minLines: 8,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Isi catatan',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Menyimpan akan menandai catatan sebagai "belum sinkron". '
                  'Tekan Sinkron di daftar saat ada jaringan.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
