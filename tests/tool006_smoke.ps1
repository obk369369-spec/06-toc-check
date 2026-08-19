$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("tool006-smoke-" + [guid]::NewGuid().ToString("N"))

try {
    $controlTower = Join-Path $testRoot "CONTROL_TOWER"
    New-Item -ItemType Directory -Path $controlTower -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot "CONTROL_TOWER\tool006_engine.ps1") -Destination $controlTower
    Copy-Item -LiteralPath (Join-Path $repoRoot "CONTROL_TOWER\observer_engine.ps1") -Destination $controlTower

    $inputText = @'
Table of Contents
Introduction
Research Scope
Market Drivers
Market Drivers
Executive Summary
'@
    $powershell = Join-Path $PSHOME "powershell.exe"
    & $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $controlTower "tool006_engine.ps1") -Root $testRoot -InputText $inputText
    if ($LASTEXITCODE -ne 0) { throw "TOOL006 process failed: $LASTEXITCODE" }
    $env:WIC34_OBSERVER_ONCE = "1"
    & $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $controlTower "observer_engine.ps1") -Root $testRoot
    if ($LASTEXITCODE -ne 0) { throw "Observer process failed: $LASTEXITCODE" }

    $state = Get-Content -LiteralPath (Join-Path $testRoot "TOOL006_TOC\tool_state.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $evidence = Get-Content -LiteralPath (Join-Path $testRoot "TOOL006_TOC\evidence\tool006_evidence.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $snapshot = Get-Content -LiteralPath (Join-Path $controlTower "observer_snapshot.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    $result = @(Get-Content -LiteralPath $state.OUTPUT_PATH -Encoding UTF8)

    if ($state.FINAL_STATUS -ne "PASS" -or [int]$state.PROGRESS -ne 100) { throw "Body state mismatch" }
    if ((@($evidence.STAGE_HISTORY.PROGRESS) -join ",") -ne "10,30,70,100") { throw "Stage history mismatch" }
    if (@($result | Where-Object { $_ -match "Market Drivers" }).Count -ne 1) { throw "Duplicate removal mismatch" }
    if ($snapshot.CURRENT_TOOL -ne "TOOL006_TOC" -or $snapshot.FINAL_STATUS -ne "PASS" -or [int]$snapshot.PROGRESS -ne 100) {
        throw ("Observer mismatch: TOOL={0}, STATUS={1}, PROGRESS={2}" -f $snapshot.CURRENT_TOOL,$snapshot.FINAL_STATUS,$snapshot.PROGRESS)
    }

    "PASS: TOOL006 body, result, state history, and observer are synchronized."
}
finally {
    Remove-Item Env:WIC34_OBSERVER_ONCE -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
