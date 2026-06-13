/-
  AAC core specification — double-entry bookkeeping as Grothendieck completion.

  STATUS: drafted 2026-06-11; typechecked 2026-06-12 against mathlib
  (Lean v4.28.0). All inline lemmas elaborate; the three former `sorry`s
  (`class_additive`, `journal_balanced_iff`, `pacioli_equal_field_sound`)
  are now closed, and the field-soundness obligation is proved both in the
  pairwise form and in the n-row accumulation form that the TRANSITION/1
  journal-balance constraint actually discharges.

  Correspondence to the implementation:
    * `Term`                ↔ PacioliTerm                 (src/pacioli.ts)
    * `Term.pacioliEqual`   ↔ pacioli_equal               (Noir, README §Noir Circuit)
    * `Term.class'`/`reduce`↔ reduceTerm / residuals      (src/pacioli.ts, oriented.ts)
    * `Journal.balanced`    ↔ journalTrialBalance.balanced (src/kernel/economic.ts)
    * `ChannelLog.balanced` ↔ channelTrialBalance.balanced (src/kernel/channel.ts)
    * single-pull rights    ↔ nullifier targets           (src/nullifier-*.ts)
  The differential harness (k-properties.ts, kept with the implementation
  tree) tests exactly the statements below against an executable kernel:
  P1↔`journal_balanced_iff`, P2↔`class_perm_invariant`, P3↔`class_additive`,
  P4↔`pacioliEqual_iff_class_eq`, P5↔`channel_balanced_iff`.
-/

import Mathlib.Data.Multiset.Count
import Mathlib.Data.Multiset.MapFold
import Mathlib.Data.ZMod.Basic
import Mathlib.Algebra.BigOperators.Group.List.Basic

namespace AAC

/-! ### Amounts

Amounts are vectors of cents over a fixed basis, valued in ℕ: a commutative,
*cancellative* monoid. Cancellativity is what makes the Grothendieck
completion injective; it is also the semantic content of the circuit's
bounded-amount (`Field → u64 → Field`) discipline. -/

variable {Basis : Type}

abbrev Amount (Basis : Type) := Basis → ℕ

/-- A Pacioli term: a formal (debit, credit) pair. The raw representative
of an element of K(Amount). -/
structure Term (Basis : Type) where
  debit  : Amount Basis
  credit : Amount Basis

namespace Term

variable (t u v : Term Basis)

/-- The Grothendieck relation, exactly as the Noir circuit decides it:
cross-addition equality, pointwise on the basis.
`pacioli_equal(ld, lc, rd, rc) := ld + rc == lc + rd`. -/
def pacioliEqual (t u : Term Basis) : Prop :=
  ∀ b, t.debit b + u.credit b = t.credit b + u.debit b

instance : Setoid (Term Basis) where
  r := pacioliEqual
  iseqv := by
    constructor
    · intro t b; omega
    · intro t u h b; have := h b; omega
    · intro t u v htu huv b; have h1 := htu b; have h2 := huv b; omega

/-- K(Amount): the Pacioli group, i.e. the Grothendieck completion of the
amount monoid, constructed as the quotient by cross-addition equality. -/
abbrev K (Basis : Type) := Quotient (inferInstanceAs (Setoid (Term Basis)))

def class' (t : Term Basis) : K Basis := Quotient.mk _ t

/-- Addition of terms is componentwise; it descends to K. -/
def add (t u : Term Basis) : Term Basis :=
  ⟨fun b => t.debit b + u.debit b, fun b => t.credit b + u.credit b⟩

theorem add_descends (t t' u u' : Term Basis)
    (ht : pacioliEqual t t') (hu : pacioliEqual u u') :
    pacioliEqual (add t u) (add t' u') := by
  intro b; have := ht b; have := hu b; simp [add]; omega

/-- The zero class: balanced. A term is balanced iff debit = credit. -/
def balanced (t : Term Basis) : Prop := ∀ b, t.debit b = t.credit b

theorem balanced_iff_class_zero (t : Term Basis) :
    balanced t ↔ pacioliEqual t ⟨fun _ => 0, fun _ => 0⟩ := by
  constructor
  · intro h b; show t.debit b + 0 = t.credit b + 0; have := h b; omega
  · intro h b; have h' : t.debit b + 0 = t.credit b + 0 := h b; omega

/-- The two faces of K(M) coincide: the circuit's equality test
(cross-addition) holds iff the kernel's normal forms agree.
Harness P4 tests this statement against the shipped code. -/
theorem pacioliEqual_iff_class_eq (t u : Term Basis) :
    pacioliEqual t u ↔ class' t = class' u := by
  constructor
  · intro h; exact Quotient.sound h
  · intro h; exact Quotient.exact h

/-- K(ℕ-vectors) is a group: every class has an inverse (swap debit/credit).
Bookkeeping's "contra entry" is literally group inversion. -/
theorem class_add_inv (t : Term Basis) :
    pacioliEqual (add t ⟨t.credit, t.debit⟩) ⟨fun _ => 0, fun _ => 0⟩ := by
  intro b; simp [add]; omega

end Term

/-- `Term.add` is left-commutative, so a multiset fold over it is
well-defined. This instance is the real content of harness P2: the journal
total is order-independent. -/
instance : LeftCommutative (Term.add (Basis := Basis)) where
  left_comm a b c := by
    simp only [Term.add, Term.mk.injEq]
    constructor <;> funext x <;> omega

/-! ### Journals -/

/-- A journal is a multiset of terms (rows). Multiset = free commutative
monoid: order-free by construction, which is harness P2. -/
abbrev Journal (Basis : Type) := Multiset (Term Basis)

def Journal.total (J : Journal Basis) : Term Basis :=
  J.foldr Term.add ⟨fun _ => 0, fun _ => 0⟩

def Journal.balanced (J : Journal Basis) : Prop := (J.total).balanced

/-- Folding `Term.add` with an arbitrary initial term is, up to the Pacioli
relation, the same as folding from zero and then adding the initial term.
The bridge lemma behind additivity. -/
theorem total_foldr_init (A : Journal Basis) (init : Term Basis) :
    Term.pacioliEqual (A.foldr Term.add init) (Term.add A.total init) := by
  induction A using Multiset.induction_on with
  | empty => intro b; simp only [Multiset.foldr_zero, Journal.total, Term.add]; omega
  | cons a s ih =>
      intro b; have h1 := ih b
      simp only [Multiset.foldr_cons, Journal.total, Term.add] at h1 ⊢; omega

/-- Harness P3: the class of a concatenation is the sum of classes. -/
theorem class_additive (A B : Journal Basis) :
    (A + B).total.class' =
      Quotient.mk _ (Term.add A.total B.total) := by
  apply Quotient.sound
  show Term.pacioliEqual _ _
  rw [Journal.total, Multiset.foldr_add]
  exact total_foldr_init A B.total

/-- Harness P2 (a corollary of using Multiset, stated for the record):
permutation invariance is definitional. -/
theorem class_perm_invariant (A B : Journal Basis) (h : A = B) :
    A.total.class' = B.total.class' := by rw [h]

/-- Harness P1: the kernel's balanced flag decides class-zero. -/
theorem journal_balanced_iff (J : Journal Basis) :
    J.balanced ↔ J.total.class' = Term.class' ⟨fun _ => 0, fun _ => 0⟩ :=
  (Term.balanced_iff_class_zero J.total).trans (Term.pacioliEqual_iff_class_eq _ _)

/-! ### Channels

Channel facts are oriented occurrences of messages; a log is a pair of
multisets (pushes, pulls). Balance is equality of multisets — the same
Grothendieck structure one level up: K(free commutative monoid on messages)
= the free abelian group ℤ[Msg]. -/

structure ChannelLog (Msg : Type) where
  pushes : Multiset Msg
  pulls  : Multiset Msg

def ChannelLog.balanced {Msg : Type} (L : ChannelLog Msg) : Prop :=
  L.pushes = L.pulls

/-- Harness P5: balanced iff every message nets to zero. -/
theorem channel_balanced_iff {Msg : Type} [DecidableEq Msg] (L : ChannelLog Msg) :
    L.balanced ↔ ∀ m, L.pushes.count m = L.pulls.count m := by
  constructor
  · intro h m; rw [h]
  · intro h; exact Multiset.ext.mpr h

/-! ### Rights and nullifiers

Rights do not stack: their natural algebra is idempotent, and Grothendieck
completion annihilates idempotents (a + a = a ⟹ a ~ 0). Hence rights are
NOT amounts; they are single-pull channels. This is the formal reason for
the account-root / nullifier-root separation in the architecture. -/

/-- A consumption log is valid when no right is pulled twice and every pull
was pushed (granted). -/
def RightsValid {R : Type} [DecidableEq R]
    (granted consumed : Multiset R) : Prop :=
  consumed.Nodup ∧ consumed ≤ granted

theorem no_double_spend {R : Type} [DecidableEq R]
    (granted consumed : Multiset R) (h : RightsValid granted consumed)
    (r : R) : consumed.count r ≤ 1 := by
  exact Multiset.nodup_iff_count_le_one.mp h.1 r

/-! ### The circuit lift — the theorem with real content

The Noir circuit evaluates `pacioli_equal` in the BN254 scalar field, not
in ℕ. Soundness requires that no sum wraps the modulus; the implementation
enforces this with the `Field → u64 → Field` roundtrip on every
amount-bearing input. The statements below are the obligation that
discipline discharges. -/

-- BN254 scalar field modulus.
def bn254ScalarOrder : ℕ := 21888242871839275222246405745257275088548364400416034343698204186575808495617

/-- Pairwise form. If all four amounts are bounded by u64 (so each cross-sum
is < 2^65 ≪ r), then field equality of the cross-sums reflects ℕ equality.
This is exactly the obligation the per-witness `Field → u64 → Field`
roundtrip discharges for a single binary `pacioli_equal`. -/
theorem pacioli_equal_field_sound
    (ld lc rd rc : ℕ)
    (hld : ld < 2 ^ 64) (hlc : lc < 2 ^ 64)
    (hrd : rd < 2 ^ 64) (hrc : rc < 2 ^ 64)
    (hfield : ((ld + rc : ℕ) : ZMod bn254ScalarOrder) = ((lc + rd : ℕ) : ZMod bn254ScalarOrder)) :
    ld + rc = lc + rd := by
  have hmod : ld + rc ≡ lc + rd [MOD bn254ScalarOrder] :=
    (ZMod.natCast_eq_natCast_iff _ _ _).mp hfield
  have hr : 2 ^ 64 + 2 ^ 64 ≤ bn254ScalarOrder := by unfold bn254ScalarOrder; omega
  exact hmod.eq_of_lt_of_lt (by omega) (by omega)

/-- Each u64-bounded amount is at most `2^64 - 1`, so a list of `n` of them
sums to at most `n · (2^64 - 1)`. -/
theorem sum_le_len_bound :
    ∀ (xs : List ℕ), (∀ x ∈ xs, x < 2 ^ 64) →
      xs.sum ≤ xs.length * (2 ^ 64 - 1) := by
  intro xs
  induction xs with
  | nil => intro _; simp
  | cons a t ih =>
      intro hx
      have ha : a < 2 ^ 64 := hx a (List.mem_cons.mpr (Or.inl rfl))
      have ht : ∀ x ∈ t, x < 2 ^ 64 := fun x hxt => hx x (List.mem_cons.mpr (Or.inr hxt))
      have hts := ih ht
      simp only [List.sum_cons, List.length_cons]
      omega

/-- A sum of `n` u64-bounded amounts cannot reach the modulus, as long as
`n · 2^64 ≤ r`. This is the accumulation bound that the per-account,
per-basis debit/credit sums in TRANSITION/1's journal-balance constraint
rely on: every partial and total sum stays below r, so carrier equality
of the sums decides ℕ equality. -/
theorem sum_lt_order (xs : List ℕ)
    (hx : ∀ x ∈ xs, x < 2 ^ 64)
    (hn : xs.length * 2 ^ 64 ≤ bn254ScalarOrder) :
    xs.sum < bn254ScalarOrder := by
  have hpos : 0 < bn254ScalarOrder := by unfold bn254ScalarOrder; omega
  have hb := sum_le_len_bound xs hx
  omega

/-- n-row field soundness, in the form the journal-balance constraint
discharges: if the per-basis debit list and credit list of a journal are
each u64-bounded and short enough that `n · 2^64 ≤ r`, then field equality
of their sums reflects ℕ equality — the circuit's in-field balance check
decides real balance, with no wrap. -/
theorem journal_sum_field_sound (ds cs : List ℕ)
    (hd : ∀ x ∈ ds, x < 2 ^ 64) (hc : ∀ x ∈ cs, x < 2 ^ 64)
    (hnd : ds.length * 2 ^ 64 ≤ bn254ScalarOrder)
    (hnc : cs.length * 2 ^ 64 ≤ bn254ScalarOrder)
    (hfield : ((ds.sum : ℕ) : ZMod bn254ScalarOrder) = ((cs.sum : ℕ) : ZMod bn254ScalarOrder)) :
    ds.sum = cs.sum := by
  have hmod : ds.sum ≡ cs.sum [MOD bn254ScalarOrder] :=
    (ZMod.natCast_eq_natCast_iff _ _ _).mp hfield
  exact hmod.eq_of_lt_of_lt (sum_lt_order ds hd hnd) (sum_lt_order cs hc hnc)

end AAC
