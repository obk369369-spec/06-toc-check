$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
$engine=Join-Path $repoRoot 'TOOL006_TOC\tool006_engine.ps1'
$fixturePaths=@(
    (Join-Path $repoRoot 'tests\marketsandmarkets_historical_fixtures.json'),
    (Join-Path $repoRoot 'fixtures\tool006_regression.json'),
    (Join-Path $repoRoot 'tests\tool006_chronic_error_fixtures.json')
)
$cases=[System.Collections.Generic.List[object]]::new()
$markets=Get-Content -LiteralPath $fixturePaths[0] -Raw -Encoding UTF8|ConvertFrom-Json
foreach($case in @($markets.functional_cases)){$cases.Add([pscustomobject]@{publisher=$markets.publisher;case=$case})}
$regression=Get-Content -LiteralPath $fixturePaths[1] -Raw -Encoding UTF8|ConvertFrom-Json
foreach($case in @($regression.cases)){$cases.Add([pscustomobject]@{publisher=$case.publisher;case=$case})}
$chronic=Get-Content -LiteralPath $fixturePaths[2] -Raw -Encoding UTF8|ConvertFrom-Json
foreach($case in @($chronic.cases)){$cases.Add([pscustomobject]@{publisher=$case.publisher;case=$case})}
if($cases.Count -lt 2){throw 'Functional fixtures were not loaded'}

$passed=0
foreach($entry in $cases){
    $case=$entry.case
    $testRoot=Join-Path ([IO.Path]::GetTempPath()) ('tool006-functional-'+[guid]::NewGuid().ToString('N'))
    try{
        $tool=Join-Path $testRoot 'TOOL006_TOC'
        New-Item -ItemType Directory -Force -Path $tool|Out-Null
        $inputPath=Join-Path $testRoot 'actual_input.txt'
        $outputPath=Join-Path $testRoot 'actual_output.txt'
        @($case.input)|Set-Content -LiteralPath $inputPath -Encoding UTF8
        & $engine -Root $testRoot -InputPath $inputPath -OutputPath $outputPath -Publisher $entry.publisher -ReportId $case.report_id
        if($LASTEXITCODE -notin @(0,$null)){throw "[$($case.id)] engine exit $LASTEXITCODE"}
        $state=Get-Content -LiteralPath (Join-Path $tool 'tool_state.json') -Raw -Encoding UTF8|ConvertFrom-Json
        $actual=@(Get-Content -LiteralPath $outputPath -Encoding UTF8)
        $expected=@($case.expected)
        if($state.FINAL_STATUS -ne $case.expected_status){throw "[$($case.id)] status expected=$($case.expected_status) actual=$($state.FINAL_STATUS)"}
        if(($actual-join "`n") -cne ($expected-join "`n")){throw "[$($case.id)] output mismatch`nEXPECTED:`n$($expected-join "`n")`nACTUAL:`n$($actual-join "`n")"}
        $passed++
        Write-Host "PASS $($case.id)"
    }finally{
        if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}
    }
}

[pscustomobject]@{
    status='PASS'
    flow='ACTUAL_INPUT_FILE->ENGINE->OUTPUT_FILE->EXPECTED_COMPARE'
    passed=$passed
    total=$cases.Count
    marketsandmarkets_cases=@($markets.functional_cases).Count
    existing_regression_cases=@($regression.cases).Count
    chronic_error_cases=@($chronic.cases).Count
}|ConvertTo-Json -Compress
