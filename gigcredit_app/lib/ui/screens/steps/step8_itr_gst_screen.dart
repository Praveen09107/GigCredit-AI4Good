import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/verification_validation_engine.dart';
import '../../../config/app_mode.dart';
import '../../../core/files/document_picker.dart';
import '../../../core/security/request_signer.dart';
import '../../../core/validation/step1_validators.dart';
import '../../../core/validation/step8_validators.dart';
import '../../../models/enums/document_type.dart';
import '../../../services/backend_client.dart';
import '../../../services/document_pipeline_service.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/step_progress_header.dart';

class Step8ItrGstScreen extends ConsumerStatefulWidget {
  const Step8ItrGstScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step8ItrGstScreen> createState() => _Step8ItrGstScreenState();
}

class _Step8ItrGstScreenState extends ConsumerState<Step8ItrGstScreen> {
  static final String _apiBaseUrl = AppMode.resolvedBackendBaseUrl;
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;

  final _itrPanController = TextEditingController();
  final _itrAckController = TextEditingController();
  final _itrNameController = TextEditingController();
  final _itrAnnualIncomeController = TextEditingController();

  final _gstPanController = TextEditingController();
  final _gstNameController = TextEditingController();
  final _gstAnnualIncomeController = TextEditingController();

  bool _itrSelected = false;
  bool _gstSelected = false;

  bool _itrUploaded = false;
  bool _gstUploaded = false;

  String? _itrFilePath;
  String? _gstFilePath;

  bool _itrOcrOk = false;
  bool _gstOcrOk = false;

  bool _itrVerified = false;
  bool _gstVerified = false;

  final _docPipeline = DocumentPipelineService();

  @override
  void dispose() {
    _itrPanController.dispose();
    _itrAckController.dispose();
    _itrNameController.dispose();
    _itrAnnualIncomeController.dispose();
    _gstPanController.dispose();
    _gstNameController.dispose();
    _gstAnnualIncomeController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double _monthlyBaselineFromStep3(int transactionCount) {
    // Prototype baseline estimator until full feature-engineering is integrated.
    final estimated = transactionCount * 1500.0;
    return estimated < 6000 ? 6000 : estimated;
  }

  String? _validateCrossStepDoc({
    required String pan,
    required String holderName,
    required String annualIncome,
    required String profilePan,
    required String profileNormalizedName,
    required double monthlyBaseline,
  }) {
    final panErr = Step8Validators.validatePan(pan);
    if (panErr != null) return panErr;

    final incomeErr = Step8Validators.validateAnnualIncome(annualIncome);
    if (incomeErr != null) return incomeErr;

    final panNormalized = pan.trim().toUpperCase();
    if (profilePan.trim().isEmpty) {
      return 'Step-2 PAN is missing. Please re-verify Step-2 identity.';
    }
    if (panNormalized != profilePan.trim().toUpperCase()) {
      return 'PAN mismatch with Step-2 profile PAN.';
    }

    final holderNormalized = Step1Validators.normalizeName(holderName);
    if (holderNormalized != profileNormalizedName) {
      return 'Name mismatch with Step-1 profile name.';
    }

    final annual = double.parse(annualIncome.trim());
    final monthlyFromDoc = annual / 12.0;
    final within = Step8Validators.withinFortyPercentTolerance(
      observed: monthlyFromDoc,
      baseline: monthlyBaseline,
    );

    if (!within) {
      return 'Income is outside allowed +-40% of Step-3 baseline.';
    }

    return null;
  }

  Future<void> _upload(String type) async {
    final file = await DocumentPicker.pickSingle();
    if (file == null || !mounted) return;
    if (file.path == null || file.path!.isEmpty) {
      return _toast('Unable to access selected file locally.');
    }

    setState(() {
      if (type == 'itr') {
        _itrUploaded = true;
        _itrFilePath = file.path;
      }
      if (type == 'gst') {
        _gstUploaded = true;
        _gstFilePath = file.path;
      }
    });

    _toast('Selected file: ${file.name}');
  }

  Future<void> _runOcr(String type, String profilePan, String profileName, double monthlyBaseline) async {
    if (type == 'itr') {
      if (!_itrUploaded) return _toast('Upload ITR document first.');
      final err = _validateCrossStepDoc(
        pan: _itrPanController.text,
        holderName: _itrNameController.text,
        annualIncome: _itrAnnualIncomeController.text,
        profilePan: profilePan,
        profileNormalizedName: profileName,
        monthlyBaseline: monthlyBaseline,
      );
      if (err != null) return _toast(err);
      final ok = await _extractAndValidateOcr(
        _itrFilePath,
        'itr',
        expectedPan: _itrPanController.text,
      );
      if (!mounted) return;
      setState(() => _itrOcrOk = ok);
      return;
    }

    if (!_gstUploaded) return _toast('Upload GST document first.');
    final err = _validateCrossStepDoc(
      pan: _gstPanController.text,
      holderName: _gstNameController.text,
      annualIncome: _gstAnnualIncomeController.text,
      profilePan: profilePan,
      profileNormalizedName: profileName,
      monthlyBaseline: monthlyBaseline,
    );
    if (err != null) return _toast(err);
    final ok = await _extractAndValidateOcr(
      _gstFilePath,
      'gst',
      expectedPan: _gstPanController.text,
    );
    if (!mounted) return;
    setState(() => _gstOcrOk = ok);
  }

  Future<bool> _extractAndValidateOcr(
    String? filePath,
    String hint, {
    required String expectedPan,
  }) async {
    if (filePath == null || filePath.isEmpty) {
      _toast('Missing local file path for OCR. Re-upload and retry.');
      return false;
    }

    final normalizedPan = expectedPan.trim().toUpperCase();

    final processed = await _docPipeline.processFile(
      filePath: filePath,
      documentType: hint == 'itr' ? DocumentType.itr : DocumentType.governmentScheme,
      validationContext: _buildValidationContext(expectedPan: normalizedPan, hint: hint),
    );
    final ok = processed.ocr.rawText.trim().isNotEmpty || processed.ocr.confidence >= 0.30;
    if (!ok) {
      _toast('OCR extraction failed. Please upload a clearer document.');
      return false;
    }

    if (!processed.validation.passed) {
      _toast('Document validation failed. Please upload a valid tax document.');
      return false;
    }

    if (normalizedPan.isNotEmpty) {
      final normalizedRaw = processed.ocr.rawText.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final normalizedExpected = normalizedPan.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (!normalizedRaw.contains(normalizedExpected)) {
        _toast('PAN mismatch between entered value and OCR document.');
        return false;
      }
    }

    _toast('Document pipeline completed successfully.');
    return true;
  }

  ValidationContext _buildValidationContext({required String expectedPan, required String hint}) {
    final profile = ref.read(verifiedProfileProvider);
    final fullName = profile.fullName.trim();
    final profilePan = profile.panNumber.trim().toUpperCase();
    final required = hint == 'itr'
        ? const <String>['itr_ack_number', 'annual_income']
      : const <String>['scheme_reference'];

    return ValidationContext(
      stepTag: hint == 'itr' ? 'step8_itr' : 'step8_gst',
      requiredFields: required,
      profile: VerifiedProfileSnapshot(
        fullName: fullName.isEmpty ? null : fullName,
        panNumber: profilePan.isEmpty ? null : profilePan,
        selfDeclaredMonthlyIncome: profile.selfDeclaredMonthlyIncome,
        estimatedMonthlyIncome: profile.estimatedMonthlyIncome,
      ),
      apiVerifiedFields: <String, String>{
        if (expectedPan.isNotEmpty) 'pan_number': expectedPan,
      },
    );
  }

  Future<void> _verifyDoc(String type) async {
    var verified = false;
    var backendAttempted = false;
    var missingIdentifierForProduction = false;
    String? itrAckError;

    if (type == 'itr') {
      verified = _itrUploaded && _itrOcrOk;
      final itrAck = _itrAckController.text.trim().toUpperCase();
      itrAckError = Step8Validators.validateItrAcknowledgement(itrAck);
      if (verified && itrAckError != null) {
        verified = false;
        missingIdentifierForProduction = _requireProductionReadiness;
      }
      if (verified && _apiBaseUrl.isNotEmpty && _apiKey.isNotEmpty) {
        if (_requireProductionReadiness && itrAck.isEmpty) {
          missingIdentifierForProduction = true;
          verified = false;
        }
      }
      if (verified && _apiBaseUrl.isNotEmpty && _apiKey.isNotEmpty) {
        backendAttempted = true;
        try {
          final client = BackendClient(
            baseUrl: _apiBaseUrl,
            apiKey: _apiKey,
            deviceId: 'dev_b_step8',
            signatureProvider: signatureProviderFromApiKey(_apiKey),
          );
          final resp = await client.verifyItr(itrAck);
          final status = resp.status.toUpperCase();
          verified = status == 'FOUND' || status == 'OK' || status == 'VERIFIED' || status == 'ACTIVE';
        } catch (_) {
          verified = !_requireProductionReadiness && _itrUploaded && _itrOcrOk;
        }
      } else if (_requireProductionReadiness) {
        verified = false;
      }
      setState(() => _itrVerified = verified);
    }

    if (type == 'gst') {
      verified = _gstUploaded && _gstOcrOk;
      if (verified && _apiBaseUrl.isNotEmpty && _apiKey.isNotEmpty) {
        backendAttempted = true;
        try {
          final client = BackendClient(
            baseUrl: _apiBaseUrl,
            apiKey: _apiKey,
            deviceId: 'dev_b_step8_gst',
            signatureProvider: signatureProviderFromApiKey(_apiKey),
          );
          final gstIdentifier = _gstPanController.text.trim().toUpperCase();
          final resp = await client.postJson('/verify/gst', <String, dynamic>{
            'identifier': gstIdentifier,
          });
          final status = resp.status.toUpperCase();
          verified = status == 'FOUND' || status == 'OK' || status == 'VERIFIED' || status == 'ACTIVE';
        } catch (_) {
          verified = !_requireProductionReadiness && _gstUploaded && _gstOcrOk;
        }
      } else if (_requireProductionReadiness) {
        verified = false;
      }
      setState(() => _gstVerified = verified);
    }

    if (!verified) {
      if (type == 'itr' && itrAckError != null) {
        _toast(itrAckError);
      } else if (type == 'itr' && missingIdentifierForProduction) {
        _toast('Enter ITR acknowledgement number before verification in production mode.');
      } else if (type == 'itr' && _requireProductionReadiness && !backendAttempted) {
        _toast('ITR backend verification is required in production mode.');
      } else if (type == 'gst' && _requireProductionReadiness && !backendAttempted) {
        _toast('GST backend verification is required in production mode.');
      } else {
        _toast('Verification failed for $type. Check details and retry.');
      }
    }
  }

  void _completeStep() {
    if (_itrSelected && !_itrVerified) {
      return _toast('Complete ITR upload, OCR and verification.');
    }
    if (_gstSelected && !_gstVerified) {
      return _toast('Complete GST upload, OCR and verification.');
    }

    final itrAnnual = _itrSelected ? double.tryParse(_itrAnnualIncomeController.text.trim()) : 0.0;
    final gstAnnual = _gstSelected ? double.tryParse(_gstAnnualIncomeController.text.trim()) : 0.0;

    if (_itrSelected && (itrAnnual == null || itrAnnual <= 0)) {
      return _toast('Enter a valid positive annual income for ITR.');
    }
    if (_gstSelected && (gstAnnual == null || gstAnnual <= 0)) {
      return _toast('Enter a valid positive annual income for GST.');
    }

    final ok = ref.read(verifiedProfileProvider.notifier).completeStep8(
          selectedItr: _itrSelected,
          selectedGst: _gstSelected,
          itrVerified: _itrVerified,
          gstVerified: _gstVerified,
          itrAnnualIncome: itrAnnual ?? 0.0,
          gstAnnualIncome: gstAnnual ?? 0.0,
        );

    if (!ok) {
      return _toast('Unable to complete Step-8. Check previous step status and selected module verification.');
    }

    widget.onContinue();
  }

  Widget _docCard({
    required String type,
    required String title,
    required bool selected,
    required ValueChanged<bool?> onSelected,
    required TextEditingController panController,
    TextEditingController? ackController,
    required TextEditingController nameController,
    required TextEditingController incomeController,
    required bool uploaded,
    required bool ocrOk,
    required bool verified,
    required String profilePan,
    required String profileName,
    required double monthlyBaseline,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
                Checkbox(value: selected, onChanged: onSelected),
              ],
            ),
            const Text('Optional module. If selected, full validation is mandatory.'),
            const SizedBox(height: 10),
            TextField(
              enabled: selected,
              controller: panController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'PAN Number'),
            ),
            if (ackController != null) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                enabled: selected,
                controller: ackController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'ITR Acknowledgement Number'),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              enabled: selected,
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name as per document'),
            ),
            const SizedBox(height: 10),
            TextField(
              enabled: selected,
              controller: incomeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Annual Income (INR)'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton(
                  onPressed: selected ? () => _upload(type) : null,
                  child: const Text('Upload'),
                ),
                OutlinedButton(
                  onPressed: selected
                      ? () => _runOcr(type, profilePan, profileName, monthlyBaseline)
                      : null,
                  child: const Text('Run OCR'),
                ),
                ElevatedButton(
                  onPressed: selected ? () => _verifyDoc(type) : null,
                  child: const Text('Verify'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Status: Upload ${uploaded ? 'OK' : 'Pending'} | OCR ${ocrOk ? 'OK' : 'Pending'} | Verify ${verified ? 'OK' : 'Pending'}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(verifiedProfileProvider);
    final pan = profile.panNumber.trim().toUpperCase();
    final name = profile.fullName.toUpperCase();
    final monthlyBaseline = _monthlyBaselineFromStep3(profile.transactionCount);

    return Scaffold(
      appBar: AppBar(title: const Text('Step 8 of 9 • ITR/GST')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const StepProgressHeader(currentStep: 8),
          const SizedBox(height: 14),
          Text('Step-3 monthly baseline (prototype): INR ${monthlyBaseline.toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          const Text('Selected ITR/GST documents must pass PAN/name checks and income within +-40% tolerance.'),
          const SizedBox(height: 12),
          _docCard(
            type: 'itr',
            title: 'Income Tax Return (ITR)',
            selected: _itrSelected,
            onSelected: (v) => setState(() => _itrSelected = v ?? false),
            panController: _itrPanController,
            ackController: _itrAckController,
            nameController: _itrNameController,
            incomeController: _itrAnnualIncomeController,
            uploaded: _itrUploaded,
            ocrOk: _itrOcrOk,
            verified: _itrVerified,
            profilePan: pan,
            profileName: name,
            monthlyBaseline: monthlyBaseline,
          ),
          _docCard(
            type: 'gst',
            title: 'GST Filing Statement',
            selected: _gstSelected,
            onSelected: (v) => setState(() => _gstSelected = v ?? false),
            panController: _gstPanController,
            nameController: _gstNameController,
            incomeController: _gstAnnualIncomeController,
            uploaded: _gstUploaded,
            ocrOk: _gstOcrOk,
            verified: _gstVerified,
            profilePan: pan,
            profileName: name,
            monthlyBaseline: monthlyBaseline,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _completeStep,
            child: const Text('Continue to Step 9'),
          ),
        ],
      ),
    );
  }
}
