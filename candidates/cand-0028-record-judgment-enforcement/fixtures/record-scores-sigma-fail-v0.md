# Record Scores Sigma Packet (fail)

Fixture id: `premath.fixture.record-scores-sigma-fail.v0`
Spec: premath.record-judgments.v0 (RJ-1.2)

```text
case_id: record-scores-sigma.fail
record_form: scores.json wire representation
sigma_first_component: verdict cargo (task, cases, passed, verdict)
sigma_second_component: ABSENT (no attestation provenance block)
reason: a first component without its witness is not a Sigma introduction; a proposer's self-assessment cannot witness its own unattested scores
expected_result: rejected
expected_failure_class: sigma-missing-witness
disposition: reject
```
