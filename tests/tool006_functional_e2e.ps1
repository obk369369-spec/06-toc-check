$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('tool006-functional-'+[guid]::NewGuid().ToString('N'))
$powershell=Join-Path $PSHOME 'powershell.exe'
try{
    $tool=Join-Path $testRoot 'TOOL006_TOC';$ct=Join-Path $testRoot 'CONTROL_TOWER'
    New-Item -ItemType Directory -Force -Path $tool,$ct|Out-Null
    Copy-Item -LiteralPath (Join-Path $repoRoot 'TOOL006_TOC\tool006_engine.ps1'),(Join-Path $repoRoot 'TOOL006_TOC\tool006_ui.ps1') -Destination $tool
    Copy-Item -LiteralPath (Join-Path $repoRoot 'CONTROL_TOWER\observer_engine.ps1') -Destination $ct
    $inputText="Introduction`nResearch Scope`nExecutive Summary`nMarket Dynamics`nMarket Drivers"
    $uiRaw=& $powershell -Sta -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $tool 'tool006_ui.ps1') -Root $testRoot -E2EInput $inputText
    if($LASTEXITCODE -ne 0){throw "UI exit $LASTEXITCODE"}
    $ui=$uiRaw|ConvertFrom-Json
    $env:WIC34_OBSERVER_ONCE='1';& $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $ct 'observer_engine.ps1') -Root $testRoot
    if($LASTEXITCODE -ne 0){throw "Observer exit $LASTEXITCODE"}
    $state=Get-Content -LiteralPath (Join-Path $tool 'tool_state.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $evidence=Get-Content -LiteralPath (Join-Path $tool 'evidence\tool006_evidence.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $snapshot=Get-Content -LiteralPath (Join-Path $ct 'observer_snapshot.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $expected="1 Introduction`r`n  1.1 Research Scope`r`n2 Executive Summary`r`n3 Market Dynamics`r`n  3.1 Market Drivers"
    $actual=(Get-Content -LiteralPath $state.OUTPUT_PATH -Raw -Encoding UTF8).TrimEnd()
    if($ui.status -ne 'PASS' -or $ui.engine_status -ne 'PASS'){throw 'UI did not complete the body flow'}
    if($state.FINAL_STATUS -ne 'PASS' -or [int]$state.PROGRESS -ne 100){throw 'Body state mismatch'}
    if((@($evidence.STAGE_HISTORY.PROGRESS)-join ',') -ne '10,30,70,100'){throw 'Stage history mismatch'}
    if($snapshot.CURRENT_TOOL -ne 'TOOL006_TOC' -or $snapshot.FINAL_STATUS -ne 'PASS' -or [int]$snapshot.PROGRESS -ne 100){throw 'Observer mismatch'}
    if(($actual -replace "`n","`r`n") -replace "`r`r`n","`r`n" -ne $expected){throw "Output mismatch: $actual"}
    [pscustomobject]@{status='PASS';flow='UI->ENGINE->OUTPUT+STATE->OBSERVER';engine_count=1;progress=100;stages='10,30,70,100'}|ConvertTo-Json
}finally{
    Remove-Item Env:WIC34_OBSERVER_ONCE -ErrorAction SilentlyContinue
    if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
