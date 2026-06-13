import { LitElement, html, css } from 'lit';

/** aac-transition — the TRANSITION/1 proof receipt. Renders the public-input
 *  ABI vector (3/PROOF §4.1) of a real proven transition as the registry sees
 *  it: prev→next roots, recomputed commitments, and the constraints the circuit
 *  discharged. The dark proof surface is invariant in light and dark, like
 *  aac-proof. Values default to the executed `circuits/transition` sample. */
export class AacTransition extends LitElement {
  static properties = {
    prevAccount: { type: String, attribute: 'prev-account' },
    nextAccount: { type: String, attribute: 'next-account' },
    prevNull: { type: String, attribute: 'prev-null' },
    nextNull: { type: String, attribute: 'next-null' },
    journal: { type: String },
    factFold: { type: String, attribute: 'fact-fold' },
    factCount: { type: Number, attribute: 'fact-count' },
    context: { type: String },
    opcodes: { type: Number },
  };

  declare prevAccount: string;
  declare nextAccount: string;
  declare prevNull: string;
  declare nextNull: string;
  declare journal: string;
  declare factFold: string;
  declare factCount: number;
  declare context: string;
  declare opcodes: number;

  constructor() {
    super();
    // The real public inputs of the sample witness solved by `nargo execute`.
    this.prevAccount = '0x285d0a920649ed8d73b49ff24228dee78fe8dfb3e7e2c1de0ea625d9220bc13a';
    this.nextAccount = '0x2de709dc001606623858291789247bd43b45e82a57b816298e620777f81f3ab8';
    this.prevNull = '0x64';
    this.nextNull = '0x1ad0978e0eb29b63e52cee7b479dcc5648b74c8863f793e6594ab09757ec53c7';
    this.journal = '0x2b3b2f90e4f8d2b00f20380de846810c1427a8600816fe4b5cb0fc321d02b33b';
    this.factFold = '0x2f4c45bb0955be9c27b54fdd6ec63dc9d146eb15ad0f3e1d5ed0b70c1e0a1e41';
    this.factCount = 1;
    this.context = '0x2a';
    this.opcodes = 673;
  }

  /** Truncate a long hex carrier to head…tail; short values pass through. */
  private mid(h: string): string {
    const x = h.startsWith('0x') ? h.slice(2) : h;
    if (x.length <= 12) return h;
    return `${x.slice(0, 6)}…${x.slice(-4)}`;
  }

  static styles = css`
    :host { display: block; }
    .panel {
      background: #15171b;
      color: #ede7d6;
      border: 1px solid var(--aac-color-rule2, #c9be9e);
      font-family: var(--aac-mono, 'IBM Plex Mono', monospace);
      font-size: 12.5px;
      line-height: 1.7;
    }
    .hd {
      display: flex; align-items: baseline; justify-content: space-between;
      gap: 12px; padding: 12px 16px; border-bottom: 1px solid #2a2d33;
    }
    .tt { font-weight: 600; letter-spacing: 0.14em; color: #ede7d6; }
    .pf { color: #8c8678; font-size: 11px; letter-spacing: 0.04em; }
    .sec {
      padding: 11px 16px 3px; font-size: 9.5px; letter-spacing: 0.18em;
      color: #6f7681; text-transform: uppercase;
    }
    .row {
      display: grid; grid-template-columns: 8.5em 1fr auto;
      align-items: baseline; gap: 8px; padding: 2px 16px;
    }
    .row.pair { grid-template-columns: 8.5em auto 1.2em auto 1fr; }
    .k { color: #8c8678; }
    .v { color: #e8d9a8; }
    .ar { color: #6f7681; text-align: center; }
    .note { color: #6f7681; font-size: 11px; text-align: right; }
    .note.un { color: #b08a4b; }
    .checks { margin: 2px 0 0; padding: 0 16px 6px; list-style: none; }
    .checks li { color: #cdc6b4; display: flex; gap: 8px; align-items: baseline; }
    .checks .c { color: #7fb08a; }
    .ft {
      padding: 11px 16px; border-top: 1px solid #2a2d33; color: #8c8678;
      font-size: 11px; line-height: 1.7;
    }
    .ft .ok { color: #7fb08a; }
  `;

  render() {
    const moved = this.prevNull !== this.nextNull;
    return html`
      <div class="panel">
        <div class="hd">
          <span class="tt">TRANSITION/1</span>
          <span class="pf">uh-bn254/1 · 3/PROOF §4.1 · public inputs</span>
        </div>

        <div class="sec">State transition</div>
        <div class="row pair">
          <span class="k">account root</span>
          <span class="v">${this.mid(this.prevAccount)}</span>
          <span class="ar">→</span>
          <span class="v">${this.mid(this.nextAccount)}</span>
          <span class="note">begin + posted = end</span>
        </div>
        <div class="row pair">
          <span class="k">nullifier root</span>
          <span class="v">${this.mid(this.prevNull)}</span>
          <span class="ar">→</span>
          <span class="v">${this.mid(this.nextNull)}</span>
          <span class="note">${moved ? '1 right consumed' : 'unchanged'}</span>
        </div>

        <div class="sec">Commitments (recomputed in-circuit)</div>
        <div class="row">
          <span class="k">journal</span><span class="v">${this.mid(this.journal)}</span>
          <span class="note">order-binding</span>
        </div>
        <div class="row">
          <span class="k">fact_fold</span><span class="v">${this.mid(this.factFold)}</span>
          <span class="note">${this.factCount} fact · Annex B</span>
        </div>
        <div class="row">
          <span class="k">context</span><span class="v">${this.mid(this.context)}</span>
          <span class="note un">unconstrained · 4/REG</span>
        </div>

        <div class="sec">Constraints discharged</div>
        <ul class="checks">
          <li><span class="c">✓</span> journal balance · K(M) class zero</li>
          <li><span class="c">✓</span> amounts bounded · Field→u64→Field</li>
          <li><span class="c">✓</span> begin + posted = end · per account, per basis</li>
          <li><span class="c">✓</span> nullifiers distinct · rights do not stack</li>
          <li><span class="c">✓</span> fact_fold · order-binding over emitted facts</li>
        </ul>

        <div class="ft">
          <span class="ok">${this.opcodes} ACIR opcodes</span> · nargo test
          <span class="ok">✓</span> · soundness pinned to
          <span class="ok">journal_sum_field_sound</span> · Core.lean · 0 sorry
        </div>
      </div>
    `;
  }
}

if (!customElements.get('aac-transition'))
  customElements.define('aac-transition', AacTransition);
