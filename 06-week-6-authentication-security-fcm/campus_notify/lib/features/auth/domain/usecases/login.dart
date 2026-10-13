import '../../../../core/failures.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Use case login: memegang aturan bisnis validasi sebelum memanggil
/// repository. Berbeda dengan operasi CRUD, validasi inilah yang membuat
/// use case ini layak berdiri sendiri.
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const ValidationFailure('Email tidak valid.');
    }
    if (password.length < 6) {
      throw const ValidationFailure('Kata sandi minimal 6 karakter.');
    }
    return _repository.login(email: trimmedEmail, password: password);
  }
}
