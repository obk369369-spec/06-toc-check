# TOOL006 recovery record

## Scope and stop condition

Only the user-named TOOL006 locations, `I:/GPT 도구 작업/6번 목차 정리 도구`, its `보관폴더`, and the existing `06-toc-check` draft branch were inspected. No other drive, repository, or conversation archive was searched.

The named `WIC34_STATE/source_originals/TOOL006_6번`, `backup_originals/TOOL006`, and `tool_complete_candidates/TOOL006` paths were not present in the checked candidate roots.

## Recovered assets

- Two user-supplied HTML implementations were read and compared.
- One screenshot (`20260506_170107.jpg`) connects a real publisher-style source TOC to a historical wrong TOOL006 output.
- One 1500-case evidence bundle was found, but its own metadata identifies it as synthetic pattern simulation. It is not counted as real-publisher proof.
- Publisher/answer-set candidate HTML files explicitly state that real source evidence was not fixed and FINAL must remain HOLD.

## Structured cases

| Classification | Count | Notes |
|---|---:|---|
| VERIFIED recovery cases | 0 | No case contained confirmed publisher identity, raw TOC, wrong output, and user-authored corrected output together. |
| PARTIAL recovery cases | 4 | One actual screenshot-derived case and three synthetic representative cases. |
| HOLD recovery cases | 0 | Ambiguous behavior is represented as an expected engine HOLD inside a PARTIAL synthetic fixture. |
| Regression fixtures | 4 | Stored in `fixtures/tool006_regression.json`. |

Confirmed publisher count is 0. The recovered rule artifacts name Fortune, ResearchReportsWorld, Precision, BusinessGrowth, and FBI patterns, but no complete per-publisher ground-truth case was recovered.

## Integrated behavior

The single decision engine at `TOOL006_TOC/tool006_engine.ps1` preserves existing numbering, generates candidate numbering, classifies top/child/grandchild depth, handles By Product/Application/Region, region-country depth, Company Profiles and company details, long market headings, SECTION/CHAPTER/PART labels, and table/figure noise. Ambiguous lines cause HOLD and are recorded instead of being forced to PASS.

The internal UI adapter contains no TOC decision rules. It calls the one engine and retains input, output, copy, basic status, suspicious-line display, error type, publisher/report identifiers, and user-corrected output capture.

## Validation

- Existing-number/SECTION/noise regression: PASS
- Actual screenshot parent-preservation regression: PASS
- Complex By/Region/Country/Company regression: PASS
- Ambiguous-line HOLD and error-candidate persistence: PASS
- UI adapter self-test: PASS
- Functional E2E (UI control -> hidden body engine -> output/state -> Observer): PASS
- Active decision engine count: 1

## Current status

`TOOL006 DATA RECOVERY = PARTIAL`

Remaining HOLD items are confirmed publisher identity, complete user-authored corrected outputs for historical failures, and additional real-publisher complex fixtures. Synthetic simulation results must not be used to claim global TOOL006 PASS.
