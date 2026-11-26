import 'dart:io';

abstract class AiRepository {
  Future<String> ask(String question);

  Future<void> saveApiKey(String key);

  Future<String> speechToText(File audioFile);

  Future<String> recognizeText(File imageFile);

  Future<String> understandImage(
    File imageFile, {
    String question = 'Describe this image in detail.',
  });
}
