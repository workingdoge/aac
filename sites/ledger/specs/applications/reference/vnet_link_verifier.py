#!/usr/bin/env python3
"""Reference VNET transition-link verifier.

This checker is not a circuit and not a native verifier. It makes the VNET/1
link boundary executable for fixtures:

1. resolve each transition_ref against a trusted transition report;
2. verify the reported TRANSITION/1 journal_commitment matches the atom;
3. verify a companion link certificate binds the atom's opened vectors to that
   exact transition_ref + journal_commitment + basis_commitment; and
4. delegate the amount-vector commitment and zero-opening checks to the
   VNET-BN254-G1/1 profile checker.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
from typing import Any

DEFAULT_PROFILE_REF = Path(__file__).resolve().parents[2] / "profiles" / "reference" / "vnet_bn254_g1_1.py"
PROFILE_ID = "vnet-bn254-g1/1"


def canonical(obj: Any) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode()


def digest_hex(label: str, *parts: Any) -> str:
    return hashlib.sha256(canonical([label, *parts])).hexdigest()


def load_profile(path: str | Path):
    p = Path(path)
    spec = importlib.util.spec_from_file_location("vnet_bn254_g1_1", p)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import profile reference: {p}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def certificate_for(atom: dict[str, Any]) -> dict[str, Any]:
    body = {
        "transition_ref": atom["transition_ref"],
        "journal_commitment": atom["journal_commitment"],
        "profile_id": atom["profile_id"],
        "basis_commitment": atom["basis_commitment"],
        "basis_type_ids": list(atom["basis_type_ids"]),
        "debit": list(atom["debit"]),
        "credit": list(atom["credit"]),
    }
    return {
        **body,
        "certificate_hash": digest_hex("aac/vnet-link-ref/1", body),
    }


def transition_report_for(vnet: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": "aac.vnet-link-ref.transition-report.v1",
        "accepted": [
            {
                "transition_ref": atom["transition_ref"],
                "target": "TRANSITION/1",
                "journal_commitment": atom["journal_commitment"],
            }
            for atom in vnet["atoms"]
        ],
    }


def link_case(case_id: str, description: str, vnet: dict[str, Any], accepted: bool, reason: str) -> dict[str, Any]:
    return {
        "id": case_id,
        "description": description,
        "transition_report": transition_report_for(vnet),
        "vnet": copy.deepcopy(vnet),
        "link_certificates": [certificate_for(atom) for atom in vnet["atoms"]],
        "expect": {"accepted": accepted, "reason": reason},
    }


def check_case(case: dict[str, Any], profile_ref: Any) -> tuple[bool, str]:
    report = {
        item["transition_ref"]: item
        for item in case.get("transition_report", {}).get("accepted", [])
    }
    certs = {
        item["transition_ref"]: item
        for item in case.get("link_certificates", [])
    }

    for atom in case["vnet"]["atoms"]:
        ref = atom["transition_ref"]
        reported = report.get(ref)
        if reported is None:
            return False, "missing_transition_ref"
        if reported.get("target") != "TRANSITION/1":
            return False, "wrong_transition_target"
        if reported.get("journal_commitment") != atom["journal_commitment"]:
            return False, "journal_commitment_mismatch"

        cert = certs.get(ref)
        if cert is None:
            return False, "missing_link_certificate"
        want = certificate_for(atom)
        if cert != want:
            return False, "link_certificate_mismatch"

    return profile_ref.check_vector(case["vnet"])


def build_vectors(profile_ref: Any) -> dict[str, Any]:
    profile_vectors = {vec["id"]: vec for vec in profile_ref.templates()["vectors"]}
    good = profile_vectors["fundraise-good-batch"]
    false_net = profile_vectors["fundraise-false-net-reject"]

    cases = [
        link_case(
            "vnet-link-good-fundraise",
            "accepted TRANSITION reports, valid link certificates, and VNET zero-opening",
            good,
            True,
            "accepted",
        ),
        link_case(
            "vnet-link-missing-transition-reject",
            "one VNET atom is absent from the trusted transition report",
            good,
            False,
            "missing_transition_ref",
        ),
        link_case(
            "vnet-link-journal-mismatch-reject",
            "the trusted transition report carries a different TRANSITION/1 journal_commitment",
            good,
            False,
            "journal_commitment_mismatch",
        ),
        link_case(
            "vnet-link-certificate-mismatch-reject",
            "the companion link certificate no longer binds the atom's opened amount vectors",
            good,
            False,
            "link_certificate_mismatch",
        ),
        link_case(
            "vnet-link-false-net-reject",
            "transition links verify but VNET amount-vector zero-opening fails",
            false_net,
            False,
            "zero_opening",
        ),
    ]

    cases[1]["transition_report"]["accepted"].pop(1)
    cases[2]["transition_report"]["accepted"][0]["journal_commitment"] = "99999999999999999999999999999999"
    cases[3]["link_certificates"][2]["credit"][0] += 1

    return {
        "schema": "aac.vnet-link-ref.conformance.v1",
        "profile_id": PROFILE_ID,
        "vectors": cases,
    }


def cmd_generate(args: argparse.Namespace) -> int:
    profile_ref = load_profile(args.profile_reference)
    doc = build_vectors(profile_ref)
    text = json.dumps(doc, indent=2, sort_keys=True) + "\n"
    if args.out:
        Path(args.out).write_text(text)
    else:
        print(text, end="")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    profile_ref = load_profile(args.profile_reference)
    doc = json.loads(Path(args.file).read_text())
    failed = False
    for case in doc["vectors"]:
        accepted, reason = check_case(case, profile_ref)
        exp = case["expect"]
        ok = accepted == exp["accepted"] and reason == exp["reason"]
        print(f"{case['id']}: {'pass' if ok else 'FAIL'} accepted={accepted} reason={reason}")
        failed = failed or not ok
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("--profile-reference", default=str(DEFAULT_PROFILE_REF))
    gen.add_argument("--out")
    gen.set_defaults(func=cmd_generate)
    chk = sub.add_parser("check")
    chk.add_argument("file")
    chk.add_argument("--profile-reference", default=str(DEFAULT_PROFILE_REF))
    chk.set_defaults(func=cmd_check)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
