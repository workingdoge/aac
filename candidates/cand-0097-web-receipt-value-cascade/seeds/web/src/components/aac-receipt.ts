import { LitElement, html, css } from 'lit';

/** aac-receipt — a BalancedVectorReceipt (Design Note 0001 / EVENT-COMPLETE/1).
 *  The clearing object is a *vector* journal: it balances per incommensurable
 *  basis dimension (USD, fabric, garment…), never collapsed through price. This
 *  renders the buyer/supplier event from the shipped Pⁿ conformance vector —
 *  every dimension's debit total equals its credit total, with role coverage and
 *  proof status. Themed by --aac-* tokens through the shadow DOM. */
export class AacReceipt extends LitElement {
  // Basis dimensions and the fabric/USD/garment event (the conformance vector).
  private dims = [
    { key: 'usd', label: 'USD', kind: 'money' as const },
    { key: 'fabric', label: 'fabric · m', kind: 'unit' as const },
    { key: 'garment', label: 'garment · u', kind: 'unit' as const },
  ];
  private rows = [
    { acct: 'Buyer · Inventory', side: 'Dr', v: [0, 50, 0] },
    { acct: 'Supplier · Receivable', side: 'Dr', v: [10000, 0, 0] },
    { acct: 'Supplier · Inventory', side: 'Cr', v: [0, 50, 0] },
    { acct: 'Buyer · Payable', side: 'Cr', v: [10000, 0, 0] },
  ];
  private proofInputs = [
    {
      label: 'event_commitment · tag 120',
      value: '0x22dde87bb42e2c0578693c0cc412f172b8ebd73de6201941f8eed299685a6d5a',
    },
    {
      label: 'participant_set · tag 124',
      value: '0x2be2070bf701535452f715ebd9898b4fb71a09732ae2401e05a698b227459667',
    },
    {
      label: 'journal_commitment · tag 3',
      value: '0x1bd134b20563b6f8e23129e7af09640e7024b7ef5fe4619807b07f8fdab896e2',
    },
    {
      label: 'event_nullifier · tag 125',
      value: '0x2425a832b86b32f7ad27a53c591bf3e4de047adc638caddbe8830fd7038c3545',
    },
  ];

  private fmt(n: number, kind: 'money' | 'unit'): string {
    if (n === 0) return '—';
    return kind === 'money' ? (n / 100).toFixed(2) : String(n);
  }

  private totals(side: string): number[] {
    return this.dims.map((_, j) =>
      this.rows.filter((r) => r.side === side).reduce((s, r) => s + r.v[j], 0),
    );
  }

  static styles = css`
    :host { display: block; font-family: var(--aac-grotesk, Inter, system-ui, sans-serif); }
    .rec { border: 1px solid var(--aac-color-navy, #21324f); background: var(--aac-color-bond, #fff); }
    .head { display: flex; justify-content: space-between; align-items: flex-start; gap: 16px; padding: 12px 16px; border-bottom: 1px solid var(--aac-color-rule2, #c9be9e); }
    .label { font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; font-size: 12px; color: var(--aac-color-ink, #1a1a1a); }
    .sub { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11.5px; color: var(--aac-color-steel, #6b6b64); margin-top: 3px; }
    .meta { text-align: right; font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11px; color: var(--aac-color-steel, #6b6b64); white-space: nowrap; }
    .roles { display: flex; gap: 8px; align-items: center; padding: 9px 16px; border-bottom: 1px solid var(--aac-color-rule, #e2dac4); flex-wrap: wrap; }
    .roles .t { font-size: 10px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--aac-color-steel, #6b6b64); margin-right: 2px; }
    .role { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11.5px; color: var(--aac-color-navy, #21324f); border: 1px solid var(--aac-color-navy, #21324f); border-radius: 2px; padding: 2px 8px; }
    .role b { color: var(--aac-color-oxblood, #93302c); }
    .inputs { display: grid; grid-template-columns: max-content minmax(0, 1fr); gap: 5px 12px; padding: 9px 16px; border-bottom: 1px solid var(--aac-color-rule, #e2dac4); font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 10.5px; }
    .input-k { color: var(--aac-color-steel, #6b6b64); white-space: nowrap; }
    .input-v { color: var(--aac-color-navy, #21324f); overflow-wrap: anywhere; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { padding: 7px 16px; text-align: right; }
    th.acct, td.acct { text-align: left; }
    th.side, td.side { text-align: center; width: 2.2em; }
    thead th { font-size: 9.5px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--aac-color-steel, #6b6b64); border-bottom: 1px solid var(--aac-color-rule2, #c9be9e); font-weight: 600; }
    tbody td { border-bottom: 1px solid var(--aac-color-rule, #e2dac4); }
    .n { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-variant-numeric: tabular-nums; color: var(--aac-color-ink, #1a1a1a); }
    .z { color: var(--aac-color-rule2, #c9be9e); }
    .side { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11px; color: var(--aac-color-steel, #6b6b64); }
    tfoot td { font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-weight: 600; font-variant-numeric: tabular-nums; color: var(--aac-color-ink, #1a1a1a); }
    tfoot tr.dr td { border-top: 3px double var(--aac-color-ink, #1a1a1a); }
    tfoot .lbl { font-family: var(--aac-grotesk, Inter, sans-serif); font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; font-size: 10px; text-align: left; }
    tfoot tr.bal td { color: var(--aac-color-navy, #21324f); }
    .ok { color: var(--aac-color-navy, #21324f); font-weight: 700; }
    .ft { padding: 11px 16px; border-top: 1px solid var(--aac-color-rule2, #c9be9e); font-family: var(--aac-mono, "IBM Plex Mono", monospace); font-size: 11.5px; color: var(--aac-color-steel, #6b6b64); display: flex; flex-wrap: wrap; gap: 6px 12px; }
    .ft .g { color: var(--aac-color-navy, #21324f); }
  `;

  render() {
    const dr = this.totals('Dr');
    const cr = this.totals('Cr');
    const balanced = dr.every((v, j) => v === cr[j]);
    return html`
      <article class="rec">
        <div class="head">
          <div>
            <div class="label">Balanced Vector Receipt</div>
            <div class="sub">Goods receipt + invoice · rulebook 7c1a…e9</div>
          </div>
          <div class="meta">EVENT-COMPLETE/1<br />basis P³ · 2 parties</div>
        </div>

        <div class="roles">
          <span class="t">Roles</span>
          <span class="role">Buyer <b>✓</b></span>
          <span class="role">Supplier <b>✓</b></span>
          <span class="t" style="margin-left:auto">coverage complete</span>
        </div>

        <div class="inputs" aria-label="EVENT-COMPLETE public inputs">
          ${this.proofInputs.map(
            (input) => html`<span class="input-k">${input.label}</span><span class="input-v">${input.value}</span>`,
          )}
        </div>

        <table>
          <thead>
            <tr>
              <th class="acct">Account</th>
              <th class="side"></th>
              ${this.dims.map((d) => html`<th>${d.label}</th>`)}
            </tr>
          </thead>
          <tbody>
            ${this.rows.map(
              (r) => html`<tr>
                <td class="acct">${r.acct}</td>
                <td class="side"><span class="side">${r.side}</span></td>
                ${r.v.map(
                  (n, j) =>
                    html`<td class="n ${n === 0 ? 'z' : ''}">${this.fmt(n, this.dims[j].kind)}</td>`,
                )}
              </tr>`,
            )}
          </tbody>
          <tfoot>
            <tr class="dr">
              <td class="lbl" colspan="2">Total Dr</td>
              ${dr.map((n, j) => html`<td class="n">${this.fmt(n, this.dims[j].kind)}</td>`)}
            </tr>
            <tr>
              <td class="lbl" colspan="2">Total Cr</td>
              ${cr.map((n, j) => html`<td class="n">${this.fmt(n, this.dims[j].kind)}</td>`)}
            </tr>
            <tr class="bal">
              <td class="lbl" colspan="2">Balance</td>
              ${dr.map((n, j) => html`<td class="n ok">${n === cr[j] ? '✓' : '✗'}</td>`)}
            </tr>
          </tfoot>
        </table>

        <div class="ft">
          <span class="g">P³ zero-account ${balanced ? '✓' : '✗'}</span>
          <span>· every dimension balances natively (no numeraire)</span>
          <span>· proof <span class="g">✓</span></span>
          <span>· event nullifier <span class="g">spent</span></span>
        </div>
      </article>
    `;
  }
}

if (!customElements.get('aac-receipt')) customElements.define('aac-receipt', AacReceipt);
