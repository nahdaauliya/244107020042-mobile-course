# Hasil Tiga Grep Verifikasi

Dijalankan pada `campus_notify` (HEAD `46edb4f`, plus perubahan working tree).
Perintah ditulis dalam bentuk `rg` (sesuai codelab). `rg` tidak terpasang di
mesin ini, jadi dijalankan lewat `Select-String` dengan pola yang identik.

## Grep 1 — Domain bebas dari Flutter/Dio/SQLite/Firebase

```bash
rg "import 'package:(flutter|dio|sqflite|firebase)" lib/features/*/domain lib/core
```

```powershell
Get-ChildItem -Recurse -File lib/features/*/domain, lib/core |
  Select-String -Pattern "import 'package:(flutter|dio|sqflite|firebase)"
```

Hasil: **NO MATCHES** ✅
Interpretasi: tidak ada satu pun file domain/core yang mengimpor framework,
klien HTTP, database, atau Firebase. Domain benar-benar murni Dart.

## Grep 2 — Entity bebas mapping (mapping hanya di model)

```bash
rg "toMap|fromMap|toJson|fromJson" lib/features/*/domain
```

```powershell
Get-ChildItem -Recurse -File lib/features/*/domain |
  Select-String -Pattern "toMap|fromMap|toJson|fromJson"
```

Hasil: **NO MATCHES** ✅
Interpretasi: serialization hanya ada di layer data
(`note_model.dart`, `announcement_model.dart`). `Note`/`Announcement` sebagai
entity tidak tahu cara map ke database/JSON.

## Grep 3 — Widget/presentation tidak menginstansiasi dependency sendiri

```bash
rg "RepositoryImpl\(|Repository\(\)|Dio\(|openDatabase" lib/features/*/presentation lib/pages
```

```powershell
Get-ChildItem -Recurse -File lib/features/*/presentation, lib/pages |
  Select-String -Pattern "RepositoryImpl\(|Repository\(\)|Dio\(|openDatabase"
```

Hasil: **NO MATCHES** ✅
Interpretasi: tidak ada widget atau file presentation yang membuat
`Repository`, `Dio`, atau membuka database sendiri. Semua dependency dirakit
di provider Riverpod (`notes_providers.dart`).

## Grep tambahan (pemeriksaan struktural)

```bash
# interface repository tidak boleh berada di data
rg "abstract class .*Repository" lib/features/*/data
# implementasi repository tidak boleh berada di domain
rg "implements .*Repository" lib/features/*/domain
```

Hasil: **NO MATCHES** ✅
Interpretasi: interface hanya di `domain/repositories`, implementasi hanya di
`data/repositories` — dependency rule terjaga.

## Status analisis & test (step 3 codelab)

```bash
flutter analyze   # -> No issues found!
flutter test      # -> All tests passed! (5/5)
```
