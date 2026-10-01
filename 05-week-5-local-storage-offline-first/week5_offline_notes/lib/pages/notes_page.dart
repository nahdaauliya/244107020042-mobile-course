import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/repositories/note_repository.dart';
import '../widgets/note_tile.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final pending = ref.watch(pendingSyncProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Notes'),
        bottom: pending > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('$pending belum tersinkron'),
                ),
              )
            : null,
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(child: Text('Belum ada catatan'));
          }
          return ListView.separated(
            itemCount: notes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notes[index];
              final id = note.id;
              return NoteTile(
                note: note,
                onTap: () => context.go('/note/$id'),
                onDelete: id == null
                    ? null
                    : () async {
                        await ref.read(noteRepositoryProvider).deleteNote(id);
                        _refresh(ref);
                      },
              );
            },
          );
        },
        error: (e, st) => Center(child: Text('Gagal memuat catatan: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await ref
              .read(noteRepositoryProvider)
              .addNote(title: 'Catatan baru', body: '');
          _refresh(ref);
        },
        tooltip: 'Tambah catatan',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(notesProvider);
    ref.invalidate(pendingSyncProvider);
  }
}
