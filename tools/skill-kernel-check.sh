#!/usr/bin/env bash
set -u

# skill-kernel-check: the kernel skill may name only tools the export
# kernel ships (wire honesty as a gate). The Pi-surface skill
# (.agents/skills/boat/SKILL.md) is a wire that PROMISES affordances;
# if it cites a tools/ or sites/ path the export manifest does not
# carry, an instance born from boat-init would read a skill that lies
# about its own kernel. This check makes that impossible to land.
#
# Every `tools/<...>.sh|.py` and `sites/<...>.md` path token in the
# skill must be COVERED by tools/schemas/export-manifest.tsv — an exact
# file entry, or a path under a dir entry. An uncovered citation is a
# verifier_contract_violation (BIDIR-4.4: the skill's claims must be
# discharge-backed by what actually travels). Fail closed.
#
# Exit: 0 every citation covered; 1 an uncovered citation; 66 missing
#       substrate.

ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILL="${SKILL_KERNEL_FILE:-$ROOT/.agents/skills/boat/SKILL.md}"
MANIFEST="${SKILL_KERNEL_MANIFEST:-$ROOT/tools/schemas/export-manifest.tsv}"
EMIT="$ROOT/tools/eval/emit-refusal.sh"
PY="$(command -v python3 || true)"

[[ -n "$PY" && -x "$PY" ]] || { printf 'skill-kernel-check: python3 unavailable\n' >&2; exit 66; }
[[ -f "$SKILL" ]] || { printf 'skill-kernel-check: skill not found: %s\n' "$SKILL" >&2; exit 66; }
[[ -f "$MANIFEST" ]] || { printf 'skill-kernel-check: manifest not found: %s\n' "$MANIFEST" >&2; exit 66; }

uncovered="$("$PY" - "$SKILL" "$MANIFEST" <<'PYEOF'
import re
import sys

skill_path, manifest_path = sys.argv[1], sys.argv[2]
skill = open(skill_path, encoding="utf-8").read()

files, dirs = set(), []
for line in open(manifest_path, encoding="utf-8"):
    line = line.rstrip("\n")
    if not line or line.startswith("#"):
        continue
    parts = line.split("\t")
    if len(parts) != 2:
        continue
    kind, path = parts
    if kind == "file":
        files.add(path)
    elif kind == "dir":
        dirs.append(path.rstrip("/"))


def covered(path):
    if path in files:
        return True
    for d in dirs:
        if path == d or path.startswith(d + "/"):
            return True
    return False


# Affordance citations: concrete tool/law file paths the skill promises.
# Prose directory mentions (no extension) are not affordance claims and
# are not checked; a path with an extension is.
tokens = set(re.findall(r'\b(tools/[A-Za-z0-9_./-]+\.(?:sh|py))', skill))
tokens |= set(re.findall(r'\b(sites/[A-Za-z0-9_./-]+\.md)', skill))

bad = sorted(t for t in tokens if not covered(t))
for t in bad:
    print(t)
PYEOF
)"

if [[ -z "$uncovered" ]]; then
  printf 'skill-kernel-check: ok (every tool the skill names is in the export kernel)\n'
  exit 0
fi

while IFS= read -r tok; do
  [[ -n "$tok" ]] || continue
  printf 'skill-kernel-check: UNCOVERED citation: %s (not in export-manifest.tsv)\n' "$tok" >&2
  # The typed envelope is the machine artifact — surface it (stdout), do
  # not mute it; a consumer cites the failure by its class/witnessId.
  [[ -f "$EMIT" ]] && bash "$EMIT" verifier_contract_violation "skill.$tok" \
    "kernel skill honesty" \
    "the kernel skill names $tok, which the export manifest does not ship — an exported instance would read a skill that over-promises its kernel; either add $tok to the manifest or stop citing it" \
    'null' || true
done <<< "$uncovered"
exit 1
