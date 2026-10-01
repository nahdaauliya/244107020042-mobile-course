import '../domain/note.dart';
import '../domain/remote_note.dart';

/// Kontrak ke jaringan.
///
/// Sengaja interface: repository, sinkronizer, dan test tidak boleh tahu
/// apakah "server" ini HTTP sungguhan atau simulasi in-memory. Mengganti ke REST
/// API asli berarti menulis satu kelas baru, bukan mengubah yang lain.
abstract class NoteRemoteSource {
  /// Ambil seluruh catatan dari server (operational pull).
  Future<List<RemoteNote>> fetchAll();

  /// Kirim satu catatan (create/update/delete soft) dan kembalikan salinan
  /// server beserta revisi barunya.
  Future<RemoteNote> push(Note note);
}

/// Server palsu: in-memory, dengan latency buatan sendiri.
///
/// Dipakai untuk (a) demo mode pesawat tanpa backend, dan (b) test. latency
/// default sengaja tidak nol supaya race antara penulisan lokal dan jawaban
/// server terlihat di log, bukan lolos diam-diam.
class InMemoryNoteRemoteSource implements NoteRemoteSource {
  InMemoryNoteRemoteSource({
    Map<String, RemoteNote>? seed,
    this.latency = const Duration(milliseconds: 180),
  }) : _store = {...?seed};

  final Map<String, RemoteNote> _store;
  final Duration latency;

  int get length => _store.length;

  RemoteNote? peek(String id) => _store[id];

  @override
  Future<List<RemoteNote>> fetchAll() async {
    await Future<void>.delayed(latency);
    return _store.values.toList(growable: false);
  }

  @override
  Future<RemoteNote> push(Note note) async {
    await Future<void>.delayed(latency);
    final previous = _store[note.id];
    final next = RemoteNote(
      id: note.id,
      title: note.title,
      body: note.body,
      updatedAt: note.updatedAt,
      deleted: note.isDeleted,
      revision: (previous?.revision ?? 0) + 1,
    );
    _store[note.id] = next;
    return next;
  }

  /// Simulasikan perangkat lain menulis catatan yang sama. Inilah cara
  /// konflik nyata dibangkitkan saat demo/test.
  RemoteNote simulateRemoteEdit(
    String id, {
    String? title,
    String? body,
    bool deleted = false,
    DateTime? at,
  }) {
    final previous = _store[id];
    final next = RemoteNote(
      id: id,
      title: title ?? previous?.title ?? 'Catatan dari server',
      body: body ?? previous?.body ?? '',
      updatedAt: at ?? DateTime.now().toUtc(),
      deleted: deleted,
      revision: (previous?.revision ?? 0) + 1,
    );
    _store[id] = next;
    return next;
  }

  /// Seed bawaan supaya aplikasi langsung punya isi saat pertama dibuka.
  factory InMemoryNoteRemoteSource.demo() {
    final now = DateTime.now().toUtc();
    return InMemoryNoteRemoteSource(
      seed: {
        'srv-1': RemoteNote(
          id: 'srv-1',
          title: 'Rencana synced',
          body: 'Contoh catatan yang sudah ada di server sebelum app dibuka.',
          updatedAt: now.subtract(const Duration(hours: 5)),
          revision: 3,
        ),
        'srv-2': RemoteNote(
          id: 'srv-2',
          title: 'Catatan lama',
          body: 'Contoh ini hanya akan terlihat setelah pull pertama.',
          updatedAt: now.subtract(const Duration(days: 2)),
          revision: 1,
        ),
      },
    );
  }
}
