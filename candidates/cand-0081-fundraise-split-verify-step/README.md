# cand-0081-fundraise-split-verify-step

Intent: Separate fundraise proof generation from the visible verifier step in the demo UI.

Status: open (pre-threshold).

Scope: fundraise web presentation only. The localhost runner still returns the
native ProveKit verifier receipt in one response; the console separates proof
generation from visible verifier acceptance so the demo does not collapse the
two acts into one control.
