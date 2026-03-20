export 'step_id.dart';

enum StepStatus {
  notStarted,
  inProgress,
  ocrComplete,
  pendingVerification,
  verified,
  rejected,
}
