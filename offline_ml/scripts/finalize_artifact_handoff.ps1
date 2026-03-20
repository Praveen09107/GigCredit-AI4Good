param(
    [string[]]$RequireRuntimeArtifact = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Run-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed with exit code ${LASTEXITCODE}: $Name"
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

$pkgArgs = @("-m", "offline_ml.src.package_runtime_models_for_app")
foreach ($artifact in $RequireRuntimeArtifact) {
    $pkgArgs += @("--require-artifact", $artifact)
}
Run-Step -Name "Package runtime model artifacts + checksums" -Action { python @pkgArgs }

$gateArgs = @("-m", "offline_ml.src.check_production_readiness")
foreach ($artifact in $RequireRuntimeArtifact) {
    $gateArgs += @("--require-runtime-model", $artifact)
}
Run-Step -Name "Run strict production readiness gate" -Action { python @gateArgs }

Run-Step -Name "Build production handoff evidence bundle" -Action {
    python -m offline_ml.src.build_handoff_evidence_bundle
}

Write-Host "`nREADY: Handoff evidence generated." -ForegroundColor Green
Write-Host "- offline_ml/data/runtime_model_handoff_report.json" -ForegroundColor Green
Write-Host "- offline_ml/data/production_handoff_bundle.json" -ForegroundColor Green
