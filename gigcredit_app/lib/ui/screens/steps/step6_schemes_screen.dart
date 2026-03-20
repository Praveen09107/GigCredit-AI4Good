import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/verification_validation_engine.dart';
import '../../../config/app_mode.dart';
import '../../../core/files/document_picker.dart';
import '../../../core/security/request_signer.dart';
import '../../../core/validation/step6_validators.dart';
import '../../../models/enums/document_type.dart';
import '../../../services/backend_client.dart';
import '../../../services/document_pipeline_service.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/step_progress_header.dart';

class Step6SchemesScreen extends ConsumerStatefulWidget {
  const Step6SchemesScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step6SchemesScreen> createState() => _Step6SchemesScreenState();
}

class _Step6SchemesScreenState extends ConsumerState<Step6SchemesScreen> {
  static final String _apiBaseUrl = AppMode.resolvedBackendBaseUrl;
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  final _svanidhiRefController = TextEditingController();
  final _eShramController = TextEditingController();
  final _pmSymController = TextEditingController();
  final _pmjjbyController = TextEditingController();
  final _udyamController = TextEditingController();
  final _ppfController = TextEditingController();

  bool _svanidhiSelected = false;
  bool _eShramSelected = false;
  bool _pmSymSelected = false;
  bool _pmjjbySelected = false;
  bool _udyamSelected = false;
  bool _ppfSelected = false;

  bool _svanidhiUploaded = false;
  bool _eShramUploaded = false;
  bool _pmSymUploaded = false;
  bool _pmjjbyUploaded = false;
  bool _udyamUploaded = false;
  bool _ppfUploaded = false;

  String? _svanidhiFilePath;
  String? _eShramFilePath;
  String? _pmSymFilePath;
  String? _pmjjbyFilePath;
  String? _udyamFilePath;
  String? _ppfFilePath;

  bool _svanidhiOcrOk = false;
  bool _eShramOcrOk = false;
  bool _pmSymOcrOk = false;
  bool _pmjjbyOcrOk = false;
  bool _udyamOcrOk = false;
  bool _ppfOcrOk = false;

  bool _svanidhiVerified = false;
  bool _eShramVerified = false;
  bool _pmSymVerified = false;
  bool _pmjjbyVerified = false;
  bool _udyamVerified = false;
  bool _ppfVerified = false;

  final _docPipeline = DocumentPipelineService();

  @override
  void dispose() {
    _svanidhiRefController.dispose();
    _eShramController.dispose();
    _pmSymController.dispose();
    _pmjjbyController.dispose();
    _udyamController.dispose();
    _ppfController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _upload(String scheme) async {
    final file = await DocumentPicker.pickSingle();
    if (file == null || !mounted) return;
    if (file.path == null || file.path!.isEmpty) {
      return _toast('Unable to access selected file locally.');
    }

    setState(() {
      if (scheme == 'svanidhi') {
        _svanidhiUploaded = true;
        _svanidhiFilePath = file.path;
      }
      if (scheme == 'eshram') {
        _eShramUploaded = true;
        _eShramFilePath = file.path;
      }
      if (scheme == 'pmsym') {
        _pmSymUploaded = true;
        _pmSymFilePath = file.path;
      }
      if (scheme == 'pmjjby') {
        _pmjjbyUploaded = true;
        _pmjjbyFilePath = file.path;
      }
      if (scheme == 'udyam') {
        _udyamUploaded = true;
        _udyamFilePath = file.path;
      }
      if (scheme == 'ppf') {
        _ppfUploaded = true;
        _ppfFilePath = file.path;
      }
    });

    _toast('Selected file: ${file.name}');
  }

  Future<void> _runOcr(String scheme) async {
    if (scheme == 'svanidhi') {
      if (!_svanidhiUploaded) return _toast('Upload SVANidhi proof first.');
      final err = Step6Validators.validateSvanidhiRef(_svanidhiRefController.text);
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(_svanidhiFilePath, 'svanidhi');
      if (!mounted) return;
      setState(() => _svanidhiOcrOk = ok);
      return;
    }

    if (scheme == 'eshram') {
      if (!_eShramUploaded) return _toast('Upload eShram proof first.');
      final err = Step6Validators.validateEShramNumber(_eShramController.text);
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(_eShramFilePath, 'eshram');
      if (!mounted) return;
      setState(() => _eShramOcrOk = ok);
      return;
    }

    if (scheme == 'pmsym') {
      if (!_pmSymUploaded) return _toast('Upload PM-SYM proof first.');
      final err = Step6Validators.validatePmSymRef(_pmSymController.text);
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(_pmSymFilePath, 'pmsym');
      if (!mounted) return;
      setState(() => _pmSymOcrOk = ok);
      return;
    }

    if (scheme == 'pmjjby') {
      if (!_pmjjbyUploaded) return _toast('Upload PMJJBY proof first.');
      final err = Step6Validators.validatePmjjbyRef(_pmjjbyController.text);
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(_pmjjbyFilePath, 'pmjjby');
      if (!mounted) return;
      setState(() => _pmjjbyOcrOk = ok);
      return;
    }

    if (scheme == 'udyam') {
      if (!_udyamUploaded) return _toast('Upload UDYAM proof first.');
      final err = Step6Validators.validateUdyamNumber(_udyamController.text);
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(_udyamFilePath, 'udyam');
      if (!mounted) return;
      setState(() => _udyamOcrOk = ok);
      return;
    }

    if (scheme == 'ppf') {
      if (!_ppfUploaded) return _toast('Upload PPF proof first.');
      final err = Step6Validators.validatePpfAccountRef(_ppfController.text);
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(_ppfFilePath, 'ppf');
      if (!mounted) return;
      setState(() => _ppfOcrOk = ok);
    }
  }

  Future<bool> _extractAndValidateOcr(String? filePath, String scheme) async {
    if (filePath == null || filePath.isEmpty) {
      _toast('Missing local file path for OCR. Re-upload and retry.');
      return false;
    }

    final processed = await _docPipeline.processFile(
      filePath: filePath,
      documentType: _documentTypeForScheme(scheme),
      validationContext: _buildValidationContext(scheme: scheme),
    );
    final ok = processed.ocr.rawText.trim().isNotEmpty || processed.ocr.confidence >= 0.30;
    if (!ok) {
      _toast('OCR extraction failed for $scheme. Please upload a clearer document.');
      return false;
    }

    if (!processed.validation.passed) {
      _toast('Validation failed for $scheme document. Please upload a valid document.');
      return false;
    }

    final expectedId = _expectedIdentifierForScheme(scheme);
    if (expectedId.isNotEmpty) {
      final normalizedExpected = expectedId.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final normalizedRaw = processed.ocr.rawText.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (normalizedExpected.isNotEmpty && !normalizedRaw.contains(normalizedExpected)) {
        _toast('Entered identifier does not match OCR text for $scheme.');
        return false;
      }
    }

    _toast('Document pipeline completed for $scheme.');
    return true;
  }

  ValidationContext _buildValidationContext({required String scheme}) {
    final profile = ref.read(verifiedProfileProvider);
    final fullName = profile.fullName.trim();
    final expected = _expectedIdentifierForScheme(scheme);
    final required = scheme == 'pmjjby'
        ? const <String>['policy_number']
        : const <String>['scheme_reference'];

    return ValidationContext(
      stepTag: 'step6_$scheme',
      requiredFields: required,
      profile: VerifiedProfileSnapshot(
        fullName: fullName.isEmpty ? null : fullName,
      ),
      apiVerifiedFields: <String, String>{
        if (scheme == 'pmjjby' && expected.isNotEmpty) 'policy_number': expected,
        if (scheme != 'pmjjby' && expected.isNotEmpty) 'scheme_reference': expected,
      },
    );
  }

  String _expectedIdentifierForScheme(String scheme) {
    switch (scheme) {
      case 'svanidhi':
        return _svanidhiRefController.text.trim().toUpperCase();
      case 'eshram':
        return _eShramController.text.trim().toUpperCase();
      case 'pmsym':
        return _pmSymController.text.trim().toUpperCase();
      case 'pmjjby':
        return _pmjjbyController.text.trim().toUpperCase();
      case 'udyam':
        return _udyamController.text.trim().toUpperCase();
      case 'ppf':
        return _ppfController.text.trim().toUpperCase();
      default:
        return '';
    }
  }

  DocumentType _documentTypeForScheme(String scheme) {
    switch (scheme) {
      case 'pmjjby':
        return DocumentType.insurance;
      case 'svanidhi':
      case 'eshram':
      case 'pmsym':
      case 'udyam':
      case 'ppf':
        return DocumentType.governmentScheme;
      default:
        return DocumentType.governmentScheme;
    }
  }

  Future<bool> _postSchemeVerification({
    required String path,
    required String identifier,
  }) async {
    if (_apiBaseUrl.isEmpty || _apiKey.isEmpty) {
      return false;
    }

    try {
      final client = BackendClient(
        baseUrl: _apiBaseUrl,
        apiKey: _apiKey,
        deviceId: 'dev_b_step6',
        signatureProvider: signatureProviderFromApiKey(_apiKey),
      );
      final resp = await client.postJson(path, <String, dynamic>{
        'identifier': identifier,
      });
      final status = resp.status.toUpperCase();
      return status == 'SUCCESS' || status == 'FOUND' || status == 'OK' || status == 'VERIFIED' || status == 'ACTIVE';
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyScheme(String scheme) async {
    var verified = false;
    var backendAttempted = false;
    var missingIdentifierForProduction = false;

    String endpoint = '';
    String identifier = '';

    if (scheme == 'svanidhi') {
      verified = _svanidhiUploaded && _svanidhiOcrOk;
      endpoint = '/verify/svanidhi';
      identifier = _svanidhiRefController.text.trim().toUpperCase();
    } else if (scheme == 'eshram') {
      verified = _eShramUploaded && _eShramOcrOk;
      endpoint = '/verify/eshram';
      identifier = _eShramController.text.trim().toUpperCase();
    } else if (scheme == 'pmsym') {
      verified = _pmSymUploaded && _pmSymOcrOk;
      endpoint = '/verify/pmsym';
      identifier = _pmSymController.text.trim().toUpperCase();
    } else if (scheme == 'pmjjby') {
      verified = _pmjjbyUploaded && _pmjjbyOcrOk;
      endpoint = '/verify/pmjjby';
      identifier = _pmjjbyController.text.trim().toUpperCase();
    } else if (scheme == 'udyam') {
      verified = _udyamUploaded && _udyamOcrOk;
      endpoint = '/verify/udyam';
      identifier = _udyamController.text.trim().toUpperCase();
    } else if (scheme == 'ppf') {
      verified = _ppfUploaded && _ppfOcrOk;
      endpoint = '/verify/ppf';
      identifier = _ppfController.text.trim().toUpperCase();
    }

    if (verified && endpoint.isNotEmpty) {
      if (_requireProductionReadiness && identifier.isEmpty) {
        missingIdentifierForProduction = true;
        verified = false;
      } else if (_apiBaseUrl.isNotEmpty && _apiKey.isNotEmpty) {
        backendAttempted = true;
        final backendOk = await _postSchemeVerification(path: endpoint, identifier: identifier);
        verified = backendOk || !_requireProductionReadiness;
      } else if (_requireProductionReadiness) {
        verified = false;
      }
    }

    setState(() {
      if (scheme == 'svanidhi') _svanidhiVerified = verified;
      if (scheme == 'eshram') _eShramVerified = verified;
      if (scheme == 'pmsym') _pmSymVerified = verified;
      if (scheme == 'pmjjby') _pmjjbyVerified = verified;
      if (scheme == 'udyam') _udyamVerified = verified;
      if (scheme == 'ppf') _ppfVerified = verified;
    });

    if (!verified) {
      if (missingIdentifierForProduction) {
        _toast('Enter a valid $scheme reference before verification in production mode.');
      } else if (_requireProductionReadiness && !backendAttempted) {
        _toast('$scheme backend verification is required in production mode.');
      } else {
        _toast('Verification failed for $scheme. Check input and retry.');
      }
    }
  }

  void _completeStep() {
    final selectedAny =
        _svanidhiSelected || _eShramSelected || _pmSymSelected || _pmjjbySelected || _udyamSelected || _ppfSelected;
    if (!selectedAny) {
      final ok = ref.read(verifiedProfileProvider.notifier).completeStep6(
            selectedSvanidhi: false,
            selectedEShram: false,
        selectedPmSym: false,
        selectedPmjjby: false,
            selectedUdyam: false,
        selectedPpf: false,
            svanidhiVerified: false,
            eShramVerified: false,
        pmSymVerified: false,
        pmjjbyVerified: false,
            udyamVerified: false,
        ppfVerified: false,
          );
      if (!ok) {
        return _toast('Unable to complete Step-6. Verify Step-5 status.');
      }
      widget.onContinue();
      return;
    }

    if (_svanidhiSelected && !_svanidhiVerified) {
      return _toast('Complete SVANidhi upload, OCR and verification.');
    }
    if (_eShramSelected && !_eShramVerified) {
      return _toast('Complete eShram upload, OCR and verification.');
    }
    if (_pmSymSelected && !_pmSymVerified) {
      return _toast('Complete PM-SYM upload, OCR and verification.');
    }
    if (_pmjjbySelected && !_pmjjbyVerified) {
      return _toast('Complete PMJJBY upload, OCR and verification.');
    }
    if (_udyamSelected && !_udyamVerified) {
      return _toast('Complete UDYAM upload, OCR and verification.');
    }
    if (_ppfSelected && !_ppfVerified) {
      return _toast('Complete PPF upload, OCR and verification.');
    }

    final ok = ref.read(verifiedProfileProvider.notifier).completeStep6(
          selectedSvanidhi: _svanidhiSelected,
          selectedEShram: _eShramSelected,
          selectedPmSym: _pmSymSelected,
          selectedPmjjby: _pmjjbySelected,
          selectedUdyam: _udyamSelected,
          selectedPpf: _ppfSelected,
          svanidhiVerified: _svanidhiVerified,
          eShramVerified: _eShramVerified,
          pmSymVerified: _pmSymVerified,
          pmjjbyVerified: _pmjjbyVerified,
          udyamVerified: _udyamVerified,
          ppfVerified: _ppfVerified,
        );

    if (!ok) {
      return _toast('Unable to complete Step-6. Verify selected scheme statuses and Step-5 progression.');
    }

    widget.onContinue();
  }

  Widget _schemeCard({
    required String title,
    required String subtitle,
    required bool selected,
    required ValueChanged<bool?> onSelected,
    required TextEditingController controller,
    required String idLabel,
    required bool uploaded,
    required bool ocrOk,
    required bool verified,
    required VoidCallback onUpload,
    required Future<void> Function() onOcr,
    required VoidCallback onVerify,
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
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Checkbox(value: selected, onChanged: onSelected),
              ],
            ),
            Text(subtitle),
            const SizedBox(height: 10),
            TextField(
              enabled: selected,
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: '$idLabel (optional if document has no ID)'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton(onPressed: selected ? onUpload : null, child: const Text('Upload Proof')),
                OutlinedButton(
                  onPressed: selected ? () => onOcr() : null,
                  child: const Text('Run OCR'),
                ),
                ElevatedButton(onPressed: selected ? onVerify : null, child: const Text('Verify')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status: Upload ${uploaded ? 'OK' : 'Pending'} | OCR ${ocrOk ? 'OK' : 'Pending'} | Verify ${verified ? 'OK' : 'Pending'}',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 6 of 9 • Government Schemes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const StepProgressHeader(currentStep: 6),
          const SizedBox(height: 14),
          const Text('All schemes in Step-6 are optional. If selected, full validation is required.'),
          const SizedBox(height: 12),
          _schemeCard(
            title: 'PM SVANidhi',
            subtitle: 'Street-vendor support proof (optional).',
            selected: _svanidhiSelected,
            onSelected: (v) => setState(() => _svanidhiSelected = v ?? false),
            controller: _svanidhiRefController,
            idLabel: 'SVANidhi Reference',
            uploaded: _svanidhiUploaded,
            ocrOk: _svanidhiOcrOk,
            verified: _svanidhiVerified,
            onUpload: () => _upload('svanidhi'),
            onOcr: () => _runOcr('svanidhi'),
            onVerify: () => _verifyScheme('svanidhi'),
          ),
          _schemeCard(
            title: 'eShram',
            subtitle: 'Unorganized worker registration proof (optional).',
            selected: _eShramSelected,
            onSelected: (v) => setState(() => _eShramSelected = v ?? false),
            controller: _eShramController,
            idLabel: 'eShram Number',
            uploaded: _eShramUploaded,
            ocrOk: _eShramOcrOk,
            verified: _eShramVerified,
            onUpload: () => _upload('eshram'),
            onOcr: () => _runOcr('eshram'),
            onVerify: () => _verifyScheme('eshram'),
          ),
          _schemeCard(
            title: 'PM-SYM',
            subtitle: 'Pension support scheme proof (optional).',
            selected: _pmSymSelected,
            onSelected: (v) => setState(() => _pmSymSelected = v ?? false),
            controller: _pmSymController,
            idLabel: 'PM-SYM Reference',
            uploaded: _pmSymUploaded,
            ocrOk: _pmSymOcrOk,
            verified: _pmSymVerified,
            onUpload: () => _upload('pmsym'),
            onOcr: () => _runOcr('pmsym'),
            onVerify: () => _verifyScheme('pmsym'),
          ),
          _schemeCard(
            title: 'PMJJBY',
            subtitle: 'Insurance enrollment proof (optional).',
            selected: _pmjjbySelected,
            onSelected: (v) => setState(() => _pmjjbySelected = v ?? false),
            controller: _pmjjbyController,
            idLabel: 'PMJJBY Reference',
            uploaded: _pmjjbyUploaded,
            ocrOk: _pmjjbyOcrOk,
            verified: _pmjjbyVerified,
            onUpload: () => _upload('pmjjby'),
            onOcr: () => _runOcr('pmjjby'),
            onVerify: () => _verifyScheme('pmjjby'),
          ),
          _schemeCard(
            title: 'UDYAM',
            subtitle: 'MSME/Udyam registration proof (optional).',
            selected: _udyamSelected,
            onSelected: (v) => setState(() => _udyamSelected = v ?? false),
            controller: _udyamController,
            idLabel: 'UDYAM Reference',
            uploaded: _udyamUploaded,
            ocrOk: _udyamOcrOk,
            verified: _udyamVerified,
            onUpload: () => _upload('udyam'),
            onOcr: () => _runOcr('udyam'),
            onVerify: () => _verifyScheme('udyam'),
          ),
          _schemeCard(
            title: 'PPF',
            subtitle: 'Public Provident Fund proof (optional).',
            selected: _ppfSelected,
            onSelected: (v) => setState(() => _ppfSelected = v ?? false),
            controller: _ppfController,
            idLabel: 'PPF Account Reference',
            uploaded: _ppfUploaded,
            ocrOk: _ppfOcrOk,
            verified: _ppfVerified,
            onUpload: () => _upload('ppf'),
            onOcr: () => _runOcr('ppf'),
            onVerify: () => _verifyScheme('ppf'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _completeStep, child: const Text('Continue to Step 7')),
        ],
      ),
    );
  }
}
