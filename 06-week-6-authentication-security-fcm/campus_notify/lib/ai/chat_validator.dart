class ChatValidator {
  static final RegExp _nikPattern = RegExp(r'\b\d{16}\b');
  static final RegExp _phonePattern = RegExp(r'(?:\+62|62|0)8\d{8,12}\b');

  static String validate(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      throw Exception('Pertanyaan tidak boleh kosong.');
    }

    if (_nikPattern.hasMatch(trimmed)) {
      throw Exception(
        'Pertanyaan berisi NIK. Hapus data sensitif '
        'sebelum mengirim ke AI.',
      );
    }

    if (_phonePattern.hasMatch(trimmed)) {
      throw Exception(
        'Pertanyaan berisi nomor telepon. Hapus data sensitif '
        'sebelum mengirim ke AI.',
      );
    }

    return trimmed;
  }
}
