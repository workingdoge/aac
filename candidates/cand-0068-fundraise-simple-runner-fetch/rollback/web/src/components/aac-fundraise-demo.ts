import { LitElement, html, css } from 'lit';
import { fundraiseDemoSummary } from '../data/fundraise-demo-summary';

type FundraiseSummary = typeof fundraiseDemoSummary;
type RunState = 'idle' | 'running' | 'proved' | 'error';

/** aac-fundraise-demo — presentation console for the ProveKit fundraise path:
 *  private issuer roots -> VNET proof/workflow authorization -> local receipt
 *  token settlement. The component owns the live runner controls, starts from a
 *  ready-to-run state, and can replace it with a fresh localhost response. */
export class AacFundraiseDemo extends LitElement {
  static properties = {
    summary: { state: true },
    runState: { state: true },
    liveError: { state: true },
    liveElapsedMs: { state: true },
    sourceLabel: { state: true },
  };

  private summary: FundraiseSummary = this.readySummary();
  private runState: RunState = 'idle';
  private liveError = '';
  private liveElapsedMs: number | null = null;
  private sourceLabel = 'ready: no proof run yet';
  private runControl: HTMLAnchorElement | null = null;
  private captureControl: HTMLAnchorElement | null = null;
  private urlActionApplied = false;

  private readySummary(): FundraiseSummary {
    return {
      ...fundraiseDemoSummary,
      accepted: false,
      status: 'ready-to-run',
      commitments: {
        ...fundraiseDemoSummary.commitments,
        transition_set: null,
        vnet_public: null,
        subscription_set: null,
        bcc_set: null,
        bridge_settlement: null,
        mint_recipient_set: null,
        prev_balance_sheet_root: null,
        next_balance_sheet_root: null,
        prev_cap_table_root: null,
        next_cap_table_root: null,
      },
      proof: {
        mode: null,
        proof_system: null,
        proof_digest: null,
        verifier_key_digest: null,
        timings_ms: {},
      },
      workflow: {
        ...fundraiseDemoSummary.workflow,
        verifier_receipt_digest: null,
        authorizer_receipt_digest: null,
        action_digest: null,
        signature_status: 'not-run',
      },
      settlement: {
        ...fundraiseDemoSummary.settlement,
        token_contract: null,
        settlement_contract: null,
        authorizer: null,
        settlement_digest: null,
        transaction_hash: null,
        total_supply: null,
        balances: [],
      },
      claims: ['No proof has been run in this browser session yet.'],
      caveats: [
        'Press Run live proof to call the localhost ProveKit runner.',
        fundraiseDemoSummary.caveats[1],
      ],
    } as unknown as FundraiseSummary;
  }

  private short(value: string | null | undefined, head = 6, tail = 4): string {
    if (!value) return 'none';
    const prefix = value.startsWith('0x') ? '0x' : '';
    const raw = prefix ? value.slice(2) : value;
    if (raw.length <= head + tail + 1) return value;
    return `${prefix}${raw.slice(0, head)}…${raw.slice(-tail)}`;
  }

  private ms(value: number | undefined): string {
    if (typeof value !== 'number') return 'n/a';
    if (value >= 1000) return `${(value / 1000).toFixed(2)}s`;
    return `${value}ms`;
  }

  static styles = css`
    :host {
      display: block;
      font-family: var(--aac-grotesk, Inter, system-ui, sans-serif);
      color: var(--aac-color-ink, #1a1a1a);
    }

    .console {
      background: var(--aac-color-bond, #fff);
      border: 1px solid var(--aac-color-navy, #21324f);
      border-radius: var(--aac-radius-r, 2px);
      overflow: hidden;
    }

    .mast {
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 16px;
      padding: 18px 20px 16px;
      border-bottom: 1px solid var(--aac-color-rule2, #c9be9e);
      background:
        linear-gradient(90deg, color-mix(in srgb, var(--aac-color-navy, #21324f) 7%, transparent), transparent 55%),
        var(--aac-color-bond, #fff);
    }

    .eyebrow {
      color: var(--aac-color-oxblood, #93302c);
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }

    h2 {
      margin: 4px 0 0;
      font-size: clamp(24px, 3vw, 40px);
      line-height: 1;
      letter-spacing: 0;
      color: var(--aac-color-navy, #21324f);
      font-weight: 700;
      max-width: 760px;
    }

    .issuer {
      margin-top: 9px;
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 12px;
      color: var(--aac-color-steel, #6b6b64);
    }

    .status {
      align-self: start;
      border: 1px solid var(--aac-color-status-recorded, #21324f);
      color: var(--aac-color-status-recorded, #21324f);
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.11em;
      text-transform: uppercase;
      padding: 7px 10px;
      white-space: nowrap;
      transform: rotate(-1deg);
    }

    .live-box {
      align-self: start;
      display: grid;
      justify-items: end;
      gap: 9px;
    }

    .actions {
      display: flex;
      flex-wrap: wrap;
      justify-content: flex-end;
      gap: 7px;
    }

    ::slotted(a) {
      appearance: none;
      border: 1px solid var(--aac-color-navy, #21324f);
      border-radius: var(--aac-radius-r, 2px);
      display: inline-flex;
      align-items: center;
      min-height: 39px;
      padding: 9px 11px;
      font: inherit;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.1em;
      text-transform: uppercase;
      cursor: pointer;
      text-decoration: none;
    }

    ::slotted(a[data-fundraise-action="run-live-proof"]) {
      background: var(--aac-color-navy, #21324f);
      color: var(--aac-color-bond, #fff);
    }

    ::slotted(a[data-fundraise-action="show-capture"]) {
      background: transparent;
      color: var(--aac-color-navy, #21324f);
    }

    ::slotted(a:hover),
    ::slotted(a:focus-visible) {
      background: var(--aac-color-oxblood, #93302c);
      border-color: var(--aac-color-oxblood, #93302c);
      color: var(--aac-color-bond, #fff);
      outline: none;
    }

    ::slotted(a[aria-disabled="true"]) {
      cursor: wait;
      opacity: 0.72;
    }

    .live-note {
      max-width: 220px;
      color: var(--aac-color-steel, #6b6b64);
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 10.5px;
      text-align: right;
      overflow-wrap: anywhere;
    }

    .live-note.error {
      color: var(--aac-color-oxblood, #93302c);
    }

    .numbers {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      border-bottom: 1px solid var(--aac-color-rule2, #c9be9e);
    }

    .num {
      padding: 13px 20px;
      border-right: 1px solid var(--aac-color-rule, #e2dac4);
      min-width: 0;
    }

    .num:last-child { border-right: 0; }
    .num b {
      display: block;
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 24px;
      line-height: 1.1;
      color: var(--aac-color-ink, #1a1a1a);
      font-variant-numeric: tabular-nums;
    }
    .num span {
      display: block;
      margin-top: 4px;
      color: var(--aac-color-steel, #6b6b64);
      font-size: 10px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    .flow {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(0, 1.06fr) minmax(0, 1fr);
      min-height: 420px;
    }

    .lane {
      min-width: 0;
      padding: 16px 18px 18px;
      border-right: 1px solid var(--aac-color-rule2, #c9be9e);
    }

    .lane:last-child { border-right: 0; }

    .lane-title {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 13px;
      padding-bottom: 8px;
      border-bottom: 3px double var(--aac-color-ink, #1a1a1a);
    }

    .lane-title b {
      color: var(--aac-color-ink, #1a1a1a);
      font-size: 12px;
      letter-spacing: 0.14em;
      text-transform: uppercase;
    }

    .lane-title span {
      color: var(--aac-color-steel, #6b6b64);
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 11px;
      white-space: nowrap;
    }

    .root-row,
    .digest-row,
    .contract-row {
      display: grid;
      grid-template-columns: minmax(8.5em, 0.6fr) minmax(0, 1fr);
      gap: 12px;
      align-items: baseline;
      padding: 8px 0;
      border-bottom: 1px solid var(--aac-color-rule, #e2dac4);
    }

    .root-row {
      grid-template-columns: 1fr;
      gap: 4px;
    }

    .root-row .val {
      justify-self: start;
      white-space: nowrap;
      font-size: 11.5px;
    }

    .key {
      color: var(--aac-color-steel, #6b6b64);
      font-size: 11px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .val {
      justify-self: end;
      min-width: 0;
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      color: var(--aac-color-ink, #1a1a1a);
      font-size: 12px;
      font-variant-numeric: tabular-nums;
      overflow-wrap: anywhere;
    }

    .next { color: var(--aac-color-navy, #21324f); font-weight: 600; }
    .sealed { color: var(--aac-color-oxblood, #93302c); }

    .slips {
      display: grid;
      gap: 8px;
      margin-top: 15px;
    }

    .slip {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      padding: 8px 10px;
      border: 1px solid var(--aac-color-rule2, #c9be9e);
      background: var(--aac-color-field, #fcf9f0);
      min-width: 0;
    }

    .slip span:first-child {
      color: var(--aac-color-steel, #6b6b64);
      font-size: 10px;
      letter-spacing: 0.1em;
      text-transform: uppercase;
    }

    .slip span:last-child {
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 11px;
      color: var(--aac-color-navy, #21324f);
      overflow-wrap: anywhere;
      text-align: right;
    }

    .spine {
      display: grid;
      gap: 10px;
      position: relative;
    }

    .spine::before {
      content: "";
      position: absolute;
      left: 15px;
      top: 19px;
      bottom: 19px;
      width: 1px;
      background: var(--aac-color-rule2, #c9be9e);
    }

    .step {
      display: grid;
      grid-template-columns: 31px minmax(0, 1fr);
      gap: 11px;
      align-items: start;
      position: relative;
    }

    .mark {
      width: 31px;
      height: 31px;
      display: grid;
      place-items: center;
      border: 1px solid var(--aac-color-navy, #21324f);
      background: var(--aac-color-bond, #fff);
      color: var(--aac-color-navy, #21324f);
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-weight: 600;
      font-size: 12px;
      z-index: 1;
    }

    .step-body {
      min-width: 0;
      border-bottom: 1px solid var(--aac-color-rule, #e2dac4);
      padding-bottom: 10px;
    }

    .step-body b {
      display: block;
      color: var(--aac-color-ink, #1a1a1a);
      font-size: 13px;
      margin-bottom: 3px;
    }

    .step-body code {
      display: block;
      color: var(--aac-color-steel, #6b6b64);
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 11px;
      overflow-wrap: anywhere;
      background: transparent;
      padding: 0;
    }

    .timings {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 1px;
      margin-top: 16px;
      border: 1px solid var(--aac-color-rule2, #c9be9e);
      background: var(--aac-color-rule2, #c9be9e);
    }

    .time {
      background: var(--aac-color-bond, #fff);
      padding: 10px;
      min-width: 0;
    }

    .time b {
      display: block;
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      color: var(--aac-color-navy, #21324f);
      font-size: 13px;
    }

    .time span {
      color: var(--aac-color-steel, #6b6b64);
      font-size: 10px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }

    .bars {
      display: grid;
      gap: 10px;
      margin-top: 14px;
    }

    .empty {
      margin-top: 14px;
      padding: 10px;
      border: 1px dashed var(--aac-color-rule2, #c9be9e);
      color: var(--aac-color-steel, #6b6b64);
      font-size: 11.5px;
      line-height: 1.45;
    }

    .bar-row {
      display: grid;
      gap: 6px;
    }

    .bar-top {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      font-family: var(--aac-mono, "IBM Plex Mono", monospace);
      font-size: 11.5px;
      color: var(--aac-color-ink, #1a1a1a);
    }

    .bar-track {
      height: 10px;
      border: 1px solid var(--aac-color-rule2, #c9be9e);
      background: var(--aac-color-field, #fcf9f0);
      position: relative;
      overflow: hidden;
    }

    .bar {
      height: 100%;
      background: var(--aac-color-navy, #21324f);
    }

    .contract-row {
      grid-template-columns: minmax(6.5em, 0.45fr) minmax(0, 1fr);
    }

    .notice {
      padding: 12px 18px;
      border-top: 1px solid var(--aac-color-rule2, #c9be9e);
      color: var(--aac-color-steel, #6b6b64);
      font-size: 12px;
      line-height: 1.55;
    }

    .notice b { color: var(--aac-color-oxblood, #93302c); }

    @media (max-width: 900px) {
      .mast { grid-template-columns: 1fr; }
      .status { justify-self: start; }
      .live-box { justify-items: start; }
      .actions { justify-content: flex-start; }
      .live-note { text-align: left; }
      .numbers { grid-template-columns: 1fr; }
      .num { border-right: 0; border-bottom: 1px solid var(--aac-color-rule, #e2dac4); }
      .num:last-child { border-bottom: 0; }
      .flow { grid-template-columns: 1fr; min-height: 0; }
      .lane { border-right: 0; border-bottom: 1px solid var(--aac-color-rule2, #c9be9e); }
      .lane:last-child { border-bottom: 0; }
      .root-row, .digest-row, .contract-row { grid-template-columns: 1fr; gap: 4px; }
      .val { justify-self: start; }
    }
  `;

  private apiEndpoint(): string {
    const base = this.getAttribute('api-base') || 'http://127.0.0.1:8787';
    return `${base.replace(/\/+$/, '')}/api/fundraise/run`;
  }

  connectedCallback() {
    super.connectedCallback();
    this.ensureOwnedControls();
    this.syncOwnedControls();
    this.applyUrlAction();
  }

  updated() {
    this.syncOwnedControls();
  }

  disconnectedCallback() {
    this.clearControlHandlers(this.runControl);
    this.clearControlHandlers(this.captureControl);
    this.runControl = null;
    this.captureControl = null;
    super.disconnectedCallback();
  }

  private ensureOwnedControls() {
    const run = this.ownedButton('run-live-proof', 'fundraise-run', 'run');
    const capture = this.ownedButton('show-capture', 'fundraise-capture', 'ghost');

    if (this.runControl !== run) {
      this.clearControlHandlers(this.runControl);
      this.bindControlHandlers(run, this.handleRunControl);
      this.runControl = run;
    }
    if (this.captureControl !== capture) {
      this.clearControlHandlers(this.captureControl);
      this.bindControlHandlers(capture, this.handleCaptureControl);
      this.captureControl = capture;
    }
  }

  private ownedButton(action: string, slot: string, className: string): HTMLAnchorElement {
    const existing = Array.from(this.children).find(
      (child): child is HTMLAnchorElement =>
        child instanceof HTMLAnchorElement && child.dataset.fundraiseAction === action,
    );
    if (existing) return existing;
    const button = document.createElement('a');
    button.href = this.fallbackHref(action);
    button.role = 'button';
    button.slot = slot;
    button.className = className;
    button.dataset.fundraiseAction = action;
    this.append(button);
    return button;
  }

  private bindControlHandlers(button: HTMLAnchorElement, handler: (event?: Event) => void) {
    button.onclick = handler;
    button.onpointerup = handler;
    button.onkeydown = (event: KeyboardEvent) => {
      if (event.key === 'Enter' || event.key === ' ') handler(event);
    };
  }

  private clearControlHandlers(button: HTMLAnchorElement | null) {
    if (!button) return;
    button.onclick = null;
    button.onpointerup = null;
    button.onkeydown = null;
  }

  private syncOwnedControls() {
    this.ensureOwnedControls();
    if (this.runControl) {
      this.runControl.textContent = this.runButtonText();
      this.runControl.href = this.fallbackHref('run-live-proof');
      this.runControl.setAttribute('aria-disabled', this.runState === 'running' ? 'true' : 'false');
    }
    if (this.captureControl) {
      this.captureControl.textContent = 'Show capture';
      this.captureControl.href = this.fallbackHref('show-capture');
      this.captureControl.setAttribute('aria-disabled', this.runState === 'running' ? 'true' : 'false');
    }
  }

  private fallbackHref(action: string): string {
    const url = new URL(window.location.href);
    url.searchParams.set('fundraise', action === 'run-live-proof' ? 'run' : 'capture');
    url.hash = 'fundraise-demo';
    return `${url.pathname}${url.search}${url.hash}`;
  }

  private applyUrlAction() {
    if (this.urlActionApplied) return;
    this.urlActionApplied = true;
    const action = new URLSearchParams(window.location.search).get('fundraise');
    if (action === 'run') {
      void this.runLiveProof();
    } else if (action === 'capture') {
      this.showCapturedReceipt();
    }
  }

  private readonly handleRunControl = (event?: Event) => {
    event?.preventDefault();
    if (this.runState === 'running') return;
    void this.runLiveProof();
  };

  private readonly handleCaptureControl = (event?: Event) => {
    event?.preventDefault();
    if (this.runState === 'running') return;
    this.showCapturedReceipt();
  };

  private async runLiveProof() {
    if (this.runState === 'running') return;
    const started = Date.now();
    this.runState = 'running';
    this.liveError = '';
    this.liveElapsedMs = null;
    try {
      const response = await fetch(this.apiEndpoint(), {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ settle_local: false }),
      });
      const payload = await response.json().catch(() => null);
      if (!response.ok || payload?.accepted !== true || !payload.summary) {
        throw new Error(payload?.message || payload?.reason || `HTTP ${response.status}`);
      }
      this.summary = payload.summary;
      this.liveElapsedMs = payload.elapsed_ms ?? Date.now() - started;
      this.sourceLabel = 'live proof';
      this.runState = 'proved';
    } catch (error) {
      this.runState = 'error';
      this.liveError = error instanceof Error ? error.message : 'live runner failed';
    }
  }

  private showCapturedReceipt() {
    if (this.runState === 'running') return;
    this.summary = fundraiseDemoSummary;
    this.liveElapsedMs = null;
    this.liveError = '';
    this.sourceLabel = 'captured fallback';
    this.runState = 'idle';
  }

  private displayStatus(status: string): string {
    return status.replaceAll('-', ' ');
  }

  private runButtonText(): string {
    if (this.runState === 'running') return 'Running proof';
    if (this.runState === 'proved') return 'Run again';
    return 'Run live proof';
  }

  private runNote(): string {
    if (this.runState === 'running') return 'provekit prepare/prove/verify in progress';
    if (this.runState === 'proved') return `fresh receipt · ${this.ms(this.liveElapsedMs ?? undefined)}`;
    if (this.runState === 'error') return `runner error · ${this.liveError}`;
    return this.sourceLabel;
  }

  render() {
    const s = this.summary;
    const balances = s.settlement.balances ?? [];
    const total = s.settlement.total_supply || s.economics.issued_unit_total || 1;
    return html`
      <section class="console" aria-label="Fundraise settlement demo">
        <div class="mast">
          <div>
            <div class="eyebrow">Private treasury issuance</div>
            <h2>${this.runState === 'idle' && !s.accepted ? 'Private fundraise ready to prove.' : 'Seed round settled against private books.'}</h2>
            <div class="issuer">${s.issuer_name} · ${s.round_id}</div>
          </div>
          <div class="live-box">
            <div class="status">${this.displayStatus(s.status)}</div>
            <div class="actions">
              <slot name="fundraise-run"></slot>
              <slot name="fundraise-capture"></slot>
            </div>
            <div class=${`live-note ${this.runState === 'error' ? 'error' : ''}`}>${this.runNote()}</div>
          </div>
        </div>

        <div class="numbers">
          <div class="num"><b>${s.economics.settlement_amount_total}</b><span>target cash</span></div>
          <div class="num"><b>${s.economics.issued_unit_total}</b><span>target receipt units</span></div>
          <div class="num"><b>${s.economics.recipient_count}</b><span>subscribers in packet</span></div>
        </div>

        <div class="flow">
          <section class="lane">
            <div class="lane-title"><b>Private row</b><span>roots move</span></div>
            ${this.rootRow('balance sheet', s.commitments.prev_balance_sheet_root, s.commitments.next_balance_sheet_root)}
            ${this.rootRow('cap table', s.commitments.prev_cap_table_root, s.commitments.next_cap_table_root)}
            <div class="slips">
              ${this.slip('transition set', s.commitments.transition_set)}
              ${this.slip('subscription set', s.commitments.subscription_set)}
              ${this.slip('bcc set', s.commitments.bcc_set)}
              ${this.slip('bridge context', s.commitments.bridge_settlement)}
            </div>
          </section>

          <section class="lane">
            <div class="lane-title"><b>Proof spine</b><span>${s.proof.proof_system ?? 'not run'}</span></div>
            <div class="spine">
              ${this.step('P', s.proof.proof_digest ? 'ProveKit accepted VNET' : 'ProveKit not run', s.proof.proof_digest)}
              ${this.step('W', s.workflow.authorizer_receipt_digest ? 'Workflow authorized mint' : 'Workflow waiting', s.workflow.authorizer_receipt_digest)}
              ${this.step('S', s.workflow.action_digest ? 'Settlement action prepared' : 'Settlement not prepared', s.workflow.action_digest)}
            </div>
            <div class="timings">
              <div class="time"><b>${this.ms(s.proof.timings_ms.prepare)}</b><span>prepare</span></div>
              <div class="time"><b>${this.ms(s.proof.timings_ms.prove)}</b><span>prove</span></div>
              <div class="time"><b>${this.ms(s.proof.timings_ms.verify)}</b><span>verify</span></div>
            </div>
          </section>

          <section class="lane">
            <div class="lane-title"><b>Settlement</b><span>local EVM</span></div>
            <div class="root-row">
              <span class="key">total supply</span>
              <span class="val next">${s.settlement.total_supply ?? 'pending'}</span>
            </div>
            ${balances.length
              ? html`
                  <div class="bars">
                    ${balances.map(
                      (item) => html`
                        <div class="bar-row">
                          <div class="bar-top">
                            <span>${this.short(item.account, 5, 4)}</span>
                            <span>${item.amount}</span>
                          </div>
                          <div class="bar-track">
                            <div class="bar" style=${`width: ${Math.max(0, Math.min(100, (item.amount / total) * 100))}%`}></div>
                          </div>
                        </div>
                      `,
                    )}
                  </div>
                `
              : html`<div class="empty">Mint authorization is proof-bound and waiting for settlement submission.</div>`}
            ${this.contractRow('token', s.settlement.token_contract)}
            ${this.contractRow('settlement', s.settlement.settlement_contract)}
            ${this.contractRow('tx', s.settlement.transaction_hash)}
          </section>
        </div>

        <div class="notice">
          <b>Boundary:</b> ${s.caveats[1]}
        </div>
      </section>
    `;
  }

  private rootRow(label: string, before: string, after: string) {
    return html`
      <div class="root-row">
        <span class="key">${label}</span>
        <span class="val"><span>${this.short(before)}</span> → <span class="next">${this.short(after)}</span></span>
      </div>
    `;
  }

  private slip(label: string, value: string) {
    return html`<div class="slip"><span>${label}</span><span>${this.short(value)}</span></div>`;
  }

  private step(mark: string, label: string, digest: string) {
    return html`
      <div class="step">
        <div class="mark">${mark}</div>
        <div class="step-body">
          <b>${label}</b>
          <code>${this.short(digest, 10, 8)}</code>
        </div>
      </div>
    `;
  }

  private contractRow(label: string, value: string | null) {
    return html`
      <div class="contract-row">
        <span class="key">${label}</span>
        <span class="val sealed">${this.short(value, 6, 4)}</span>
      </div>
    `;
  }
}

if (!customElements.get('aac-fundraise-demo')) {
  customElements.define('aac-fundraise-demo', AacFundraiseDemo);
}
