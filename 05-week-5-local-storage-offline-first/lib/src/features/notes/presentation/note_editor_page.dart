import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/datetime_format.dart';
import '../../../ui/widgets/status_widgets.dart';
import '../application/note_providers.dart';
import '../domain/note.dart';
import 'notes_page.dart';

/// Editor catatan. `noteId == null` berarti mode buat baru.
///
/// Plympa `ConsumerStatefulWidget` karena controller text harus berpasangan
/// dengan data yang dimuat: kalau catatan berubah karena sinkron, isinya ikut
/// berubah, tapi teks yang sedang diketik pengguna tidak boleh ditimpa.
class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  /// Id yang sedang diedit; dipakai agar `build` tahu harus memuat atau tidak.
  String? _loadedId;
  bool _loaded = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _hydrate(Note note) {
    if (_loaded) return;
    _loaded = true;
    _loadedId = note.id;
    _titleController.text = note.title;
    _bodyController.text = note.body;
  }

  Future<void> _save() async {
    final notifier = ref.read(notesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final title = _titleController.text.trim();
    final body = _bodyController.text;

    if (_loadedId == null) {
      await notifier.addNote(
        title: title.isEmpty ? 'Catatan baru' : title,
        body: body,
      );
    } else {
      final current = await ref.read(noteRepositoryProvider).findNote(_loadedId!);
      if (current == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Catatan sudah dihapus')));
        return;
      }
      await notifier.updateNote(
        current.copyWith(title: title, body: body, isDirty: true),
      );
    }

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Tersimpan lokal · masuk antrean sinkron'),
      ),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.noteId == null;
    final noteAsync = isNew
        ? const AsyncValue<Note?>.data(null)
        : ref.watch(noteByIdProvider(widget.noteId!));

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Catatan baru' : 'Edit catatan'),
        actions: [
          IconButton(
            tooltip: 'Simpan',
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: noteAsync.when(
        data: (note) {
          if (note != null) _hydrate(note);
          return _form(note);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat: $error')),
      ),
    );
  }

  Widget _form(Note? note) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (note != null) ...[
          Row(
            children: [
              if (note.isDirty) const DirtyBadge(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diubah ${formatRelative(note.updatedAt)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          style: theme.textTheme.titleLarge,
          decoration: const InputDecoration(
            labelText: 'Judul',
            hintText: 'Judul catatan',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bodyController,
          minLines: 8,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            labelText: 'Isi',
            hintText: 'Tulis isi catatan',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Penyimpanan terjadi lokal di SQLite dan ditandai "belum sinkron". '
          'Tekan tombol sync saat online untuk mengirimnya ke server.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (note != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await confirmDelete(context, ref, note);
              navigator.pop();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus catatan'),
          ),
        ],
      ],
    );
  }
}