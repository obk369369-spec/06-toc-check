"""FIRST_VALIDATION for TOOL006 verified-root self-improvement gate."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "TOOL006_TOC"))
from tool006_self_improvement_gate import evaluate  # noqa: E402

fixtures = json.loads((ROOT / "tests" / "tool006_chronic_error_fixtures.json").read_text(encoding="utf-8"))
cases = {row["id"]: row for row in fixtures["cases"]}

hierarchy = cases["T6-RC-01-HIERARCHY-INDENT"]
r1 = evaluate({"original_input": hierarchy["input"], "engine_output": hierarchy["input"], "hold_lines": []})
assert r1["status"] == "PASS"
assert r1["corrected_output"] == hierarchy["expected"]
assert any(x["root"] == "T6-RC-01" for x in r1["matched_verified_roots"])

paren = cases["T6-RC-02-PARENTHESIS-NOTE"]
r2 = evaluate({"original_input": paren["input"], "engine_output": paren["expected"], "hold_lines": [{"text": paren["input"][1], "reason": "ambiguous_hold"}]})
assert r2["status"] == "PASS" and not r2["unresolved_hold_lines"]
assert any(x["root"] == "T6-RC-02" for x in r2["matched_verified_roots"])

asterisk = cases["T6-RC-03-ASTERISK-FOOTNOTE"]
r3 = evaluate({"original_input": asterisk["input"], "engine_output": asterisk["expected"], "hold_lines": [{"text": asterisk["input"][1], "reason": "ambiguous_hold"}]})
assert r3["status"] == "PASS"
assert any(x["root"] == "T6-RC-03" for x in r3["matched_verified_roots"])

mixed = cases["T6-RC-04-TABLE-FIGURE-APPENDIX"]
r4 = evaluate({
    "original_input": mixed["input"],
    "engine_output": mixed["expected"],
    "hold_lines": [
        {"text": "List Of Tables 2", "reason": "ambiguous_hold"},
        {"text": "Unexpected appendix explanation", "reason": "ambiguous_hold"},
    ],
})
assert r4["status"] == "HOLD"
assert any(x["root"] == "T6-RC-04" for x in r4["matched_verified_roots"])
assert r4["unresolved_hold_lines"] == [{"text": "Unexpected appendix explanation", "reason": "ambiguous_hold"}]
assert r4["promotion_allowed"] is False
assert r4["user_repeated_testing_required"] is False

print("PASS: verified roots autocorrect; unknown type remains HOLD")

# Same contract and immutable original identity: a successful correction must
# not grant a new recovery attempt when the corrected text is displayed.
tx = {"original_run_id": "actual-run-transaction-1", "original_input": hierarchy["input"], "recovery_attempts": 0}
payload = {"transaction": tx, "original_run_id": tx["original_run_id"], "original_input": hierarchy["input"], "engine_output": hierarchy["input"]}
assert evaluate(payload)["status"] == "PASS"
assert tx["recovery_attempts"] == 1
assert evaluate(payload)["reason"] == "REPEATED_AUTO_REPAIR_FORBIDDEN"
assert evaluate({**payload, "original_run_id": "different"})["reason"] == "ORIGINAL_RUN_ID_MISMATCH"
mixed_input = {"original_input": ["1 Overview", "Research Scope"], "engine_output": ["1 Overview", "  1.1 Research Scope"]}
assert evaluate(mixed_input)["corrected_output"] == mixed_input["engine_output"]
print("PASS: shared immutable transaction; repeat blocked; mixed source not truncated")
