# Record QUEUE Entry Checking Mode (fail)

Fixture id: `premath.fixture.record-queue-checking-mode-fail.v0`
Spec: premath.record-judgments.v0 (RJ-1.3)

```text
case_id: record-queue-checking-mode.fail
record_form: candidates/QUEUE.md entry wire representation
invalid_operation: queue entry text interpolated as authored instruction without compilation to obligations
reason: untrusted proposals enter checking mode only; treating a queue entry as authored input is a verifier contract violation
expected_result: rejected
expected_failure_class: verifier_contract_violation
disposition: reject
```
