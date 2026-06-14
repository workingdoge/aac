ReviewNote:
  candidate_id: cand-0033-kernel-boundary-law
  reviewed_at: 2026-06-14T02:13:01Z
  brief_audited: |
    agree. RE-REVIEW after the transform round; both prior findings CLOSED.

    - B1 CLOSED: BRIEF.md:10 now states the checker is "91 lines"; `wc -l` of
      cargo/tools/kernel-boundary-check.sh = 91 (4362 bytes). EXACT match. The
      prior round's stale "82" (file was then 86) was regenerated; the brief now
      tracks the landed body. Both the brief's stated count and the cargo agree.
    - M4 CLOSED: BRIEF.md:11 "+2/-0 lines vs live" still holds (diff below).
    - AGREE: evaluate-landed.sh delta is exactly +2/-0 -- `diff live cargo`
      yields only `209a210,211` adding the two-line [[ -f ]]-guarded
      kernel-boundary suite member (cargo evaluate-landed.sh:210-211), nothing
      else touched.
    - AGREE: KERNEL = {pacioli,hash,ledger,transition,nullify} and APP =
      {rulebook,receipt,event-complete} match the live circuits/ workspace
      (`ls circuits/`: event-complete, hash, ledger, nullify, pacioli, receipt,
      rulebook, transition + Nargo.toml).
    - AGREE: "checker green on the live post-cand-0032 tree; a manifest-dep
      mutant AND a use-import mutant both refused; enrollment present" -- all
      independently reproduced (claims below). The Coverage-honesty framing
      (BRIEF.md:19-23) is accurate; the only behavior change is the two named
      cargo files.

  claims_verified: |
    1. eval-check REPRODUCED ->
       `bash tools/eval/eval-check.sh candidates/cand-0033-kernel-boundary-law $(pwd)`
       -> "REPRODUCED (pass attested, pass reproduced, evidence intact)",
       attestation 440061c5e073 verified twice, evidence restored byte-exact,
       harness rc=0, exit 0. VERIFIED.

    2. CLEAN on live, ZERO stderr ->
       `BOAT_ROOT=<root> KBC_CIRCUITS=<root>/circuits bash <cargo checker> 2>&1`
       -> "kernel-boundary-check: ok (5 kernel crates depend only on kernel
       crates)", exit 0, ZERO stderr. No `local: can only be used in a function`:
       all three `local` uses are inside functions in_kernel/refuse
       (checker:39,43,45). `bash -n` syntax OK. VERIFIED.

    3. B1 FIX -- BRIEF line count now matches body. BRIEF.md:10 = "91 lines";
       `wc -l` checker = 91. EXACT. B1 CLOSED. VERIFIED.

    4. M4 FIX (key-order-independent extraction) -- THE CENTRAL RE-REVIEW CLAIM.
       My OWN reordered-key mutant: copied circuits to /tmp/kbc-mutant-m4, added
       to transition/[dependencies] a line with `path` NOT first:
       `aliased = { tag = "v1", path = "../rulebook" }`. Checker against it
       (KBC_CIRCUITS=mutant, BOAT_ROOT=worktree) -> REFUSED, **exit 1**, typed
       witness tokenPath "transition.Nargo.toml.rulebook", reason "kernel crate
       'transition' depends on non-kernel crate 'rulebook' (path '../rulebook')",
       real witnessId minted (w1_uat6f5h3rku8...). The extraction (checker:67-74)
       is genuinely key-order-independent and comment-safe:
         grep -vE '^[[:space:]]*#'   (checker:72) strips full-comment lines
         grep -oE 'path[[:space:]]*=[[:space:]]*"[^"]*"'  (checker:73) matches the
           `path = "..."` field WHEREVER it sits in the inline table
         sed -E 's/.*"([^"]*)".*/\1/'  (checker:74) takes that match's value
       then basename (checker:69) resolves the TARGET dir and in_kernel keys on
       it. Direct pipeline demo on a crafted manifest with a commented EVIL dep,
       a reordered-key rulebook dep, a mypath line, and a legit hash dep emitted
       exactly: ../rulebook, ../X, ../hash -- comment stripped, reorder caught,
       legit preserved. M4 CLOSED. VERIFIED.

    5. Non-vacuity unbroken (all REFUSED exit 1) ->
       (a) alias path-first S1 vector: transition pacioli->../receipt -> exit 1,
           tokenPath "transition.Nargo.toml.receipt", witnessId
           w1_5678l4k37f18... -- IDENTICAL to the attested trace, confirming the
           evidence was generated against the FIXED checker.
       (b) honest app dep: receipt={path=../receipt} on ledger -> exit 1,
           "ledger.Nargo.toml.receipt".
       (c) use-import: `use receipt::Receipt;` in hash/src/lib.nr -> exit 1,
           "hash.lib.nr.receipt".
       (d) hyphenated app crate aliased under kernel name, path not first:
           ledger hash-alias->../event-complete -> exit 1,
           "ledger.Nargo.toml.event-complete".
       (e) two reordered app deps on nullify (receipt + rulebook) -> exit 1,
           BOTH named (multiple-dep handling correct).
       (f) nested+trailing-slash app path (../foo/receipt/) -> exit 1, basename
           correctly "receipt". VERIFIED.

    6. Fix did NOT weaken legitimate deps ->
       - clean live tree -> exit 0 (claim 2).
       - reordered-key LEGIT kernel dep `extra = { tag="v1", path="../hash" }`
         on pacioli -> exit 0 (accepted).
       - `path=../receipt, tag=../hash` on one line -> names "receipt" (the path
         value, not the tag value) exit 1: the grep anchors on `path =` and
         captures only its own quoted value; a later quoted value cannot hijack.
       - live 5 kernel manifests: deps are ../hash, ../pacioli, ../ledger only
         (ledger->hash; transition->pacioli,ledger,hash; nullify->hash;
         pacioli/hash->none) -> all basenames in KERNEL -> accepted. VERIFIED.

    7. Enrollment [[ -f ]]-guarded, +2/-0, ROOT-relative ->
       cargo evaluate-landed.sh:210-211:
         `[[ -f "$ROOT/tools/kernel-boundary-check.sh" ]] \`
         `  && run_suite kernel-boundary bash tools/kernel-boundary-check.sh`
       diff vs live = only `209a210,211` (2 added, 0 removed). Live
       tools/kernel-boundary-check.sh ABSENT pre-land (`ls` -> No such file) so
       it lands via cargo and the guard fires post-land on the source instance --
       no cand-0028 silent-skip footgun (the guarded artifact IS this cargo, and
       it is enrolled in the same export-course shape as sibling suites).
       VERIFIED.

    8. Read-only / ROOT-relative -> empirical: tree-hash (sha256 over all files)
       of a mutated scratch circuits/ is BYTE-IDENTICAL before vs after a
       VIOLATING run (exit 1): 91a1b723...==91a1b723... ROOT/CIRCUITS resolve
       from $BOAT_ROOT/$KBC_CIRCUITS (checker:28-29). Missing-substrate path
       (KBC_CIRCUITS=/nonexistent) -> exit 66 with stderr notice, as documented.
       VERIFIED.

    9. Non-vacuity (discrimination) -> exit 0 on clean tree, exit 1 on every
       mutant above; not an always-fail. VERIFIED.

  concerns: |
    - B1: CLOSED (was minor/brief-mismatch). BRIEF.md:10 = "91 lines" == `wc -l`
      = 91. No remaining discrepancy.

    - M4: CLOSED (was minor->notable, the key-order manifest-alone evasion). The
      extraction at checker:67-74 was rewritten from the old
      `\{ *path`-anchored awk to a `path[[:space:]]*=`-anywhere grep over
      comment-stripped lines, and is now key-order-independent. My reordered-key
      mutant (`path` not first) exits 1 and names the real target. The
      "Sound via the manifest alone" wording (checker:18, BRIEF intent) is no
      longer falsified by key reordering.

    - C3 (very minor, NEW, strictly fail-CLOSED -- note only, NOT blocking):
      because the new extractor greps `path[[:space:]]*=` as a substring, a key
      that ENDS in `path` matches too -- e.g. `mypath = "../receipt"` (not a real
      Nargo dependency form) triggers a violation (exit 1) on the value
      `../receipt` (path:73 captures the quoted value). This can only ever
      OVER-refuse (a spurious key with a quoted `../X` value); it can never let an
      app dep through, so it does not weaken soundness. The only real-world way to
      hit it is to write a non-standard key like `mypath`/`devpath` carrying a
      quoted relative path, which Nargo would not parse as a dep anyway. Severity
      very minor, fail-closed, note only.

    - C1 (very minor, pre-existing, NOT a regression): a path whose basename
      collides with a kernel name but whose real dir is elsewhere
      (`hash = { path = "../evil/hash" }`) passes (basename "hash" is kernel).
      Dual of the old blind spot; the basename change neither introduced nor
      closed it; the workspace already holds the real hash. Note only.

    - C2 (very minor, pre-existing): git/registry source deps with no `path` key
      (`evil = { git = "..." }`) are skipped (exit 0; reproduced). In-workspace
      app crates are path-referenced, so not a practical hole for the documented
      seam. Note only.

    - Carried-forward minors from the doctrine (defense-in-depth `use` scan),
      re-noted, none blocking: block-comment `use` could false-positive
      (fail-closed); non-recursive src/*.nr glob (no live kernel submodules);
      hyphenated .nr basename appears unescaped in tokenPath JSON but is a
      benign label, not a Noir module name. None blocking; the manifest guard is
      the primary law and it is sound for conventional manifests.

  questions_asked: |
    Operator's directed re-review probes, grounded:
    - B1 CLOSED: BRIEF.md:10 "91 lines" == `wc -l` checker = 91 (exact).
    - M4 CLOSED: my OWN reordered-key mutant (`aliased = { tag = "v1",
      path = "../rulebook" }`, path NOT first) -> checker exit 1, typed witness
      naming `rulebook`, real witnessId minted. Extraction (checker:67-74) is
      key-order-independent (grep `path =` anywhere) AND comment-safe (grep -vE
      strips `#` lines) -- both confirmed by direct pipeline demo.
    - eval-check REPRODUCED (claim 1); CLEAN live exit 0 ZERO stderr, no `local`
      error (claim 2).
    - Non-vacuity unbroken: alias path-first / honest dep / use-import / hyphen
      alias / double-dep / nested-trailing-slash all REFUSED exit 1 (claim 5).
    - Fix did not weaken: reordered-key LEGIT kernel dep accepted; path-value
      precedence correct; live 5 kernel manifests pass (claim 6).
    - [[ -f ]]-enrolled +2/-0 ROOT-relative; read-only (tree byte-identical
      after violating run); exit 66 on missing substrate (claims 7-8).
    - NEW issue from the grep|sed change: only C3, a `mypath`-style substring
      OVER-match that is strictly fail-closed (can only over-refuse). No
      false-accept regression. Comment lines, empty [dependencies], multiple
      deps, odd path chars all handled.

  recommendation: admit
