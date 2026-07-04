#!/usr/bin/env python3
"""Reference cjson/1 encoder for 2/FACT.

This module implements 2/FACT section 2, "Canonical form `cjson/1`":
null/booleans/strings/integers/arrays/objects only; arbitrary-precision
minimal decimal integers; strings with the pinned cjson/1 escape spelling;
object keys sorted by the UTF-8 bytes of the keys; and no whitespace. It also
implements 2/FACT section 3's `typeId := H(enc(TypeDecl))` with SHA-256 for
the reference deployment register.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any


class CjsonError(ValueError):
    """Raised when a value is outside the 2/FACT cjson/1 grammar."""


def _parse_int(token: str) -> int:
    # 2/FACT §2: integers are minimal decimal; no -0 or leading zeros.
    body = token[1:] if token.startswith("-") else token
    if token == "-0" or (len(body) > 1 and body.startswith("0")):
        raise CjsonError(f"non-minimal integer token: {token}")
    return int(token, 10)


def _reject_float(token: str) -> None:
    # 2/FACT §2: floats are not in the grammar; exponent forms are forbidden.
    raise CjsonError(f"non-integer number token: {token}")


def _reject_constant(token: str) -> None:
    raise CjsonError(f"non-JSON/cjson constant token: {token}")


def _object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    # 2/FACT §2: duplicate object keys are forbidden.
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise CjsonError(f"duplicate object key: {key!r}")
        out[key] = value
    return out


def loads_json(text: str) -> Any:
    """Parse a JSON document as an input Value, rejecting non-cjson numbers."""

    try:
        return json.loads(
            text,
            parse_int=_parse_int,
            parse_float=_reject_float,
            parse_constant=_reject_constant,
            object_pairs_hook=_object_pairs,
        )
    except CjsonError:
        raise
    except json.JSONDecodeError as exc:
        raise CjsonError(str(exc)) from exc


def load_json(path: str | Path) -> Any:
    with Path(path).open("r", encoding="utf-8") as fh:
        return loads_json(fh.read())


def _check_string(value: str) -> None:
    # 2/FACT §2: no unpaired surrogates.
    for char in value:
        code = ord(char)
        if 0xD800 <= code <= 0xDFFF:
            raise CjsonError("strings must not contain surrogate code points")


_SHORT_ESCAPES = {
    '"': '\\"',
    "\\": "\\\\",
    "\b": "\\b",
    "\t": "\\t",
    "\n": "\\n",
    "\f": "\\f",
    "\r": "\\r",
}


def _encode_string(value: str) -> str:
    # 2/FACT §2: strings use JSON syntax. cjson/1 pins short escapes for
    # JSON's short two-character spellings, lowercase \u00xx for other control
    # characters, and no escaping for any other character.
    _check_string(value)
    parts = ['"']
    for char in value:
        if char in _SHORT_ESCAPES:
            parts.append(_SHORT_ESCAPES[char])
            continue
        code = ord(char)
        if code < 0x20:
            parts.append(f"\\u{code:04x}")
        else:
            parts.append(char)
    parts.append('"')
    return "".join(parts)


def _key_sort_bytes(key: str) -> bytes:
    _check_string(key)
    return key.encode("utf-8")


def _encode_text(value: Any) -> str:
    # 2/FACT §2: null, booleans, and integers are literal/minimal.
    if value is None:
        return "null"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        return _encode_string(value)

    # 2/FACT §2: arrays preserve order and emit no whitespace.
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        return "[" + ",".join(_encode_text(item) for item in value) + "]"

    # 2/FACT §2: objects have string keys, no duplicates, UTF-8-byte key order,
    # and no whitespace around pairs or separators.
    if isinstance(value, Mapping):
        items: list[tuple[str, Any]] = []
        for key, item in value.items():
            if not isinstance(key, str):
                raise CjsonError(f"object key is not a string: {key!r}")
            items.append((key, item))
        items.sort(key=lambda pair: _key_sort_bytes(pair[0]))
        pairs = [
            f"{_encode_string(key)}:{_encode_text(item)}"
            for key, item in items
        ]
        return "{" + ",".join(pairs) + "}"

    raise CjsonError(f"value outside cjson/1 grammar: {type(value).__name__}")


def encode_text(value: Any) -> str:
    """Return cjson/1 canonical UTF-8 text as a Python string."""

    return _encode_text(value)


def encode(value: Any) -> bytes:
    """Return cjson/1 canonical bytes."""

    return encode_text(value).encode("utf-8")


def sha256_hex(value: Any) -> str:
    """2/FACT §3 reference H(enc(value)) using SHA-256."""

    return hashlib.sha256(encode(value)).hexdigest()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Encode a JSON Value as cjson/1")
    parser.add_argument("json_file", help="JSON file containing a cjson/1 Value")
    parser.add_argument(
        "--sha256",
        action="store_true",
        help="print sha256(enc(value)) hex instead of canonical bytes",
    )
    args = parser.parse_args(argv)

    try:
        value = load_json(args.json_file)
        if args.sha256:
            print(sha256_hex(value))
        else:
            sys.stdout.buffer.write(encode(value))
    except CjsonError as exc:
        print(f"cjson1_encode: {exc}", file=sys.stderr)
        return 65
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
