#!/usr/bin/env python3
"""Transparent FUNDRAISE-CLEARING/1 demo packet checker.

This file is deliberately not a circuit, native verifier, settlement adapter,
CRE workflow, or token contract. It makes the demo transcript executable:

1. check a fixed round policy against subscriptions;
2. check settlement and admissibility reports for those subscriptions;
3. check mint authorization is bound to the same round and token contract; and
4. delegate transition-link + amount-vector netting to the VNET reference
   checker.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
from typing import Any

DEFAULT_VNET_REF = Path(__file__).resolve().with_name("vnet_link_verifier.py")
DEFAULT_PROFILE_REF = Path(__file__).resolve().parents[2] / "profiles" / "reference" / "vnet_bn254_g1_1.py"

SCHEMA = "aac.fundraise-demo.conformance.v1"
SETTLEMENT_ASSET = "USDC:arc-testnet:atomic"
ISSUED_UNIT = "SAFE:issuer:series-a:unit"


def canonical(obj: Any) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode()


def digest_hex(label: str, *parts: Any) -> str:
    return hashlib.sha256(canonical([label, *parts])).hexdigest()


def load_module(name: str, path: str | Path):
    p = Path(path)
    spec = importlib.util.spec_from_file_location(name, p)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {name}: {p}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def base_policy() -> dict[str, Any]:
    return {
        "round_id": "aac-seed-2026-001",
        "issuer_name": "issuer-a.private-row",
        "settlement_asset_type_id": SETTLEMENT_ASSET,
        "issued_unit_type_id": ISSUED_UNIT,
        "price_numerator": 10,
        "price_denominator": 1,
        "max_settlement_amount": 2_000,
        "max_issued_units": 200,
        "token_contract": "0xAac000000000000000000000000000000000039",
        "transfer_policy_hash": digest_hex("aac/demo/transfer-policy", "restricted-safe"),
        "admissibility_policy_hash": digest_hex("aac/demo/admissibility-policy", "allowlist"),
        "settlement_adapter_hash": digest_hex("aac/demo/settlement-adapter", "arc-usdc-report"),
    }


def base_subscriptions() -> list[dict[str, Any]]:
    return [
        {
            "subscription_id": "sub-investor-a-001",
            "investor_id": "investor-a",
            "mint_recipient": "0xA11ce00000000000000000000000000000000039",
            "settlement_ref": "arc-usdc-payment:0xa001",
            "settlement_amount": 1_000,
            "issued_units": 100,
            "admissibility_ref": "cre-admissibility:investor-a:001",
            "subscription_nullifier": "0x31f4f93b6c2e19a001",
        },
        {
            "subscription_id": "sub-investor-b-001",
            "investor_id": "investor-b",
            "mint_recipient": "0xB0b000000000000000000000000000000000039",
            "settlement_ref": "arc-usdc-payment:0xb001",
            "settlement_amount": 500,
            "issued_units": 50,
            "admissibility_ref": "cre-admissibility:investor-b:001",
            "subscription_nullifier": "0x31f4f93b6c2e19b001",
        },
    ]


def settlement_report(policy: dict[str, Any], subscriptions: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema": "aac.fundraise-demo.settlement-report.v1",
        "adapter_hash": policy["settlement_adapter_hash"],
        "accepted": [
            {
                "settlement_ref": sub["settlement_ref"],
                "investor_id": sub["investor_id"],
                "asset_type_id": policy["settlement_asset_type_id"],
                "amount": sub["settlement_amount"],
            }
            for sub in subscriptions
        ],
    }


def admissibility_report(policy: dict[str, Any], subscriptions: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema": "aac.fundraise-demo.admissibility-report.v1",
        "policy_hash": policy["admissibility_policy_hash"],
        "accepted": [
            {
                "admissibility_ref": sub["admissibility_ref"],
                "investor_id": sub["investor_id"],
                "accepted": True,
            }
            for sub in subscriptions
        ],
    }


def mint_authorization(policy: dict[str, Any], subscriptions: list[dict[str, Any]]) -> dict[str, Any]:
    recipients = [
        {
            "investor_id": sub["investor_id"],
            "recipient": sub["mint_recipient"],
            "issued_units": sub["issued_units"],
        }
        for sub in subscriptions
    ]
    return {
        "schema": "aac.fundraise-demo.mint-authorization.v1",
        "round_id": policy["round_id"],
        "token_contract": policy["token_contract"],
        "issued_unit_total": sum(item["issued_units"] for item in recipients),
        "mint_recipient_set_commitment": digest_hex("aac/fundraise/mint-recipients/1", recipients),
        "recipients": recipients,
    }


def vnet_public(vnet_link: dict[str, Any]) -> dict[str, Any]:
    vnet = vnet_link["vnet"]
    return {
        "profile_id": vnet["profile_id"],
        "basis_commitment": vnet["basis_commitment"],
        "aggregate_opening": vnet["aggregate_opening"],
        "atom_count": len(vnet["atoms"]),
        "transition_refs": [
            {
                "transition_ref": atom["transition_ref"],
                "journal_commitment": atom["journal_commitment"],
            }
            for atom in vnet["atoms"]
        ],
    }


def vnet_amount_totals(vnet_link: dict[str, Any]) -> tuple[list[int], list[int]]:
    atoms = vnet_link["vnet"]["atoms"]
    n = len(atoms[0]["debit"])
    debit = [0] * n
    credit = [0] * n
    for atom in atoms:
        for i in range(n):
            debit[i] += atom["debit"][i]
            credit[i] += atom["credit"][i]
    return debit, credit


def public_inputs(
    policy: dict[str, Any],
    subscriptions: list[dict[str, Any]],
    vnet_link: dict[str, Any],
    mint: dict[str, Any],
) -> dict[str, Any]:
    transitions = vnet_public(vnet_link)["transition_refs"]
    settlement_total = sum(sub["settlement_amount"] for sub in subscriptions)
    issued_total = sum(sub["issued_units"] for sub in subscriptions)
    return {
        "round_id": policy["round_id"],
        "issuer_name": policy["issuer_name"],
        "prev_balance_sheet_root": digest_hex("aac/demo/root", "balance-sheet", "prev"),
        "next_balance_sheet_root": digest_hex("aac/demo/root", "balance-sheet", "next"),
        "prev_cap_table_root": digest_hex("aac/demo/root", "cap-table", "prev"),
        "next_cap_table_root": digest_hex("aac/demo/root", "cap-table", "next"),
        "subscription_set_commitment": digest_hex("aac/fundraise/subscriptions/1", subscriptions),
        "transition_set_commitment": digest_hex("aac/fundraise/transitions/1", transitions),
        "vnet_public_commitment": digest_hex("aac/fundraise/vnet-public/1", vnet_public(vnet_link)),
        "mint_recipient_set_commitment": mint["mint_recipient_set_commitment"],
        "settlement_amount_total": settlement_total,
        "issued_unit_total": issued_total,
        "token_contract": mint["token_contract"],
        "context_commitment": digest_hex(
            "aac/fundraise/context/1",
            policy,
            settlement_report(policy, subscriptions),
            admissibility_report(policy, subscriptions),
        ),
    }


def finalize_packet(
    policy: dict[str, Any],
    subscriptions: list[dict[str, Any]],
    vnet_link: dict[str, Any],
    *,
    settlement: dict[str, Any] | None = None,
    admissibility: dict[str, Any] | None = None,
    mint: dict[str, Any] | None = None,
) -> dict[str, Any]:
    settlement = settlement if settlement is not None else settlement_report(policy, subscriptions)
    admissibility = admissibility if admissibility is not None else admissibility_report(policy, subscriptions)
    mint = mint if mint is not None else mint_authorization(policy, subscriptions)
    return {
        "round_policy": policy,
        "subscriptions": subscriptions,
        "settlement_report": settlement,
        "admissibility_report": admissibility,
        "vnet_link": vnet_link,
        "mint_authorization": mint,
        "public_inputs": public_inputs(policy, subscriptions, vnet_link, mint),
    }


def base_packet(vnet_link: dict[str, Any]) -> dict[str, Any]:
    policy = base_policy()
    subscriptions = base_subscriptions()
    return finalize_packet(policy, subscriptions, copy.deepcopy(vnet_link))


def case_for(case_id: str, description: str, packet: dict[str, Any], accepted: bool, reason: str) -> dict[str, Any]:
    return {
        "id": case_id,
        "description": description,
        "packet": packet,
        "expect": {"accepted": accepted, "reason": reason},
    }


def build_vectors(vnet_ref: Any, profile_ref: Any) -> dict[str, Any]:
    link_vectors = {vec["id"]: vec for vec in vnet_ref.build_vectors(profile_ref)["vectors"]}
    good_link = link_vectors["vnet-link-good-fundraise"]
    false_net_link = link_vectors["vnet-link-false-net-reject"]

    good = base_packet(good_link)

    price_bad_subs = copy.deepcopy(base_subscriptions())
    price_bad_subs[0]["issued_units"] = 101
    price_bad = finalize_packet(base_policy(), price_bad_subs, copy.deepcopy(good_link))

    missing_settlement = base_packet(good_link)
    missing_settlement["settlement_report"]["accepted"].pop(1)

    token_bad = base_packet(good_link)
    token_bad["mint_authorization"]["token_contract"] = "0xBad0000000000000000000000000000000000039"
    token_bad["public_inputs"] = public_inputs(
        token_bad["round_policy"],
        token_bad["subscriptions"],
        token_bad["vnet_link"],
        token_bad["mint_authorization"],
    )

    vnet_bad = base_packet(false_net_link)

    return {
        "schema": SCHEMA,
        "vectors": [
            case_for(
                "fundraise-demo-good",
                "accepted settlement/admissibility reports, balanced VNET link, and token-bound mint authorization",
                good,
                True,
                "accepted",
            ),
            case_for(
                "fundraise-demo-price-mismatch-reject",
                "one subscription violates the round's fixed issue-price arithmetic",
                price_bad,
                False,
                "price_mismatch",
            ),
            case_for(
                "fundraise-demo-missing-settlement-reject",
                "one subscription settlement reference is absent from the trusted settlement report",
                missing_settlement,
                False,
                "settlement_report_missing",
            ),
            case_for(
                "fundraise-demo-token-mismatch-reject",
                "mint authorization names a token contract different from the round policy",
                token_bad,
                False,
                "token_contract_mismatch",
            ),
            case_for(
                "fundraise-demo-vnet-false-net-reject",
                "the fundraising transcript is otherwise bound but VNET amount-vector clearing fails",
                vnet_bad,
                False,
                "vnet_zero_opening",
            ),
        ],
    }


def settlement_index(report: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["settlement_ref"]: item for item in report.get("accepted", [])}


def admissibility_index(report: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["admissibility_ref"]: item for item in report.get("accepted", [])}


def check_case(case: dict[str, Any], vnet_ref: Any, profile_ref: Any) -> tuple[bool, str]:
    packet = case["packet"]
    policy = packet["round_policy"]
    subscriptions = packet["subscriptions"]
    pub = packet["public_inputs"]
    settlement = settlement_index(packet["settlement_report"])
    admissibility = admissibility_index(packet["admissibility_report"])
    mint = packet["mint_authorization"]
    vnet_link = packet["vnet_link"]

    if pub.get("round_id") != policy["round_id"]:
        return False, "round_id_mismatch"
    if pub.get("token_contract") != mint["token_contract"]:
        return False, "public_token_mismatch"
    if mint.get("round_id") != policy["round_id"]:
        return False, "mint_round_mismatch"
    if mint.get("token_contract") != policy["token_contract"]:
        return False, "token_contract_mismatch"

    nullifiers: set[str] = set()
    settlement_total = 0
    issued_total = 0
    for sub in subscriptions:
        if sub["settlement_amount"] * policy["price_denominator"] != sub["issued_units"] * policy["price_numerator"]:
            return False, "price_mismatch"
        if sub["subscription_nullifier"] in ("", "0", "0x0"):
            return False, "zero_nullifier"
        if sub["subscription_nullifier"] in nullifiers:
            return False, "duplicate_nullifier"
        nullifiers.add(sub["subscription_nullifier"])

        reported = settlement.get(sub["settlement_ref"])
        if reported is None:
            return False, "settlement_report_missing"
        if reported.get("investor_id") != sub["investor_id"]:
            return False, "settlement_report_mismatch"
        if reported.get("asset_type_id") != policy["settlement_asset_type_id"]:
            return False, "settlement_asset_mismatch"
        if reported.get("amount") != sub["settlement_amount"]:
            return False, "settlement_amount_mismatch"

        admitted = admissibility.get(sub["admissibility_ref"])
        if admitted is None or admitted.get("accepted") is not True:
            return False, "admissibility_missing"
        if admitted.get("investor_id") != sub["investor_id"]:
            return False, "admissibility_mismatch"

        settlement_total += sub["settlement_amount"]
        issued_total += sub["issued_units"]

    if settlement_total > policy["max_settlement_amount"]:
        return False, "settlement_cap_exceeded"
    if issued_total > policy["max_issued_units"]:
        return False, "issued_cap_exceeded"
    if pub.get("settlement_amount_total") != settlement_total:
        return False, "settlement_total_mismatch"
    if pub.get("issued_unit_total") != issued_total:
        return False, "issued_total_mismatch"
    if mint.get("issued_unit_total") != issued_total:
        return False, "mint_total_mismatch"
    if mint.get("mint_recipient_set_commitment") != digest_hex("aac/fundraise/mint-recipients/1", mint.get("recipients", [])):
        return False, "mint_recipient_commitment_mismatch"
    if pub.get("mint_recipient_set_commitment") != mint["mint_recipient_set_commitment"]:
        return False, "public_mint_recipient_mismatch"

    if pub.get("subscription_set_commitment") != digest_hex("aac/fundraise/subscriptions/1", subscriptions):
        return False, "subscription_set_commitment_mismatch"
    transitions = vnet_public(vnet_link)["transition_refs"]
    if pub.get("transition_set_commitment") != digest_hex("aac/fundraise/transitions/1", transitions):
        return False, "transition_set_commitment_mismatch"
    if pub.get("vnet_public_commitment") != digest_hex("aac/fundraise/vnet-public/1", vnet_public(vnet_link)):
        return False, "vnet_public_commitment_mismatch"

    vnet_ok, vnet_reason = vnet_ref.check_case(vnet_link, profile_ref)
    if not vnet_ok:
        return False, f"vnet_{vnet_reason}"

    debit, credit = vnet_amount_totals(vnet_link)
    expected = [settlement_total, issued_total]
    if debit != expected or credit != expected:
        return False, "vnet_amount_total_mismatch"

    return True, "accepted"


def cmd_generate(args: argparse.Namespace) -> int:
    vnet_ref = load_module("vnet_link_verifier", args.vnet_reference)
    profile_ref = vnet_ref.load_profile(args.profile_reference)
    doc = build_vectors(vnet_ref, profile_ref)
    text = json.dumps(doc, indent=2, sort_keys=True) + "\n"
    if args.out:
        Path(args.out).write_text(text)
    else:
        print(text, end="")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    vnet_ref = load_module("vnet_link_verifier", args.vnet_reference)
    profile_ref = vnet_ref.load_profile(args.profile_reference)
    doc = json.loads(Path(args.file).read_text())
    failed = False
    for case in doc["vectors"]:
        accepted, reason = check_case(case, vnet_ref, profile_ref)
        exp = case["expect"]
        ok = accepted == exp["accepted"] and reason == exp["reason"]
        print(f"{case['id']}: {'pass' if ok else 'FAIL'} accepted={accepted} reason={reason}")
        failed = failed or not ok
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("--vnet-reference", default=str(DEFAULT_VNET_REF))
    gen.add_argument("--profile-reference", default=str(DEFAULT_PROFILE_REF))
    gen.add_argument("--out")
    gen.set_defaults(func=cmd_generate)
    chk = sub.add_parser("check")
    chk.add_argument("file")
    chk.add_argument("--vnet-reference", default=str(DEFAULT_VNET_REF))
    chk.add_argument("--profile-reference", default=str(DEFAULT_PROFILE_REF))
    chk.set_defaults(func=cmd_check)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
