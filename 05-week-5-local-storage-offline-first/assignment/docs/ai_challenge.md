# AI Challenge — Analisis dan Keputusan Penyimpanan Lokal

Bagian ini berisi jejak kerja AI Challenge: prompt yang dipakai, tabel
perbandingan storage lokal, keputusan akhir, dan alasan teknis di baliknya.

---

## 1. Prompt yang dipakai

**Prompt 1 — analisis storage (tanpa menulis kode):**

> Saya sedang membangun aplikasi catatan offline-first di Flutter dengan
> Riverpod. Saat ini preferensi (tema gelap/terang) memakai SharedPreferences
> dan catatan memakai sqflite. Tolong bandingkan SharedPreferences, Hive,
> sqflite, dan Drift untuk dua kasus ini: (a) key-value preferences kecil,
> (b) daftar catatan yang perlu CRUD, urutan `updated_at` terbaru, dan aman
> untuk 1000+ baris. Sertakan rekomendasi final beserta alasan teknis dan
> trade-off yang harus diterima.

**Prompt 2 — desain skema:**

> Dengan rekomendasi itu, tuliskan skema SQL untuk tabel `notes` yang mendukung
> status sinkronisasi, penghapusan, dan index untuk query
> `ORDER BY updated_at DESC` serta `WHERE status = 1`. Lalu jelaskan aturan
> konflik yang eksplisit untuk aplikasi catatan dengan dua perangkat.

**Prompt 3 — validasi:**

> Tinjau ulang implementasinya. Tunjukkan kelemahan yang nyata di kode, dan kalau
> ada klaim yang tidak benar atau berlebihan, katakan.

---

## 2. Tabel perbandingan storage

| Kriteria | SharedPreferences | Hive CE | sqflite | Drift |
| --- | --- | --- | --- | --- |
| Model data | Key-value | Key-value biner | Relasional (SQL) | Relasional (SQL) |
| Query | Tidak ada. Satu key per panggilan | Scan + filter di memori | SQL penuh: JOIN, subquery, agregat, FTS | SQL penuh lewat DSL Dart |
| Reaktivitas | Tidak ada stream; invalidate manual | `box.watch()` memicu ulang seluruh box | Tidak ada stream; notifying manual | `select().watch()` granular |
| Type safety | Lemah; cast di pemanggil | Sedang (`TypeAdapter`) | Lemah; `Map<String, Object?>` | Penuh; kelas generated |
| Kode boilerplate | ±20 baris | ±40 baris + adapter | Besar: `toMap`/`fromMap`, string SQL | Sedang, tapi wajib `build_runner` |
| Biaya test | Murah (`setMockInitialValues`) | Murah (`Hive.init`) | Mahal (butuh `sqflite_common_ffi`) | Termurah (`memory()` per test) |
| Skala 1000+ baris | Tidak relevan | O(n) tiap baca | Aman **kalau ada index** | Aman (index + query plan) |
| Migrasi skema | Tidak ada konsep | `boxVersion` manual | `onUpgrade` SQL manual | `MigrationStrategy` + `stepByStep` |
| Ukuran APK tambahan | ±0 | ±1,5 MB | ±1,5 MB | ±2,5 MB |
| Status di Flutter | Dipakai luas | Mode maintenance | Dipakai luas | Dipakai luas |

---

## 3. Verifikasi klaim AI

Rekomendasi AI adalah memakai **Drift** untuk tabel `notes`, dengan alasan
"butuh reaktivitas granular dan type safety penuh". Saya tidak menerimanya
apa adanya sebagai keputusan final, dengan tiga alasan:

1. **Reaktivitas granular bukan kebutuhannya.** Checklist meminta "daftar
   diurutkan `updated_at` terbaru", bukan "reaktif per baris". Riverpod sudah
   menyediakan reaktivitas di level provider (`AsyncNotifier` di
   `lib/providers/app_providers.dart`). Menambah lapisan kedua lewat
   `watch()` dari Drift menghasilkan dua sumber kebenaran state yang harus
   dijaga sinkron — menambah risiko, bukan mengurangi.
2. **Type safety penuh tidak sebanding dengan biayanya.** Butuh `drift_dev`
   plus `build_runner`, artinya `dart run build_runner build` wajib jalan
   sebelum aplikasi bisa dikompilasi. Untuk lingkup tugas ini seluruh pemetaan
   baris-ke-model berada di satu file (`lib/data/local/note.dart`, dua fungsi)
   dan sudah ada unit test yang memverifikasi `toMap`/`fromMap` bolak-balik.
   Risiko salah mapping sudah ditutup test, bukan oleh tipe.
3. **Migrasi belum jadi masalah.** Skema masih `version: 1`
   (`lib/data/local/db.dart`). Handler `onUpgrade` baru dibutuhkan saat skema
   kedua muncul, dan menambahkannya nanti hanya menyentuh satu fungsi.

Yang saya terima dari analisis AI: perlunya index untuk
`ORDER BY updated_at DESC` dan `WHERE status = 1`. Itu memang kunci performa,
dan sudah dibuat di `createNotesSchema()`.

---

## 4. Keputusan final

| Data | Pilihan | Alasan teknis | Trade-off yang diterima |
| --- | --- | --- | --- |
| Preferensi: tema dan waktu terakhir dibuka | SharedPreferences | Dua key tanpa relasi. Dibaca satu kali di `main()` **sebelum** `runApp` sehingga tema tidak pernah flash. Test paling murah. | Tidak reaktif dan tidak terenkripsi. Perubahan ditulis manual lewat controller. |
| Catatan: CRUD, urutan `updated_at`, status sinkron | sqflite | Butuh query berurutan, agregat `COUNT(*)` untuk badge, dan transaksi saat seeding. Ketiganya gratis di SQL, mahal bila dipaksakan ke key-value. Mapping model terkurung di satu file dan sudah diuji. | Tidak ada stream; reaktivivitas diserahkan ke Riverpod. Mapping manual. `onUpgrade` ditulis manual saat skema berubah. |
| Status sinkronisasi | Satu kolom INTEGER `status` | Tiga kondisi nyata perlu disimpan: sudah sinkron, belum terunggah, dan konflik. Satu integer dengan satu index, bukan dua boolean. | Nilainya harus dijaga kompatibel saat skema berubah. |
| Navigasi | go_router | Rute `/`, `/editor/:id`, `/settings` tanpa state manual per halaman. | Satu dependency tambahan. |

Ringkasnya: **SharedPreferences untuk konfigurasi, sqflite untuk entitas
domain.** Keduanya tidak tumpang tindih, dan pemisahannya mengikuti sifat data.

---

## 5. Alasan teknis di balik keputusan

### 5.1 Menyimpan `ThemeMode`, bukan `bool`

Boolean `dark_mode` menutup satu opsi: "ikuti sistem". Karena itu
`prefs.theme_mode` menyimpan `ThemeMode` (`light`, `dark`, atau `system`) dan
halaman Pengaturan punya tiga pilihan. Konsekuensinya satu key sudah cukup untuk
semua kebutuhan; tidak perlu bool terpisah untuk override sistem.

### 5.2 `updated_at` disimpan sebagai INTEGER

`Note.toMap()` menulis `updatedAt.millisecondsSinceEpoch`. Alasannya langsung
terlihat saat pengurutan:

- SQLite mengurutkan TEXT secara leksikografis. Format ISO yang tidak memakai
  nol di depan akan salah urutan: `"2026-3-2"` terurut sebelum `"2026-10-1"`.
  Format ISO dengan nol di depan benar, tapi hanya asal semua nilai selalu UTC
  dengan presisi tetap, dan itu rapuh begitu ada satu baris yang menyimpang.
- INTEGER dibandingkan secara numerik, jadi `idx_notes_updated` langsung
  terpakai tanpa perlu ekspresi tambahan.

### 5.3 Kenapa satu kolom `status`, bukan boolean `dirty`

Begitu sinkronisasi ditambahkan, ada tiga keadaan nyata:

| Keadaan | Arti |
| --- | --- |
| `synced` | server sudah mengonfirmasi isi terbaru |
| `pendingUpload` | ada suntingan lokal yang belum dikirim (ini "dirty") |
| `conflicted` | server dan lokal sama-sama berubah, menunggu keputusan pengguna |

Dengan hanya satu boolean, keadaan ketiga harus disimulasikan lewat bool
`true` plus kolom tambahan, atau dibiarkan menumpuk di antrean — dan
`syncNotes()` bisa tanpa sengaja menimpa pekerjaan pengguna lain. Test di
`test/sync_service_test.dart` mengunci perilaku itu:

```dart
test('catatan konflik tidak ikut terunggah pada putaran berikutnya', () async {
  await service.syncNotes();
  expect(api.serverNotes, isEmpty);
});
```

### 5.4 Kenapa `NotesApi` berupa interface

Sinkronisasi adalah bagian yang paling rawan bug dan paling sulit diuji lewat
UI. Antarmukanya dibuat tipis supaya aplikasi tetap bisa dijalankan penuh
tanpa backend (server tiruan di memori, sehingga demo mode pesawat selalu punya
isi), dan test bisa menyuntikkan `AlwaysFailingNotesApi` (jaringan ada tapi
server mati) serta `ImmediateNotesApi` (tanpa latensi) tanpa mengubah kode
sinkronisasi sama sekali. Dengan begitu "jaringan putus" dan "server error" diuji
sebagai dua kasus terpisah, bukan satu kondisi yang disamarkan.

---

## 6. Yang sengaja tidak dikerjakan

Dinyatakan terbuka supaya batas pekerjaannya jelas:

- **Tombstone dan hapus permanen.** `deleteNote` menghapus baris langsung,
  sehingga hapus offline tidak ikut ke server. Perbaikannya adalah kolom
  `deleted_at` plus penyaringan tombstone saat `pullAndMerge`. Belum dikerjakan
  karena tidak diminta checklist, dan menambahkannya tanpa mekanisme penghiripan
  akan membuat konflik lebih sulit ditebak.
- **Pencarian full-text (FTS5).** Kode saat ini melakukan pengurutan dan filter
  status di SQL; FTS5 baru relevan kalau ada kotak pencarian.
- **Penggabungan otomatis saat konflik.** Yang dipakai adalah last-write-wins
  ditambah eskalasi ke pengguna. Untuk catatan teks bebas, merge otomatis
  hampir selalu menghasilkan teks yang tidak pernah ditulis siapa pun.

Detail aturan sinkronisasinya ada di [`offline_first.md`](offline_first.md).
