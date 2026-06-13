// One-per-human starter credits, keyed by the stored World ID uniqueness nullifier.
//
// Design Note 0002 §2.3 / §6: a one-time uniqueness proof mints one-per-human
// starter credits, "keyed by storing the nullifier". The nullifier is the
// one-time-per-action handle; storing it is what makes the grant ONE per human.
//
// This is a CLIENT-SIDE view only. The AUTHORITATIVE per-human metering lives in the
// gateway (the AgentBook-resolved shared counter) — this local store is UX state, not
// a security boundary. The server must independently enforce the quota.

export interface StarterCredits {
  /** the stored uniqueness nullifier — the per-human grant key. */
  nullifier: string;
  /** remaining starter credits (mirrors, does not replace, the gateway counter). */
  remaining: number;
  grantedAt: number;
}

const STORAGE_KEY = "aac.starter-credits.v1";
const STARTER_GRANT = 3; // mirrors demoPolicies() free-trial caps

/**
 * Mint starter credits for a freshly proven unique human, idempotently: a second
 * call with the SAME nullifier does NOT re-grant (that is the anti-Sybil point —
 * one grant per human, enforced authoritatively by the gateway, mirrored here).
 */
export function mintStarterCredits(nullifier: string, store: KeyValueStore = browserStore()): StarterCredits {
  const existing = readCredits(store);
  if (existing && existing.nullifier === nullifier) return existing; // idempotent
  const fresh: StarterCredits = { nullifier, remaining: STARTER_GRANT, grantedAt: Date.now() };
  store.set(STORAGE_KEY, JSON.stringify(fresh));
  return fresh;
}

export function readCredits(store: KeyValueStore = browserStore()): StarterCredits | null {
  const raw = store.get(STORAGE_KEY);
  if (raw === null) return null;
  try {
    return JSON.parse(raw) as StarterCredits;
  } catch {
    return null;
  }
}

// ---- a tiny KV seam so this is testable without a DOM ------------------------

export interface KeyValueStore {
  get(key: string): string | null;
  set(key: string, value: string): void;
}

function browserStore(): KeyValueStore {
  // Guard for SSR / non-browser: fall back to an ephemeral map.
  if (typeof localStorage === "undefined") {
    const m = new Map<string, string>();
    return { get: (k) => m.get(k) ?? null, set: (k, v) => void m.set(k, v) };
  }
  return { get: (k) => localStorage.getItem(k), set: (k, v) => localStorage.setItem(k, v) };
}
