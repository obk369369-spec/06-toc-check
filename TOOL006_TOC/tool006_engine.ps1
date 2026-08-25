param(
    [Parameter(Mandatory=$true)][string]$Root,
    [string]$InputPath,
    [string]$InputText,
    [string]$OutputPath,
    [string]$Publisher = "UNKNOWN",
    [string]$ReportId = "UNKNOWN",
    [string]$ErrorType,
    [string]$CorrectedOutput
)

$ErrorActionPreference = "Stop"
$toolRoot = Join-Path $Root "TOOL006_TOC"
$controlTower = Join-Path $Root "CONTROL_TOWER"
$statePath = Join-Path $toolRoot "tool_state.json"
$logPath = Join-Path $toolRoot "logs\progress.csv"
$packetPath = Join-Path $controlTower "STATE_PACKET.json"
$evidencePath = Join-Path $toolRoot "evidence\tool006_evidence.json"
$candidateDir = Join-Path $toolRoot "evidence\error_candidates"
if (-not $OutputPath) { $OutputPath = Join-Path $toolRoot "working\toc_result.txt" }
$runId = "TOOL006-" + (Get-Date -Format "yyyyMMdd-HHmmss-fff")
$started = Get-Date
$stageHistory = [System.Collections.Generic.List[object]]::new()

foreach ($path in @((Split-Path $statePath),(Split-Path $logPath),(Split-Path $evidencePath),(Split-Path $OutputPath),$candidateDir,$controlTower)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

function Write-ToolState {
    param([string]$EngineStatus,[string]$FinalStatus,[int]$Progress,[string]$Step,[string]$Explain,[string]$NextAction)
    $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $stageHistory.Add([ordered]@{TIME=$now;PROGRESS=$Progress;STEP=$Step;STATUS=$FinalStatus})
    "$now,TOOL006_TOC,$Step,$EngineStatus,$Explain" | Add-Content -LiteralPath $logPath -Encoding UTF8
    [ordered]@{
        CURRENT_TOOL="TOOL006_TOC";ENGINE_STATUS=$EngineStatus;FINAL_STATUS=$FinalStatus
        CURRENT_STEP=$Step;EASY_EXPLAIN=$Explain;PROGRESS=$Progress;NEXT_ACTION=$NextAction
        USER_ACTION="NONE";DONE_ITEMS=@($stageHistory|ForEach-Object{$_.STEP});RUN_ID=$runId
        OUTPUT_PATH=$OutputPath;SOURCE_PACKET=$packetPath
        VALIDATION_REASON=if($FinalStatus -eq "PASS"){"VERIFIED"}else{"HOLD_OR_ERROR"}
        MISSING_FIELDS=@();BLACK_WINDOW_BLOCK="PASS";TIME=$now
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8
}

function Clean-Line([string]$value) { return (($value -replace "`t"," " -replace [char]0xA0," " -replace ([char]0x2013),'-' -replace ([char]0x2014),'-' -replace '\s+',' ').Trim()) }
function Test-Noise([string]$text) {
    return $text -match '^\(?\s*(table of contents|contents|list\s+of\s+(tables|figures))(?:\s*[-:./]?\s*\d+)?\s*\)?$' -or
        $text -match '^(table|figure|appendix table|appendix figure)\s+\d+' -or
        $text -match '^Page\s+No\.?\s*[-:]?\s*\d+$' -or
        $text -match '^\d+$' -or
        $text -match '^\*+' -or
        $text -match '^\([^)]{3,}\)$' -or
        $text -match '^(read more|read less|description|sample request|request sample|download sample|select license|buy now|enquire before buying)$'
}
function New-ItemRecord([string]$text,[int]$depth,[string]$number,[bool]$hold,[string]$reason) { return [pscustomobject]@{Text=$text;Depth=$depth;Number=$number;Hold=$hold;Reason=$reason;Generated=[string]::IsNullOrWhiteSpace($number)} }

function Classify-Line([string]$text,[hashtable]$context) {
    $numbered = [regex]::Match($text,'^(\d+(?:\.\d+){0,8})[.)\s]+(.+)$')
    if ($numbered.Success) { $number=$numbered.Groups[1].Value; return New-ItemRecord (Clean-Line $numbered.Groups[2].Value) ($number.Split('.').Count) $number $false "number_preserve" }
    if ($text -match '^(SECTION\s+[IVXLC0-9]+|CHAPTER\s+\d+|PART\s+[IVXLC0-9]+)[:.]?\s*(.*)$') { $context.Parent=$text;$context.Group="";$context.Region="";return New-ItemRecord $text 1 "" $false "section_preserve" }
    $top='^(Introduction|Executive Summary|Market Overview|Market Dynamics|Key Insights|Competitive Analysis|Competitive Landscape|Company Profiles|Strategic Recommendations|Appendix|Market Trends)$'
    $longTop='(Global|North America|Europe|Asia Pacific|Latin America|Middle East|Africa).{3,140}(Market|Industry).{0,100}(Analysis|Insights|Forecast|Outlook)'
    if ($text -match $top -or $text -match $longTop) { $context.Parent=$text;$context.Group="";$context.Region="";return New-ItemRecord $text 1 "" $false "top_detected" }
    if ($text -match '^By\s+(Product|Application|Region|Country|Type|Material|End[- ]?use|Technology|Component|Distribution Channel|Service|Deployment|Industry|Source|Form|Grade|Process|Sales Channel|Offering|Function|Capacity|Packaging|Route|Class|Category)\b') { $context.Group=$Matches[1];$context.Region="";return New-ItemRecord $text 2 "" $false "by_group_head" }
    $regions='^(North America|Europe|Asia Pacific|Latin America|Middle East\s*&\s*Africa|Middle East and Africa)$'
    $countries='^(U\.S\.|United States|Canada|Germany|U\.K\.|United Kingdom|France|Italy|Spain|China|India|Japan|South Korea|Australia|Brazil|Mexico|GCC|South Africa|Rest of .+)$'
    if ($text -match $regions) { $context.Region=$text;return New-ItemRecord $text $(if($context.Group -eq 'Region'){3}else{2}) "" $false "region" }
    if ($text -match $countries) { return New-ItemRecord $text $(if($context.Region){4}elseif($context.Group){3}else{2}) "" $false "country" }
    $companyDetail='^(Overview|Business Overview|Company Snapshot|Product Portfolio|Products Offered|Financials|Recent Developments|Recent News|Strategy|SWOT Analysis)$'
    if ($text -match $companyDetail -and $context.Parent -match 'Company Profiles|Competitive Landscape') { return New-ItemRecord $text 3 "" $false "company_detail" }
    $companyName='(Inc\.|Corporation|Corp\.|Ltd\.|Limited|LLC|PLC|AG$|GmbH|S\.A\.|Co\.,|Company|Group|Industries|Technologies|Systems|Solutions|Healthcare|Laboratories|BASF|DuPont|Merck|Thermo|Danaher|Siemens|Honeywell|3M|IBM|Microsoft|Google|Samsung|LG|Hitachi|Panasonic|Toyota|Bayer|Roche|Pfizer|TORAY|TEIJIN)'
    if ($text -match $companyName -and $context.Parent -match 'Company Profiles|Competitive Landscape') { return New-ItemRecord $text 2 "" $false "company_name" }
    $knownChild='^(Research Scope|Market Segmentation|Research Methodology|Definitions and Assumptions|Market Drivers|Market Restraints|Market Opportunities|Key Findings|Key Findings / Summary|Key Emerging Trends|Key Developments|Latest Technological|Insights on Sustainability|Porter''s Five Forces Analysis|Impact of Tariff|Price Trend Analysis|Regulatory Framework|Value Chain|Supply Chain|Patent Analysis|Import/Export|Production|Consumption|Revenue|Volume)'
    if ($text -match $knownChild) { return New-ItemRecord $text 2 "" $false "known_child" }
    if ($context.Group) { return New-ItemRecord $text 3 "" $false "by_group_child" }
    if ($context.Parent -match 'Key Insights|Market Dynamics|Research Methodology|Introduction') { return New-ItemRecord $text 2 "" $false "parent_context_child" }
    return New-ItemRecord $text 2 "" $true "ambiguous_hold"
}

function Apply-Numbers([object[]]$items) {
    $counter=@(0,0,0,0,0,0,0,0,0)
    foreach($item in $items) {
        if ($item.Reason -eq 'section_preserve') { continue }
        if ($item.Hold) { $item.Number=''; continue }
        if ($item.Number) { $parts=@($item.Number.Split('.')|ForEach-Object{[int]$_});for($i=0;$i -lt $parts.Count;$i++){$counter[$i+1]=$parts[$i]};for($i=$parts.Count+1;$i -lt $counter.Count;$i++){$counter[$i]=0};continue }
        $depth=[Math]::Max(1,[Math]::Min([int]$item.Depth,8))
        if($depth -eq 1){$counter[1]++;for($i=2;$i -lt $counter.Count;$i++){$counter[$i]=0}}
        else{if($counter[1] -eq 0){$counter[1]=1};for($i=2;$i -lt $depth;$i++){if($counter[$i] -eq 0){$counter[$i]=1}};$counter[$depth]++;for($i=$depth+1;$i -lt $counter.Count;$i++){$counter[$i]=0}}
        $item.Number=(@($counter[1..$depth])-join '.')
    }
    return $items
}

Write-ToolState "RUNNING" "HOLD" 10 "READ_INPUT" "Reading TOC input and report metadata." "CLASSIFY_STRUCTURE"
try {
    if($InputPath){if(-not(Test-Path -LiteralPath $InputPath -PathType Leaf)){throw "Input file not found: $InputPath"};$InputText=Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8}
    if([string]::IsNullOrWhiteSpace($InputText)){throw "Input text is empty"}
    Write-ToolState "RUNNING" "HOLD" 30 "NORMALIZE_INPUT" "Removing empty lines and known noise." "CLASSIFY_DEPTH"
    $lines=@($InputText -split "`r?`n"|ForEach-Object{Clean-Line $_}|Where-Object{$_ -and -not(Test-Noise $_)})
    $seen=@{};$items=[System.Collections.Generic.List[object]]::new();$context=@{Parent="";Group="";Region=""}
    foreach($line in $lines){$item=Classify-Line $line $context;$key=($item.Text -replace '^\d+(?:\.\d+)*\s+','').ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true;$items.Add($item)}
    $numbered=@(Apply-Numbers @($items))
    Write-ToolState "RUNNING" "HOLD" 70 "ORGANIZE_HIERARCHY" "Preserved numbers and classified candidate depth and review lines." "VALIDATE_RESULT"
    $output=@($numbered|Where-Object{-not $_.Hold}|ForEach-Object{(('  '*([Math]::Max(0,$_.Depth-1)))+$(if($_.Reason -eq 'section_preserve'){$_.Text}else{$_.Number+' '+$_.Text}))})
    $holds=@($numbered|Where-Object{$_.Hold});$status=if($output.Count -gt 0 -and $holds.Count -eq 0){"PASS"}else{"HOLD"}
    $output|Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-ToolState $(if($status -eq 'PASS'){'COMPLETED'}else{'REVIEW_REQUIRED'}) $status 100 "TOC_COMPLETE" $(if($status -eq 'PASS'){'Output created with no suspicious lines.'}else{"Output created; $($holds.Count) suspicious line(s) require review."}) "SYNC_OBSERVER"
    $evidence=[ordered]@{RUN_ID=$runId;PUBLISHER=$Publisher;REPORT_ID=$ReportId;INPUT_SOURCE=if($InputPath){$InputPath}else{'INLINE_TEXT'};INPUT_COUNT=$lines.Count;OUTPUT_COUNT=$output.Count;OUTPUT_PATH=$OutputPath;STATUS=$status;HOLD_COUNT=$holds.Count;HOLD_LINES=@($holds|ForEach-Object{[ordered]@{text=$_.Text;number=$_.Number;depth=$_.Depth;reason=$_.Reason}});ITEMS=@($numbered);STAGE_HISTORY=@($stageHistory);STARTED=$started.ToString('yyyy-MM-dd HH:mm:ss');FINISHED=Get-Date -Format 'yyyy-MM-dd HH:mm:ss'}
    $evidence|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $evidencePath -Encoding UTF8
    if($status -eq 'HOLD' -or $ErrorType -or $CorrectedOutput){[ordered]@{RUN_ID=$runId;PUBLISHER=$Publisher;REPORT_ID=$ReportId;ORIGINAL_TOC=$InputText;TOOL_OUTPUT=($output -join "`n");SUSPICIOUS_LINES=$evidence.HOLD_LINES;ERROR_TYPE=if($ErrorType){$ErrorType}else{'AMBIGUOUS_DEPTH'};USER_CORRECTED_OUTPUT=$CorrectedOutput;CREATED_AT=Get-Date -Format 'yyyy-MM-dd HH:mm:ss';FIXTURE_STATUS=if($CorrectedOutput){'CANDIDATE'}else{'HOLD'}}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $candidateDir ($runId+'.json')) -Encoding UTF8}
    [ordered]@{'34_RULES_LOADED'='TRUE';RUN_ID=$runId;STATUS=$status;CURRENT_STAGE='TOOL006_COMPLETE';TOTAL_COUNT=$lines.Count;PROCESSED_COUNT=$output.Count;SUCCESS_COUNT=if($status -eq 'PASS'){$output.Count}else{0};HOLD_COUNT=$holds.Count;FAIL_COUNT=0;LAST_RUN_TIME=Get-Date -Format 'yyyy-MM-dd HH:mm:ss';LAST_OUTPUT=$OutputPath;NEXT_OUTPUT='NONE';ERROR_TYPE=if($status -eq 'PASS'){'NONE'}else{'AMBIGUOUS_DEPTH'};CHECKPOINT='TOOL006_OUTPUT_WRITTEN';RESTART_POINT='NEXT_INPUT';EVIDENCE_BUNDLE=$evidencePath;STOP_CARD=if($status -eq 'PASS'){'CLEAR'}else{'HOLD'}}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $packetPath -Encoding UTF8
} catch { Write-ToolState "FAILED" "HOLD" 0 "TOC_ERROR" $_.Exception.Message "CHECK_INPUT_AND_ERROR";throw }
