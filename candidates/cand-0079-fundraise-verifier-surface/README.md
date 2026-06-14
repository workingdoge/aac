# cand-0079-fundraise-verifier-surface

Intent: Expose the real ProveKit verifier receipt in the fundraise summary and render it as a visible verifier panel.

Status: open (pre-threshold).

Cargo exposes the existing ProveKit verifier receipt as first-class
presentation data. The runner summary gains `verifier`, captured fallback data
gets the deterministic receipt commitments, and the fundraise component renders
a visible verifier lane with the verifier status, receipt digest, proof digest,
public-input binding, key digest, timing, and native/on-chain boundary.
