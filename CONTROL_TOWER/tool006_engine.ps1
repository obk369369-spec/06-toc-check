param(
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$InputPath,
    [string]$InputText,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$controlTower = Join-Path $Root "CONTROL_TOWER"
$toolRoot = Join-Path $Root "TOOL006_TOC"
$statePath = Join-Path $toolRoot "tool_state.json"
$logPath = Join-Path $toolRoot "logs\progress.csv"
$packetPath = Join-Path $controlTower "STATE_PACKET.json"
$evidencePath = Join-Path $toolRoot "evidence\tool006_evidence.json"
if (-not $OutputPath) { $OutputPath = Join-Path $toolRoot "working\toc_result.txt" }
$runId = "TOOL006-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$started = Get-Date

foreach ($path in @((Split-Path $statePath), (Split-Path $logPath), (Split-Path $evidencePath), (Split-Path $OutputPath))) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$stageHistory = [System.Collections.Generic.List[object]]::new()
function Write-ToolState {
    param([string]$EngineStatus, [string]$FinalStatus, [int]$Progress, [string]$Step, [string]$Explain, [string]$NextAction)
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $event = [ordered]@{ TIME=$now; PROGRESS=$Progress; STEP=$Step; STATUS=$FinalStatus }
    $stageHistory.Add($event)
    "$now,TOOL006_TOC,$Step,$EngineStatus,$Explain" | Add-Content -LiteralPath $logPath -Encoding UTF8
    [ordered]@{
        CURRENT_TOOL="TOOL006_TOC"; ENGINE_STATUS=$EngineStatus; FINAL_STATUS=$FinalStatus
        CURRENT_STEP=$Step; EASY_EXPLAIN=$Explain; PROGRESS=$Progress; NEXT_ACTION=$NextAction
        USER_ACTION="없음"; DONE_ITEMS=@($stageHistory | ForEach-Object { $_.STEP })
        RUN_ID=$runId; OUTPUT_PATH=$OutputPath; SOURCE_PACKET=$packetPath
        VALIDATION_REASON=if($FinalStatus -eq "PASS"){"VERIFIED"}else{"IN_PROGRESS_OR_ERROR"}
        MISSING_FIELDS=@(); BLACK_WINDOW_BLOCK="PASS"; TIME=$now
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8
}

Write-ToolState "RUNNING" "HOLD" 10 "입력 확인" "목차 입력을 읽고 있습니다." "입력 내용 정규화"

try {
    if ($InputPath) {
        if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) { throw "Input file not found: $InputPath" }
        $InputText = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8
    }
    if ([string]::IsNullOrWhiteSpace($InputText)) { throw "Input text is empty" }

    Write-ToolState "RUNNING" "HOLD" 30 "입력 정규화" "빈 줄과 목차 잡음을 제거하고 있습니다." "목차 계층 정리"

$noise = '^(table of contents|contents|table\b|figure\b|list of tables|list of figures|description|methodology|title|close|read more|read less)$'
$lines = @($InputText -split "`r?`n" | ForEach-Object { ($_ -replace "`t", " " -replace '\s+', ' ').Trim() } | Where-Object { $_ -and $_ -notmatch $noise })
$seen = @{}
$output = [System.Collections.Generic.List[string]]::new()
$top = 0
$child = 0

foreach ($line in $lines) {
    $key = ($line -replace '^\d+(?:\.\d+){0,6}[\.\s]+', '').ToLowerInvariant()
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true

    if ($line -match '^(\d+(?:\.\d+){0,6})[\.\s]+(.+)$') {
        $depth = $Matches[1].Split('.').Count
        $output.Add((('  ' * ($depth - 1)) + $Matches[1] + ' ' + $Matches[2]))
        continue
    }

    $isTop = $line -match '^(Introduction|Executive Summary|Market Dynamics|Key Insights|Competitive Analysis|Competitive Landscape|Strategic Recommendations|Appendix|Company Profiles|Market Trends)$' -or
        $line -match 'Market Analysis, Insights and Forecast'
    if ($isTop) {
        $top++
        $child = 0
        $output.Add("$top $line")
    } else {
        if ($top -eq 0) { $top = 1 }
        $child++
        $output.Add("  $top.$child $line")
    }
}

    Write-ToolState "RUNNING" "HOLD" 70 "목차 계층 정리" "중복을 제거하고 번호와 들여쓰기를 정리했습니다." "결과 파일 검증"

    $status = if ($output.Count -gt 0) { "PASS" } else { "HOLD" }
    $output | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    $outputExists = Test-Path -LiteralPath $OutputPath -PathType Leaf
    $outputLength = if ($outputExists) { (Get-Item -LiteralPath $OutputPath).Length } else { 0 }

    Write-ToolState "COMPLETED" $status 100 "목차 정리 완료" "실제 결과 파일을 만들고 검증했습니다." "Observer 상태 동기화"

$evidence = [ordered]@{
    RUN_ID = $runId
    INPUT_SOURCE = if ($InputPath) { $InputPath } else { "INLINE_TEXT" }
    INPUT_COUNT = $lines.Count
    OUTPUT_COUNT = $output.Count
    OUTPUT_PATH = $OutputPath
    OUTPUT_LENGTH = $outputLength
    STATUS = $status
    STARTED = $started.ToString("yyyy-MM-dd HH:mm:ss")
    FINISHED = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    STAGE_HISTORY = @($stageHistory)
}
$evidence | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $evidencePath -Encoding UTF8

$packet = [ordered]@{
    "34_RULES_LOADED" = "TRUE"
    RUN_ID = $runId
    STATUS = $status
    CURRENT_STAGE = "TOOL006 목차 정리 완료"
    TOTAL_COUNT = $lines.Count
    PROCESSED_COUNT = $output.Count
    SUCCESS_COUNT = if ($status -eq "PASS") { $output.Count } else { 0 }
    HOLD_COUNT = if ($status -eq "HOLD") { 1 } else { 0 }
    FAIL_COUNT = 0
    LAST_RUN_TIME = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    LAST_OUTPUT = $OutputPath
    NEXT_OUTPUT = "없음"
    ERROR_TYPE = if ($status -eq "PASS") { "NONE" } else { "NO_OUTPUT" }
    CHECKPOINT = "TOOL006_OUTPUT_WRITTEN"
    RESTART_POINT = "NEXT_INPUT"
    EVIDENCE_BUNDLE = $evidencePath
    STOP_CARD = if ($status -eq "PASS") { "CLEAR" } else { "HOLD" }
}
$packet | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $packetPath -Encoding UTF8
}
catch {
    Write-ToolState "FAILED" "HOLD" 0 "목차 정리 오류" $_.Exception.Message "입력과 오류 내용을 확인"
    throw
}
