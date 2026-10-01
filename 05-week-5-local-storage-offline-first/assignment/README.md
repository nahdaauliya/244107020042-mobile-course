# Offline Notes

Aplikasi catatan **offline-first** berbasis Flutter. Semua bacaan datang dari
SQLite lokal lebih dulu, sehingga daftar catatan tetap tampil utuh tanpa
jaringan. Perubahan lokal disimpan sebagai dirty flag dan dikirim ke server
begitu koneksi tersedia, dengan aturan konflik yang ditulis eksplisit dan
minta keputusan pengguna bila kedua sisi benar-benar berubah.

## Fitur

| Fitur | Perilaku |
| --- | --- |
| CRUD catatan | Buat, baca, ubah, hapus; tersimpan permanen di SQLite |
| Urutan daftar | `updated_at` terbaru selalu di atas |
| Mode gelap/terang | Tiga pilihan: Ikuti sistem, Terang, Gelap |
| Waktu terakhir dibuka | Disimpan lewat SharedPreferences, ditampilkan di Pengaturan |
| Badge dirty | "Belum sinkron" per catatan dan penghitung di app bar |
| Bukti mode pesawat | Daftar tetap tampil saat offline; sinkron ditunda, bukan gagal |
| Konflik eksplisit | Last-write-wins bila satu sisi berubah; sheet resolusi bila dua sisi berubah |
| Penghitung konflik | Badge di app bar membuka daftar yang menunggu keputusan |

## Teknologi

| Lapisan | Pilihan |
| --- | --- |
| State management | Riverpod (`AsyncNotifier`, `FutureProvider`, `Notifier`) |
| Penyimpanan entitas | sqflite (SQLite) |
| Penyimpanan preferensi | SharedPreferences |
| Navigasi | go_router |
| Test | flutter_test dengan repository dan API palsu |

Alasan pemilihan storage ada di
[`docs/ai_challenge.md`](docs/ai_challenge.md).

## Cara menjalankan

```bash
flutter pub get
flutter run
```

Tanpa backend pun aplikasi ini bisa dijalankan penuh: `NotesApi` memakai
`InMemoryNotesApi` sebagai server tiruan di memori, dan status jaringan
dapat dimatikan lewat menu **Pengaturan > Mode pesawat**.

## Struktur folder

```
lib/
  main.dart                          bootstrap, router, tema, prompt konflik
  data/
    local/note.dart                  model Note + SyncStatus
    local/db.dart                    skema SQLite dan index
    remote/notes_api.dart            antarmuka API + server tiruan
    repositories/note_repository.dart  satu-satunya sumber kebenaran catatan
    repositories/prefs_repository.dart tema dan waktu terakhir dibuka
    sync/conflict_resolver.dart      aturan konflik sebagai fungsi murni
    sync/sync_service.dart           cache-first, syncNotes, resolusi
  providers/app_providers.dart       seluruh provider Riverpod
  pages/                             daftar, editor, pengaturan
  widgets/                           badge, banner, tile, sheet konflik
test/                                unit, provider, sinkronisasi, widget
tool/generate_screenshots.dart       generator tangkapan layar
docs/                                analisis storage dan aturan offline-first
screenshots/                         bukti mode pesawat, tema, konflik
```

## Test

```bash
flutter analyze
flutter test
```

Hasil terakhir: **analyzer bersih** dan **32 test lulus**. Cakupannya:

| Berkas | Yang diuji |
| --- | --- |
| `test/note_test.dart` | Serialisasi model, status dirty, pengurutan |
| `test/notes_provider_test.dart` | Provider dengan repository palsu: CRUD, urutan, badge |
| `test/sync_service_test.dart` | Aturan konflik, antrean unggah, server menolak, jaringan mati |
| `test/offline_notes_app_test.dart` | Widget: daftar tampil saat offline, tombol Sinkron |

## Bukti

Tangkapan layar dibuat dari widget tree aplikasi yang sungguhan, bukan gambar
rekaan:

```bash
flutter test tool/generate_screenshots.dart
```

| Berkas | Isi |
| --- | --- |
| `screenshots/01-mode-pesawat-daftar-dari-cache.png` | Mode pesawat aktif, daftar dari cache, badge "Belum sinkron" |
| `screenshots/02-mode-pesawat-catatan-baru.png` | Catatan baru dibuat lewat editor saat offline; badge naik ke dua |
| `screenshots/03-online-setelah-sinkron.png` | Setelah online dan sinkron berjalan, semua badge "Tersinkron" |
| `screenshots/04-daftar-tema-gelap.png` | Daftar utama bertema gelap |
| `screenshots/05-editor-tema-gelap.png` | Editor bertema gelap |
| `screenshots/06-konflik-perlu-diputuskan.png` | Sheet konflik: pakai versi ini atau versi server |
| `screenshots/07-pengaturan-preferensi.png` | Tema, mode pesawat, waktu terakhir dibuka, lokasi database |
| `screenshots/08-daftar-kosong.png` | Keadaan daftar kosong |

Pasangan 01 dan 03 adalah bukti badge dirty sebelum dan sesudah sinkron;
pasangan 01 dan 02 adalah bukti daftar tetap tampil saat tidak ada jaringan.

## Dokumentasi

- [`docs/ai_challenge.md`](docs/ai_challenge.md): prompt, tabel perbandingan
  SharedPreferences/Hive/sqflite/Drift, keputusan akhir, dan alasan teknisnya.
- [`docs/offline_first.md`](docs/offline_first.md): alur cache-first, dirty
  flag, skema SQL, tabel aturan konflik, batasan yang diketahui.

## Batasan yang diketahui

- Hapus catatan belum ikut sinkron; `deleteNote` menghapus baris langsung, jadi
  hapus offline tidak akan sampai ke server.
- Konflik diselesaikan dengan memilih salah satu versi utuh, bukan merge
  karakter.
- `InMemoryNotesApi` menyimpan data di memori, jadi isinya hilang saat aplikasi
  ditutup. Ini disengaja agar demo dapat direproduksi tanpa backend.
