$ErrorActionPreference="Stop"
$repoRoot=Split-Path $PSScriptRoot -Parent
$fixture=Get-Content -LiteralPath (Join-Path $repoRoot 'fixtures\tool006_regression.json') -Raw -Encoding UTF8|ConvertFrom-Json
$powershell=Join-Path $PSHOME 'powershell.exe'
$passed=0;$failed=0;$results=@()
foreach($case in $fixture.cases){
    $testRoot=Join-Path ([IO.Path]::GetTempPath()) ('tool006-fixture-'+[guid]::NewGuid().ToString('N'))
    try{
        $ct=Join-Path $testRoot 'CONTROL_TOWER';New-Item -ItemType Directory -Path $ct -Force|Out-Null
        $tool=Join-Path $testRoot 'TOOL006_TOC';New-Item -ItemType Directory -Path $tool -Force|Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot 'TOOL006_TOC\tool006_engine.ps1') -Destination $tool
        Copy-Item -LiteralPath (Join-Path $repoRoot 'CONTROL_TOWER\observer_engine.ps1') -Destination $ct
        $inputText=($case.input -join "`n")
        & $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $tool 'tool006_engine.ps1') -Root $testRoot -InputText $inputText -Publisher $case.publisher -ReportId $case.report_id
        if($LASTEXITCODE -ne 0){throw "engine exit $LASTEXITCODE"}
        $env:WIC34_OBSERVER_ONCE='1';& $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $ct 'observer_engine.ps1') -Root $testRoot
        if($LASTEXITCODE -ne 0){throw "observer exit $LASTEXITCODE"}
        $state=Get-Content -LiteralPath (Join-Path $testRoot 'TOOL006_TOC\tool_state.json') -Raw -Encoding UTF8|ConvertFrom-Json
        $actual=@(Get-Content -LiteralPath $state.OUTPUT_PATH -Encoding UTF8)
        $snapshot=Get-Content -LiteralPath (Join-Path $ct 'observer_snapshot.json') -Raw -Encoding UTF8|ConvertFrom-Json
        $ok=($state.FINAL_STATUS -eq $case.expected_status)-and(($actual -join "`n") -eq (@($case.expected)-join "`n"))-and($snapshot.CURRENT_TOOL -eq 'TOOL006_TOC')-and($snapshot.FINAL_STATUS -eq $case.expected_status)
        if($case.expected_status -eq 'HOLD'){
            $candidate=@(Get-ChildItem -LiteralPath (Join-Path $testRoot 'TOOL006_TOC\evidence\error_candidates') -File)
            if($candidate.Count -ne 1){throw "error candidate count=$($candidate.Count)"}
            $candidateBody=Get-Content -LiteralPath $candidate[0].FullName -Raw -Encoding UTF8|ConvertFrom-Json
            $ok=$ok-and(-not[string]::IsNullOrWhiteSpace($candidateBody.ORIGINAL_TOC))-and(-not[string]::IsNullOrWhiteSpace($candidateBody.TOOL_OUTPUT))-and(@($candidateBody.SUSPICIOUS_LINES).Count -gt 0)-and(-not[string]::IsNullOrWhiteSpace($candidateBody.CREATED_AT))
        }
        if(-not $ok){throw "expected=$($case.expected_status)/$(@($case.expected)-join '|') actual=$($state.FINAL_STATUS)/$($actual-join '|')"}
        $passed++;$results+=[pscustomobject]@{id=$case.id;status='PASS';engine_status=$state.FINAL_STATUS}
    }catch{$failed++;$results+=[pscustomobject]@{id=$case.id;status='FAIL';error=$_.Exception.Message}}
    finally{Remove-Item Env:WIC34_OBSERVER_ONCE -ErrorAction SilentlyContinue;if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}}
}
$results|Format-Table -AutoSize
if($failed){throw "Fixture regression failed: $failed/$($fixture.cases.Count)"}
"PASS: $passed representative fixtures; single engine, output, state, and observer synchronized."
