#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0093.
#
# This evaluator stages the candidate landing, checks the PEDERSEN-VECTOR/1
# derivation clarifications against mutants, regenerates the vector through the
# standalone Noir beta.19 harness, and checks the queue move.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"

# tools/eval/attest.sh uses GNU `head -n -1`. On BSD/macOS, provide the exact
# behavior to the child bash process without modifying the verifier-set tool.
head() {
  if [[ "${1:-}" == "-n" && "${2:-}" == "-1" && $# -eq 3 ]]; then
    awk 'NR > 1 { print prev } { prev = $0 }' "$3"
  else
    command head "$@"
  fi
}
export -f head

# shellcheck source=../../tools/eval/eval-lib.sh
. "$ROOT/tools/eval/eval-lib.sh"
eval_init "$CAND_DIR" "$ROOT" || exit 1

WORK="$(mktemp -d /private/tmp/aac-cand-0093.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

PROFILE="$STAGED/sites/ledger/specs/profiles/PEDERSEN-VECTOR-1.md"
VECTOR="$STAGED/sites/ledger/specs/profiles/vectors/PEDERSEN-VECTOR-1.json"
QUEUE="$STAGED/candidates/QUEUE.md"
HARNESS="$STAGED/world-app/provekit-pedersen-vector-derivation"

check_encoding() {
  local f="$1"
  grep_prose 'field_of(s) = UTF-8 bytes of s interpreted as a big-endian integer' "$f" >/dev/null || return 1
  grep_prose 'MUST require `len(utf8(s)) <= 31` bytes' "$f" >/dev/null || return 1
  grep_prose 'INVALID: the target fails closed and MUST NOT reduce the integer modulo the field' "$f" >/dev/null || return 1
  grep_prose 'domain tags (`"aac/vnet/1"`, `"aac/vnet/1/basis"`), labels (`"G"`, `"H"`), `profile_id` (`"pedersen-vector/1"`), and every `basis_type_id_j`' "$f" >/dev/null || return 1
  grep_prose 'Integers (`j`, `ctr`, and `n`) are used as field elements directly' "$f" >/dev/null || return 1
}

encoding_probe() {
  local m="$WORK/encoding-mutant.md"
  check_encoding "$PROFILE" || { echo "positive encoding prose check failed"; return 0; }
  cp "$PROFILE" "$m"
  perl -0pi -e 's/len\(utf8\(s\)\) <= 31/len(utf8(s)) <= 32/' "$m"
  if check_encoding "$m"; then
    echo "encoding mutant unexpectedly passed"
    return 0
  fi
  echo "encoding mutant rejected after changing the 31-byte fail-closed bound"
  return 41
}

check_basis_formula() {
  local f="$1"
  grep_prose 'basis_commitment = Poseidon2( field_of("aac/vnet/1/basis"), field_of(profile_id), n, field_of(basis_type_id_0), ..., field_of(basis_type_id_{n-1}) )' "$f" >/dev/null || return 1
  grep_prose 'The list is ordered and `n` is explicit' "$f" >/dev/null || return 1
  grep_prose "A production target MAY replace this hash with the deployment's canonical 2/FACT encoding" "$f" >/dev/null || return 1
  grep_prose 'the target identity changes unless the replacement is already declared in its obligations digest' "$f" >/dev/null || return 1
}

basis_formula_probe() {
  local m="$WORK/basis-mutant.md"
  check_basis_formula "$PROFILE" || { echo "positive basis formula check failed"; return 0; }
  cp "$PROFILE" "$m"
  perl -0pi -e 's/field_of\(profile_id\), n,/field_of(profile_id),/' "$m"
  if check_basis_formula "$m"; then
    echo "basis formula mutant unexpectedly passed"
    return 0
  fi
  echo "basis formula mutant rejected after removing explicit n"
  return 42
}

check_canonical_y() {
  local f="$1"
  grep_prose 'The first `ctr` whose `rhs` is a quadratic residue is accepted' "$f" >/dev/null || return 1
  grep_prose 'The `y` coordinate is the even square root of `rhs`; if the square root has odd least significant bit, use `p - y`' "$f" >/dev/null || return 1
  grep_prose 'The resulting affine point is the generator' "$f" >/dev/null || return 1
}

canonical_y_probe() {
  local m="$WORK/canonical-y-mutant.md"
  check_canonical_y "$PROFILE" || { echo "positive canonical-y check failed"; return 0; }
  cp "$PROFILE" "$m"
  perl -0pi -e 's/even square root/odd square root/' "$m"
  if check_canonical_y "$m"; then
    echo "canonical-y mutant unexpectedly passed"
    return 0
  fi
  echo "canonical-y mutant rejected after changing even root to odd root"
  return 43
}

check_profile_id_lowercase() {
  local f="$1"
  grep_prose 'A target that adopts PEDERSEN-VECTOR/1 names this profile and its `profile_id` (`pedersen-vector/1`) in its declaration' "$f" >/dev/null || return 1
  ! grep_prose 'its `profile_id` (`PEDERSEN-VECTOR/1`)' "$f" >/dev/null
}

profile_id_probe() {
  local m="$WORK/profile-id-mutant.md"
  check_profile_id_lowercase "$PROFILE" || { echo "positive lowercase profile_id check failed"; return 0; }
  cp "$PROFILE" "$m"
  perl -0pi -e 's/its `profile_id`\s+\(`pedersen-vector\/1`\)/its `profile_id` (`PEDERSEN-VECTOR\/1`)/' "$m"
  if check_profile_id_lowercase "$m"; then
    echo "uppercase profile_id mutant unexpectedly passed"
    return 0
  fi
  echo "uppercase profile_id mutant rejected; §8 lowercase identity is pinned"
  return 44
}

check_seed_formula() {
  local f="$1"
  grep_prose 'seed(label, j) = Poseidon2( "aac/vnet/1", profile_id, basis_commitment, basis_type_id_j, label, j )' "$f" >/dev/null
}

seed_formula_probe() {
  local m="$WORK/seed-mutant.md"
  check_seed_formula "$PROFILE" || { echo "positive seed formula check failed"; return 0; }
  cp "$PROFILE" "$m"
  perl -0pi -e 's/basis_commitment,/n,/' "$m"
  if check_seed_formula "$m"; then
    echo "seed formula mutant unexpectedly passed"
    return 0
  fi
  echo "seed formula mutant rejected; prescribed seed text remains unchanged"
  return 45
}

resolve_nargo19() {
  local p
  for p in "${NARGO19_BIN:-}" "$ROOT/result/bin/nargo" "/nix/store/hgz7fp6br2721vh7c72bk0c9bwdz04ii-nargo-v1.0.0-beta.19/bin/nargo"; do
    [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

regenerate_vector() {
  local root="$1" out="$2" pkg nargo home execute_out
  pkg="$root/world-app/provekit-pedersen-vector-derivation"
  nargo="$(resolve_nargo19)" || { echo "nargo19 binary not available"; return 1; }
  home="$WORK/nargo-home"
  mkdir -p "$home"
  HOME="$home" "$nargo" --version > "$TRACES/t06-nargo-version.out" 2>&1 || return 1
  ( cd "$pkg" && HOME="$home" "$nargo" test --show-output ) > "$TRACES/t06-nargo-test.out" 2>&1 || return 1
  execute_out="$WORK/nargo-execute.out"
  ( cd "$pkg" && HOME="$home" "$nargo" execute "$WORK/pedersen-vector-derivation.gz" ) > "$execute_out" 2>&1 || return 1
  node "$pkg/render-vector.mjs" < "$execute_out" > "$out" || return 1
}

vector_probe() {
  local generated="$WORK/PEDERSEN-VECTOR-1.generated.json" corrupt="$WORK/PEDERSEN-VECTOR-1.corrupt.json"
  regenerate_vector "$STAGED" "$generated" || { echo "vector regeneration failed"; return 0; }
  cmp -s "$generated" "$VECTOR" || { echo "generated vector does not match staged vector"; diff -u "$VECTOR" "$generated" | head -80; return 0; }
  cp "$VECTOR" "$corrupt"
  perl -0pi -e 's/"accepted_ctr": 3/"accepted_ctr": 4/' "$corrupt"
  if cmp -s "$generated" "$corrupt"; then
    echo "corrupt vector mutant unexpectedly matched regenerated output"
    return 0
  fi
  echo "Noir harness regenerated PEDERSEN-VECTOR-1.json byte-identically; corrupt vector mutant rejected"
  return 46
}

check_honesty() {
  local profile="$1" vector="$2"
  grep_prose 'using the Noir stdlib Poseidon2 permutation, the same implementation family as the ProveKit VNET circuit' "$profile" >/dev/null || return 1
  grep_prose 'it is not yet an independent Poseidon2 implementation cross-check' "$profile" >/dev/null || return 1
  grep -Fq 'These vectors pin the PEDERSEN-VECTOR/1 derivation rule; they are not yet an independent Poseidon2 implementation cross-check.' "$vector" || return 1
  grep -Fq 'An independent Python Poseidon2 cross-check is intentionally queued as follow-up work.' "$vector" || return 1
}

honesty_probe() {
  local mp="$WORK/honesty-profile-mutant.md" mv="$WORK/honesty-vector-mutant.json"
  check_honesty "$PROFILE" "$VECTOR" || { echo "positive honesty clause check failed"; return 0; }
  cp "$PROFILE" "$mp"
  cp "$VECTOR" "$mv"
  perl -0pi -e 's/it is not yet an independent Poseidon2 implementation cross-check/it is independently cross-checked/' "$mp"
  perl -0pi -e 's/not yet an independent Poseidon2 implementation cross-check/independently cross-checked/' "$mv"
  if check_honesty "$mp" "$mv"; then
    echo "honesty-clause mutant unexpectedly passed"
    return 0
  fi
  echo "honesty-clause mutant rejected"
  return 47
}

queue_probe() {
  local q="$QUEUE" m="$WORK/QUEUE-duplicate-header.md" open_count resolved_count
  BOAT_ROOT="$STAGED" QUEUE_MD="$q" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t08-queue-lint.out" 2>&1 \
    || { echo "staged queue does not lint"; cat "$TRACES/t08-queue-lint.out"; return 0; }
  open_count="$(awk '$0 == "## Open" { c++ } END { print c + 0 }' "$q")"
  resolved_count="$(awk '$0 == "## Resolved" { c++ } END { print c + 0 }' "$q")"
  [[ "$open_count" == "1" && "$resolved_count" == "1" ]] || { echo "header count Open=$open_count Resolved=$resolved_count"; return 0; }
  grep_prose 'PEDERSEN-VECTOR/1 independent Poseidon2 cross-check' "$q" >/dev/null || { echo "follow-up open entry missing"; return 0; }
  grep_prose 'Resolves the cand-0092 obstruction' "$q" >/dev/null || { echo "cand-0092 resolved entry missing"; return 0; }
  ! grep_prose 'PEDERSEN-VECTOR/1 ProveKit generator pinning is underspecified' "$q" >/dev/null || { echo "cand-0092 obstruction still open"; return 0; }
  cp "$q" "$m"
  printf '\n## Open\n' >> "$m"
  if BOAT_ROOT="$STAGED" QUEUE_MD="$m" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t08-queue-dup-header.out" 2>&1; then
    echo "duplicate-header queue mutant unexpectedly passed"
    return 0
  fi
  echo "queue formation passes with one Open/Resolved pair; duplicate-header mutant rejected"
  return 48
}

run_failing_probe \
  t01-pinned-encoding \
  "field_of prose pins UTF-8 big-endian, <=31-byte fail-closed strings, no reduction, and integer fields; mutant rejected" \
  "pinned encoding probe did not reject its mutant" \
  encoding_probe

run_failing_probe \
  t02-basis-commitment \
  "basis_commitment formula pins ordered basis with explicit n and 2/FACT target-identity clause; mutant rejected" \
  "basis commitment probe did not reject its mutant" \
  basis_formula_probe

run_failing_probe \
  t03-canonical-y \
  "canonical-y prose pins first QR counter and even square root; mutant rejected" \
  "canonical-y probe did not reject its mutant" \
  canonical_y_probe

run_failing_probe \
  t04-profile-id-lowercase \
  "§8 profile_id remains lowercase pedersen-vector/1; uppercase mutant rejected" \
  "profile_id lowercase probe did not reject its mutant" \
  profile_id_probe

run_failing_probe \
  t05-seed-formula-unchanged \
  "prescribed seed formula text remains unchanged; mutant rejected" \
  "seed formula probe did not reject its mutant" \
  seed_formula_probe

run_failing_probe \
  t06-vectors-regenerate \
  "Noir derivation harness runs and regenerates PEDERSEN-VECTOR-1.json byte-identically; corrupt mutant rejected" \
  "vector regeneration probe did not reject its corrupt mutant" \
  vector_probe

run_failing_probe \
  t07-honesty-clause \
  "spec and vector carry the Noir-family/not-independent-cross-check honesty clause; mutant rejected" \
  "honesty clause probe did not reject its mutant" \
  honesty_probe

run_failing_probe \
  t08-queue-formation \
  "queue has one Open/Resolved header pair, resolves cand-0092, and opens the independent cross-check follow-up; duplicate-header mutant rejected" \
  "queue formation probe did not reject its duplicate-header mutant" \
  queue_probe

attest_tail "Complete PEDERSEN-VECTOR/1 generator-pinning profile: field_of encoding, basis commitment, canonical y, beta.19 Noir-generated vectors, honesty boundary, and cand-0092 queue resolution."
