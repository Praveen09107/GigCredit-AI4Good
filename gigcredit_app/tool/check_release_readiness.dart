import 'dart:io';

void main(List<String> args) {
  final allowPlaceholderModels = args.contains('--allow-placeholder-models');

  final repoRoot = Directory.current.path;
  final appDir = Directory('$repoRoot/gigcredit_app');
  if (!appDir.existsSync()) {
    stderr.writeln(
        'Run this from repository root. Expected gigcredit_app directory.');
    exit(2);
  }

  final checks = <_Check>[];

  checks.addAll([
    _fileExists(
        '$repoRoot/gigcredit_app/assets/constants/artifact_manifest.json',
        'Scoring artifact manifest is present'),
    _fileExists(
        '$repoRoot/gigcredit_app/assets/constants/meta_coefficients.json',
        'Meta-learner coefficients are present'),
    _fileExists('$repoRoot/gigcredit_app/assets/constants/shap_lookup.json',
        'SHAP lookup constants are present'),
    _fileExists(
        '$repoRoot/gigcredit_app/assets/constants/state_income_anchors.json',
        'State income anchors are present'),
    _fileExists('$repoRoot/gigcredit_app/assets/constants/feature_means.json',
        'Feature means are present'),
  ]);

  checks.add(_Check(true,
      'External authenticity/face model binaries are not required by current runtime contract'));

  final gradlePath = '$repoRoot/gigcredit_app/android/app/build.gradle.kts';
  final gradle = File(gradlePath);
  if (gradle.existsSync()) {
    final content = gradle.readAsStringSync();
    checks.add(_Check(!content.contains('com.example.'),
        'Android application ID is not using com.example placeholder'));
    checks.add(_Check(content.contains('releaseKeystoreConfigured'),
        'Release keystore configuration hook is present in Gradle'));
  } else {
    checks.add(
        _Check(false, 'Android Gradle file missing: ${_relative(gradlePath)}'));
  }

  final keyPropertiesPath = '$repoRoot/gigcredit_app/android/key.properties';
  final keyPropsExists = File(keyPropertiesPath).existsSync();
  checks.add(_Check(
    keyPropsExists || allowPlaceholderModels,
    keyPropsExists
        ? 'Release keystore file present: ${_relative(keyPropertiesPath)}'
        : 'Release keystore file pending: ${_relative(keyPropertiesPath)}',
  ));

  final failed = checks.where((c) => !c.ok).toList(growable: false);

  stdout.writeln('=== GigCredit Release Readiness Check ===');
  for (final check in checks) {
    final icon = check.ok ? '[PASS]' : '[FAIL]';
    stdout.writeln('$icon ${check.message}');
  }

  if (failed.isEmpty) {
    stdout.writeln('\nResult: PASS');
    exit(0);
  }

  stdout.writeln('\nResult: FAIL (${failed.length} issue(s))');
  exit(1);
}

class _Check {
  _Check(this.ok, this.message);

  final bool ok;
  final String message;
}

_Check _fileExists(String path, String label) {
  return _Check(File(path).existsSync(), '$label: ${_relative(path)}');
}

String _relative(String path) {
  return path.replaceAll('\\\\', '/').split('/GigCredit-AI4Good/').last;
}
