#!/usr/bin/env python3
"""Transparent FUNDRAISE-CLEARING/1 demo packet checker.

This file is deliberately not a circuit, native verifier, settlement adapter,
CRE workflow, or token contract. It makes the demo transcript executable:

1. check a fixed round policy against subscriptions;
2. check settlement and admissibility reports for those subscriptions;
3. check BCC agreement certificates and bridge settlement context;
4. check mint authorization is bound to the same round and token contract; and
5. delegate transition-link + amount-vector netting to the VNET reference
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
        "settlement_chain": "arc-testnet",
        "vault_or_contract": "0xVa01700000000000000000000000000000000039",
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


def bridge_settlement(policy: dict[str, Any], subscriptions: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema": "aac.fundraise-demo.bridge-settlement.v1",
        "settlement_chain": policy["settlement_chain"],
        "vault_or_contract": policy["vault_or_contract"],
        "asset_type_id": policy["settlement_asset_type_id"],
        "accepted": [
            {
                "subscription_id": sub["subscription_id"],
                "investor_id": sub["investor_id"],
                "settlement_ref": sub["settlement_ref"],
                "deposit_ref": sub["settlement_ref"],
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


def signed_vector(debit: list[int], credit: list[int]) -> list[int]:
    return [debit[i] - credit[i] for i in range(len(debit))]


def mock_record_commitment(basis: list[str], debit: list[int], credit: list[int], blinding: str) -> dict[str, str]:
    return {
        "scheme": "mock-record-commitment/1",
        "value": digest_hex("aac/bcc/mock-record-commitment/1", basis, signed_vector(debit, credit), blinding),
    }


def bcc_public_record(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "party_id": record["party_id"],
        "role": record["role"],
        "transition_ref": record["transition_ref"],
        "journal_commitment": record["journal_commitment"],
        "basis_type_ids": record["basis_type_ids"],
        "record_commitment": record["record_commitment"],
    }


def bcc_transcript_payload(cert: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": cert["schema"],
        "event": cert["event"],
        "basis_type_ids": cert["basis_type_ids"],
        "records": [
            {
                "party_id": r["party_id"],
                "role": r["role"],
                "transition_ref": r["transition_ref"],
                "journal_commitment": r["journal_commitment"],
                "basis_type_ids": r["basis_type_ids"],
                "record_commitment": r["record_commitment"],
            }
            for r in cert["records"]
        ],
        "cancellation_opening": cert["cancellation_opening"],
        "authenticated_dh": cert.get("authenticated_dh"),
        "finality": {
            "scheme": cert["finality"]["scheme"],
            "log_ref": cert["finality"]["log_ref"],
            "nullifier": cert["finality"]["nullifier"],
        },
    }


def bcc_certificate(policy: dict[str, Any], sub: dict[str, Any], vnet_link: dict[str, Any], index: int) -> dict[str, Any]:
    atoms = vnet_link["vnet"]["atoms"]
    investor_atom = atoms[index * 2]
    issuer_atom = atoms[index * 2 + 1]
    basis = [policy["settlement_asset_type_id"], policy["issued_unit_type_id"]]
    event = {
        "event_id": f"fundraise:{policy['round_id']}:{sub['subscription_id']}",
        "description": f"Investor {sub['investor_id']} subscribes to {sub['issued_units']} issued units for {sub['settlement_amount']} settlement units.",
        "basis_type_ids": basis,
        "state_refs": {
            "investor_row": investor_atom["transition_ref"],
            "issuer_row": issuer_atom["transition_ref"],
        },
        "fundraise_context": {
            "round_id": policy["round_id"],
            "issuer_name": policy["issuer_name"],
            "investor_id": sub["investor_id"],
            "subscription_id": sub["subscription_id"],
            "settlement_ref": sub["settlement_ref"],
            "settlement_amount": sub["settlement_amount"],
            "issued_units": sub["issued_units"],
            "token_contract": policy["token_contract"],
        },
        "bridge_context": {
            "asset": policy["settlement_asset_type_id"],
            "settlement_chain": policy["settlement_chain"],
            "vault_or_contract": policy["vault_or_contract"],
            "deposit_ref": sub["settlement_ref"],
        },
    }
    private_records = [
        {
            "party_id": sub["investor_id"],
            "role": "investor",
            "transition_ref": investor_atom["transition_ref"],
            "journal_commitment": investor_atom["journal_commitment"],
            "basis_type_ids": basis,
            "debit": [0, sub["issued_units"]],
            "credit": [sub["settlement_amount"], 0],
            "record_blinding": f"{sub['investor_id']}:record",
        },
        {
            "party_id": policy["issuer_name"],
            "role": "issuer",
            "transition_ref": issuer_atom["transition_ref"],
            "journal_commitment": issuer_atom["journal_commitment"],
            "basis_type_ids": basis,
            "debit": [sub["settlement_amount"], 0],
            "credit": [0, sub["issued_units"]],
            "record_blinding": f"{policy['issuer_name']}:record",
        },
    ]
    for record in private_records:
        record["record_commitment"] = mock_record_commitment(
            basis,
            record["debit"],
            record["credit"],
            record["record_blinding"],
        )
    public_records = [bcc_public_record(r) for r in private_records]
    aggregate_opening = digest_hex("aac/bcc/mock-aggregate-opening/1", [r["record_blinding"] for r in private_records])
    cancellation = {
        "scheme": "mock-cancellation-opening/1",
        "commitment_scheme": "mock-record-commitment/1",
        "aggregate_opening": aggregate_opening,
        "zero_opening": True,
        "proof_digest": digest_hex(
            "aac/bcc/mock-cancellation-opening/1",
            [r["record_commitment"]["value"] for r in public_records],
            aggregate_opening,
            True,
        ),
        "record_count": 2,
    }
    participants = {
        sub["investor_id"]: "buyer-ephemeral-x25519",
        policy["issuer_name"]: "seller-ephemeral-x25519",
    }
    dh = {
        "scheme": "mock-authenticated-ecdh/1",
        "ephemeral_public_keys": participants,
        "kdf": "hkdf-sha256",
        "transcript_binding": "ephemeral keys are signed inside transcript_hash",
        "public_edge_tag": digest_hex("aac/bcc/mock-authenticated-ecdh/1", participants),
    }
    nullifier = sub["subscription_nullifier"]
    partial = {
        "schema": "aac.bcc.certificate.v1",
        "event": event,
        "basis_type_ids": basis,
        "records": public_records,
        "cancellation_opening": cancellation,
        "authenticated_dh": dh,
        "finality": {
            "scheme": "bcc-finality-tag/1",
            "log_ref": f"fundraise:{policy['round_id']}",
            "nullifier": nullifier,
            "finality_tag": "",
        },
        "transcript_hash": "",
        "signatures": [],
    }
    partial["transcript_hash"] = digest_hex("aac/bcc/transcript/1", bcc_transcript_payload(partial))
    partial["finality"]["finality_tag"] = digest_hex(
        "aac/bcc/finality/1",
        partial["finality"]["log_ref"],
        nullifier,
        partial["transcript_hash"],
    )
    partial["signatures"] = [
        {
            "party_id": r["party_id"],
            "public_key": f"{r['party_id']}:pub",
            "scheme": "mock-signature/1",
            "signature": digest_hex("aac/bcc/mock-signature/1", r["party_id"], f"{r['party_id']}:pub", partial["transcript_hash"]),
        }
        for r in public_records
    ]
    return partial


def bcc_agreements(policy: dict[str, Any], subscriptions: list[dict[str, Any]], vnet_link: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "schema": "aac.fundraise-demo.bcc-agreement.v1",
            "subscription_id": sub["subscription_id"],
            "certificate": bcc_certificate(policy, sub, vnet_link, i),
        }
        for i, sub in enumerate(subscriptions)
    ]


def bcc_public(agreement: dict[str, Any]) -> dict[str, Any]:
    cert = agreement["certificate"]
    return {
        "subscription_id": agreement["subscription_id"],
        "transcript_hash": cert["transcript_hash"],
        "finality_tag": cert["finality"]["finality_tag"],
        "nullifier": cert["finality"]["nullifier"],
        "parties": [r["party_id"] for r in cert["records"]],
        "record_commitments": [r["record_commitment"]["value"] for r in cert["records"]],
    }


def check_bcc(
    policy: dict[str, Any],
    sub: dict[str, Any],
    cert: dict[str, Any],
    seen_finality_tags: set[str],
) -> tuple[bool, str]:
    if cert.get("schema") != "aac.bcc.certificate.v1":
        return False, "bcc_schema_mismatch"
    records = cert.get("records", [])
    if len(records) != 2:
        return False, "bcc_two_party_shape"
    if cert["finality"]["finality_tag"] in seen_finality_tags:
        return False, "bcc_finality_replay"
    for record in records:
        if "debit" in record or "credit" in record or "record_blinding" in record:
            return False, "bcc_private_witness_leak"
        if record.get("basis_type_ids") != cert.get("basis_type_ids"):
            return False, "bcc_basis_mismatch"
        if record.get("record_commitment", {}).get("scheme") != "mock-record-commitment/1":
            return False, "bcc_record_commitment_missing"

    opening = cert.get("cancellation_opening", {})
    expected_proof = digest_hex(
        "aac/bcc/mock-cancellation-opening/1",
        [r["record_commitment"]["value"] for r in records],
        opening.get("aggregate_opening"),
        opening.get("zero_opening"),
    )
    if opening.get("scheme") != "mock-cancellation-opening/1" or opening.get("proof_digest") != expected_proof:
        return False, "bcc_cancellation_opening_mismatch"
    if opening.get("zero_opening") is not True:
        return False, "bcc_cancellation_zero_opening"

    dh = cert.get("authenticated_dh")
    if dh is not None:
        expected_parties = sorted(r["party_id"] for r in records)
        actual_parties = sorted((dh.get("ephemeral_public_keys") or {}).keys())
        if actual_parties != expected_parties:
            return False, "bcc_authenticated_dh_party_mismatch"
        if dh.get("public_edge_tag") != digest_hex("aac/bcc/mock-authenticated-ecdh/1", dh.get("ephemeral_public_keys")):
            return False, "bcc_authenticated_dh_mismatch"

    if cert.get("transcript_hash") != digest_hex("aac/bcc/transcript/1", bcc_transcript_payload(cert)):
        return False, "bcc_transcript_hash_mismatch"
    signatures = {sig["party_id"]: sig for sig in cert.get("signatures", [])}
    for record in records:
        sig = signatures.get(record["party_id"])
        if sig is None:
            return False, "bcc_signature_missing"
        expected = digest_hex("aac/bcc/mock-signature/1", record["party_id"], sig["public_key"], cert["transcript_hash"])
        if sig.get("signature") != expected:
            return False, "bcc_signature_mismatch"

    expected_finality = digest_hex(
        "aac/bcc/finality/1",
        cert["finality"]["log_ref"],
        cert["finality"]["nullifier"],
        cert["transcript_hash"],
    )
    if cert["finality"]["finality_tag"] != expected_finality:
        return False, "bcc_finality_tag_mismatch"
    if cert["finality"]["nullifier"] != sub["subscription_nullifier"]:
        return False, "bcc_nullifier_mismatch"

    ctx = cert.get("event", {}).get("fundraise_context")
    if ctx is None:
        return False, "bcc_context_missing"
    if ctx.get("round_id") != policy["round_id"]:
        return False, "bcc_round_mismatch"
    if ctx.get("subscription_id") != sub["subscription_id"]:
        return False, "bcc_subscription_mismatch"
    if ctx.get("investor_id") != sub["investor_id"]:
        return False, "bcc_investor_mismatch"
    if ctx.get("issuer_name") != policy["issuer_name"]:
        return False, "bcc_issuer_mismatch"
    if ctx.get("settlement_ref") != sub["settlement_ref"]:
        return False, "bcc_settlement_ref_mismatch"
    if ctx.get("settlement_amount") != sub["settlement_amount"]:
        return False, "bcc_settlement_amount_mismatch"
    if ctx.get("issued_units") != sub["issued_units"]:
        return False, "bcc_issued_units_mismatch"
    if ctx.get("token_contract") != policy["token_contract"]:
        return False, "bcc_token_contract_mismatch"

    bridge = cert.get("event", {}).get("bridge_context")
    if bridge is None:
        return False, "bcc_bridge_context_missing"
    if bridge.get("asset") != policy["settlement_asset_type_id"]:
        return False, "bcc_bridge_asset_mismatch"
    if bridge.get("settlement_chain") != policy["settlement_chain"]:
        return False, "bcc_bridge_chain_mismatch"
    if bridge.get("vault_or_contract") != policy["vault_or_contract"]:
        return False, "bcc_bridge_contract_mismatch"
    if bridge.get("deposit_ref") != sub["settlement_ref"]:
        return False, "bcc_bridge_deposit_mismatch"

    return True, "accepted"


def public_inputs(
    policy: dict[str, Any],
    subscriptions: list[dict[str, Any]],
    vnet_link: dict[str, Any],
    mint: dict[str, Any],
    bcc: list[dict[str, Any]],
    bridge: dict[str, Any],
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
        "bcc_set_commitment": digest_hex("aac/fundraise/bcc-agreements/1", [bcc_public(agreement) for agreement in bcc]),
        "bridge_settlement_commitment": digest_hex("aac/fundraise/bridge-settlement/1", bridge),
        "mint_recipient_set_commitment": mint["mint_recipient_set_commitment"],
        "settlement_amount_total": settlement_total,
        "issued_unit_total": issued_total,
        "token_contract": mint["token_contract"],
        "context_commitment": digest_hex(
            "aac/fundraise/context/1",
            policy,
            settlement_report(policy, subscriptions),
            admissibility_report(policy, subscriptions),
            bridge,
        ),
    }


def finalize_packet(
    policy: dict[str, Any],
    subscriptions: list[dict[str, Any]],
    vnet_link: dict[str, Any],
    *,
    bcc: list[dict[str, Any]] | None = None,
    bridge: dict[str, Any] | None = None,
    settlement: dict[str, Any] | None = None,
    admissibility: dict[str, Any] | None = None,
    mint: dict[str, Any] | None = None,
) -> dict[str, Any]:
    settlement = settlement if settlement is not None else settlement_report(policy, subscriptions)
    admissibility = admissibility if admissibility is not None else admissibility_report(policy, subscriptions)
    mint = mint if mint is not None else mint_authorization(policy, subscriptions)
    bridge = bridge if bridge is not None else bridge_settlement(policy, subscriptions)
    bcc = bcc if bcc is not None else bcc_agreements(policy, subscriptions, vnet_link)
    return {
        "round_policy": policy,
        "subscriptions": subscriptions,
        "bcc_agreements": bcc,
        "bridge_settlement": bridge,
        "settlement_report": settlement,
        "admissibility_report": admissibility,
        "vnet_link": vnet_link,
        "mint_authorization": mint,
        "public_inputs": public_inputs(policy, subscriptions, vnet_link, mint, bcc, bridge),
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
        token_bad["bcc_agreements"],
        token_bad["bridge_settlement"],
    )

    vnet_bad = base_packet(false_net_link)

    missing_bcc = base_packet(good_link)
    missing_bcc["bcc_agreements"].pop(1)

    bcc_signature_bad = base_packet(good_link)
    bcc_signature_bad["bcc_agreements"][0]["certificate"]["signatures"][0]["signature"] = "bad-signature"

    bcc_replay_bad = base_packet(good_link)
    bcc_replay_context = {
        "seen_bcc_finality_tags": [
            bcc_replay_bad["bcc_agreements"][0]["certificate"]["finality"]["finality_tag"],
        ]
    }

    bcc_round_bad = base_packet(good_link)
    wrong_policy = base_policy()
    wrong_policy["round_id"] = "wrong-round"
    bcc_round_bad["bcc_agreements"][0] = bcc_agreements(wrong_policy, base_subscriptions(), good_link)[0]

    bridge_asset_bad = base_packet(good_link)
    bridge_asset_bad["bridge_settlement"]["asset_type_id"] = "EURC:arc-testnet:atomic"

    return {
        "schema": SCHEMA,
        "vectors": [
            case_for(
                "fundraise-demo-good",
                "accepted BCC agreements, bridge settlement, settlement/admissibility reports, balanced VNET link, and token-bound mint authorization",
                good,
                True,
                "accepted",
            ),
            case_for(
                "fundraise-demo-missing-bcc-reject",
                "one subscription lacks its co-signed BCC agreement certificate",
                missing_bcc,
                False,
                "bcc_missing",
            ),
            case_for(
                "fundraise-demo-bcc-signature-reject",
                "one BCC certificate signature no longer matches the transcript",
                bcc_signature_bad,
                False,
                "bcc_signature_mismatch",
            ),
            {
                **case_for(
                    "fundraise-demo-bcc-replay-reject",
                    "one BCC finality tag was already accepted by the deployment replay surface",
                    bcc_replay_bad,
                    False,
                    "bcc_finality_replay",
                ),
                "verifier_context": bcc_replay_context,
            },
            case_for(
                "fundraise-demo-bcc-round-mismatch-reject",
                "one BCC agreement is validly signed for a different round than the fundraising policy",
                bcc_round_bad,
                False,
                "bcc_round_mismatch",
            ),
            case_for(
                "fundraise-demo-bridge-asset-mismatch-reject",
                "bridge settlement report names a different custody asset than the round policy",
                bridge_asset_bad,
                False,
                "bridge_asset_mismatch",
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
    verifier_context = case.get("verifier_context", {})
    policy = packet["round_policy"]
    subscriptions = packet["subscriptions"]
    pub = packet["public_inputs"]
    settlement = settlement_index(packet["settlement_report"])
    admissibility = admissibility_index(packet["admissibility_report"])
    mint = packet["mint_authorization"]
    vnet_link = packet["vnet_link"]
    bcc_items = packet.get("bcc_agreements")
    bridge = packet.get("bridge_settlement")

    if pub.get("round_id") != policy["round_id"]:
        return False, "round_id_mismatch"
    if pub.get("token_contract") != mint["token_contract"]:
        return False, "public_token_mismatch"
    if mint.get("round_id") != policy["round_id"]:
        return False, "mint_round_mismatch"
    if mint.get("token_contract") != policy["token_contract"]:
        return False, "token_contract_mismatch"
    if not isinstance(bcc_items, list) or len(bcc_items) != len(subscriptions):
        return False, "bcc_missing"
    if bridge is None or bridge.get("schema") != "aac.fundraise-demo.bridge-settlement.v1":
        return False, "bridge_missing"
    if bridge.get("settlement_chain") != policy["settlement_chain"]:
        return False, "bridge_chain_mismatch"
    if bridge.get("vault_or_contract") != policy["vault_or_contract"]:
        return False, "bridge_contract_mismatch"
    if bridge.get("asset_type_id") != policy["settlement_asset_type_id"]:
        return False, "bridge_asset_mismatch"

    nullifiers: set[str] = set()
    bcc_by_subscription = {item["subscription_id"]: item for item in bcc_items}
    bridge_by_subscription = {item["subscription_id"]: item for item in bridge.get("accepted", [])}
    bcc_finality_tags: set[str] = set(verifier_context.get("seen_bcc_finality_tags", []))
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

        bridge_item = bridge_by_subscription.get(sub["subscription_id"])
        if bridge_item is None:
            return False, "bridge_settlement_missing"
        if bridge_item.get("investor_id") != sub["investor_id"]:
            return False, "bridge_settlement_mismatch"
        if bridge_item.get("settlement_ref") != sub["settlement_ref"]:
            return False, "bridge_settlement_mismatch"
        if bridge_item.get("deposit_ref") != sub["settlement_ref"]:
            return False, "bridge_deposit_mismatch"
        if bridge_item.get("amount") != sub["settlement_amount"]:
            return False, "bridge_amount_mismatch"

        bcc_item = bcc_by_subscription.get(sub["subscription_id"])
        if bcc_item is None:
            return False, "bcc_missing"
        bcc_ok, bcc_reason = check_bcc(policy, sub, bcc_item["certificate"], bcc_finality_tags)
        if not bcc_ok:
            return False, bcc_reason
        bcc_finality_tags.add(bcc_item["certificate"]["finality"]["finality_tag"])

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
    if pub.get("bcc_set_commitment") != digest_hex("aac/fundraise/bcc-agreements/1", [bcc_public(agreement) for agreement in bcc_items]):
        return False, "bcc_set_commitment_mismatch"
    if pub.get("bridge_settlement_commitment") != digest_hex("aac/fundraise/bridge-settlement/1", bridge):
        return False, "bridge_settlement_commitment_mismatch"

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
