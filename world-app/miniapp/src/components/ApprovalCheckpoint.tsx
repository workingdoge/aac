// The human-in-the-loop approval checkpoint, bound to a DOMAIN action token.
//
// Design Note 0002 §3 / §4 / §2.3: the agent is useful before approval (it drafted
// the receipt proof above) but MAY NOT autonomously commit an irreversible action.
// Committing the receipt PAUSES for an explicit World ID-backed approval whose action
// id is bound to `receipt:<nullifier>` — not a generic tool id.

import { useState } from "react";
import {
  requestHumanAuthorization,
  receiptActionToken,
  type HitlApproval,
} from "../lib/worldid.js";

export function ApprovalCheckpoint(props: { enabled: boolean; nullifier: string }) {
  const { enabled, nullifier } = props;
  const [approval, setApproval] = useState<HitlApproval | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const token = receiptActionToken(nullifier);

  async function onApprove() {
    setError(null);
    setBusy(true);
    try {
      // requestHumanAuthorization — the VERIFIED HITL function. Bound to the domain
      // action token, overriding the default (tool-call id) binding.
      setApproval(await requestHumanAuthorization(token));
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section
      style={{
        border: "2px solid #d9b310",
        background: "#fffdf5",
        borderRadius: 8,
        padding: 12,
        marginTop: 16,
        opacity: enabled ? 1 : 0.5,
      }}
    >
      <strong style={{ fontSize: 14 }}>⏸ Human-in-the-loop: commit receipt</strong>
      <div style={{ color: "#666", fontSize: 12, marginTop: 6 }}>
        Irreversible. Pauses for a World ID approval bound to <code>{token.value}</code>.
      </div>
      {approval ? (
        <div style={{ color: "#2a7", fontSize: 12, marginTop: 8 }}>
          ✓ authorized {approval.approved ? "(approved)" : "(declined)"} — action{" "}
          <code>{approval.actionToken.value}</code>
        </div>
      ) : (
        <button
          onClick={() => void onApprove()}
          disabled={!enabled || busy}
          style={{
            marginTop: 8,
            fontSize: 12,
            padding: "5px 12px",
            borderRadius: 6,
            border: "1px solid #d9b310",
            background: "#fff",
            cursor: enabled ? "pointer" : "not-allowed",
          }}
        >
          {busy ? "awaiting approval…" : "requestHumanAuthorization()"}
        </button>
      )}
      {error && (
        <div style={{ color: "#c33", fontSize: 12, marginTop: 8 }}>
          stub / integration error: {error}
        </div>
      )}
    </section>
  );
}
