# TOOL006 목차 정리 도구 — ACTIVE 기준본

검증된 목차 정리 본체와 공통 CONTROL TOWER 연결만 보존한 기준본입니다.
과거 HTML 껍데기·복제본·중간 상태 파일은 운영 계보에서 제외했습니다.

## 실제 처리 흐름

1. `TOOL006_TOC/tool006_engine.ps1` 단 하나가 입력을 읽고 모든 목차 판단을 수행합니다.
2. 본체가 `TOOL006_TOC/tool_state.json`과 실행 증거를 직접 기록합니다.
3. `observer_engine.ps1`이 최신 도구 상태만 읽어 snapshot을 만듭니다.
4. 공통 타워 HTML은 snapshot에서 생성된 `tower_state.js`만 표시합니다.

`TOOL006_TOC/tool006_ui.ps1`은 판단 규칙이 없는 내부 UI 어댑터입니다. 단일 엔진을 숨김 실행하여 입력·출력·복사·의심줄 표시·오류유형·사용자 수정결과를 연결합니다.

## Data recovery

- 실제 원자료: `20260506_170107.jpg` 1건(원문과 과거 오출력 연결, 발행사 URL/사용자 정답 원문은 미복구)
- 합성 보조자료: `T6-SIM1500-EVIDENCE-20260508011213` 오류유형 패턴
- 상태: `EXTERNAL_EVIDENCE_REQUIRED` — 확인된 실제 자료만으로는 발행사별 golden pair와 투입 횟수 기준을 확정할 수 없음
- 구조화 fixture: `fixtures/tool006_regression.json`

합성 1500건 PASS는 실제 발행사 전체 PASS 근거로 사용하지 않습니다.

입력·출력 패널에는 각각 독립적인 `위로가기` 버튼이 있으며 각 영역 자체의 scroll/caret을 최상단으로 이동합니다.

## 실행 예시

```powershell
$root = (Get-Location).Path
$input = "Introduction`nResearch Scope`nExecutive Summary"
& .\TOOL006_TOC\tool006_engine.ps1 -Root $root -InputText $input
```

사용자용 공통 타워 실행 파일은 루트의 `WIC34_공통타워_자동찾기.vbs` 하나입니다.

## 최소 검증

```powershell
& .\tests\tool006_smoke.ps1
& .\tests\tool006_functional_e2e.ps1
```

PASS 기준은 실제 결과 파일 생성, 본체 상태 PASS/100, 10→30→70→100 단계 증거,
Observer의 TOOL006/PASS/100 동기화입니다.

