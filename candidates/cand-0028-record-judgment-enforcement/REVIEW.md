ReviewNote:
  candidate_id: cand-0028-record-judgment-enforcement
  reviewed_at: 2026-06-13T21:20:00Z
  brief_audited: |
    agree. BRIEF.md's cargo list matches the directory contents: 1 NEW checker
    (record-judgment-check.sh, 196 lines — verified by Read; the file ends at
    line 197 incl. trailing newline) + 8 NEW fixtures under fixtures/ +
    export-manifest.tsv replacement. Manifest delta verified by `diff` of
    live tools/schemas/export-manifest.tsv against the candidate's copy: -0/+9
    lines, the checker grouped with the other enforcers (after
    verdict-tripwire.sh, line 16) and the 8 record-* fixtures grouped
    immediately after the queue-* file fixtures (lines 50-57), preserving
    the kernel-manifest grouping discipline. Toolchain pin recorded.
  claims_verified:
    - claim: aac currently does NOT enforce premath.record-judgments.v0 ->
        evidence: tools/eval/evaluate-landed.sh:206-207 enrolls
        `run_suite record-judgments` guarded by
        `[[ -f "$ROOT/tools/record-judgment-check.sh" ]]`; `ls
        tools/record-judgment-check.sh` returns ENOENT in live aac ->
        guard is false, member silently skipped -> verdict: VERIFIED
    - claim: shipped checker is the boat kernel checker, ROOT-relative ->
        evidence: record-judgment-check.sh:15 sets
        `ROOT="${BOAT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"`,
        FIXTURE_DIR resolves under `$ROOT/sites/premath/fixtures`, STATEMENT
        under `$ROOT/sites/premath/statements/record-judgments-v0.md` -> runs
        identically in aac without modification -> verdict: VERIFIED
    - claim: the 8 fixtures are EXACTLY the checker's ALL_FIXTURES closure ->
        evidence: ALL_FIXTURES array at record-judgment-check.sh:165-174
        enumerates the same 8 basenames present under fixtures/ (verified by
        `ls fixtures/`) -> verdict: VERIFIED (perfect closure, no surplus,
        no missing)
    - claim: aac's sites/premath/statements/record-judgments-v0.md satisfies
        check_statement -> evidence: grepped each `require_contains` needle
        from check_statement against the live file — all 12 needles match
        (Statement id, Law: RJ-1.1..RJ-1.6, adjoint support is ABSENT, never
        executable authority, record-formation-incomplete, sigma-missing-
        witness, verifier_contract_violation, vocabulary-atom-failure) ->
        verdict: VERIFIED
    - claim: LANDING map provides every one of the 9 new entries -> evidence:
        LANDING enumerates checker + 8 fixtures + the manifest update; lines
        cross-check exactly with the +9 manifest delta -> verdict: VERIFIED
    - claim: evidence ATTESTED + reproducible -> evidence: ran
        `bash tools/eval/eval-check.sh candidates/cand-0028-... .` ->
        "REPRODUCED (pass attested, pass reproduced, evidence intact)"; all
        5 trace cases re-PASS (t01..t05); evidence restored byte-exact and
        attestation re-verified at ea3ea56ed887 -> verdict: VERIFIED
    - claim: enforcement is real, not vacuous (t04) -> evidence:
        traces/t04_enforcement_real.txt records rc=1 when a shipped fixture
        is corrupted; eval-self.sh harness re-confirmed it on fresh run ->
        verdict: VERIFIED
    - claim: deltas additive; statement not re-added; tools/loop untouched
        (t05) -> evidence: trace records "deltas additive (-0/+9); statement
        single; tools/loop untouched"; LANDING contains no entry for
        sites/premath/statements/record-judgments-v0.md or tools/loop ->
        verdict: VERIFIED
    - claim: individual-fixture lines are correct, not a dir entry ->
        evidence: aac's manifest already enumerates queue-clean-pass.md,
        queue-bad-status-fail.md, queue-misfiled-report.md individually
        (lines 47-49); sites/premath/fixtures/ in live aac also contains
        the loop-model/ subdir which is enrolled as its own `dir` entry.
        A `dir sites/premath/fixtures/` line would (a) violate the
        established file-enumeration convention for kernel fixtures and
        (b) silently traveler any future aac-sovereign fixtures dropped
        into that directory (sigpi-*, cwf-*, vocab-* candidates etc) into
        the kernel manifest — i.e., it would drag aac's soul into the
        kernel, the very anti-pattern OB-1.3 / boat.export.v0 guards
        against. The +9 individual lines are the right shape ->
        verdict: VERIFIED
  concerns: none
  questions_asked: |
    The operator directive supplied four self-verification questions; all
    were resolved affirmatively, grounded in files I read:
    - "delta is -0/+9 (1 checker + 8 record-* fixtures)?" -> YES, confirmed
      by direct `diff` of tools/schemas/export-manifest.tsv vs candidate
      copy: 1 insertion at line 15 (checker) + 8 insertions at lines 48-57
      (fixtures). Nothing else changed.
    - "aac currently does NOT enforce record-judgments?" -> YES, confirmed
      from tools/eval/evaluate-landed.sh:206-207 (the guarded enrollment)
      and the absence of tools/record-judgment-check.sh on disk.
    - "shipped checker is kernel-pattern, fixtures are exact ALL_FIXTURES
      closure, aac's statement satisfies check_statement?" -> YES on all
      three; ALL_FIXTURES closure is a one-to-one match with the shipped
      fixtures/ directory listing, and every needle in check_statement
      is grep-confirmed in aac's live statement.
    - "safe re-run with eval-check.sh reproduces?" -> YES; harness reports
      "REPRODUCED (pass attested, pass reproduced, evidence intact)";
      attestation ea3ea56ed887 verified both pre- and post-replay.
    - "is shipping 8 individual fixture lines (vs a dir entry) the right
      shape?" -> YES; a dir entry would conflict with the existing
      file-enumeration convention (queue-* are individual) and would
      silently drag any future aac-sovereign fixtures into the kernel
      export. Individual lines keep the kernel set hermetic.
  recommendation: admit
