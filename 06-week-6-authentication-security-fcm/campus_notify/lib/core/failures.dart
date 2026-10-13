abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Terjadi kesalahan pada server.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Gagal membaca data lokal.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Data tidak ditemukan.']);
}
