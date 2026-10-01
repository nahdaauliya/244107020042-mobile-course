# Aturan Offline-First dan Konflik Sinkronisasi

Dokumen ini menjelaskan bagaimana aplikasi tetap berguna tanpa jaringan, dan
kapan aplikasi memilih versi mana yang menang saat server dan perangkat
berbeda. Semua aturan di sini terikat pada test di
`test/sync_service_test.dart` dan `test/notes_provider_test.dart`.

---

## 1. Prinsip: baca dari cache, jaringan menyusul

Pembagian tanggung jawabnya sengaja dipisah menjadi dua jalur yang tidak saling
menunggu:

| Jalur | Metode | Menyentuh jaringan? |
| --- | --- | --- |
| Tampil | `SyncService.loadFromCache()` | Tidak pernah |
| Sinkron | `pullAndMerge()` lalu `syncNotes()` | Ya, hanya bila online |

`NotesController.build()` hanya memanggil `loadFromCache()`, sehingga daftar
tampil seketika dari SQLite. `backgroundSyncProvider` baru berjalan sesudahnya di
background. Konsekuensinya:

- Saat offline, `loadFromCache()` tetap mengembalikan data utuh. Tidak ada
  skeleton, tidak ada error, tidak ada permintaan jaringan yang gagal.
- Saat online, data lokal yang sudah tampil tidak pernah hilang walau
  `pullAndMerge()` gagal. Banner hanya berubah pesan, bukan mengosongkan daftar.
- UI tidak perlu tahu sedang online atau tidak untuk menampilkan data.

---

## 2. Dirty flag dalam bentuk enum

Setiap perubahan lokal menyalakan kembali dirty flag:

| Aksi | Yang berubah di SQLite |
| --- | --- |
| `createNote` | baris baru dengan `status = pendingUpload` |
| `updateNote` | `updated_at = now()`, `status = pendingUpload`, `conflict_note = ''` |
| `markSynced` | `status = synced`, `conflict_note = ''` |
| `markConflicted` | `status = conflicted`, `conflict_note = <alasan>` |

Catatan baru disimpan ke lokal lebih dulu sebelum diunggah. Itu yang membuat
sinkron bisa idempoten: kolom `id` INTEGER AUTINCREMENT dipakai dua kali dengan
arti yang sama sebagai primary key lokal dan sebagai id di server, jadi
unggahan ulang tidak menciptakan duplikat.

`conflict_note` sengaja disimpan terpisah dari `status` supaya alasan konflik
tetap ada setelah badge-nya hilang. Catatan konflik juga tidak ikut masuk
antrean unggah, karena `fetchPendingNotes()` hanya mengambil `status = 1`.

---

## 3. Skema SQL

```sql
CREATE TABLE notes(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,
  conflict_note TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_notes_updated ON notes(updated_at DESC);
CREATE INDEX idx_notes_status  ON notes(status);
```

Query yang memanfaatkan kedua index itu:

```sql
-- Daftar utama: yang baru diedit selalu di atas.
SELECT * FROM notes ORDER BY updated_at DESC, id DESC;

-- Antrean sync: hanya yang pending, perubahan lama lebih dulu.
SELECT * FROM notes WHERE status = 1 ORDER BY updated_at ASC;

-- Badge jumlah menunggu sinkron.
SELECT COUNT(*) AS c FROM notes WHERE status = 1;
```

Kenapa `updated_at` berupa INTEGER dan bukan TEXT ISO sudah dijelaskan di
[`ai_challenge.md`](ai_challenge.md#52-updated_at-disimpan-sebagai-integer).

---

## 4. Aturan konflik eksplisit

Semua aturan berada di satu fungsi murni, `ConflictResolver.resolve(local,
remote)`, supaya bisa diuji tanpa database dan tanpa jaringan.

| # | Local | Remote | Keputusan | Alasan |
| --- | --- | --- | --- | --- |
| 1 | tidak ada | ada | `pullRemote` | Perubahan baru dari perangkat lain |
| 2 | ada | tidak ada | `pushLocal` | Perubahan lokal yang belum sampai ke server |
| 3 | ada, status `synced` | lebih baru | `pullRemote` | Tidak ada pekerjaan lokal yang bisa hilang |
| 4 | ada, status `synced` | tidak lebih baru | `pushLocal` | Praktis tidak terjadi karena `syncNotes()` hanya mengambil yang pending, tetapi aman bila terjadi |
| 5 | `pendingUpload` | tidak lebih baru | `pushLocal` | Fast-forward, tidak ada yang menimpa |
| 6 | `pendingUpload` | lebih baru | `needsUserDecision` | Dua pihak benar-benar berubah |

### Kenapa last-write-wins, dan kenapa tetap ada eskalasi ke pengguna

- **Server selalu menang** berbahaya: satu perangkat yang salah jam, atau yang
  keliru membaca isi catatan, bisa menimpa pekerjaan pengguna tanpa jejak.
- **Lokal selalu menang** juga berbahaya: dua perangkat yang sama-sama offline
  lalu menyala akan menghasilkan dua versi berbeda tanpa ada yang menang.
- Karena itu, kalau hanya satu sisi yang berubah, otomatis aman. Kalau keduanya
  berubah, jam menentukan sementara, dan hasilnya tetap ditandai `conflicted`
  supaya pengguna bisa menimpa keputusannya.

### Dua jalan keluar yang ditawarkan pengguna

| Pilihan | Aksi | Perilaku |
| --- | --- | --- |
| Pakai versi ini | `keepLocalVersion(id)` | `updateNote` menaikkan `updated_at`, lalu `uploadNote(force: true)` |
| Pakai versi server | `keepRemoteVersion(id)` | Ambil versi server lalu `applyRemote`, suntingan lokal dibuang |

`force: true` pada pilihan pertama itu disengaja: memilih "pakai versi ini"
adalah keputusan sadar, bukan hasil tebak-tebakan jam, jadi aturan
last-write-wins di server harus dilewati. `updated_at` lokal tetap dimajukan
supaya daftar lokal dan server melihat urutan suntingan yang sama.

Catatan berstatus `conflicted` tidak pernah diunggah oleh `syncNotes()`, karena
itu berarti menimpa suntingan orang lain secara buta. Antreannya baru jalan
setelah salah satu dari dua pilihan di atas dipakai.

---

## 5. Urutan satu putaran sinkronisasi

```
buka halaman
  |-- NotesController.build() --> loadFromCache() --> SQLite --> UI
  |   (tampil, tanpa jaringan)
  |
  '-- backgroundSyncProvider (hanya bila online)
        |-- pullAndMerge() --> fetchAllNotes()  --> resolve() per id
        '-- syncNotes()    --> fetchPendingNotes() --> uploadNote() per id
```

Hasil satu putaran dilaporkan lewat `SyncReport` dengan status `offline`,
`upToDate`, `completed`, `needsDecision`, atau `failed`. Status `failed`
sengaja dipisah dari `upToDate`, karena "prosesnya gagal" tidak boleh
disamarkan menjadi "catatannya bersih".

Kalau jaringan putus di tengah antrean, catatan yang gagal tetap berstatus
`pendingUpload` dan dicoba lagi pada putaran berikutnya. Tidak ada keadaan
setengah jadi.

---

## 6. Bukti mode pesawat

Tangkapan layar di `screenshots/` dihasilkan dari widget tree aplikasi yang
sungguhan, dengan `isOnlineProvider` dipaksa `false` dan `NotesApi` tiruan
berisi data contoh. Bukan gambar rekaan. Perintahnya:

```
flutter test tool/generate_screenshots.dart
```

| Tangkapan layar | Yang dibuktikan |
| --- | --- |
| `01-mode-pesawat-daftar-dari-cache.png` | Daftar tetap tampil utuh saat offline, dengan badge "Belum sinkron" |
| `02-mode-pesawat-catatan-baru.png` | Catatan yang dibuat lewat editor saat offline masuk antrean; badge naik dari satu ke dua |
| `03-online-setelah-sinkron.png` | Setelah jaringan dinyalakan dan sinkron berjalan, semua badge menjadi "Tersinkron" |

Test yang mengunci hal sama ada di `test/offline_notes_app_test.dart`:
"daftar catatan tampil dari cache lokal saat mode pesawat" dan "tombol Sinkron
nonaktif saat offline dan aktif setelah online".

---

## 7. Batasan yang diketahui

- **Hapus tidak ikut sinkron.** `deleteNote` menghapus baris langsung, jadi
  hapus offline tidak akan pernah sampai ke server. Perbaikannya adalah kolom
  `deleted_at` plus penyaringan tombstone saat `pullAndMerge`.
- **Tidak ada penggabungan karakter.** Konflik diselesaikan dengan memilih
  salah satu versi utuh, bukan merge. Untuk catatan teks bebas, merge otomatis
  hampir selalu menghasilkan teks yang tidak pernah ditulis siapa pun.
- **Server tiruan di memori.** `InMemoryNotesApi` menyimpan data di RAM, jadi
  isinya hilang saat aplikasi ditutup. Itu disengaja agar demo bisa direproduksi
  tanpa backend, dan agar `sync_service.dart` bisa diuji penuh memakai
  `test/support/fakes.dart`.
