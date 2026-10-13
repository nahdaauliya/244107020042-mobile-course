import '../entities/auth_session.dart';

/// Kontrak autentikasi. Layer data menyediakan implementasinya; layer lain
/// hanya bergantung pada abstraksi ini.
abstract class AuthRepository {
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<String> refresh(String refreshToken);
}
