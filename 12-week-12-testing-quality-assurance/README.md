# LAPORAN PRAKTIKUM
# MINGGU 12 – TESTING & QUALITY ASSURANCE IN FLUTTER

## 1. Tujuan Praktikum

Praktikum ini bertujuan untuk memahami dan menerapkan proses pengujian (testing) pada aplikasi Flutter. Pengujian dilakukan untuk memastikan setiap bagian aplikasi dapat berjalan sesuai dengan fungsinya, mulai dari validasi logika, pengelolaan dependensi, tampilan antarmuka, hingga alur utama aplikasi.

Pada praktikum ini, pengujian diterapkan pada project **Campus Notify**, khususnya fitur AI Chat. Pengujian dilakukan menggunakan unit testing, repository testing, widget testing, dan integration testing.

## 2. Fitur yang Diuji

Fitur yang digunakan dalam praktikum ini adalah **AI Chat** pada aplikasi Campus Notify.

Fitur ini memungkinkan pengguna untuk mengirimkan pertanyaan kepada AI Assistant dan menerima jawaban secara otomatis. Selain itu, aplikasi juga memiliki validasi pesan untuk mencegah input kosong dan data sensitif tertentu, serta penanganan ketika terjadi kegagalan komunikasi dengan layanan AI.

## 3. Skenario Pengujian

Sebelum melakukan pengujian, ditentukan beberapa skenario untuk memastikan perilaku aplikasi berjalan sesuai harapan.

| No. | Skenario Pengujian | Hasil yang Diharapkan |
|---|---|---|
| 1 | Pengguna membuka halaman AI Chat | Halaman AI Chat ditampilkan dengan benar |
| 2 | Pengguna mengirim pertanyaan valid | Pesan berhasil dikirim dan respons AI ditampilkan |
| 3 | Pengguna mengirim pesan kosong | Sistem menolak pesan dan tidak mengirim permintaan |
| 4 | Pengguna memasukkan NIK 16 digit | Sistem menolak input tersebut |
| 5 | Layanan AI mengalami kegagalan | Sistem menampilkan pesan kesalahan |
| 6 | Aplikasi berada dalam kondisi offline | Sistem dapat menangani kegagalan koneksi |
| 7 | Pengguna mencoba mengirim pesan berulang saat proses berlangsung | Sistem mencegah pengiriman berulang selama proses berlangsung |

Skenario tersebut mencakup kondisi normal, kasus tepi (edge case), input tidak valid, dan kondisi kegagalan (failure).

## 4. Implementasi Pengujian

### 4.1 Unit Testing

Unit testing dilakukan untuk menguji fungsi validasi pesan secara terpisah dari bagian aplikasi lainnya.

Pengujian validasi dibuat pada file:

`test/ai/chat_validator_test.dart`

Fungsi validasi yang diuji berada pada:

`lib/ai/chat_validator.dart`

Pengujian mencakup:
- Memastikan pesan valid dapat diterima.
- Memastikan pesan kosong ditolak.
- Memastikan spasi di awal dan akhir pesan dihilangkan.
- Memastikan input NIK 16 digit ditolak.
- Memastikan format nomor telepon tertentu ditolak.
- Memastikan pesan yang valid dikembalikan dalam bentuk teks yang sudah dibersihkan.

Pengujian dikelompokkan menggunakan fungsi `group` agar setiap kasus pengujian lebih terstruktur.

Hasil pengujian:

**6 unit test berhasil dijalankan.**

### 4.2 Repository Testing dan Fake Repository

Repository testing dilakukan untuk menguji komunikasi antara fitur AI Chat dan sumber data tanpa harus bergantung pada layanan AI yang sebenarnya.

Untuk memisahkan logika aplikasi dari layanan AI, dibuat sebuah kontrak repository bernama `AiRepository`.

File yang digunakan:
- `lib/ai/ai_repository.dart`
- `lib/ai/ai_service.dart`
- `test/fakes/fake_ai_repository.dart`
- `test/ai/ai_repository_test.dart`

`AiRepository` berfungsi sebagai kontrak yang mendefinisikan operasi AI, seperti mengirim pertanyaan, menyimpan API key, melakukan transkripsi suara, mengenali teks dari gambar, dan memahami gambar.

Selanjutnya, `FakeAiRepository` digunakan sebagai pengganti layanan AI sebenarnya selama proses pengujian.

Fake repository menyediakan dua kondisi utama:
1. **Kondisi berhasil:** repository mengembalikan respons sesuai konfigurasi.
2. **Kondisi gagal:** repository menghasilkan exception untuk mensimulasikan kegagalan layanan.

Dengan pendekatan ini, pengujian dapat dilakukan tanpa harus bergantung pada koneksi internet atau API AI yang sebenarnya.

Hasil pengujian repository menunjukkan bahwa respons berhasil, kondisi kegagalan, dan respons khusus dapat diuji sesuai konfigurasi fake.

### 4.3 Widget Testing

Widget testing dilakukan untuk memastikan komponen antarmuka AI Chat dapat ditampilkan dan berinteraksi sesuai dengan fungsinya.

Pengujian dibuat pada file:

`test/features/chat_screen_test.dart`

Pengujian mencakup:
1. Memastikan halaman AI Chat ditampilkan dengan benar.
2. Memastikan pesan kosong tidak dikirim ke repository.
3. Memastikan pesan berhasil dikirim dan respons fake AI ditampilkan.
4. Memastikan aplikasi menampilkan dialog kesalahan ketika API gagal serta informasi Offline Mode.

Pada pengujian ini digunakan `FakeAiRepository` agar respons dapat dikontrol dan tidak bergantung pada layanan eksternal.

Hasil pengujian:

**4 widget test berhasil dijalankan.**

### 4.4 Integration Testing

Integration testing dilakukan untuk menguji alur utama aplikasi dengan melibatkan beberapa bagian sekaligus.

Pengujian dibuat pada file:

`integration_test/app_test.dart`

Skenario pengujian yang dilakukan adalah pengguna membuka halaman AI Chat, memasukkan pesan, mengirim pesan, kemudian menerima respons dari AI Assistant.

Tahapan pengujian:
1. Membuat konfigurasi `FakeAiRepository` dengan respons yang telah ditentukan.
2. Menjalankan aplikasi menggunakan `MyApp`.
3. Memastikan halaman AI Chat berhasil ditampilkan.
4. Memasukkan pesan "Halo AI" ke kolom input.
5. Menekan tombol kirim.
6. Memastikan pesan pengguna muncul pada halaman.
7. Memastikan respons "Halo! Saya AI Assistant." ditampilkan.
8. Memastikan repository menerima satu permintaan dengan pertanyaan yang benar.

Pengujian dijalankan menggunakan perangkat Android dengan perintah:

`flutter test integration_test/app_test.dart -d 10DE6D0L890005X`

Hasil pengujian:

**1 integration test berhasil dijalankan pada perangkat Android.**

## 5. Hasil Pengujian

Setelah seluruh pengujian dibuat, dilakukan pemeriksaan menggunakan perintah Flutter.

### 5.1 Menjalankan Seluruh Unit dan Widget Test

Perintah:

`flutter test`

Hasil:

`00:12 +29: All tests passed!`

Seluruh pengujian berhasil dijalankan dengan total 29 test tanpa kegagalan.

### 5.2 Menjalankan Integration Test

Perintah:

`flutter test integration_test/app_test.dart -d 10DE6D0L890005X`

Hasil:

`05:49 +1: All tests passed!`

Integration test berhasil dijalankan pada perangkat Android. Alur pengiriman pesan dan penerimaan respons AI berhasil diuji.

### 5.3 Melakukan Analisis Kode

Perintah:

`flutter analyze`

Hasil pemeriksaan menunjukkan terdapat dua warning, yaitu deklarasi `_noRetry` yang tidak digunakan pada file:
- `lib/features/auth/presentation/providers/auth_providers.dart` baris 25.
- `lib/features/notes/presentation/providers/notes_providers.dart` baris 51.

Kedua warning tersebut berkaitan dengan deklarasi yang tidak digunakan dan bukan merupakan error kompilasi pada implementasi pengujian AI Chat.

## 6. Kesimpulan

Berdasarkan praktikum yang telah dilakukan, pengujian aplikasi Flutter berhasil diterapkan pada fitur AI Chat di project Campus Notify.

Pengujian dilakukan melalui empat pendekatan, yaitu unit testing untuk memeriksa logika validasi, repository testing untuk menguji dependensi menggunakan fake repository, widget testing untuk memeriksa tampilan dan interaksi pengguna, serta integration testing untuk memastikan alur utama aplikasi berjalan dengan baik.

Hasil pengujian menunjukkan bahwa seluruh 29 test pada `flutter test` berhasil dijalankan dan integration test pada perangkat Android juga berhasil. Sementara itu, hasil `flutter analyze` menunjukkan dua warning terkait deklarasi yang tidak digunakan.

Dengan demikian, penerapan testing membantu memastikan fungsi utama AI Chat berjalan sesuai dengan skenario yang telah ditentukan serta mempermudah proses identifikasi kesalahan pada aplikasi.