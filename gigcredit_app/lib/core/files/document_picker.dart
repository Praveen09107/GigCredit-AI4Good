import 'package:file_picker/file_picker.dart';

class DocumentPicker {
  const DocumentPicker._();

  static Future<PlatformFile?> pickSingle({
    bool imageOnly = false,
    bool pdfOnly = false,
  }) async {
    final allowPdfOnly = !imageOnly && pdfOnly;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: imageOnly ? FileType.image : FileType.custom,
      allowedExtensions: imageOnly
          ? null
          : (allowPdfOnly ? <String>['pdf'] : <String>['jpg', 'jpeg', 'png', 'pdf']),
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.first;
  }
}
