# Threshold Brief: cand-0003-publish-specs

Generated: 2026-06-13T05:07:35Z
Status: validated
Intent: Publish the AAC RFC suite as a verified Paintgun spec-publication pack — an atlas.spec-publication.v1 manifest over sites/ledger/specs (11 documents), built and verified by paint spec-pack / verify-spec-pack. Even the spec publication is an attested pack.
Toolchain (pinned): nixpkgs_rev=ac62194c3917 flake_lock_sha256=e656d083e825bd60e35c27316fa623f45d838fedecc699a1725b2e9089cb075a

## Cargo (what lands if admitted)

- `cargo/publication.json` is NEW at `sites/ledger/publication.json`: 111 lines

## Witnessed behavioral delta (task: spec-pack + verify-spec-pack the AAC RFC suite over sites/ledger/specs (11 documents), completeness + broken-manifest rejection)

Evidence: ATTESTED (hash chain over scores, traces, harness verifies)

Evaluator verdict: **pass**

## Coverage honesty

The delta above is witnessed only over the evaluated cases. Behavior
changes outside that coverage are NOT excluded by this brief; the line
diff above bounds where they could hide. Raw evidence: `traces/`.

## What admit means

Admit records your threshold decision bound to this brief (sha256 in
DECISION). It does not land cargo: landing takes the receipted path.
