import '../../../../core/failures.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      // REPLACE dengan FirebaseAuth.instance.signInWithEmailAndPassword
      // atau GoogleSignIn saat backend siap.
      await Future.delayed(const Duration(milliseconds: 500));
      return AuthSession(
        access: 'mock-access-for-$email',
        refresh: 'mock-refresh-for-$email',
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure(
        'Gagal masuk. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  @override
  Future<String> refresh(String refreshToken) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (refreshToken.isEmpty) {
        throw const AuthFailure('Sesi berakhir. Silakan masuk kembali.');
      }
      return 'mock-access-renewed-${DateTime.now().millisecondsSinceEpoch}';
    } on Failure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure('Gagal memperbarui sesi login.');
    }
  }
}
