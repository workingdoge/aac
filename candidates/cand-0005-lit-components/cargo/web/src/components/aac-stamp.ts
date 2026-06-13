import { LitElement, html, css } from 'lit';

/** aac-stamp — a status stamp. Status is stamped, not badged: a letterspaced
 *  keyline, coloured by the record's state. (No decorators — Vite/esbuild does
 *  not transpile them; we register the element directly.) */
export class AacStamp extends LitElement {
  static properties = { status: { type: String } };

  declare status: 'recorded' | 'reconciled' | 'sealed' | 'pending' | 'exception';

  constructor() {
    super();
    this.status = 'recorded';
  }

  static styles = css`
    :host { display: inline-block; }
    .s {
      display: inline-block;
      font-family: var(--aac-grotesk, Inter, system-ui, sans-serif);
      font-weight: 600;
      font-size: 0.68rem;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      border: 1.5px solid currentColor;
      border-radius: 2px;
      padding: 4px 11px;
      line-height: 1;
    }
    .recorded, .reconciled { color: var(--aac-color-navy, #21324f); }
    .sealed { color: var(--aac-color-oxblood, #93302c); }
    .pending { color: var(--aac-color-steel, #6b6b64); }
    .exception {
      color: var(--aac-color-cream, #f8f3e7);
      background: var(--aac-color-oxblood, #93302c);
      border-color: var(--aac-color-oxblood, #93302c);
    }
  `;

  render() {
    const label = this.textContent?.trim() || this.status;
    return html`<span class="s ${this.status}">${label}</span>`;
  }
}

if (!customElements.get('aac-stamp')) customElements.define('aac-stamp', AacStamp);
