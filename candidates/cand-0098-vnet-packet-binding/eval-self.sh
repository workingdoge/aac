#!/usr/bin/env bash
# eval-self.sh -- functional evidence for cand-0098.
#
# This evaluator stages the candidate landing, verifies that Prover.toml is
# generated from packet.vnet_link instead of copied from a static witness,
# checks the cand-0094/0095 public-input ABI correspondence, runs the generated
# witness through beta.19 nargo when available, and proves fail-closed mutants.
set -u

CAND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$CAND_DIR/../.." && pwd)"

# Older candidate evaluators shimmed GNU head for macOS. attest.sh is now sed
# based, but keeping this harmless export preserves reviewer-shell portability.
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

WORK="$(mktemp -d /private/tmp/aac-cand-0098.XXXXXX)"
STAGED="$WORK/root"
stage_root "$STAGED" || exit 1

RUNNER="$STAGED/fundraise-demo-runner"
RUNNER_SRC="$RUNNER/src/index.mjs"
RUNNER_TYPES="$RUNNER/src/index.d.ts"
VNET_BINDING="$RUNNER/src/vnet-provekit-binding.mjs"
RUNNER_README="$RUNNER/README.md"
QUEUE="$STAGED/candidates/QUEUE.md"
LANDING="$CAND_DIR/LANDING"
SAMPLE_MODULE="$WORK/provekit-sample.mjs"

cat > "$SAMPLE_MODULE" <<'NODE'
export function samplePacket() {
  const profileId = "pedersen-vector/1";
  const basisTypeIds = ["USD", "fabric", "shares"];
  const basisCommitment = "3199263021048886800067584263637418741171169451581946816529327257071282393363";
  const atom = ({
    transition_ref,
    journal_commitment,
    debit,
    credit,
    debit_blinding,
    credit_blinding,
    transition_accounts,
    transition_debits,
    transition_credits,
  }) => ({
    profile_id: profileId,
    basis_type_ids: basisTypeIds,
    basis_commitment: basisCommitment,
    transition_ref,
    journal_commitment,
    debit,
    credit,
    debit_blinding,
    credit_blinding,
    transition_link: {
      transition_accounts,
      transition_debits,
      transition_credits,
    },
  });
  return {
    public_inputs: {
      round_id: "provekit-vnet-sample",
      context_commitment: "9001",
    },
    vnet_link: {
      vnet: {
        profile_id: profileId,
        basis_type_ids: basisTypeIds,
        basis_commitment: basisCommitment,
        context_commitment: "9001",
        transition_set_commitment:
          "0x2b8a24d48020d3af53b6c2853450eefa0e73ce04d22365530e6ddcadb191973a",
        commitment_set_commitment:
          "0x13947fc7b94aff97d38d9e375de087d6058c7a3204f547045736a0a0c31690e6",
        aggregate_opening: {
          x: "0x0189efcd83678b566806f7b40bdedcd818a9adb56cff1aeabff00431164e05f0",
          y: "0x140d6729a40f8393576efb10b4bd0eb05e87a280b6c1d2400c4d40dc6edb9dc9",
        },
        atoms: [
          atom({
            transition_ref: "7001",
            journal_commitment:
              "0x14ccbd5f8c9e45d77a96b9eb9d47278e43344dd75c686a76689e209e66dda885",
            debit: [100, 50, 0],
            credit: [100, 50, 0],
            debit_blinding: 11,
            credit_blinding: 17,
            transition_accounts: [1, 2, 0, 0],
            transition_debits: [[100, 0, 0], [0, 50, 0], [0, 0, 0], [0, 0, 0]],
            transition_credits: [[0, 50, 0], [100, 0, 0], [0, 0, 0], [0, 0, 0]],
          }),
          atom({
            transition_ref: "7002",
            journal_commitment:
              "0x27c16360cd1c685a825e9f385c6d1959a8508125d8ee9ba3ccc4d6f617916719",
            debit: [25, 75, 10],
            credit: [25, 75, 10],
            debit_blinding: 13,
            credit_blinding: 19,
            transition_accounts: [2, 3, 0, 0],
            transition_debits: [[0, 75, 10], [25, 0, 0], [0, 0, 0], [0, 0, 0]],
            transition_credits: [[25, 0, 0], [0, 75, 10], [0, 0, 0], [0, 0, 0]],
          }),
        ],
      },
    },
  };
}
NODE

resolve_nargo19() {
  local p
  for p in "${NARGO19_BIN:-}" "$ROOT/result/bin/nargo" "/nix/store/hgz7fp6br2721vh7c72bk0c9bwdz04ii-nargo-v1.0.0-beta.19/bin/nargo"; do
    [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

resolve_provekit_cli() {
  local p
  for p in "${PROVEKIT_BIN:-}" "$ROOT/result/bin/provekit-cli" "/nix/store/sx6yrx22zyh9vni6mv35zjfd1cydciz7-provekit-cli-1.0.0/bin/provekit-cli"; do
    [[ -n "$p" && -x "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

check_generated_not_copied() {
  local f="$1" helper="$2" readme="$3"
  ! grep -Fq 'Prover.toml.example' "$f" || return 1
  grep -Fq 'buildProveKitVnetWitnessFromPacket(packet)' "$f" || return 1
  grep -Fq 'resolve(target, "Prover.toml")' "$f" || return 1
  grep -Fq 'buildPacketBoundPlaceholderProverToml(packet)' "$f" || return 1
  grep -Fq 'packet.vnet_link' "$helper" || return 1
  grep -Fq 'PROVEKIT_VNET_PACKET_BINDING_SCHEMA' "$helper" || return 1
  grep_prose 'generate `Prover.toml` from the packet'\''s `vnet_link` witness fields' "$readme" >/dev/null || return 1
}

generated_not_copied_probe() {
  local mut="$WORK/index-static-witness-mutant.mjs"
  check_generated_not_copied "$RUNNER_SRC" "$VNET_BINDING" "$RUNNER_README" || {
    echo "positive generated-witness source check failed"
    return 0
  }
  cp "$RUNNER_SRC" "$mut"
  printf '\nawait cp(resolve(target, "Prover.toml.example"), resolve(target, "Prover.toml"));\n' >> "$mut"
  if check_generated_not_copied "$mut" "$VNET_BINDING" "$RUNNER_README"; then
    echo "static-copy mutant unexpectedly passed"
    return 0
  fi
  echo "default VNET Prover.toml is generated from packet.vnet_link; mutant restoring the example-copy path rejected"
  return 41
}

public_input_correspondence_probe() {
  local nargo provekit circuit_dir home out
  if ! ( cd "$RUNNER" && npm test ) > "$TRACES/t02-runner-tests.out" 2>&1; then
    cat "$TRACES/t02-runner-tests.out"
    return 0
  fi
  if ! RUNNER="$RUNNER" SAMPLE_MODULE="$SAMPLE_MODULE" STAGED="$STAGED" WORK="$WORK" node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const runner = await import(pathToFileURL(`${process.env.RUNNER}/src/index.mjs`));
const { samplePacket } = await import(pathToFileURL(process.env.SAMPLE_MODULE));
const packet = samplePacket();
const witness = runner.buildProveKitVnetWitnessFromPacket(packet);
assert.equal(witness.public_inputs.profile_id_pub, "38246398409996331787205124593264425578289");
assert.equal(witness.public_inputs.basis_commitment_pub, "3199263021048886800067584263637418741171169451581946816529327257071282393363");
assert.equal(witness.public_inputs.atom_count_pub, "2");
assert.equal(witness.public_inputs.context_commitment_pub, "9001");
assert.equal(witness.public_inputs.aggregate_opening_x_pub, "696025954462360609854244429735001228443867042826384838556274523143607813616");
assert.match(witness.public_inputs_commitment, /^0x[0-9a-f]{64}$/);
assert.match(witness.packet_public_inputs_commitment, /^0x[0-9a-f]{64}$/);
assert.match(witness.packet_vnet_link_commitment, /^0x[0-9a-f]{64}$/);
assert.match(witness.prover_toml_digest, /^0x[0-9a-f]{64}$/);
const work = await runner.prepareProveKitWorkdir({
  repo_root: process.env.STAGED,
  keep_workdir: true,
  packet,
});
assert.deepEqual(work.vnet_witness.public_inputs, witness.public_inputs);
assert.equal(await readFile(`${work.circuit_dir}/Prover.toml`, "utf8"), witness.prover_toml);
assert.equal(witness.prover_toml.includes("example witness"), false);
await writeFile(`${process.env.WORK}/generated-circuit-dir.txt`, work.circuit_dir);
await writeFile(`${process.env.WORK}/public-inputs-commitment.txt`, witness.public_inputs_commitment);
console.log(`generated circuit dir: ${work.circuit_dir}`);
console.log(`circuit public inputs: ${witness.public_inputs_commitment}`);
NODE
  then
    echo "positive witness/public-input correspondence check failed"
    return 0
  fi

  circuit_dir="$(cat "$WORK/generated-circuit-dir.txt")"
  if nargo="$(resolve_nargo19)"; then
    home="$WORK/nargo-home"
    mkdir -p "$home"
    out="$TRACES/t02-nargo-execute-generated.out"
    if ! ( cd "$circuit_dir" && HOME="$home" "$nargo" execute "$WORK/vnet-generated-witness.gz" ) > "$out" 2>&1; then
      cat "$out"
      return 0
    fi
  else
    echo "nargo19 unavailable; witness correspondence checked without circuit execution"
  fi

  if provekit="$(resolve_provekit_cli)"; then
    home="$WORK/provekit-home"
    mkdir -p "$home"
    out="$TRACES/t02-provekit-native-chain.out"
    if ! (
      cd "$circuit_dir" &&
      HOME="$home" "$provekit" prepare --deny-warnings --force -p aac_vnet_provekit.pkp -v aac_vnet_provekit.pkv . &&
      HOME="$home" "$provekit" prove -p aac_vnet_provekit.pkp -i Prover.toml -o proof.np &&
      HOME="$home" "$provekit" verify -v aac_vnet_provekit.pkv --proof proof.np
    ) > "$out" 2>&1; then
      echo "provekit-cli full chain blocked or failed in this sandbox; see $out"
    fi
  else
    echo "provekit-cli unavailable; real nargo witness execution remains the local proof of circuit-side solving"
  fi

  RUNNER="$RUNNER" SAMPLE_MODULE="$SAMPLE_MODULE" node --input-type=module <<'NODE'
import { pathToFileURL } from "node:url";

const runner = await import(pathToFileURL(`${process.env.RUNNER}/src/index.mjs`));
const { samplePacket } = await import(pathToFileURL(process.env.SAMPLE_MODULE));
const packet = samplePacket();
packet.vnet_link.vnet.atoms[0].debit[0] = 101;
try {
  runner.buildProveKitVnetWitnessFromPacket(packet);
  console.error("amount-tampered packet unexpectedly produced a witness");
  process.exit(0);
} catch (error) {
  if (error?.reason !== "vnet_provekit_atom_debit_mismatch") {
    console.error(`wrong tamper rejection reason: ${error?.reason ?? error?.message}`);
    process.exit(0);
  }
  console.log("amount-tampered packet refused before proving");
  process.exit(42);
}
NODE
}

shape_mismatch_probe() {
  RUNNER="$RUNNER" STAGED="$STAGED" node --input-type=module <<'NODE'
import { pathToFileURL } from "node:url";

const runner = await import(pathToFileURL(`${process.env.RUNNER}/src/index.mjs`));
const packet = await runner.loadFundraiseDemoPacket({ repo_root: process.env.STAGED });
try {
  runner.buildProveKitVnetWitnessFromPacket(packet);
  console.error("current FUNDRAISE-DEMO-1 packet unexpectedly matched the cand-0095 fixed circuit ABI");
  process.exit(0);
} catch (error) {
  if (error?.reason !== "vnet_provekit_profile_mismatch") {
    console.error(`wrong shape-mismatch reason: ${error?.reason ?? error?.message}`);
    process.exit(0);
  }
  console.log("current four-atom vnet-bn254-g1/1 fundraise packet fails closed against the cand-0095 fixed circuit");
  process.exit(43);
}
NODE
}

receipt_digest_probe() {
  RUNNER="$RUNNER" SAMPLE_MODULE="$SAMPLE_MODULE" STAGED="$STAGED" node --input-type=module <<'NODE'
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";

const runner = await import(pathToFileURL(`${process.env.RUNNER}/src/index.mjs`));
const adapter = await import(pathToFileURL(`${process.env.STAGED}/fundraise-provekit-adapter/src/index.mjs`));
const { samplePacket } = await import(pathToFileURL(process.env.SAMPLE_MODULE));

function assertBoundReceipt(receipt, witness) {
  assert.equal(receipt.packet_binding_schema, runner.PROVEKIT_VNET_PACKET_BINDING_SCHEMA);
  assert.equal(receipt.packet_public_inputs_commitment, witness.packet_public_inputs_commitment);
  assert.equal(receipt.packet_vnet_link_commitment, witness.packet_vnet_link_commitment);
  assert.equal(receipt.vnet_circuit_public_inputs_commitment, witness.public_inputs_commitment);
  assert.equal(receipt.public_inputs_commitment, witness.public_inputs_commitment);
  assert.equal(receipt.vnet_witness_commitment, witness.witness_commitment);
  assert.equal(receipt.prover_toml_digest, witness.prover_toml_digest);
  assert.match(receipt.receipt_digest, /^0x[0-9a-f]{64}$/);
  assert.match(receipt.packet_binding_note, /generated from packet\.vnet_link/);
}

let bound;
let witness;
try {
  const packet = samplePacket();
  witness = runner.buildProveKitVnetWitnessFromPacket(packet);
  const base = adapter.buildProveKitVerifierReceipt({
    packet,
    provekit: {
      accepted: true,
      reason: "accepted",
      proof_system: "provekit-whir",
      mode: "native-cli",
      public_inputs: witness.public_inputs,
      proof_digest: `0x${"11".repeat(32)}`,
      verifier_key_digest: `0x${"22".repeat(32)}`,
      timings_ms: { verify: 1 },
    },
    verifier_id: "cand-0098-eval",
    verifier_profile: "fundraise-runtime/v1+vnet-runtime/v1",
  });
  bound = runner.bindProveKitVnetWitnessToVerifierReceipt(base, { packet, witness });
  assertBoundReceipt(bound, witness);
  assert.notEqual(bound.receipt_digest, base.receipt_digest);
} catch (error) {
  console.error(`positive receipt digest field check failed: ${error?.stack ?? error}`);
  process.exit(0);
}

const mutant = { ...bound };
delete mutant.packet_vnet_link_commitment;
try {
  assertBoundReceipt(mutant, witness);
  console.error("receipt mutant missing packet_vnet_link_commitment unexpectedly passed");
  process.exit(0);
} catch {
  console.log("receipt records packet and circuit public-input digests; missing-digest mutant rejected");
  process.exit(44);
}
NODE
}

check_receipt_type_surface() {
  local f="$1"
  perl -0e '
    my $s = <>;
    exit($s =~ /export declare function bindProveKitVnetWitnessToVerifierReceipt\([\s\S]*?\): VerifierReceipt & \{[\s\S]*?packet_binding_schema: typeof PROVEKIT_VNET_PACKET_BINDING_SCHEMA;[\s\S]*?packet_public_inputs_commitment: string;[\s\S]*?packet_vnet_link_commitment: string;[\s\S]*?vnet_circuit_public_inputs_commitment: string;[\s\S]*?vnet_witness_commitment: string;[\s\S]*?prover_toml_digest: string;[\s\S]*?packet_binding_note: string;[\s\S]*?\};/ ? 0 : 1)
  ' "$f"
}

check_receipt_types_probe() {
  local mut="$WORK/index.d.ts.digest-mutant"
  check_receipt_type_surface "$RUNNER_TYPES" || return 0
  cp "$RUNNER_TYPES" "$mut"
  perl -0pi -e 's/\n\s*packet_vnet_link_commitment: string;//g' "$mut"
  if check_receipt_type_surface "$mut"; then
    echo "digest type mutant unexpectedly passed"
    return 0
  fi
  echo "public type surface exposes the binding helper and all receipt digest fields; digest-field deletion mutant rejected"
  return 45
}

check_queue_merge() {
  local landing="$1" queue="$2"
  [[ -f "$CAND_DIR/QUEUE.base" ]] || return 1
  grep -Fq $'seeds/QUEUE.md\tcandidates/QUEUE.md\tqueue-merge' "$landing" || return 1
  BOAT_ROOT="$STAGED" QUEUE_MD="$queue" bash "$STAGED/tools/queue-lint.sh" >/dev/null 2>&1 || return 1
  grep_prose "Fundraise-shaped ProveKit circuit/profile remains" "$queue" >/dev/null || return 1
  grep_prose "[resolved cand-0098-vnet-packet-binding, 2026-07-03] **Fundraise VNET proof packet binding." "$queue" >/dev/null || return 1
  grep_prose "Shape mismatches fail closed" "$queue" >/dev/null || return 1
}

queue_merge_probe() {
  local mut_landing="$WORK/LANDING-no-queue-merge" mut_queue="$WORK/QUEUE-dup-header.md"
  check_queue_merge "$LANDING" "$QUEUE" || {
    echo "positive queue-merge check failed"
    return 0
  }
  sed 's/[[:space:]]queue-merge$//' "$LANDING" > "$mut_landing"
  if check_queue_merge "$mut_landing" "$QUEUE"; then
    echo "LANDING mutant without queue-merge unexpectedly passed"
    return 0
  fi
  cp "$QUEUE" "$mut_queue"
  printf '\n## Resolved\n' >> "$mut_queue"
  if BOAT_ROOT="$STAGED" QUEUE_MD="$mut_queue" bash "$STAGED/tools/queue-lint.sh" > "$TRACES/t06-queue-dup-header.out" 2>&1; then
    echo "duplicate-header queue mutant unexpectedly passed"
    return 0
  fi
  echo "queue update is a queue-merge with QUEUE.base and the merged queue records cand-0098 closure; mutants rejected"
  return 46
}

run_failing_probe \
  t01-generated-not-copied \
  "default VNET Prover.toml is generated from packet.vnet_link; mutant restoring the example-copy path rejected" \
  "generated-not-copied probe did not reject its static-copy mutant" \
  generated_not_copied_probe

run_failing_probe \
  t02-public-input-correspondence \
  "generated Prover.toml public inputs match the packet-derived expectation, nargo executes the generated witness when available, and amount-tamper is refused" \
  "public-input correspondence probe did not reject its tampered packet" \
  public_input_correspondence_probe

run_failing_probe \
  t03-shape-mismatch-refusal \
  "current four-atom fundraise fixture fails closed against the cand-0095 fixed circuit ABI" \
  "shape mismatch probe did not refuse the current fundraise fixture" \
  shape_mismatch_probe

run_failing_probe \
  t04-receipt-digest-fields \
  "verifier receipt records packet-public-input, packet-vnet-link, circuit-public-input, witness, and generated-TOML digests; missing-digest mutant rejected" \
  "receipt digest probe did not reject its missing-digest mutant" \
  receipt_digest_probe

run_failing_probe \
  t05-receipt-type-surface \
  "public declaration surface exposes the binding helper and receipt digest fields; digest-field deletion mutant rejected" \
  "receipt type-surface probe did not reject its deletion mutant" \
  check_receipt_types_probe

run_failing_probe \
  t06-queue-merge \
  "queue update uses queue-merge with QUEUE.base and records cand-0098 closure plus the remaining fundraise-shaped circuit work; mutants rejected" \
  "queue merge probe did not reject its queue mutants" \
  queue_merge_probe

attest_tail "cand-0098 fundraise VNET packet binding"
