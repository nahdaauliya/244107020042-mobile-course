import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/local/note.dart';
import '../data/repositories/note_repository.dart';
import '../widgets/note_tile.dart';

/// Memuat satu catatan berdasarkan `id` dari route, langsung dari repository
/// lokal — bukan meneruskan state halaman list. Karena itu halaman detail tetap
/// berisi data terbaru meski daftar di-refresh atau catatan dihapus dari tempat
/// lain.
final noteDetailProvider =
    FutureProvider.family<Note?, int>((ref, id) {
  return ref.watch(noteRepositoryProvider).fetchNoteById(id);
});

class NoteDetailPage extends ConsumerStatefulWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final int noteId;

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  TextEditingController? _titleCtrl;
  TextEditingController? _bodyCtrl;

  @override
  void dispose() {
    _titleCtrl?.dispose();
    _bodyCtrl?.dispose();
    super.dispose();
  }

  /// Controller dibuat sekali, saat data pertama tersedia.
  void _initControllers(Note note) {
    _titleCtrl ??= TextEditingController(text: note.title);
    _bodyCtrl ??= TextEditingController(text: note.body);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(noteRepositoryProvider);

    final current = await repo.fetchNoteById(widget.noteId);
    if (current == null || !mounted) return;

    await repo.updateNote(
      Note(
        id: current.id,
        title: _titleCtrl?.text.trim() ?? '',
        body: _bodyCtrl?.text ?? '',
        updatedAt: DateTime.now(),
        dirty: true, // tandai perlu sinkron ulang
      ),
    );
    ref.invalidate(noteDetailProvider(widget.noteId));
    ref.invalidate(notesProvider);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Catatan disimpan')));
  }

  Future<void> _delete() async {
    final router = GoRouter.of(context);
    await ref.read(noteRepositoryProvider).deleteNote(widget.noteId);
    ref.invalidate(notesProvider);
    router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteDetailProvider(widget.noteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Catatan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Simpan',
            onPressed: _save,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Hapus',
            onPressed: _delete,
          ),
        ],
      ),
      body: noteAsync.when(
        data: (note) {
          if (note == null) {
            return const Center(child: Text('Catatan tidak ditemukan'));
          }
          _initControllers(note);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.dirty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: DirtyBadge(label: 'Belum tersinkron'),
                  ),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Judul',
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyCtrl,
                  maxLines: null,
                  minLines: 10,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Tulis isi catatan…',
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          );
        },
        error: (e, st) => Center(child: Text('Gagal memuat catatan: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
