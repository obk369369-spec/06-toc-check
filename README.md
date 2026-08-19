# TOOL006 목차 정리 도구 — ACTIVE 기준본

검증된 목차 정리 본체와 공통 CONTROL TOWER 연결만 보존한 기준본입니다.
과거 HTML 껍데기·복제본·중간 상태 파일은 운영 계보에서 제외했습니다.

## 실제 처리 흐름

1. `CONTROL_TOWER/tool006_engine.ps1`이 입력을 읽어 목차를 정리합니다.
2. 본체가 `TOOL006_TOC/tool_state.json`과 실행 증거를 직접 기록합니다.
3. `observer_engine.ps1`이 최신 도구 상태만 읽어 snapshot을 만듭니다.
4. 공통 타워 HTML은 snapshot에서 생성된 `tower_state.js`만 표시합니다.

## 실행 예시

```powershell
$root = (Get-Location).Path
$input = "Introduction`nResearch Scope`nExecutive Summary"
& .\CONTROL_TOWER\tool006_engine.ps1 -Root $root -InputText $input
```

사용자용 공통 타워 실행 파일은 루트의 `WIC34_공통타워_자동찾기.vbs` 하나입니다.

## 최소 검증

```powershell
& .\tests\tool006_smoke.ps1
```

PASS 기준은 실제 결과 파일 생성, 본체 상태 PASS/100, 10→30→70→100 단계 증거,
Observer의 TOOL006/PASS/100 동기화입니다.

