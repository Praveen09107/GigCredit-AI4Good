import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../ai/ai_native_bridge.dart';
import '../../../config/app_mode.dart';
import '../../../core/files/document_picker.dart';
import '../../../core/security/request_signer.dart';
import '../../../core/validation/step2_validators.dart';
import '../../../services/backend_client.dart';
import '../../../services/document_pipeline_service.dart';
import '../../../models/enums/document_type.dart';
import '../../../ai/verification_validation_engine.dart';
import '../../../state/offline_sync_service.dart';
import '../../../state/verified_profile_provider.dart';
import '../../widgets/step_progress_header.dart';

class Step2KycScreen extends ConsumerStatefulWidget {
  const Step2KycScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<Step2KycScreen> createState() => _Step2KycScreenState();
}

class _Step2KycScreenState extends ConsumerState<Step2KycScreen> {
  static final String _apiBaseUrl = AppMode.resolvedBackendBaseUrl;
  static const String _apiKey = String.fromEnvironment('GIGCREDIT_API_KEY');
  static const bool _requireProductionReadiness = AppMode.requireProductionReadiness;
  final _docPipeline = DocumentPipelineService();

  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();

  bool _aadhaarVerifying = false;
  bool _panVerifying = false;
  bool _aadhaarVerified = false;
  bool _panVerified = false;

  bool _aadhaarDocUploaded = false;
  bool _aadhaarBackUploaded = false;
  bool _panDocUploaded = false;
  bool _selfieCaptured = false;
  bool _faceVerified = false;
  double _faceMatchScore = 0.0;

  String? _aadhaarDocPath;
  String? _selfiePath;

  @override
  void dispose() {
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }

  Future<void> _verifyAadhaar() async {
    final err = Step2Validators.validateAadhaar(_aadhaarController.text);
    if (err != null) {
      _toast(err);
      return;
    }

    setState(() => _aadhaarVerifying = true);
    final verifiedOnline = await _verifyOrQueue(
      path: '/verify/aadhaar',
      body: <String, dynamic>{
        'identifier': Step2Validators.normalizeAadhaar(_aadhaarController.text),
      },
    );
    if (!mounted) return;
    setState(() {
      _aadhaarVerifying = false;
      _aadhaarVerified = verifiedOnline;
    });
    if (verifiedOnline) {
      _toast('Aadhaar verified via backend. Upload unlocked.');
    } else if (_requireProductionReadiness) {
      _toast('Aadhaar backend verification is required in production mode.');
    } else {
      _toast('Aadhaar verification queued (offline/mock fallback). Upload unlocked.');
    }
  }

  Future<void> _verifyPan() async {
    final err = Step2Validators.validatePan(_panController.text);
    if (err != null) {
      _toast(err);
      return;
    }

    setState(() => _panVerifying = true);
    final normalizedPan = Step2Validators.normalizePan(_panController.text);
    final verifiedOnline = await _verifyOrQueue(
      path: '/verify/pan',
      body: <String, dynamic>{
        'identifier': normalizedPan,
      },
    );
    if (!mounted) return;
    setState(() {
      _panVerifying = false;
      _panVerified = verifiedOnline;
      _panController.text = normalizedPan;
    });
    if (verifiedOnline) {
      _toast('PAN verified via backend. Upload unlocked.');
    } else if (_requireProductionReadiness) {
      _toast('PAN backend verification is required in production mode.');
    } else {
      _toast('PAN verification queued (offline/mock fallback). Upload unlocked.');
    }
  }

  Future<bool> _verifyOrQueue({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    if (_apiBaseUrl.isNotEmpty && _apiKey.isNotEmpty) {
      try {
        final client = BackendClient(
          baseUrl: _apiBaseUrl,
          apiKey: _apiKey,
          deviceId: 'dev_b_kyc',
          signatureProvider: signatureProviderFromApiKey(_apiKey),
        );
        final response = await client.postJson(path, body).timeout(const Duration(seconds: 4));
        final status = response.status.toUpperCase();
        if (status == 'SUCCESS' || status == 'FOUND' || status == 'OK' || status == 'VERIFIED') {
          return true;
        }
      } catch (_) {
        // Fall through to offline queue.
      }
    }

    await ref.read(offlineSyncServiceProvider).queueVerification(path: path, body: body);
    return false;
  }

  Future<void> _uploadAadhaar({required bool isBack}) async {
    if (!_aadhaarVerified) {
      _toast('Verify Aadhaar number first.');
      return;
    }

    final file = await DocumentPicker.pickSingle(imageOnly: true);
    if (file == null || !mounted) return;

    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      _toast('Unable to read Aadhaar file from local storage. Please retry.');
      return;
    }

    try {
      final profile = ref.read(verifiedProfileProvider);
      final normalizedAadhaar = Step2Validators.normalizeAadhaar(_aadhaarController.text);
      final aadhaarLast4 = normalizedAadhaar.length >= 4
          ? normalizedAadhaar.substring(normalizedAadhaar.length - 4)
          : '';
      final processed = await _docPipeline.processFile(
        filePath: filePath,
        documentType: isBack ? DocumentType.aadhaarBack : DocumentType.aadhaarFront,
        validationContext: ValidationContext(
          stepTag: isBack ? 'step2_aadhaar_back' : 'step2_aadhaar_front',
          requiredFields: isBack
              ? const <String>['address_line']
              : const <String>['aadhaar_last4'],
          profile: VerifiedProfileSnapshot(
            fullName: profile.fullName,
            aadhaarLast4: profile.aadhaarNumber.length >= 4
                ? profile.aadhaarNumber.substring(profile.aadhaarNumber.length - 4)
                : null,
          ),
          apiVerifiedFields: <String, String>{
            'aadhaar_last4': aadhaarLast4,
          },
        ),
      );
      if (!isBack) {
        final extractedLast4 = (processed.fields['aadhaar_last4'] ?? '').trim();
        final entered = Step2Validators.normalizeAadhaar(_aadhaarController.text);
        final enteredLast4 = entered.length >= 4 ? entered.substring(entered.length - 4) : '';
        if (extractedLast4.isNotEmpty && enteredLast4.isNotEmpty && extractedLast4 != enteredLast4) {
          if (_requireProductionReadiness) {
            _toast('Aadhaar number mismatch with uploaded document. Please re-check and upload a matching Aadhaar image.');
            return;
          }
          _toast('Warning: Aadhaar number does not fully match OCR extraction.');
        }
      }
    } catch (_) {
      _toast(
        isBack
            ? 'Aadhaar back OCR/validation failed. Please upload a clearer Aadhaar back image.'
            : 'Aadhaar OCR/validation failed. Please upload a clearer Aadhaar image.',
      );
      return;
    }

    setState(() {
      if (isBack) {
        _aadhaarBackUploaded = true;
      } else {
        _aadhaarDocUploaded = true;
        _aadhaarDocPath = filePath;
      }
      _faceVerified = false;
    });
    _toast(
      isBack
          ? 'Aadhaar back document selected: ${file.name}'
          : 'Aadhaar front document selected: ${file.name}',
    );
  }

  Future<void> _uploadPan() async {
    if (!_panVerified) {
      _toast('Verify PAN number first.');
      return;
    }

    final file = await DocumentPicker.pickSingle(imageOnly: true);
    if (file == null || !mounted) return;

    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      _toast('Unable to read PAN file from local storage. Please retry.');
      return;
    }

    try {
      final profile = ref.read(verifiedProfileProvider);
      final enteredPan = Step2Validators.normalizePan(_panController.text);
      final processed = await _docPipeline.processFile(
        filePath: filePath,
        documentType: DocumentType.pan,
        validationContext: ValidationContext(
          stepTag: 'step2_pan',
          requiredFields: const <String>['pan_number'],
          profile: VerifiedProfileSnapshot(
            fullName: profile.fullName,
            panNumber: profile.panNumber.isEmpty ? null : profile.panNumber,
          ),
          apiVerifiedFields: <String, String>{
            'pan_number': enteredPan,
          },
        ),
      );
      final extractedPan = (processed.fields['pan_number'] ?? '').trim().toUpperCase();

      if (extractedPan.isNotEmpty && enteredPan.isNotEmpty && extractedPan != enteredPan) {
        if (_requireProductionReadiness) {
          _toast('PAN mismatch with uploaded document. Please re-check and upload a matching PAN image.');
          return;
        }
        _toast('Warning: PAN does not fully match OCR extraction.');
      }

      if (extractedPan.isNotEmpty) {
        _panController.text = extractedPan;
      }
    } catch (_) {
      _toast('PAN OCR/validation failed. Please upload a clearer PAN image.');
      return;
    }

    setState(() {
      _panDocUploaded = true;
      _faceVerified = false;
    });
    _toast('PAN document selected: ${file.name}');
  }

  Future<void> _captureSelfieAndVerifyFace() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null || !mounted) return;

    if (!_aadhaarDocUploaded || !_aadhaarBackUploaded || !_panDocUploaded) {
      setState(() {
        _selfieCaptured = true;
        _selfiePath = picked.path;
        _faceVerified = false;
      });
      _toast('Upload Aadhaar front, Aadhaar back, and PAN documents before face verification.');
      return;
    }

    setState(() {
      _selfieCaptured = true;
      _selfiePath = picked.path;
    });

    final selfiePath = _selfiePath;
    final aadhaarPath = _aadhaarDocPath;

    if (selfiePath == null || aadhaarPath == null || selfiePath.isEmpty || aadhaarPath.isEmpty) {
      if (_requireProductionReadiness) {
        setState(() => _faceVerified = false);
        _toast('Face verification requires readable local selfie and Aadhaar image paths.');
      } else {
        setState(() {
          _faceVerified = true;
          _faceMatchScore = 0.80;
        });
        _toast('Face verification accepted in integration mode (file-path fallback).');
      }
      return;
    }

    try {
      final bridge = NativeAiBridge();
      final health = await bridge.getHealth();
      if (!mounted) return;

      if (!health.supportsFaceMatch) {
        if (_requireProductionReadiness) {
          setState(() {
            _faceVerified = false;
            _faceMatchScore = 0.0;
          });
          _toast('Native face-match model/runtime is unavailable in production mode.');
        } else {
          setState(() {
            _faceVerified = true;
            _faceMatchScore = 0.80;
          });
          _toast('Face verification accepted in integration mode (native face path unavailable).');
        }
        return;
      }

      final selfieBytes = await File(selfiePath).readAsBytes();
      final aadhaarBytes = await File(aadhaarPath).readAsBytes();
      final result = await bridge.matchFaces(selfieBytes, aadhaarBytes);
      if (!mounted) return;

      setState(() {
        _faceVerified = result.passed;
        _faceMatchScore = result.similarity;
      });
      if (result.passed) {
        _toast('Face verification completed via native runtime (similarity ${result.similarity.toStringAsFixed(2)}).');
      } else {
        _toast('Face verification failed (similarity ${result.similarity.toStringAsFixed(2)}).');
      }
    } catch (_) {
      if (!mounted) return;
      if (_requireProductionReadiness) {
        setState(() {
          _faceVerified = false;
          _faceMatchScore = 0.0;
        });
        _toast('Face verification failed. Native match is required in production mode.');
      } else {
        setState(() {
          _faceVerified = true;
          _faceMatchScore = 0.80;
        });
        _toast('Face verification accepted in integration mode (runtime fallback).');
      }
    }
  }

  void _completeStep() {
    if (!(_aadhaarVerified && _panVerified && _aadhaarDocUploaded && _aadhaarBackUploaded && _panDocUploaded && _faceVerified)) {
      _toast('Complete all Step-2 verification checks to continue.');
      return;
    }

    final ok = ref.read(verifiedProfileProvider.notifier).completeStep2(
          aadhaarNumber: Step2Validators.normalizeAadhaar(_aadhaarController.text),
          panNumber: Step2Validators.normalizePan(_panController.text),
          faceMatchScore: _faceMatchScore,
        );

    if (!ok) {
      _toast('Cross-step validation failed. Check identity consistency.');
      return;
    }

    widget.onContinue();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _statusChip(bool ok, String label) {
    return Chip(
      label: Text(label),
      backgroundColor: ok ? const Color(0xFFD5F5DE) : const Color(0xFFF2F2F5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 2 of 9 • Identity (KYC)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const StepProgressHeader(currentStep: 2),
          const SizedBox(height: 14),
          const Text('Aadhaar Verification', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _aadhaarController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Aadhaar Number (12 digits)'),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              ElevatedButton(
                onPressed: _aadhaarVerifying ? null : _verifyAadhaar,
                child: Text(_aadhaarVerifying ? 'Verifying...' : 'Verify Aadhaar'),
              ),
              const SizedBox(width: 8),
              _statusChip(_aadhaarVerified, _aadhaarVerified ? 'Verified' : 'Not verified'),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _aadhaarVerified ? () => _uploadAadhaar(isBack: false) : null,
            child: Text(_aadhaarDocUploaded ? 'Aadhaar front uploaded' : 'Upload Aadhaar Front Photo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _aadhaarVerified ? () => _uploadAadhaar(isBack: true) : null,
            child: Text(_aadhaarBackUploaded ? 'Aadhaar back uploaded' : 'Upload Aadhaar Back Photo'),
          ),
          const Divider(height: 26),
          const Text('PAN Verification', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _panController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'PAN Number'),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              ElevatedButton(
                onPressed: _panVerifying ? null : _verifyPan,
                child: Text(_panVerifying ? 'Verifying...' : 'Verify PAN'),
              ),
              const SizedBox(width: 8),
              _statusChip(_panVerified, _panVerified ? 'Verified' : 'Not verified'),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _panVerified ? _uploadPan : null,
            child: Text(_panDocUploaded ? 'PAN uploaded' : 'Upload PAN Card Photo'),
          ),
          const Divider(height: 26),
          const Text('Live Selfie + Face Match', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _captureSelfieAndVerifyFace,
            child: Text(_selfieCaptured ? 'Selfie captured' : 'Capture Live Selfie'),
          ),
          const SizedBox(height: 8),
          _statusChip(_faceVerified, _faceVerified ? 'Face verified' : 'Face not verified'),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: _completeStep, child: const Text('Continue to Step 3')),
        ],
      ),
    );
  }
}
