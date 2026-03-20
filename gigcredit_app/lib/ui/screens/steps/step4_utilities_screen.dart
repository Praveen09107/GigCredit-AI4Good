import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_mode.dart';
import '../../../core/files/document_picker.dart';
import '../../../core/security/request_signer.dart';
import '../../../ai/verification_validation_engine.dart';
import '../../../models/enums/document_type.dart';
import '../../../services/backend_client.dart';
import '../../../services/document_pipeline_service.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/step_progress_header.dart';

class Step4UtilitiesScreen extends ConsumerStatefulWidget {
  const Step4UtilitiesScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step4UtilitiesScreen> createState() => _Step4UtilitiesScreenState();
}

class _Step4UtilitiesScreenState extends ConsumerState<Step4UtilitiesScreen> {
  static final String _apiBaseUrl = AppMode.resolvedBackendBaseUrl;
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  final _docPipeline = DocumentPipelineService();

  bool _ebVerified = false;
  bool _lpgVerified = false;
  bool _mobileVerified = false;

  bool _rentVerified = false;
  bool _wifiVerified = false;
  bool _ottVerified = false;

  int _ebUploads = 0;
  int _lpgUploads = 0;
  int _mobileUploads = 0;
  int _rentUploads = 0;
  int _wifiUploads = 0;
  int _ottUploads = 0;

  final List<String> _ebFilePaths = <String>[];
  final List<String> _lpgFilePaths = <String>[];
  final List<String> _mobileFilePaths = <String>[];

  String? _rentFilePath;
  String? _wifiFilePath;
  String? _ottFilePath;

  Future<void> _upload(String type) async {
    final file = await DocumentPicker.pickSingle();
    if (file == null || !mounted) return;
    if (file.path == null || file.path!.isEmpty) {
      return _toast('Unable to access selected file locally.');
    }

    setState(() {
      switch (type) {
        case 'eb':
          _appendMandatoryPath(_ebFilePaths, file.path!);
          _ebUploads = _ebFilePaths.length;
          break;
        case 'lpg':
          _appendMandatoryPath(_lpgFilePaths, file.path!);
          _lpgUploads = _lpgFilePaths.length;
          break;
        case 'mobile':
          _appendMandatoryPath(_mobileFilePaths, file.path!);
          _mobileUploads = _mobileFilePaths.length;
          break;
        case 'rent':
          _rentUploads = (_rentUploads + 1).clamp(0, 6);
          _rentFilePath = file.path;
          break;
        case 'wifi':
          _wifiUploads = (_wifiUploads + 1).clamp(0, 6);
          _wifiFilePath = file.path;
          break;
        case 'ott':
          _ottUploads = (_ottUploads + 1).clamp(0, 6);
          _ottFilePath = file.path;
          break;
      }
    });
    _toast('Selected file: ${file.name}');
  }

  void _appendMandatoryPath(List<String> target, String path) {
    if (target.contains(path)) {
      return;
    }
    if (target.length >= 6) {
      target.removeAt(0);
    }
    target.add(path);
  }

  Future<void> _verifyEb() async {
    if (_ebUploads < 6) return _toast('Upload 6 EB bills first.');
    final batch = await _verifyMandatoryUtilityBatch(
      filePaths: _ebFilePaths,
      documentType: DocumentType.electricityBill,
      identityKey: 'bill_id',
      label: 'electricity',
    );
    if (!batch.ok) return;
    final ok = await _verifyUtility(
      'electricity',
      fallback: !_requireProductionReadiness,
      identifier: batch.identityValue,
    );
    setState(() => _ebVerified = ok);
    _toast(ok
        ? 'Electricity utility verified.'
        : (_requireProductionReadiness
            ? 'Electricity backend verification is required in production mode.'
            : 'Electricity verification failed.'));
  }

  Future<void> _verifyLpg() async {
    if (_lpgUploads < 6) return _toast('Upload 6 LPG invoices first.');
    final batch = await _verifyMandatoryUtilityBatch(
      filePaths: _lpgFilePaths,
      documentType: DocumentType.lpgBill,
      identityKey: 'bill_id',
      label: 'lpg',
    );
    if (!batch.ok) return;
    final ok = await _verifyUtility(
      'lpg',
      fallback: !_requireProductionReadiness,
      identifier: batch.identityValue,
    );
    setState(() => _lpgVerified = ok);
    _toast(ok
        ? 'LPG utility verified (offline/cash tolerant).'
        : (_requireProductionReadiness
            ? 'LPG backend verification is required in production mode.'
            : 'LPG verification failed.'));
  }

  Future<void> _verifyMobile() async {
    if (_mobileUploads < 6) return _toast('Upload 6 mobile bills first.');
    final batch = await _verifyMandatoryUtilityBatch(
      filePaths: _mobileFilePaths,
      documentType: DocumentType.mobileBill,
      identityKey: 'bill_id',
      label: 'mobile',
    );
    if (!batch.ok) return;
    final ok = await _verifyUtility(
      'mobile',
      fallback: !_requireProductionReadiness,
      identifier: batch.identityValue,
    );
    setState(() => _mobileVerified = ok);
    _toast(ok
        ? 'Mobile utility verified.'
        : (_requireProductionReadiness
            ? 'Mobile backend verification is required in production mode.'
            : 'Mobile verification failed.'));
  }

  Future<bool> _runUtilityOcrAutoDetect(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      _toast('Missing local file path for OCR. Re-upload and retry.');
      return false;
    }

    final processed = await _docPipeline.processFile(
      filePath: filePath,
      autoDetectCandidates: const <DocumentType>[
        DocumentType.electricityBill,
        DocumentType.lpgBill,
        DocumentType.mobileBill,
        DocumentType.wifiBill,
      ],
      validationContext: _buildValidationContext(),
    );

    final ok = processed.ocr.rawText.trim().isNotEmpty || processed.ocr.confidence >= 0.30;
    if (!ok) {
      _toast('OCR extraction failed. Please upload a clearer utility document.');
      return false;
    }

    if (!processed.validation.passed) {
      _toast('Document validation failed. Please upload a valid utility document.');
      return false;
    }

    _toast('Document pipeline completed successfully as ${processed.documentType.name}.');
    return true;
  }

  Future<_UtilityBatchResult> _verifyMandatoryUtilityBatch({
    required List<String> filePaths,
    required DocumentType documentType,
    required String identityKey,
    required String label,
  }) async {
    final identities = <String>{};

    if (filePaths.length < 6) {
      _toast('Upload all 6 $label documents before verification.');
      return const _UtilityBatchResult(ok: false);
    }

    for (final path in filePaths) {
      final processed = await _docPipeline.processFile(
        filePath: path,
        documentType: documentType,
        validationContext: _buildValidationContext(),
      );

      final hasText = processed.ocr.rawText.trim().isNotEmpty || processed.ocr.confidence >= 0.70;
      if (!hasText || !processed.validation.passed) {
        _toast('One or more $label documents failed OCR/validation checks. Re-upload clearer files.');
        return const _UtilityBatchResult(ok: false);
      }

      final identity = (processed.fields[identityKey] ?? '').trim().toUpperCase();
      if (identity.isEmpty) {
        _toast('Unable to extract required $label identity field from all 6 documents.');
        return const _UtilityBatchResult(ok: false);
      }
      identities.add(identity);
    }

    if (identities.length != 1) {
      _toast('Identity mismatch across 6 $label documents. Please upload bills for the same account/number.');
      return const _UtilityBatchResult(ok: false);
    }

    return _UtilityBatchResult(ok: true, identityValue: identities.first);
  }

  ValidationContext _buildValidationContext() {
    final profile = ref.read(verifiedProfileProvider);
    final fullName = profile.fullName.trim();
    final ifsc = profile.ifscCode.trim().toUpperCase();

    return ValidationContext(
      stepTag: 'step4_utilities',
      profile: VerifiedProfileSnapshot(
        fullName: fullName.isEmpty ? null : fullName,
        bankIfsc: ifsc.isEmpty ? null : ifsc,
      ),
    );
  }

  Future<bool> _verifyUtility(
    String utilityType, {
    required bool fallback,
    String? identifier,
  }) async {
    if (_apiBaseUrl.isEmpty || _apiKey.isEmpty) {
      return fallback;
    }
    try {
      final client = BackendClient(
        baseUrl: _apiBaseUrl,
        apiKey: _apiKey,
        deviceId: 'dev_b_step4',
        signatureProvider: signatureProviderFromApiKey(_apiKey),
      );
      var response = await client.postJson('/verify/utility/$utilityType', <String, dynamic>{
        'identifier': (identifier == null || identifier.trim().isEmpty) ? utilityType : identifier.trim(),
      });
      if (response.status.toUpperCase() == 'ERROR') {
        response = await client.postJson('/verify/utility', <String, dynamic>{
          'identifier': (identifier == null || identifier.trim().isEmpty) ? utilityType : identifier.trim(),
        });
      }
      final status = response.status.toUpperCase();
      return status == 'FOUND' || status == 'OK' || status == 'VERIFIED' || status == 'ACTIVE';
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _verifyOptional(String type) async {
    String? filePath;
    int uploadCount;

    switch (type) {
      case 'rent':
        filePath = _rentFilePath;
        uploadCount = _rentUploads;
        break;
      case 'wifi':
        filePath = _wifiFilePath;
        uploadCount = _wifiUploads;
        break;
      case 'ott':
        filePath = _ottFilePath;
        uploadCount = _ottUploads;
        break;
      default:
        return;
    }

    if (uploadCount < 1) {
      return _toast('Upload at least one document first.');
    }

    final ocrOk = await _runUtilityOcrAutoDetect(filePath);
    if (!ocrOk) {
      return;
    }

    final verified = await _verifyUtility(type, fallback: !_requireProductionReadiness);
    setState(() {
      switch (type) {
        case 'rent':
          _rentVerified = verified;
          break;
        case 'wifi':
          _wifiVerified = verified;
          break;
        case 'ott':
          _ottVerified = verified;
          break;
      }
    });

    if (!verified && _requireProductionReadiness) {
      _toast('$type backend verification is required in production mode.');
    }
  }

  void _completeStep() {
    if (!(_ebVerified && _lpgVerified && _mobileVerified)) {
      return _toast('Verify mandatory utilities: Electricity, LPG, Mobile.');
    }

    final ok = ref.read(verifiedProfileProvider.notifier).completeStep4(
          electricityVerified: _ebVerified,
          lpgVerified: _lpgVerified,
          mobileVerified: _mobileVerified,
          rentVerified: _rentVerified,
          wifiVerified: _wifiVerified,
          ottVerified: _ottVerified,
        );

    if (!ok) {
      return _toast('Unable to complete Step-4. Verify Step-3 status and required utilities.');
    }

    widget.onContinue();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _utilityCard({
    required String title,
    required String subtitle,
    required int uploads,
    required VoidCallback onUpload,
    required VoidCallback onVerify,
    required bool verified,
    bool mandatory = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    mandatory ? '$title (Mandatory)' : '$title (Optional)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(verified ? 'Verified' : 'Pending'),
                  backgroundColor: verified ? const Color(0xFFD5F5DE) : const Color(0xFFF1F1F4),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 10),
            Text('Uploads: $uploads/6'),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                OutlinedButton(onPressed: onUpload, child: const Text('Upload')),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: onVerify, child: const Text('Verify')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 4 of 9 • Utility Bills')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const StepProgressHeader(currentStep: 4),
          const SizedBox(height: 14),
          _utilityCard(
            title: 'Electricity Bills',
            subtitle: 'EB name can differ from Step-1 if house owner name appears.',
            uploads: _ebUploads,
            onUpload: () => _upload('eb'),
            onVerify: _verifyEb,
            verified: _ebVerified,
            mandatory: true,
          ),
          _utilityCard(
            title: 'Gas / LPG Bills',
            subtitle: 'Cash/offline payment allowed. Bank-match is not strict.',
            uploads: _lpgUploads,
            onUpload: () => _upload('lpg'),
            onVerify: _verifyLpg,
            verified: _lpgVerified,
            mandatory: true,
          ),
          _utilityCard(
            title: 'Mobile Bills',
            subtitle: '6 months consistency required.',
            uploads: _mobileUploads,
            onUpload: () => _upload('mobile'),
            onVerify: _verifyMobile,
            verified: _mobileVerified,
            mandatory: true,
          ),
          _utilityCard(
            title: 'Rent',
            subtitle: 'Optional utility boost.',
            uploads: _rentUploads,
            onUpload: () => _upload('rent'),
            onVerify: () => _verifyOptional('rent'),
            verified: _rentVerified,
          ),
          _utilityCard(
            title: 'WiFi / Broadband',
            subtitle: 'Optional utility boost.',
            uploads: _wifiUploads,
            onUpload: () => _upload('wifi'),
            onVerify: () => _verifyOptional('wifi'),
            verified: _wifiVerified,
          ),
          _utilityCard(
            title: 'OTT Subscription',
            subtitle: 'Optional utility boost.',
            uploads: _ottUploads,
            onUpload: () => _upload('ott'),
            onVerify: () => _verifyOptional('ott'),
            verified: _ottVerified,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _completeStep, child: const Text('Continue to Step 5')),
        ],
      ),
    );
  }
}

class _UtilityBatchResult {
  const _UtilityBatchResult({required this.ok, this.identityValue});

  final bool ok;
  final String? identityValue;
}
