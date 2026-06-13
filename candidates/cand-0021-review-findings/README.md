# cand-0021-review-findings

Remediates the three findings from the post-compaction review (P1/P2/P3) over
the landed circuits + the EVENT-COMPLETE/1 spec. No new surface; corrections and
hardening to `circuits/nullify`, `circuits/event-complete`, the spec, and the
cand-0017 record.

## P2 — NULLIFY/1 accepted the reserved `0` sentinel

`TRANSITION/1` treats `0` as the empty-slot (no-nullifier) sentinel, but
`NULLIFY/1` would "consume" `new_value == 0`: `0` brackets cleanly below the
first member, so the before-first range check accepted it vacuously. Added
`assert(new_value != 0, ...)` plus a `rejects_inserting_the_zero_sentinel`
negative test. For symmetry, `EVENT-COMPLETE/1` now asserts its derived
nullifier is nonzero (`event_nullifier is the 0 sentinel`) — a hash image never
is, so this only aligns the two circuits' nullifier domains.

## P3 — cand-0017 claimed before-first coverage it did not witness

cand-0017's evidence claimed accept coverage for "before-first / after-last"
while its tests only exercised middle + after-last. Added an explicit
`accepts_insert_before_first` (`low_index = 0`) accept test so the claim is
witnessed, and appended a transparent correction note to cand-0017's README.

## P1 — EVENT-COMPLETE/1 obligation 9 did not match the spec's factId rule

The spec (obligation 9) and 2/FACT §3 derive one-shot nullifiers from
`factId := H(enc(fact))`. The circuit derives an *event-scoped*
`N = H(tag, rulebook_id, event_commitment, participant_set)` — a different,
narrower construction (no `enc(fact)` / cjson is computed in-circuit). Rather
than fake a `factId`, the claim is **narrowed honestly**: the circuit header and
in-circuit comment now say obligation 9 is realized in an event-scoped form, and
the spec gains a non-normative **"Implementation status"** section recording
exactly which obligations the reference circuit realizes (2,4,5,10 in full; 9
event-scoped; 1,3,6-partial,7,8 + the rest of the §5 ABI deferred). The
normative obligation text is unchanged — it remains the target.

## Evidence (`eval-self.sh`, attested)

- logic — the `new_value != 0` guard + the zero-sentinel negative test + the
  EVENT-COMPLETE/1 nonzero assert + the before-first accept test + the cand-0017
  correction + the obligation-9 narrowing (circuit *and* spec "Implementation
  status" / "event-scoped nullifier") are all present.
- prove — a scratch workspace over the landed deps + the two changed crates:
  `nargo test` green (nullify 10, event_complete 6), both sample witnesses solve,
  the whole workspace compiles.

Status: open (pre-threshold).
