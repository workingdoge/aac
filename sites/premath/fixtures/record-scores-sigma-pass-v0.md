# Record Scores Sigma Packet (pass)

Fixture id: `premath.fixture.record-scores-sigma-pass.v0`
Spec: premath.record-judgments.v0 (RJ-1.2, RJ-1.6)

```text
case_id: record-scores-sigma.pass
record_form: scores.json wire representation
sigma_first_component: verdict cargo (task, cases, passed, verdict)
sigma_second_component: attestation witness (provenance: harness_sha256, traces_sha256, body_sha256, attestation)
reason: the packet pairs construction cargo with the witness that the cargo satisfies the dependent body
authority_note: the serialized packet does not create authority; the statement is the type, the file is a wire representation
expected_result: accepted
disposition: accept
```
