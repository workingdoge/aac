# Record META Telescope Formation (fail)

Fixture id: `premath.fixture.record-meta-telescope-fail.v0`
Spec: premath.record-judgments.v0 (RJ-1.1)

```text
case_id: record-meta-telescope.fail
record_form: META key:value wire representation
telescope: Gamma_dev, candidate_id : CandId, cycle_id : CycleId, opened : Timestamp, intent : Intent, status : StatusVocab
missing_premise: status
reason: a required extension premise is uninhabited; formation fails before any judgment about the candidate is meaningful
expected_result: rejected
expected_failure_class: record-formation-incomplete
distinct_from: comprehension-missing-evidence (absence of witness at admission, not absence of a formation premise)
disposition: reject
```
