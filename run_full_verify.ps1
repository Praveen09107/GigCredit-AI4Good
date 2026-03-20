$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonExe = Join-Path $repoRoot 'venv\Scripts\python.exe'

if (-not (Test-Path $pythonExe)) {
  throw "Python executable not found at $pythonExe"
}

Write-Host '== GigCredit Full Verify: Backend + Flutter ==' -ForegroundColor Cyan

Push-Location (Join-Path $repoRoot 'backend')
try {
  Write-Host ''
  Write-Host 'Running backend contract smoke tests...' -ForegroundColor Yellow
  & $pythonExe -m unittest tests.test_contract_smoke.BackendContractSmokeTests
  if ($LASTEXITCODE -ne 0) {
    throw "Backend smoke tests failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

$flutterSuites = @(
  'test/verification_validation_engine_test.dart'
  'test/document_pipeline_service_test.dart'
  'test/step1_validators_test.dart'
  'test/step5_validators_test.dart'
  'test/step6_validators_test.dart'
  'test/step9_validators_test.dart'
  'test/step3_to_step9_linkage_test.dart'
  'test/step4_to_step9_guardrails_test.dart'
  'test/ondevice_ocr_service_test.dart'
  'test/ocr_engine_test.dart'
  'test/sample_inputs_ocr_parsing_test.dart'
  'test/integration_9_step_progression_test.dart'
)

Push-Location (Join-Path $repoRoot 'gigcredit_app')
try {
  Write-Host ''
  Write-Host 'Running Flutter verification and validation suites...' -ForegroundColor Yellow
  & flutter test @flutterSuites
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter verification suites failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

Write-Host ''
Write-Host 'Full verification battery passed.' -ForegroundColor Green
