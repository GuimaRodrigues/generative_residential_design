// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html';

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
    final blob = Blob(<Object>[contents], mimeType);
    final url = Url.createObjectUrlFromBlob(blob);
    AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    scheduleMicrotask(() => Url.revokeObjectUrl(url));
  }

  Future<ImportedText?> pickText({String accept = '.json'}) async {
    final input = FileUploadInputElement()..accept = accept;
    input.click();
    await input.onChange.first;
    final file = input.files?.firstOrNull;
    if (file == null) return null;
    final reader = FileReader()..readAsText(file);
    await reader.onLoad.first;
    final result = reader.result;
    if (result is! String) {
      throw const FormatException(
        'The selected file could not be read as text.',
      );
    }
    return ImportedText(name: file.name, contents: result);
  }
}
