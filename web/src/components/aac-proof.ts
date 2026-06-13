import { LitElement, html, css } from 'lit';

/** aac-proof — the proof terminal. A dark mono surface, identical in light and
 *  dark: proofs are invariant. Records what the verifiers discharged. */
export class AacProof extends LitElement {
  static properties = { record: { type: String }, hash: { type: String }, root: { type: String } };

  declare record: string;
  declare hash: string;
  declare root: string;

  constructor() {
    super();
    this.record = 'AAC·000148213';
    this.hash = 'sha256 9f2c…a17b';
    this.root = 'e7a0…4c19';
  }

  static styles = css`
    :host { display: block; }
    .term {
      background: #15171b;
      color: #ede7d6;
      border: 1px solid var(--aac-color-rule2, #c9be9e);
      padding: 16px 18px;
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 12.5px;
      line-height: 1.85;
    }
    .dim { color: #8c8678; }
    .ok { color: #7fb08a; }
    .k { color: #8c8678; display: inline-block; min-width: 4.5em; }
    .v { color: #ede7d6; }
  `;

  render() {
    return html`
      <div class="term">
        <div class="dim">// ledger.proof — verified</div>
        <div><span class="k">record</span><span class="v">${this.record}</span></div>
        <div><span class="k">proof</span><span class="v">${this.hash}</span></div>
        <div><span class="k">root</span><span class="v">${this.root}</span></div>
        <div><span class="k">status</span><span class="ok">Core.lean · machine-checked · 0 sorry</span></div>
      </div>
    `;
  }
}

if (!customElements.get('aac-proof')) customElements.define('aac-proof', AacProof);
