import { LitElement, html, css } from 'lit';

/** aac-row — a 4/REG registry Row advancing from a TRANSITION/1 proof. The
 *  registry holds books, not funds: its state is commitments, its update rule is
 *  proof, and its refusals are the trust model. This shows the row before→after
 *  plus the verifier-contract discharge (3/PROOF §5) — the real roots from the
 *  proof the on-chain HonkVerifier accepts. Themed by --aac-* tokens. */
export class AacRow extends LitElement {
  static properties = {
    name: { type: String },
    prevAccount: { type: String, attribute: 'prev-account' },
    nextAccount: { type: String, attribute: 'next-account' },
    prevNull: { type: String, attribute: 'prev-null' },
    nextNull: { type: String, attribute: 'next-null' },
    nonce: { type: Number },
  };

  declare name: string;
  declare prevAccount: string;
  declare nextAccount: string;
  declare prevNull: string;
  declare nextNull: string;
  declare nonce: number;

  constructor() {
    super();
    this.name = 'aac.example';
    // the real TRANSITION/1 public inputs the on-chain registry consumed.
    this.prevAccount = '0x2d49369e0148879f1c8901250c5b803e8afb0109d6391678ec07a35e55e2cb74';
    this.nextAccount = '0x1515c1ab700685b3f2ea99e8e512906c3b4be583a7d3cde2c382297301e7b374';
    this.prevNull = '0x64';
    this.nextNull = '0x147f6950b70c67867c87782724a483f114952bc5f64b9cf5b273270cd766928f';
    this.nonce = 0;
  }

  private mid(h: string): string {
    const x = h.startsWith('0x') ? h.slice(2) : h;
    return x.length <= 12 ? h : `${x.slice(0, 6)}…${x.slice(-4)}`;
  }

  static styles = css`
    :host { display: block; font-family: var(--aac-grotesk, Inter, system-ui, sans-serif); }
    .row { border: 1px solid var(--aac-color-navy, #21324f); background: var(--aac-color-bond, #fff); }
    .head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; padding: 12px 16px; border-bottom: 1px solid var(--aac-color-rule2, #c9be9e); }
    .label { font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; font-size: 12px; color: var(--aac-color-ink, #1a1a1a); }
    .name { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 12px; color: var(--aac-color-steel, #6b6b64); margin-top: 3px; }
    .meta { text-align: right; font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11px; color: var(--aac-color-steel, #6b6b64); white-space: nowrap; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { padding: 8px 16px; }
    thead th { font-size: 9.5px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--aac-color-steel, #6b6b64); border-bottom: 1px solid var(--aac-color-rule2, #c9be9e); font-weight: 600; }
    th.k, td.k { text-align: left; }
    th.a, td.a { text-align: right; }
    .arrow { text-align: center; color: var(--aac-color-steel, #6b6b64); width: 2em; }
    td.k { color: var(--aac-color-steel, #6b6b64); }
    .v { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-variant-numeric: tabular-nums; color: var(--aac-color-ink, #1a1a1a); text-align: right; }
    .next { color: var(--aac-color-navy, #21324f); font-weight: 600; }
    tbody td { border-bottom: 1px solid var(--aac-color-rule, #e2dac4); }
    .sec { padding: 9px 16px 2px; font-size: 9.5px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--aac-color-steel, #6b6b64); }
    .checks { margin: 0; padding: 0 16px 8px; list-style: none; }
    .checks li { display: flex; gap: 8px; align-items: baseline; font-size: 13px; color: var(--aac-color-ink, #1a1a1a); }
    .checks .c { color: var(--aac-color-navy, #21324f); font-weight: 700; }
    .evt { padding: 10px 16px; border-top: 1px solid var(--aac-color-rule2, #c9be9e); font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11.5px; color: var(--aac-color-steel, #6b6b64); word-break: break-word; }
    .evt b { color: var(--aac-color-navy, #21324f); font-weight: 600; }
    .foot { padding: 10px 16px; border-top: 1px solid var(--aac-color-rule, #e2dac4); font-size: 12px; color: var(--aac-color-ink, #1a1a1a); }
    .foot b { color: var(--aac-color-oxblood, #93302c); }
    .foot .m { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11px; color: var(--aac-color-steel, #6b6b64); }
  `;

  render() {
    const next = this.nonce + 1;
    const nullMoved = this.prevNull !== this.nextNull;
    return html`
      <article class="row">
        <div class="head">
          <div>
            <div class="label">Registry Row</div>
            <div class="name">${this.name}</div>
          </div>
          <div class="meta">4/REG · update(TRANSITION/1)<br />nonce ${this.nonce} → ${next}</div>
        </div>

        <table>
          <thead>
            <tr><th class="k">Commitment</th><th class="a">before</th><th class="arrow"></th><th class="a">after</th></tr>
          </thead>
          <tbody>
            <tr>
              <td class="k">account_root</td>
              <td class="v">${this.mid(this.prevAccount)}</td>
              <td class="arrow">→</td>
              <td class="v next">${this.mid(this.nextAccount)}</td>
            </tr>
            <tr>
              <td class="k">nullifier_root</td>
              <td class="v">${this.mid(this.prevNull)}</td>
              <td class="arrow">→</td>
              <td class="v next">${nullMoved ? this.mid(this.nextNull) : 'unchanged'}</td>
            </tr>
            <tr>
              <td class="k">nonce</td>
              <td class="v">${this.nonce}</td>
              <td class="arrow">→</td>
              <td class="v next">${next}</td>
            </tr>
          </tbody>
        </table>

        <div class="sec">Discharged · 3/PROOF §5</div>
        <ul class="checks">
          <li><span class="c">✓</span> UltraHonk proof verified on-chain</li>
          <li><span class="c">✓</span> old-root equality · the concurrency rule</li>
          <li><span class="c">✓</span> context pinned to the row</li>
        </ul>

        <div class="evt">
          event <b>Updated</b>(${this.name}, nonce ${next},
          ${this.mid(this.nextAccount)}, ${this.mid(this.nextNull)})
        </div>
        <div class="foot">
          The registry <b>refuses anything it cannot verify.</b>
          <span class="m">· HonkVerifier 23,782 B · EIP-170-fit · deploys on a live EVM</span>
        </div>
      </article>
    `;
  }
}

if (!customElements.get('aac-row')) customElements.define('aac-row', AacRow);
