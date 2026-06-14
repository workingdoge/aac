# cand-0051-pedersen-vector-msm-profile

Port the governed MSM finding from main into the vnet-fundraising branch as a
new candidate number: PEDERSEN-VECTOR/1, a Grumpkin/ProveKit-oriented VNET/1
profile whose core rule is that all embedded-curve aggregation is expressed as
a single `multi_scalar_mul` rather than point-addition opcodes.

This candidate deliberately does not land the untracked `world-app/provekit-vnet`
prototype from main. That prototype is useful evidence, but it uses demo
generators with known discrete-log relations and should become a later circuit
candidate with proper constants/conformance vectors.

Intent: port the governed ProveKit MSM-only Pedersen vector profile into vnet fundraising

Status: open (pre-threshold).
