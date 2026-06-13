// AAC tonight-harness: differential + property tests
// Reference model: the Grothendieck group K(M) of fixed-decimal amount
// vectors, implemented independently here, tested against the shipped kernel
// (src/pacioli.ts, src/kernel/economic.ts, src/kernel/channel.ts,
// src/kernel/oriented.ts).
//
// Run: npx tsx harness/k-properties.ts

import { parseFixedDecimal, formatFixedDecimal, addTerms, equalTerms, reduceTerm, type PacioliTerm } from '../src/pacioli';
import { journalTrialBalance, addJournalRows, type JournalComponentRow, type TComponent } from '../src/kernel/economic';
import { pushFact, pullFact, channelTrialBalance, type ChannelOccurrence } from '../src/kernel/channel';
import { trialBalanceOriented, stableMessageKey } from '../src/kernel/oriented';

// ---------- deterministic PRNG (mulberry32) ----------
let seed = 0xC0FFEE;
const rnd = () => {
  seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const ri = (n: number) => Math.floor(rnd() * n);
const shuffle = <T,>(xs: T[]): T[] => {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) { const j = ri(i + 1); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
};

// ---------- independent reference model: K(M) ----------
// M = amount vectors over BASIS with bigint cents; K(M) = formal differences.
// Class of a journal = net (debit - credit) per basis. Balanced <=> class 0.
const BASIS = ['usdc', 'eth', 'sui'] as const;
type Net = Map<string, bigint>;

const refClassOfRows = (rows: JournalComponentRow[]): Net => {
  const net: Net = new Map(BASIS.map((b) => [b, 0n]));
  for (const row of rows) for (const c of row.components) {
    const d = parseFixedDecimal(c.debit ?? '0.00');
    const cr = parseFixedDecimal(c.credit ?? '0.00');
    net.set(c.basisId, (net.get(c.basisId) ?? 0n) + d - cr);
  }
  return net;
};
const refZero = (n: Net) => [...n.values()].every((v) => v === 0n);
const refAdd = (a: Net, b: Net): Net => {
  const out: Net = new Map(a);
  for (const [k, v] of b) out.set(k, (out.get(k) ?? 0n) + v);
  return out;
};

// Grothendieck relation on terms: (d1,c1) ~ (d2,c2) iff d1+c2 = c1+d2 (per basis)
const crossEqual = (l: PacioliTerm, r: PacioliTerm): boolean =>
  BASIS.every((b) => {
    const ld = parseFixedDecimal(l.debit[b] ?? '0.00');
    const lc = parseFixedDecimal(l.credit[b] ?? '0.00');
    const rd = parseFixedDecimal(r.debit[b] ?? '0.00');
    const rc = parseFixedDecimal(r.credit[b] ?? '0.00');
    return ld + rc === lc + rd; // pacioli_equal, the K(M) defining relation
  });

// ---------- random generators ----------
const amt = () => formatFixedDecimal(BigInt(ri(500_000))); // 0.00 .. 4999.99
const randComponent = (): TComponent => {
  const basisId = BASIS[ri(BASIS.length)];
  const which = ri(3);
  return {
    basisId,
    ...(which !== 1 ? { debit: amt() } : {}),
    ...(which !== 0 ? { credit: amt() } : {}),
  };
};
const randRows = (n: number): JournalComponentRow[] =>
  Array.from({ length: n }, (_, i) => ({
    entryId: `e${ri(4)}`,
    accountId: ['assets', 'liabilities', 'equity'][ri(3)],
    components: Array.from({ length: 1 + ri(3) }, randComponent),
  }));
// A guaranteed-balanced journal: random debits mirrored by equal credits.
const balancedRows = (n: number): JournalComponentRow[] => {
  const rows = randRows(n);
  const net = refClassOfRows(rows);
  const fix: JournalComponentRow = {
    entryId: 'fix', accountId: 'equity',
    components: [...net.entries()]
      .filter(([, v]) => v !== 0n)
      .map(([basisId, v]) => (v > 0n
        ? { basisId, credit: formatFixedDecimal(v) }
        : { basisId, debit: formatFixedDecimal(-v) })),
  };
  return fix.components.length ? [...rows, fix] : rows;
};

type Msg = { asset: string; tid: number };
const randFacts = (n: number): ChannelOccurrence<Msg>[] =>
  Array.from({ length: n }, () => {
    const m: Msg = { asset: BASIS[ri(BASIS.length)], tid: ri(6) };
    const mult = BigInt(1 + ri(5));
    return rnd() < 0.5 ? pushFact('payments', m, mult) : pullFact('payments', m, mult);
  });
const refChannelNet = (facts: ChannelOccurrence<Msg>[]): Map<string, bigint> => {
  const net = new Map<string, bigint>();
  for (const f of facts) {
    const k = `${f.channel}|${stableMessageKey(f.message)}`;
    const m = f.multiplicity ?? 1n;
    net.set(k, (net.get(k) ?? 0n) + (f.side === 'push' ? m : -m));
  }
  return net;
};

// ---------- test runner ----------
let pass = 0, fail = 0;
const check = (name: string, cond: boolean, detail?: string) => {
  if (cond) pass++;
  else { fail++; console.error(`FAIL ${name}${detail ? ` :: ${detail}` : ''}`); }
};

const N = 500;

// P1 — differential: kernel balanced-flag agrees with reference K-class == 0,
// on both arbitrary and constructed-balanced journals.
for (let i = 0; i < N; i++) {
  const rows = rnd() < 0.5 ? randRows(1 + ri(6)) : balancedRows(1 + ri(6));
  const kernel = journalTrialBalance([...BASIS], rows);
  const ref = refClassOfRows(rows);
  check('P1.diff-balanced', kernel.balanced === refZero(ref));
  // residuals must equal |net| on the correct side, per basis
  for (const r of kernel.residuals) {
    const v = ref.get(r.basisId) ?? 0n;
    const d = parseFixedDecimal(r.debit), c = parseFixedDecimal(r.credit);
    check('P1.residual-net', d - c === v, `${r.basisId}: ${d}-${c} vs ${v}`);
  }
}

// P2 — permutation invariance: K-class (and kernel verdict) ignores row order.
for (let i = 0; i < N; i++) {
  const rows = randRows(2 + ri(6));
  const a = journalTrialBalance([...BASIS], rows);
  const b = journalTrialBalance([...BASIS], shuffle(rows));
  check('P2.perm-balanced', a.balanced === b.balanced);
  check('P2.perm-reduced', equalTerms([...BASIS], a.reduced, b.reduced));
}

// P3 — additivity: class(A ++ B) = class(A) + class(B); kernel sum-term agrees.
for (let i = 0; i < N; i++) {
  const A = randRows(1 + ri(4)), B = randRows(1 + ri(4));
  const refAB = refAdd(refClassOfRows(A), refClassOfRows(B));
  check('P3.ref-additive',
    [...refClassOfRows([...A, ...B]).entries()].every(([k, v]) => refAB.get(k) === v));
  const sumTerm = addTerms([...BASIS], [addJournalRows([...BASIS], A), addJournalRows([...BASIS], B)]);
  check('P3.kernel-additive',
    equalTerms([...BASIS], reduceTerm([...BASIS], sumTerm), reduceTerm([...BASIS], addJournalRows([...BASIS], [...A, ...B]))));
}

// P4 — Grothendieck relation: cross-addition equality (pacioli_equal) iff
// reduced normal forms coincide. This is the circuit's equality test vs the
// kernel's normal form: the two faces of K(M).
for (let i = 0; i < N; i++) {
  const A = addJournalRows([...BASIS], randRows(1 + ri(4)));
  const sameClass = rnd() < 0.5;
  const B = sameClass
    ? addTerms([...BASIS], [A, { debit: { usdc: '7.00' }, credit: { usdc: '7.00' } }]) // add (x,x): class-preserving
    : addTerms([...BASIS], [A, { debit: { usdc: '7.00' }, credit: {} }]);              // shift class
  check('P4.cross-iff-normal',
    crossEqual(A, B) === equalTerms([...BASIS], reduceTerm([...BASIS], A), reduceTerm([...BASIS], B)));
  if (sameClass) check('P4.same-class-detected', crossEqual(A, B));
  else check('P4.shift-detected', !crossEqual(A, B));
}

// P5 — channels: balanced iff per-(channel,message) pushes equal pulls;
// residuals are exact nets; multiset semantics (duplicates accumulate).
for (let i = 0; i < N; i++) {
  const facts = randFacts(1 + ri(10));
  const tb = channelTrialBalance(facts);
  const net = refChannelNet(facts);
  check('P5.diff-balanced', tb.balanced === [...net.values()].every((v) => v === 0n));
  for (const r of tb.residualPushes) {
    const k = `${r.channel}|${stableMessageKey(r.message)}`;
    check('P5.push-net', net.get(k) === r.multiplicity);
  }
  for (const r of tb.residualPulls) {
    const k = `${r.channel}|${stableMessageKey(r.message)}`;
    check('P5.pull-net', net.get(k) === -r.multiplicity);
  }
  const keys = new Set([...tb.residualPushes, ...tb.residualPulls]
    .map((r) => `${r.channel}|${stableMessageKey(r.message)}`));
  check('P5.disjoint-support',
    keys.size === tb.residualPushes.length + tb.residualPulls.length);
}

// P6 — guards: non-positive multiplicity must throw (monoid constraint).
{
  let threw = false;
  try { trialBalanceOriented([{ side: 'positive', message: 'x', multiplicity: 0n }]); }
  catch { threw = true; }
  check('P6.zero-multiplicity-throws', threw);
  threw = false;
  try { trialBalanceOriented([{ side: 'positive', message: 'x', multiplicity: -3n }]); }
  catch { threw = true; }
  check('P6.negative-multiplicity-throws', threw);
}

console.log(`\n${pass} checks passed, ${fail} failed  (seed=0xC0FFEE, N=${N})`);
if (fail > 0) process.exit(1);
