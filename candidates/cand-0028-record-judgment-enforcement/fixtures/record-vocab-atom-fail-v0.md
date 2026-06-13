# Record Vocabulary Atom (fail)

Fixture id: `premath.fixture.record-vocab-atom-fail.v0`
Spec: premath.record-judgments.v0 (RJ-1.5)

```text
case_id: record-vocab-atom.fail
record_form: META status field wire representation
atom: StatusVocab(s) — profile-owned atomic predicate; not a sum type (disjunction is not active in the regular fragment)
invalid_value: status not in the admitted vocabulary
reason: enumerations enter the fragment only as boarded atomic predicates; an out-of-vocabulary value fails the atom
expected_result: rejected
expected_failure_class: vocabulary-atom-failure
disposition: reject
```
