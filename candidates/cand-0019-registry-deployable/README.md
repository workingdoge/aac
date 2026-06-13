# cand-0019-registry-deployable

Makes the 4/REG registry **actually deployable on a real EVM**. The bb UltraHonk
`HonkVerifier` is 24,644 B runtime at `optimizer_runs=200` — **68 B over the
EIP-170 limit** (24,576), so it passes `forge test` (the test EVM doesn't enforce
EIP-170) but cannot be deployed. Dropping to `optimizer_runs=50` gives 23,782 B
(794 B under); correctness is unchanged.

Adds `registry/script/Deploy.s.sol` — deploys the verifier (forge auto-deploys +
links its `ZKTranscriptLib`) and the `Registry` pinned to it. Verified deploying
to **live anvil under EIP-170 enforcement** (ONCHAIN EXECUTION SUCCESSFUL).

## Evidence (`eval-self.sh`, attested)

- present — `optimizer_runs=50` (with the EIP-170 rationale) + the Deploy script.
- deployable — `forge build --sizes` shows `HonkVerifier` under EIP-170; `forge
  test` stays green (the real proof still verifies); `forge script Deploy`
  deploys + links the verifier library + the Registry in a forge EVM.

Status: open (pre-threshold).
