#!/usr/bin/env python3
"""Reference generator/checker for VNET-BN254-G1/1 conformance fixtures.

This is intentionally small and dependency-free. It is not optimized and is not
a production cryptographic library; it exists so profile fixtures are concrete
BN254 G1 points rather than symbolic examples.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any

P = 21888242871839275222246405745257275088696311157297823662689037894645226208583
R = 21888242871839275222246405745257275088548364400416034343698204186575808495617
PROFILE_ID = "vnet-bn254-g1/1"
INF = None


def canonical(obj: Any) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode()


def scalar_hash(label: str, *parts: Any) -> int:
    return int.from_bytes(hashlib.sha256(canonical([label, *parts])).digest(), "big") % R


def inv(x: int) -> int:
    return pow(x, P - 2, P)


def is_square(x: int) -> bool:
    if x == 0:
        return True
    return pow(x, (P - 1) // 2, P) == 1


def sqrt_even(x: int) -> int:
    y = pow(x, (P + 1) // 4, P)
    if (y * y) % P != x % P:
        raise ValueError("not a square")
    return y if y % 2 == 0 else P - y


def is_on_curve(pt: tuple[int, int] | None) -> bool:
    if pt is INF:
        return True
    x, y = pt
    return 0 <= x < P and 0 <= y < P and (y * y - x * x * x - 3) % P == 0


def add(a: tuple[int, int] | None, b: tuple[int, int] | None) -> tuple[int, int] | None:
    if a is INF:
        return b
    if b is INF:
        return a
    x1, y1 = a
    x2, y2 = b
    if x1 == x2 and (y1 + y2) % P == 0:
        return INF
    if a == b:
        lam = (3 * x1 * x1) * inv(2 * y1 % P) % P
    else:
        lam = (y2 - y1) * inv((x2 - x1) % P) % P
    x3 = (lam * lam - x1 - x2) % P
    y3 = (lam * (x1 - x3) - y1) % P
    return (x3, y3)


def neg(a: tuple[int, int] | None) -> tuple[int, int] | None:
    if a is INF:
        return INF
    x, y = a
    return (x, (-y) % P)


def mul(k: int, pt: tuple[int, int] | None) -> tuple[int, int] | None:
    k %= R
    out = INF
    cur = pt
    while k:
        if k & 1:
            out = add(out, cur)
        cur = add(cur, cur)
        k >>= 1
    return out


def h2c(label: str, *parts: Any) -> tuple[int, int]:
    base = canonical([label, *parts])
    for counter in range(1_000_000):
        digest = hashlib.sha256(base + counter.to_bytes(4, "big")).digest()
        x = int.from_bytes(digest, "big") % P
        rhs = (pow(x, 3, P) + 3) % P
        if is_square(rhs):
            return (x, sqrt_even(rhs))
    raise RuntimeError("hash_to_curve failed")


def basis_commitment(basis_type_ids: list[str]) -> str:
    return str(scalar_hash("aac/vnet-bn254-g1/1/basis", PROFILE_ID, basis_type_ids))


def generators(basis_type_ids: list[str]) -> tuple[tuple[int, int], list[tuple[int, int]], str]:
    bc = basis_commitment(basis_type_ids)
    h = h2c("aac/vnet-bn254-g1/1/H", PROFILE_ID, bc)
    gs = [
        h2c("aac/vnet-bn254-g1/1/G", PROFILE_ID, bc, i, basis_type_ids[i])
        for i in range(len(basis_type_ids))
    ]
    return h, gs, bc


def encode_point(pt: tuple[int, int] | None) -> dict[str, str]:
    if pt is INF:
        raise ValueError("infinity is not encodable")
    x, y = pt
    return {
        "x": str(x),
        "y": str(y),
        "uncompressed": "0x04" + x.to_bytes(32, "big").hex() + y.to_bytes(32, "big").hex(),
    }


def decode_point(obj: dict[str, str]) -> tuple[int, int]:
    x = int(obj["x"])
    y = int(obj["y"])
    enc = "0x04" + x.to_bytes(32, "big").hex() + y.to_bytes(32, "big").hex()
    if obj.get("uncompressed") != enc:
        raise ValueError("non-canonical point encoding")
    pt = (x, y)
    if not is_on_curve(pt):
        raise ValueError("point not on BN254 G1")
    if mul(R, pt) is not INF:
        raise ValueError("point not in subgroup")
    return pt


def commit(vec: list[int], rho: int, basis_type_ids: list[str]) -> tuple[int, int]:
    h, gs, _ = generators(basis_type_ids)
    acc = mul(rho, h)
    for amount, gen in zip(vec, gs):
        if amount < 0 or amount >= 2**64:
            raise ValueError("amount out of profile bound")
        acc = add(acc, mul(amount, gen))
    if acc is INF:
        raise ValueError("commitment is infinity")
    return acc


def fold_scalar(label: str, items: Any) -> str:
    return str(scalar_hash(label, items))


def fill_vector(vec: dict[str, Any]) -> dict[str, Any]:
    out = copy.deepcopy(vec)
    for atom in out["atoms"]:
        atom.setdefault("profile_id", PROFILE_ID)
        atom.setdefault("basis_type_ids", out["basis_type_ids"])
        atom["basis_commitment"] = basis_commitment(atom["basis_type_ids"])
        atom["debit_commitment"] = encode_point(commit(atom["debit"], atom["debit_blinding"], atom["basis_type_ids"]))
        atom["credit_commitment"] = encode_point(commit(atom["credit"], atom["credit_blinding"], atom["basis_type_ids"]))
    a = INF
    r_blind = 0
    for atom in out["atoms"]:
        cd = decode_point(atom["debit_commitment"])
        cc = decode_point(atom["credit_commitment"])
        a = add(add(a, cd), neg(cc))
        r_blind = (r_blind + atom["debit_blinding"] - atom["credit_blinding"]) % R
    out["profile_id"] = PROFILE_ID
    out["basis_commitment"] = basis_commitment(out["basis_type_ids"])
    out["aggregate_blinding"] = str(r_blind)
    out["aggregate_opening"] = encode_point(a)
    out["transition_set_commitment"] = fold_scalar(
        "aac/vnet-bn254-g1/1/transition-set",
        [[a["transition_ref"], a["journal_commitment"]] for a in out["atoms"]],
    )
    out["commitment_set_commitment"] = fold_scalar(
        "aac/vnet-bn254-g1/1/commitment-set",
        [[a["debit_commitment"], a["credit_commitment"], a["basis_commitment"]] for a in out["atoms"]],
    )
    return out


def check_vector(vec: dict[str, Any]) -> tuple[bool, str]:
    try:
        if vec.get("profile_id") != PROFILE_ID:
            return False, "profile_id"
        common_basis = vec["basis_type_ids"]
        common_bc = basis_commitment(common_basis)
        if vec.get("basis_commitment") != common_bc:
            return False, "basis_commitment"
        for atom in vec["atoms"]:
            if atom.get("profile_id") != PROFILE_ID:
                return False, "profile_id"
            if atom.get("basis_commitment") != common_bc or atom.get("basis_type_ids") != common_basis:
                return False, "mixed_basis"
            if not atom.get("transition_link", {}).get("opening_matches_journal", False):
                return False, "missing_transition_link"
            if decode_point(atom["debit_commitment"]) != commit(atom["debit"], atom["debit_blinding"], common_basis):
                return False, "commitment_mismatch"
            if decode_point(atom["credit_commitment"]) != commit(atom["credit"], atom["credit_blinding"], common_basis):
                return False, "commitment_mismatch"

        expected_ts = fold_scalar(
            "aac/vnet-bn254-g1/1/transition-set",
            [[a["transition_ref"], a["journal_commitment"]] for a in vec["atoms"]],
        )
        expected_cs = fold_scalar(
            "aac/vnet-bn254-g1/1/commitment-set",
            [[a["debit_commitment"], a["credit_commitment"], a["basis_commitment"]] for a in vec["atoms"]],
        )
        if vec.get("transition_set_commitment") != expected_ts:
            return False, "transition_set_commitment"
        if vec.get("commitment_set_commitment") != expected_cs:
            return False, "commitment_set_commitment"

        a = INF
        r_blind = 0
        debits = [0 for _ in common_basis]
        credits = [0 for _ in common_basis]
        for atom in vec["atoms"]:
            cd = decode_point(atom["debit_commitment"])
            cc = decode_point(atom["credit_commitment"])
            a = add(add(a, cd), neg(cc))
            r_blind = (r_blind + atom["debit_blinding"] - atom["credit_blinding"]) % R
            debits = [x + y for x, y in zip(debits, atom["debit"])]
            credits = [x + y for x, y in zip(credits, atom["credit"])]
        if decode_point(vec["aggregate_opening"]) != a:
            return False, "aggregate_opening"
        h, _, _ = generators(common_basis)
        if a != mul(r_blind, h) or vec.get("aggregate_blinding") != str(r_blind):
            return False, "zero_opening"
        if debits != credits:
            return False, "pn_balance"
        return True, "accepted"
    except Exception as exc:  # fixture failure details are part of the checker output
        return False, type(exc).__name__


def templates() -> dict[str, Any]:
    basis = ["USDC:arc-testnet:atomic", "SAFE:issuer:series-a:unit"]
    good_atoms = [
        {
            "transition_ref": "investor-a-subscription-row/7",
            "journal_commitment": "17171717171717171717171717171717",
            "debit": [0, 100],
            "credit": [1000, 0],
            "debit_blinding": 11,
            "credit_blinding": 12,
            "transition_link": {"opening_matches_journal": True},
        },
        {
            "transition_ref": "issuer-a-recognition-row/19",
            "journal_commitment": "29292929292929292929292929292929",
            "debit": [1000, 0],
            "credit": [0, 100],
            "debit_blinding": 21,
            "credit_blinding": 20,
            "transition_link": {"opening_matches_journal": True},
        },
        {
            "transition_ref": "investor-b-subscription-row/8",
            "journal_commitment": "31313131313131313131313131313131",
            "debit": [0, 50],
            "credit": [500, 0],
            "debit_blinding": 31,
            "credit_blinding": 33,
            "transition_link": {"opening_matches_journal": True},
        },
        {
            "transition_ref": "issuer-b-recognition-row/20",
            "journal_commitment": "37373737373737373737373737373737",
            "debit": [500, 0],
            "credit": [0, 50],
            "debit_blinding": 43,
            "credit_blinding": 40,
            "transition_link": {"opening_matches_journal": True},
        },
    ]
    cases = [
        {
            "id": "fundraise-good-batch",
            "description": "two approved subscriptions clear USDC and SAFE units per basis",
            "basis_type_ids": basis,
            "atoms": good_atoms,
            "expect": {"accepted": True, "reason": "accepted"},
        },
        {
            "id": "fundraise-mismatched-basis-reject",
            "description": "one atom uses a different issued-unit basis",
            "basis_type_ids": basis,
            "atoms": copy.deepcopy(good_atoms),
            "expect": {"accepted": False, "reason": "mixed_basis"},
        },
        {
            "id": "fundraise-missing-transition-link-reject",
            "description": "Pedersen openings are not linked to the posted TRANSITION journal",
            "basis_type_ids": basis,
            "atoms": copy.deepcopy(good_atoms),
            "expect": {"accepted": False, "reason": "missing_transition_link"},
        },
        {
            "id": "fundraise-false-net-reject",
            "description": "points are well-formed but SAFE unit credits do not net",
            "basis_type_ids": basis,
            "atoms": copy.deepcopy(good_atoms),
            "expect": {"accepted": False, "reason": "zero_opening"},
        },
    ]
    cases[1]["atoms"][1]["basis_type_ids"] = ["USDC:arc-testnet:atomic", "SAFE:issuer:series-b:unit"]
    cases[2]["atoms"][2]["transition_link"]["opening_matches_journal"] = False
    cases[3]["atoms"][3]["credit"] = [0, 49]
    return {
        "schema": "aac.vnet-bn254-g1.conformance.v1",
        "profile_id": PROFILE_ID,
        "vectors": [fill_vector(c) for c in cases],
    }


def cmd_generate(args: argparse.Namespace) -> int:
    doc = templates()
    text = json.dumps(doc, indent=2, sort_keys=True) + "\n"
    if args.out:
        Path(args.out).write_text(text)
    else:
        print(text, end="")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    doc = json.loads(Path(args.file).read_text())
    failed = False
    for vec in doc["vectors"]:
        accepted, reason = check_vector(vec)
        exp = vec["expect"]
        ok = accepted == exp["accepted"] and reason == exp["reason"]
        print(f"{vec['id']}: {'pass' if ok else 'FAIL'} accepted={accepted} reason={reason}")
        failed = failed or not ok
    return 1 if failed else 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    gen = sub.add_parser("generate")
    gen.add_argument("--out")
    gen.set_defaults(func=cmd_generate)
    chk = sub.add_parser("check")
    chk.add_argument("file")
    chk.set_defaults(func=cmd_check)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
