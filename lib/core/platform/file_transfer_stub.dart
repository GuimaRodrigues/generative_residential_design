class ImportedText {
  const ImportedText({required this.name, required this.contents});
  final String name;
  final String contents;
}

class BrowserFileTransfer {
  const BrowserFileTransfer();

  void downloadText({
    required String filename,
    required String contents,
    required String mimeType,
  }) {
    throw UnsupportedError(
      'Browser downloads are only available on Flutter Web.',
    );
  }

  Future<ImportedText?> pickText({String accept = '.json'}) {
    throw UnsupportedError(
      'Browser file selection is only available on Flutter Web.',
    );
  }
}
