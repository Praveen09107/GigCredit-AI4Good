param(
    [switch]$SkipTraining,
    [switch]$SkipScorerPackaging,
    [string[]]$RequireRuntimeArtifact = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed with exit code ${LASTEXITCODE}: $Name"
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

$contractTemplate = Join-Path $repoRoot "offline_ml\data\runtime_model_contract.template.json"
$contractActual = Join-Path $repoRoot "offline_ml\data\runtime_model_contract.json"

if (-not (Test-Path $contractActual)) {
    Copy-Item $contractTemplate $contractActual
    Write-Host "Created runtime contract placeholder at offline_ml/data/runtime_model_contract.json" -ForegroundColor Yellow
    Write-Host "Fill real metadata values, then rerun this script." -ForegroundColor Yellow
    exit 1
}

if (-not $SkipTraining) {
    Invoke-Step -Name "Train final pillar models" -Action { python -m offline_ml.src.train_final }
    Invoke-Step -Name "Train meta learner" -Action { python -m offline_ml.src.train_meta_learner }
}

Invoke-Step -Name "Evaluate real-ready metrics" -Action { python -m offline_ml.src.evaluate_real_ready }
Invoke-Step -Name "Validate export parity" -Action { python -m offline_ml.src.validate_export }

if (-not $SkipScorerPackaging) {
    Invoke-Step -Name "Export scorer Dart artifacts" -Action { python -m offline_ml.src.export_to_dart }
    Invoke-Step -Name "Package scorer/constants artifacts" -Action { python -m offline_ml.src.package_artifacts_for_app }
}

$runtimeArgs = @("-m", "offline_ml.src.package_runtime_models_for_app")
foreach ($artifact in $RequireRuntimeArtifact) {
    $runtimeArgs += @("--require-artifact", $artifact)
}
Invoke-Step -Name "Package runtime model artifacts" -Action { python @runtimeArgs }

$gateArgs = @("-m", "offline_ml.src.check_production_readiness")
foreach ($artifact in $RequireRuntimeArtifact) {
    $gateArgs += @("--require-runtime-model", $artifact)
}
Invoke-Step -Name "Run strict production readiness gate" -Action { python @gateArgs }

Invoke-Step -Name "Build production handoff evidence bundle" -Action { python -m offline_ml.src.build_handoff_evidence_bundle }

Write-Host "`nSUCCESS: Production handoff workflow complete." -ForegroundColor Green
Write-Host "Evidence bundle: offline_ml/data/production_handoff_bundle.json" -ForegroundColor Green
