ReviewNote:
  candidate_id: cand-0029-queue-archive
  reviewed_at: 2026-06-13T21:35:00Z
  brief_audited: agree — BRIEF.md claims "queue-archive.sh NEW at tools/queue-archive.sh (173 lines)" and "export-manifest.tsv +1/-0 vs live". Verified: `wc -l candidates/cand-0029-queue-archive/queue-archive.sh` = 173; `diff tools/schemas/export-manifest.tsv candidates/cand-0029-queue-archive/export-manifest.tsv` = single addition `file\ttools/queue-archive.sh` at line 14 (exact -0/+1). Witnessed task narrative matches scores.json (cases=4, passed=4, verdict=pass) and the four trace files (t01..t04).
  claims_verified:
    - "built from post-cand-0028 base, record-judgments +9 preserved" -> candidates/cand-0029-queue-archive/export-manifest.tsv -> VERIFIED (grep finds `tools/record-judgment-check.sh` present; not clobbered)
    - "delta is -0/+1 manifest, tools/loop untouched" -> diff against tools/schemas/export-manifest.tsv -> VERIFIED (single + line, no loop change)
    - "mutates only candidates/QUEUE.md and candidates/QUEUE-archive.md, writes to temps then os.replace" -> candidates/cand-0029-queue-archive/queue-archive.sh L144-149 -> VERIFIED (only two `.tmp` writes + os.replace; no other fs writes)
    - "line-multiset conservation safety check" -> queue-archive.sh L101-108 -> VERIFIED (sorted(out+moved_lines) != sorted(lines) -> SAFETY FAIL, nothing written)
    - "refuse-rather-than-fragment on column-0 '## ' inside resolved body" -> queue-archive.sh L86-89 -> VERIFIED (early sys.exit before any write)
    - "candidate STORE never touched" -> full read of queue-archive.sh -> VERIFIED (no path operations outside QUEUE_MD/ARCHIVE_MD args)
    - "check is read-only, exit 0 always" -> queue-archive.sh L157-167 -> VERIFIED (only `bash $LIB parse` + awk/grep counts + printf; no warning-driven exit; warning goes to stderr only)
    - "only dependency is tools/queue-lib.sh, already in aac" -> queue-archive.sh L32,37 + `ls tools/queue-lib.sh` -> VERIFIED (LIB path; aac repo has tools/queue-lib.sh present)
    - "NOT enrolled in evaluate-landed (hygiene tool, manually invoked)" -> tools/eval/evaluate-landed.sh -> VERIFIED (grep -c queue-archive = 0; record-judgment-check IS enrolled at line referencing `tools/record-judgment-check.sh --all`)
    - "attested evidence reproduces" -> bash tools/eval/eval-check.sh candidates/cand-0029-queue-archive /Users/arj/irai/aac -> VERIFIED ("REPRODUCED (pass attested, pass reproduced, evidence intact)"; attest verified 38dc0040eada twice; all four traces PASS on fresh run)
  concerns: none — script is defensive (set -u, explicit safety asserts before any rename, both writes go through temps, both files left untouched on any assertion failure). The advisory-only nature of `check` (always exit 0) means it cannot block CI even if the open count balloons; that is the documented intent and matches the brief.
  questions_asked: none — operator directive specified an autonomous, non-interactive review.
  recommendation: admit
