param(
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$StatePacketPath
)

$ErrorActionPreference = "Stop"
$controlTower = Join-Path $Root "CONTROL_TOWER"
$outputPath = Join-Path $controlTower "tool034_state.json"
if (-not $StatePacketPath) {
    $localPacket = Join-Path $controlTower "STATE_PACKET.json"
    if (Test-Path -LiteralPath $localPacket -PathType Leaf) { $StatePacketPath = $localPacket }
}

$requiredFields = @(
    "RUN_ID", "STATUS", "CURRENT_STAGE", "TOTAL_COUNT", "PROCESSED_COUNT",
    "SUCCESS_COUNT", "HOLD_COUNT", "FAIL_COUNT", "LAST_RUN_TIME", "LAST_OUTPUT",
    "NEXT_OUTPUT", "ERROR_TYPE", "CHECKPOINT", "RESTART_POINT", "EVIDENCE_BUNDLE",
    "STOP_CARD", "34_RULES_LOADED"
)
$missing = @()
$packet = $null
$readError = $null
if (-not $StatePacketPath -or -not (Test-Path -LiteralPath $StatePacketPath -PathType Leaf)) {
    $missing = @($requiredFields)
    $readError = "STATE_PACKET_NOT_FOUND"
} else {
    try {
        $packet = Get-Content -LiteralPath $StatePacketPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $available = @($packet.PSObject.Properties.Name)
        $missing = @($requiredFields | Where-Object { $_ -notin $available })
    } catch {
        $missing = @($requiredFields)
        $readError = "STATE_PACKET_PARSE_FAIL"
    }
}

$processed = if ($packet -and $packet.PSObject.Properties.Name -contains "PROCESSED_COUNT") { [int]$packet.PROCESSED_COUNT } else { 0 }
$rulesLoaded = $packet -and $packet.PSObject.Properties.Name -contains "34_RULES_LOADED" -and [string]$packet."34_RULES_LOADED" -eq "TRUE"
$hasEvidence = $packet -and $packet.PSObject.Properties.Name -contains "EVIDENCE_BUNDLE" -and -not [string]::IsNullOrWhiteSpace([string]$packet.EVIDENCE_BUNDLE)
$hasCheckpoint = $packet -and $packet.PSObject.Properties.Name -contains "CHECKPOINT" -and -not [string]::IsNullOrWhiteSpace([string]$packet.CHECKPOINT)
$rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
$outputFull = if ($packet -and $packet.PSObject.Properties.Name -contains "LAST_OUTPUT") { [System.IO.Path]::GetFullPath([string]$packet.LAST_OUTPUT) } else { $null }
$evidenceFull = if ($hasEvidence) { [System.IO.Path]::GetFullPath([string]$packet.EVIDENCE_BUNDLE) } else { $null }
$outputInsideRoot = $outputFull -and $outputFull.StartsWith($rootFull,[System.StringComparison]::OrdinalIgnoreCase)
$evidenceInsideRoot = $evidenceFull -and $evidenceFull.StartsWith($rootFull,[System.StringComparison]::OrdinalIgnoreCase)
$outputExists = $outputInsideRoot -and (Test-Path -LiteralPath $outputFull -PathType Leaf)
$evidenceExists = $evidenceInsideRoot -and (Test-Path -LiteralPath $evidenceFull -PathType Leaf)
$runTime = if ($packet -and $packet.PSObject.Properties.Name -contains "LAST_RUN_TIME") { [datetime]::MinValue } else { [datetime]::MinValue }
if ($packet -and $packet.PSObject.Properties.Name -contains "LAST_RUN_TIME") { [datetime]::TryParse([string]$packet.LAST_RUN_TIME,[ref]$runTime) | Out-Null }
$isFresh = $runTime -ne [datetime]::MinValue -and ((Get-Date) - $runTime).TotalMinutes -le 10 -and ((Get-Date) - $runTime).TotalMinutes -ge -1
$canPass = $missing.Count -eq 0 -and $processed -gt 0 -and $rulesLoaded -and $hasEvidence -and $hasCheckpoint -and $outputExists -and $evidenceExists -and $isFresh
$reason = if ($readError) { $readError } elseif ($missing.Count -gt 0) {
    "MISSING_FIELDS=" + ($missing -join ",")
} elseif ($processed -le 0) { "NO_REAL_PROCESSING" } elseif (-not $rulesLoaded) {
    "34_RULES_LOADED_NOT_TRUE"
} elseif (-not $hasEvidence -or -not $hasCheckpoint) { "EVIDENCE_OR_CHECKPOINT_MISSING" } elseif (-not $outputExists -or -not $evidenceExists) {
    "OUTPUT_OR_EVIDENCE_FILE_NOT_FOUND"
} elseif (-not $isFresh) {
    "STALE_STATE_PACKET"
} else { "VERIFIED" }

$data = [ordered]@{
    CURRENT_TOOL = "TOOL034"
    ENGINE_STATUS = if ($readError) { "HOLD" } else { "RUNNING" }
    FINAL_STATUS = if ($canPass) { "PASS" } else { "HOLD" }
    CURRENT_STEP = "중앙 STATE_PACKET 검증"
    EASY_EXPLAIN = if ($canPass) { "34번이 실제 중앙 상태와 증거를 확인했습니다." } else { "중앙 상태에 실제 실행 증거가 부족해 HOLD입니다." }
    PROGRESS = if ($canPass) { 100 } else { 0 }
    NEXT_ACTION = if ($canPass) { "Observer snapshot 일치 검증" } else { "본체가 필수 상태와 실제 처리 증거를 기록해야 합니다." }
    USER_ACTION = "없음"
    DONE_ITEMS = @("34번 기준 로드", "중앙 상태파일 읽기", "필수 필드와 증거 검증")
    SOURCE_PACKET = $StatePacketPath
    VALIDATION_REASON = $reason
    MISSING_FIELDS = @($missing)
    PROCESSED_COUNT = $processed
    TIME = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
$data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputPath -Encoding UTF8
