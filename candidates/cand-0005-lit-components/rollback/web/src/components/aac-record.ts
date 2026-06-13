import { LitElement, html, css } from 'lit';

/** aac-record — a signed journal voucher. The core object is a record, not a
 *  screen: who signed, what moved, which ledger changed, what proof exists. */
export class AacRecord extends LitElement {
  static properties = {
    no: { type: String }, date: { type: String }, ledger: { type: String },
    proof: { type: String }, status: { type: String },
  };

  declare no: string;
  declare date: string;
  declare ledger: string;
  declare proof: string;
  declare status: 'recorded' | 'sealed' | 'pending';

  constructor() {
    super();
    this.no = 'AAC·000148213';
    this.date = '14 Jun 2026';
    this.ledger = 'accounts-payable.q2';
    this.proof = 'sha256 9f2c…a17b';
    this.status = 'recorded';
  }

  static styles = css`
    :host { display: block; font-family: var(--aac-grotesk, Inter, system-ui, sans-serif); }
    .rec { border: 1px solid var(--aac-color-navy, #21324f); background: var(--aac-color-bond, #fff); }
    .head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; padding: 12px 16px; border-bottom: 1px solid var(--aac-color-rule2, #c9be9e); }
    .label { font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; font-size: 12px; color: var(--aac-color-ink, #1a1a1a); }
    .no { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 12px; color: var(--aac-color-steel, #6b6b64); margin-top: 3px; }
    .date { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 12px; color: var(--aac-color-steel, #6b6b64); text-align: right; white-space: nowrap; }
    table { width: 100%; border-collapse: collapse; font-size: 14px; }
    th, td { padding: 9px 16px; text-align: left; }
    thead th { font-size: 10px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--aac-color-steel, #6b6b64); border-bottom: 1px solid var(--aac-color-rule2, #c9be9e); font-weight: 600; }
    .n { font-family: var(--aac-mono, "IBM Plex Mono", monospace); text-align: right; color: var(--aac-color-ink, #1a1a1a); font-variant-numeric: tabular-nums; }
    .acct { color: var(--aac-color-ink, #1a1a1a); }
    tbody td { border-bottom: 1px solid var(--aac-color-rule, #e2dac4); }
    tfoot td { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-weight: 600; color: var(--aac-color-ink, #1a1a1a); border-top: 3px double var(--aac-color-ink, #1a1a1a); font-variant-numeric: tabular-nums; }
    .totlabel { font-family: var(--aac-grotesk, Inter, sans-serif); font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; font-size: 11px; }
    .bal { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 9px 16px; font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 12px; color: var(--aac-color-navy, #21324f); border-top: 1px solid var(--aac-color-rule2, #c9be9e); }
    .bal b { font-family: var(--aac-grotesk, Inter, sans-serif); font-weight: 700; letter-spacing: 0.06em; }
    .prov { padding: 11px 16px; border-top: 1px solid var(--aac-color-rule, #e2dac4); font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11.5px; color: var(--aac-color-steel, #6b6b64); }
    .prov span { color: var(--aac-color-ink, #1a1a1a); }
  `;

  render() {
    return html`
      <article class="rec">
        <div class="head">
          <div>
            <div class="label">Journal Voucher</div>
            <div class="no">No. ${this.no}</div>
          </div>
          <div class="date">Posted ${this.date}<br />Epoch 0x1a4 · Block 77,412</div>
        </div>
        <table>
          <thead><tr><th>Account</th><th style="text-align:right">Debit</th><th style="text-align:right">Credit</th></tr></thead>
          <tbody>
            <tr><td class="acct">Finished Goods Inventory</td><td class="n">48,000.00</td><td class="n">—</td></tr>
            <tr><td class="acct">A/P — Hollis &amp; Crane Mill</td><td class="n">—</td><td class="n">48,000.00</td></tr>
          </tbody>
          <tfoot><tr><td class="totlabel">Totals</td><td class="n">48,000.00</td><td class="n">48,000.00</td></tr></tfoot>
        </table>
        <div class="bal"><span><b>Balanced</b> · Δ = 0 · K(M) class zero · pacioli_equal ✓</span><aac-stamp status=${this.status}></aac-stamp></div>
        <div class="prov">ledger <span>${this.ledger}</span> · proof <span>${this.proof}</span> · machine-checked</div>
      </article>
    `;
  }
}

if (!customElements.get('aac-record')) customElements.define('aac-record', AacRecord);
