# cand-0011-bvr-note-refresh

Refreshes Design Note 0001 to fold in the user's RFC-sketch deltas and stay
current with the now-landed spec:

- points §4 to the landed **EVENT-COMPLETE/1** application-target spec
  (`specs/applications/EVENT-COMPLETE-1.md`);
- adds the coSNARK pragmatism — coSNARKs are for genuinely distributed/private
  witnesses, **not a universal proving mode** (a bilateral known-terms event may
  use signatures + an ordinary proof);
- adds the vector-commitment profile requirements, load-bearing among them
  *require a zero-opening (aggregate-blinding) proof, not inspection of an
  arbitrary group point.*

## Evidence (`eval-self.sh`, attested)

- deltas — spec pointer + coSNARK pragmatism + zero-opening present; still
  non-normative.
- pointer — the referenced EVENT-COMPLETE/1 spec actually exists in the tree.

Status: open (pre-threshold).
