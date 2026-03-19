import 'dart:io';
import 'dart:typed_data';

class CleanupReport {
  const CleanupReport({
    required this.deletedPaths,
    required this.failedPaths,
    required this.zeroedBuffers,
  });

  final List<String> deletedPaths;
  final List<String> failedPaths;
  final int zeroedBuffers;
}

class SecureCleanupPolicy {
  const SecureCleanupPolicy();

  Future<CleanupReport> cleanup({
    required List<String> rawArtifactPaths,
    List<Uint8List> inMemoryBuffers = const <Uint8List>[],
  }) async {
    final deleted = <String>[];
    final failed = <String>[];

    for (final path in rawArtifactPaths) {
      final file = File(path);
      final directory = Directory(path);

      try {
        if (await file.exists()) {
          await file.delete();
          deleted.add(path);
          continue;
        }

        if (await directory.exists()) {
          await directory.delete(recursive: true);
          deleted.add(path);
        }
      } catch (_) {
        failed.add(path);
      }
    }

    var zeroed = 0;
    for (final buffer in inMemoryBuffers) {
      for (var i = 0; i < buffer.length; i++) {
        buffer[i] = 0;
      }
      zeroed += 1;
    }

    return CleanupReport(
      deletedPaths: deleted,
      failedPaths: failed,
      zeroedBuffers: zeroed,
    );
  }
}