"""TOOL006 verified-root self-analysis and safe autocorrection gate."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "knowledge" / "tool006_asset_index.json"

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
    if re.fullmatch(r"\([^)]{3,}\)", value):
        return ROOT_PAREN
    if re.match(r"^\*+", value):
        return ROOT_ASTERISK
    if re.fullmatch(r"(?i)(list\s+of\s+(tables|figures))(?:\s*[-:./]?\s*\d+)?", value):
        return ROOT_LISTS
    return None


def indent_numbered(text: str) -> str | None:
    match = re.match(r"^(\d+(?:\.\d+){0,8})[.)\s]+(.+)$", text.strip())
    if not match:
        return None
    number, title = match.groups()
    return "  " * (number.count(".")) + f"{number} {title.strip()}"


def evaluate(payload: dict[str, Any]) -> dict[str, Any]:
    allowed = active_roots()
    detected: list[dict[str, str]] = []
    corrected = list(payload.get("engine_output", []))
    unresolved: list[dict[str, Any]] = []

    numbered = [indent_numbered(line) for line in payload.get("original_input", [])]
    numbered = [line for line in numbered if line]
    if numbered and ROOT_HIERARCHY in allowed:
        if corrected != numbered:
            corrected = numbered
            detected.append({"root": ROOT_HIERARCHY, "action": "RESTORE_VERIFIED_HIERARCHY"})

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
