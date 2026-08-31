"""TOOL006 verified-root self-analysis and safe autocorrection gate."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "knowledge" / "tool006_asset_index.json"
HTML = ROOT / "TOOL006_TOC" / "toc_lock_v2_26_v10_실제본체반영_HOLD.html"


def anomaly_contract() -> dict[str, Any]:
    """One data contract, embedded for portable file:// browser operation."""
    match = re.search(r'<script id="T6_ANOMALY_CONTRACT" type="application/json">\s*(.*?)\s*</script>', HTML.read_text(encoding="utf-8"), re.S)
    if not match:
        raise ValueError("ANOMALY_CONTRACT_MISSING")
    return json.loads(match.group(1))

ROOT_HIERARCHY = "T6-RC-01"
ROOT_PAREN = "T6-RC-02"
ROOT_ASTERISK = "T6-RC-03"
ROOT_LISTS = "T6-RC-04"


def active_roots() -> set[str]:
    data = json.loads(ASSETS.read_text(encoding="utf-8"))
    return {
        row["root_type"]
        for row in data["assets"]
        if row.get("validation_status") == "ACTIVE_VERIFIED"
    }


def classify_known(text: str) -> str | None:
    value = " ".join(text.replace("\u00a0", " ").split())
    for rule in anomaly_contract()["noise_rules"]:
        if re.search(rule["pattern"], value, re.I):
            return rule["root"]
    return None


def indent_numbered(text: str) -> str | None:
    match = re.match(r"^(\d+(?:\.\d+){0,8})[.)\s]+(.+)$", text.strip())
    if not match:
        return None
    number, title = match.groups()
    return "  " * (number.count(".")) + f"{number} {title.strip()}"


def evaluate(payload: dict[str, Any]) -> dict[str, Any]:
    transaction = payload.get("transaction")
    if transaction is not None:
        contract = anomaly_contract()
        if not transaction.get("original_run_id") or transaction.get("original_run_id") != payload.get("original_run_id"):
            return {"status": "HOLD", "reason": "ORIGINAL_RUN_ID_MISMATCH", "promotion_allowed": False}
        attempts = transaction.get("recovery_attempts")
        if type(attempts) is not int or attempts < 0:
            return {"status": "HOLD", "reason": "INVALID_ATTEMPT_STATE", "promotion_allowed": False}
        if attempts >= contract["recovery_limit"]:
            return {"status": "HOLD", "reason": contract["repeat_code"], "promotion_allowed": False}
        if transaction.get("original_input") != payload.get("original_input"):
            return {"status": "HOLD", "reason": "ORIGINAL_INPUT_MISMATCH", "promotion_allowed": False}
        # Consume before classification, even if the outcome is HOLD.
        transaction["recovery_attempts"] = attempts + 1
    allowed = active_roots()
    detected: list[dict[str, str]] = []
    corrected = list(payload.get("engine_output", []))
    unresolved: list[dict[str, Any]] = []

    numbered = [indent_numbered(line) for line in payload.get("original_input", [])]
    numbered = [line for line in numbered if line]
    content = [line for line in payload.get("original_input", []) if str(line).strip() and not classify_known(str(line))]
    if numbered and len(numbered) == len(content) and ROOT_HIERARCHY in allowed:
        if corrected != numbered:
            corrected = numbered
            detected.append({"root": ROOT_HIERARCHY, "action": "RESTORE_VERIFIED_HIERARCHY"})
    elif numbered and any(line.strip() not in [str(x).strip() for x in corrected] for line in numbered):
        unresolved.append({"reason": "MIXED_INPUT_RECONSTRUCTION_UNVERIFIED"})

    for item in payload.get("hold_lines", []):
        text = str(item.get("text", ""))
        root = classify_known(text)
        if root and root in allowed:
            detected.append({"root": root, "action": "REMOVE_VERIFIED_NOISE", "text": text})
        else:
            unresolved.append(item)

    status = "PASS" if corrected and not unresolved else "HOLD"
    return {
        "status": status,
        "self_analyze": "PASS",
        "error_classify": "PASS",
        "matched_verified_roots": detected,
        "safe_autocorrection_applied": bool(detected),
        "corrected_output": corrected,
        "recheck": "PASS" if status == "PASS" else "HOLD_UNKNOWN_TYPE",
        "unresolved_hold_lines": unresolved,
        "user_repeated_testing_required": False,
        "promotion_allowed": status == "PASS",
    }


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    result = evaluate(json.loads(Path(args.input).read_text(encoding="utf-8")))
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    if result["status"] != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
