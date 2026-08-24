param([Parameter(Mandatory=$true)][string]$Root)

$ErrorActionPreference="Stop"
$CT=Join-Path $Root "CONTROL_TOWER"
$FallbackState=Join-Path $CT "tool034_state.json"
$Snapshot=Join-Path $CT "observer_snapshot.json"
$StateJs=Join-Path $CT "tower_state.js"

$rootBytes=[System.Text.Encoding]::UTF8.GetBytes($Root.ToLowerInvariant())
$sha256=[System.Security.Cryptography.SHA256]::Create()
try{ $hashBytes=$sha256.ComputeHash($rootBytes) }
finally{ $sha256.Dispose() }
$rootHash=([BitConverter]::ToString($hashBytes) -replace '-','').Substring(0,16)
$createdNew=$false
$mutex=New-Object System.Threading.Mutex($true,("Local\WIC34_OBSERVER_"+$rootHash),[ref]$createdNew)
if(-not $createdNew){ $mutex.Dispose(); return }

try{
while($true){

    $toolStateCandidates=@(Get-ChildItem -LiteralPath $Root -Directory -Filter "TOOL*" -ErrorAction SilentlyContinue | ForEach-Object {
        $candidate=Join-Path $_.FullName "tool_state.json"
        if(Test-Path -LiteralPath $candidate -PathType Leaf){ Get-Item -LiteralPath $candidate }
    } | Sort-Object LastWriteTimeUtc -Descending)
    $ToolState=if($toolStateCandidates.Count -gt 0){$toolStateCandidates[0].FullName}else{$FallbackState}

    if(Test-Path $ToolState){
        try{
            $body=Get-Content $ToolState -Raw -Encoding UTF8 | ConvertFrom-Json

            $data=[ordered]@{
                CURRENT_ROOT=$Root
                CURRENT_TOOL=$body.CURRENT_TOOL
                OBSERVER_ENGINE="RUNNING"
                STATUS_SYNC="RUNNING"
                TOOL_ENGINE=$body.ENGINE_STATUS
                FINAL_STATUS=$body.FINAL_STATUS
                CURRENT_STEP=$body.CURRENT_STEP
                EASY_EXPLAIN=$body.EASY_EXPLAIN
                PROGRESS=$body.PROGRESS
                NEXT_ACTION=$body.NEXT_ACTION
                USER_ACTION=$body.USER_ACTION
                DONE_ITEMS=@($body.DONE_ITEMS)
                SOURCE_PACKET=$body.SOURCE_PACKET
                VALIDATION_REASON=$body.VALIDATION_REASON
                MISSING_FIELDS=@($body.MISSING_FIELDS | Where-Object { $null -ne $_ })
                RECENT_EVENT="BODY_STATE_READ"
                LAST_BODY_UPDATE=$body.TIME
                SNAPSHOT=$Snapshot
                BLACK_WINDOW_BLOCK=if($body.BLACK_WINDOW_BLOCK){$body.BLACK_WINDOW_BLOCK}else{"HOLD"}
                OBSERVER_TIME=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
        }
        catch{
            $data=[ordered]@{
                CURRENT_ROOT=$Root
                CURRENT_TOOL="UNKNOWN"
                OBSERVER_ENGINE="RUNNING"
                STATUS_SYNC="FAIL"
                TOOL_ENGINE="HOLD"
                FINAL_STATUS="HOLD"
                CURRENT_STEP="도구 상태파일 오류"
                EASY_EXPLAIN="도구 상태파일을 읽는 중 오류가 발생했습니다."
                PROGRESS=0
                NEXT_ACTION="선택된 tool_state.json 형식 확인"
                USER_ACTION="없음"
                DONE_ITEMS=@()
                SOURCE_PACKET="없음"
                VALIDATION_REASON="TOOL_STATE_PARSE_FAIL"
                MISSING_FIELDS=@()
                RECENT_EVENT="BODY_STATE_PARSE_FAIL"
                LAST_BODY_UPDATE="없음"
                SNAPSHOT=$Snapshot
                BLACK_WINDOW_BLOCK="HOLD"
                OBSERVER_TIME=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
        }
    }
    else{
        $data=[ordered]@{
            CURRENT_ROOT=$Root
            CURRENT_TOOL="UNKNOWN"
            OBSERVER_ENGINE="RUNNING"
            STATUS_SYNC="HOLD"
            TOOL_ENGINE="HOLD"
            FINAL_STATUS="HOLD"
            CURRENT_STEP="본체 상태 대기"
            EASY_EXPLAIN="타워는 도구 본체의 실제 처리 상태를 기다리고 있습니다."
            PROGRESS=0
            NEXT_ACTION="도구 본체 실행"
            USER_ACTION="없음"
            DONE_ITEMS=@("단일 타워 구조 생성","Observer 실행","검은 창 차단")
            SOURCE_PACKET="없음"
            VALIDATION_REASON="TOOL_STATE_NOT_FOUND"
            MISSING_FIELDS=@()
            RECENT_EVENT="WAITING_BODY_STATE"
            LAST_BODY_UPDATE="없음"
            SNAPSHOT=$Snapshot
            BLACK_WINDOW_BLOCK="HOLD"
            OBSERVER_TIME=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }

    $json=$data | ConvertTo-Json -Depth 8
    $json | Set-Content $Snapshot -Encoding UTF8
    "window.WIC34_STATE = $json;" | Set-Content $StateJs -Encoding UTF8

    if($env:WIC34_OBSERVER_ONCE -eq "1"){ break }
    Start-Sleep -Seconds 5
}
}
finally{
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
