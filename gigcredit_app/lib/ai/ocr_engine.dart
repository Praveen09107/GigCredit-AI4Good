import 'dart:async';
import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import '../config/app_mode.dart';
import 'ai_interfaces.dart';
import 'ai_native_bridge.dart';

const String kPasswordProtectedPdfMarker = 'PDF_PASSWORD_PROTECTED';

class BridgePaddleOcrEngine implements OcrEngine {
  BridgePaddleOcrEngine({
    required this.bridge,
    bool? requireProductionReadiness,
    Duration? healthCheckTimeout,
    Duration? primaryPassTimeout,
    Duration? secondaryPassTimeout,
  }) : _requireProductionReadiness =
            requireProductionReadiness ?? AppMode.requireProductionReadiness,
       _healthCheckTimeout = healthCheckTimeout ?? const Duration(seconds: 4),
       _primaryPassTimeout = primaryPassTimeout ?? const Duration(seconds: 8),
       _secondaryPassTimeout = secondaryPassTimeout ?? const Duration(seconds: 8);

  final NativeAiBridge bridge;
  final bool _requireProductionReadiness;
  final Duration _healthCheckTimeout;
  final Duration _primaryPassTimeout;
  final Duration _secondaryPassTimeout;

  static const int _maxInputBytes = 15 * 1024 * 1024; // 15 MB
  static final double _minConfidence = AppMode.ocrConfidenceThreshold;

  @override
  Future<OcrResult> extractText(List<int> imageBytes) async {
    if (imageBytes.isEmpty) {
      return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
    }

    if (imageBytes.length > _maxInputBytes) {
      return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
    }

    if (_looksLikePdf(imageBytes) && _isPasswordProtectedPdf(imageBytes)) {
      return const OcrResult(
        rawText: kPasswordProtectedPdfMarker,
        confidence: 0.0,
        lowConfidence: true,
      );
    }

    try {
      final health = await bridge.getHealth().timeout(_healthCheckTimeout);
      if (!health.supportsOcr) {
        return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
      }

      final native = await bridge.extractText(
        imageBytes,
        meta: <String, Object?>{
          'engine': 'paddle_ocr_lite',
          'supportsPdf': true,
          'byteCount': imageBytes.length,
          'ocr_pass': 'primary_english',
        },
      ).timeout(_primaryPassTimeout);

      final primary = _normalizeResult(native);
      OcrResult best = primary;

      // Spec alignment: if confidence is low, run an additional pass and merge complementary results.
      if (_isLowConfidence(primary)) {
        final secondary = await _trySecondaryRegionalPass(imageBytes);
        if (secondary != null) {
          best = _mergePassResults(primary, secondary);
        }
      }

      final low = _isLowConfidence(best);

      if (_requireProductionReadiness && (best.rawText.trim().isEmpty || low)) {
        return OcrResult(
          rawText: best.rawText,
          confidence: best.confidence,
          blocks: best.blocks,
          lowConfidence: true,
        );
      }

      return OcrResult(
        rawText: best.rawText,
        confidence: best.confidence,
        blocks: best.blocks,
        lowConfidence: low,
      );
    } on NativeBridgeException {
      return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
    } on TimeoutException {
      return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
    }
  }

  Future<OcrResult?> _trySecondaryRegionalPass(List<int> imageBytes) async {
    try {
      final second = await bridge.extractText(
        imageBytes,
        meta: <String, Object?>{
          'engine': 'paddle_ocr_lite',
          'byteCount': imageBytes.length,
          'ocr_pass': 'secondary_regional',
          'language_hint': 'regional',
        },
      ).timeout(_secondaryPassTimeout);
      return _normalizeResult(second);
    } on NativeBridgeException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  OcrResult _normalizeResult(OcrResult input) {
    final normalizedText = _sanitizeText(input.rawText);
    final blocks = input.blocks.isEmpty
        ? _blocksFromRawText(normalizedText, input.confidence)
        : input.blocks;
    final avg = _averageConfidence(blocks, input.confidence);
    return OcrResult(
      rawText: normalizedText,
      confidence: avg,
      blocks: blocks,
      lowConfidence: avg < _minConfidence,
    );
  }

  bool _isLowConfidence(OcrResult value) {
    return value.confidence < _minConfidence ||
        value.rawText.trim().isEmpty ||
        value.rawText.contains(kPasswordProtectedPdfMarker);
  }

  OcrResult _pickBetter(OcrResult primary, OcrResult secondary) {
    if (secondary.rawText.trim().isEmpty) {
      return primary;
    }
    if (secondary.confidence > primary.confidence) {
      return secondary;
    }
    if (secondary.confidence == primary.confidence &&
        secondary.rawText.length > primary.rawText.length) {
      return secondary;
    }
    return primary;
  }

  OcrResult _mergePassResults(OcrResult primary, OcrResult secondary) {
    final better = _pickBetter(primary, secondary);
    final other = identical(better, primary) ? secondary : primary;

    final mergedText = _mergeRawText(better.rawText, other.rawText);
    final mergedBlocks = _mergeBlocks(
      better.blocks.isEmpty ? _blocksFromRawText(better.rawText, better.confidence) : better.blocks,
      other.blocks.isEmpty ? _blocksFromRawText(other.rawText, other.confidence) : other.blocks,
    );

    final mergedConfidence = _averageConfidence(
      mergedBlocks,
      better.confidence > other.confidence ? better.confidence : other.confidence,
    );

    return OcrResult(
      rawText: mergedText,
      confidence: mergedConfidence,
      blocks: mergedBlocks,
      lowConfidence: mergedConfidence < _minConfidence || mergedText.trim().isEmpty,
    );
  }

  static String _mergeRawText(String preferred, String secondary) {
    final seen = <String>{};
    final ordered = <String>[];

    void addLines(String source) {
      for (final line in source
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)) {
        final key = line.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        if (seen.add(key)) {
          ordered.add(line);
        }
      }
    }

    addLines(preferred);
    addLines(secondary);
    return ordered.join('\n');
  }

  static List<OcrBlock> _mergeBlocks(List<OcrBlock> primary, List<OcrBlock> secondary) {
    final merged = <OcrBlock>[];
    final seen = <String, int>{};

    void addOrReplace(OcrBlock block) {
      final key = block.text.trim().toLowerCase();
      if (key.isEmpty) {
        return;
      }
      final existingIndex = seen[key];
      if (existingIndex == null) {
        seen[key] = merged.length;
        merged.add(block);
        return;
      }
      if (block.confidence > merged[existingIndex].confidence) {
        merged[existingIndex] = block;
      }
    }

    for (final block in primary) {
      addOrReplace(block);
    }
    for (final block in secondary) {
      addOrReplace(block);
    }

    return merged;
  }

  static String _sanitizeText(String input) {
    return input
        .replaceAll('\u0000', ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ')
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  static List<OcrBlock> _blocksFromRawText(String text, double confidence) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return lines
        .map((line) => OcrBlock(text: line, confidence: confidence.clamp(0.0, 1.0)))
        .toList(growable: false);
  }

  static double _averageConfidence(List<OcrBlock> blocks, double fallback) {
    if (blocks.isEmpty) {
      return fallback.clamp(0.0, 1.0);
    }
    final total = blocks.fold<double>(0.0, (acc, block) => acc + block.confidence);
    return (total / blocks.length).clamp(0.0, 1.0);
  }
}

class PdfTextStreamOcrEngine implements OcrEngine {
  const PdfTextStreamOcrEngine();

  @override
  Future<OcrResult> extractText(List<int> imageBytes) async {
    if (_looksLikePdf(imageBytes) && _isPasswordProtectedPdf(imageBytes)) {
      return const OcrResult(
        rawText: kPasswordProtectedPdfMarker,
        confidence: 0.0,
        lowConfidence: true,
      );
    }

    final pdfText = _extractPdfText(imageBytes);
    if (pdfText.length > 100) {
      final realBlocks = <OcrBlock>[];
      for (final line in pdfText
          .split(RegExp(r'\r?\n'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)) {
        realBlocks.add(OcrBlock(text: line, confidence: 0.58));
      }

      return OcrResult(
        rawText: pdfText,
        confidence: 0.58,
        blocks: realBlocks,
        lowConfidence: true,
      );
    }

    // If direct extraction is weak, treat document as scanned and perform OCR-style byte decode fallback.
    final utf8Text = utf8.decode(imageBytes, allowMalformed: true).trim();
    if (_looksLikeReadableText(utf8Text)) {
      final blocks = utf8Text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => OcrBlock(text: line, confidence: 0.45))
          .toList(growable: false);
      return OcrResult(
        rawText: utf8Text,
        confidence: 0.45,
        blocks: blocks,
        lowConfidence: true,
      );
    }

    return const OcrResult(rawText: '', confidence: 0.0, lowConfidence: true);
  }

  static String _extractPdfText(List<int> bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final out = StringBuffer();

    final directTextMatches = RegExp(r'\(([^\)]{3,})\)\s*Tj').allMatches(raw);
    for (final match in directTextMatches) {
      out.writeln(_decodePdfEscaped(match.group(1) ?? ''));
    }

    final streamRegex = RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream');
    for (final match in streamRegex.allMatches(raw)) {
      final payloadText = match.group(1) ?? '';
      if (payloadText.isEmpty) {
        continue;
      }

      final streamBytes = Uint8List.fromList(payloadText.codeUnits.map((c) => c & 0xFF).toList());
      final inflated = _tryInflate(streamBytes);
      if (inflated == null || inflated.isEmpty) {
        continue;
      }

      final content = latin1.decode(inflated, allowInvalid: true);
      for (final tj in RegExp(r'\(([^\)]{2,})\)\s*Tj').allMatches(content)) {
        out.writeln(_decodePdfEscaped(tj.group(1) ?? ''));
      }

      for (final tjArray in RegExp(r'\[(.*?)\]\s*TJ').allMatches(content)) {
        final segment = tjArray.group(1) ?? '';
        for (final textToken in RegExp(r'\(([^\)]*)\)').allMatches(segment)) {
          final token = _decodePdfEscaped(textToken.group(1) ?? '');
          if (token.isNotEmpty) {
            out.write(token);
            out.write(' ');
          }
        }
        out.writeln();
      }
    }

    return out
      .toString()
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  }

  static List<int>? _tryInflate(Uint8List input) {
    try {
      return zlib.decode(input);
    } catch (_) {
      return null;
    }
  }

  static String _decodePdfEscaped(String value) {
    return value
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', '\\')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\r', ' ')
        .trim();
  }

  static bool _looksLikeReadableText(String text) {
    if (text.isEmpty || text.length < 16) {
      return false;
    }
    final printable = RegExp(r'[A-Za-z0-9]').allMatches(text).length;
    return printable >= 8;
  }
}

bool _looksLikePdf(List<int> bytes) {
  if (bytes.length < 4) {
    return false;
  }
  return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46;
}

bool _isPasswordProtectedPdf(List<int> bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Encrypt\b').hasMatch(raw) || RegExp(r'/Filter\s*/Standard\b').hasMatch(raw);
}
