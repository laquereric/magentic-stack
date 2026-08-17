import * as vscode from 'vscode';
import type { JourneyStateService } from './state';
import { spineFor } from './spines';
import type { JourneyState, JourneyTab, StepDef } from './types';
import { loadCidState, type Op } from '../cid';

export class JourneyPanel {
  public static current: JourneyPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private disposables: vscode.Disposable[] = [];

  private constructor(
    panel: vscode.WebviewPanel,
    private readonly svc: JourneyStateService,
  ) {
    this.panel = panel;
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage(
      (msg) => { void this.onMessage(msg); },
      null,
      this.disposables
    );
    this.disposables.push(this.svc.onDidChange(() => this.render()));
    this.render();
  }

  static show(svc: JourneyStateService): JourneyPanel {
    if (JourneyPanel.current) {
      JourneyPanel.current.panel.reveal(vscode.ViewColumn.Beside);
      JourneyPanel.current.render();
      return JourneyPanel.current;
    }
    const panel = vscode.window.createWebviewPanel(
      'threedotJourney',
      '3dot Cyborg Journey',
      vscode.ViewColumn.Beside,
      { enableScripts: true, retainContextWhenHidden: true }
    );
    JourneyPanel.current = new JourneyPanel(panel, svc);
    return JourneyPanel.current;
  }

  render(): void {
    const state = this.svc.snapshot;
    this.panel.webview.html = this.html(state);
  }

  private async onMessage(msg: {
    type: string;
    command?: string;
    persona?: string;
    tab?: string;
  }): Promise<void> {
    switch (msg.type) {
      case 'runCommand':
        if (msg.command) {
          await vscode.commands.executeCommand(msg.command);
          this.render();
        }
        break;
      case 'selectPersona':
        if (msg.persona === 'rails' || msg.persona === 'javascript') {
          await vscode.commands.executeCommand('threedot.journey.selectPersona', msg.persona);
          this.render();
        }
        break;
      case 'selectTab': {
        const tab: JourneyTab = msg.tab === 'run' ? 'run' : 'develop';
        this.svc.setActiveTab(tab);
        this.render();
        break;
      }
      case 'refresh':
        this.svc.load();
        this.render();
        break;
      default:
        break;
    }
  }

  private html(state: JourneyState): string {
    const activeTab: JourneyTab = state.activeTab === 'run' ? 'run' : 'develop';
    const developPane = this.developHtml(state);
    const runPane = this.runHtml(state);

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<style>
  :root {
    color-scheme: light dark;
    --bg: var(--vscode-editor-background);
    --fg: var(--vscode-editor-foreground);
    --muted: var(--vscode-descriptionForeground);
    --border: var(--vscode-panel-border, #444);
    --accent: var(--vscode-button-background);
    --accent-fg: var(--vscode-button-foreground);
    --card: var(--vscode-sideBar-background);
  }
  body { font-family: var(--vscode-font-family); color: var(--fg); background: var(--bg); margin: 0; padding: 16px 18px 32px; }
  h1 { font-size: 18px; margin: 0 0 8px; }
  h2 { font-size: 15px; margin: 0 0 10px; }
  h3 { font-size: 14px; margin: 0 0 6px; }
  p { margin: 0 0 10px; color: var(--muted); font-size: 12.5px; line-height: 1.45; }
  .muted { color: var(--muted); }
  .top { display:flex; flex-wrap:wrap; gap:8px; align-items:center; margin-bottom:14px; }
  .chip { font-size: 11px; border: 1px solid var(--border); border-radius: 999px; padding: 4px 10px; }
  .row { display:flex; gap:8px; flex-wrap:wrap; margin: 10px 0; }
  button {
    background: var(--accent); color: var(--accent-fg); border: 0; border-radius: 6px;
    padding: 7px 12px; cursor: pointer; font-size: 12px;
  }
  button:disabled { opacity: 0.45; cursor: not-allowed; }
  button.ghost { background: transparent; color: var(--fg); border: 1px solid var(--border); }
  .tabs {
    display: flex; gap: 0; border-bottom: 1px solid var(--border); margin: 0 0 16px;
  }
  .tab {
    background: transparent; color: var(--muted); border: 0; border-bottom: 2px solid transparent;
    border-radius: 0; padding: 10px 16px; font-weight: 600; cursor: pointer; font-size: 13px;
  }
  .tab.active {
    color: var(--fg); border-bottom-color: var(--accent);
  }
  .tab-hint {
    font-size: 11px; color: var(--muted); margin: -8px 0 14px; line-height: 1.4;
  }
  .pane { display: none; }
  .pane.active { display: block; }
  .step {
    background: var(--card); border: 1px solid var(--border); border-radius: 10px;
    padding: 12px 14px; margin-bottom: 10px;
  }
  .step.current { border-color: var(--accent); }
  .step.locked { opacity: 0.55; }
  .step.done { border-left: 3px solid #3dd68c; }
  .step.available { border-left: 3px solid var(--accent); }
  .meta { display:flex; gap:8px; align-items:center; margin-bottom:6px; font-size: 11px; color: var(--muted); }
  .idx { font-weight: 700; color: var(--fg); }
  .badge { border-radius: 4px; padding: 1px 6px; border: 1px solid var(--border); }
  .badge.done { color: #3dd68c; }
  .badge.available { color: var(--accent-fg); background: var(--accent); border-color: transparent; }
  .badge.locked { opacity: 0.7; }
  .footer { margin-top: 16px; font-size: 11px; color: var(--muted); }
  .card {
    background: var(--card); border: 1px solid var(--border); border-radius: 10px;
    padding: 14px; margin-bottom: 12px;
  }
  .card.placeholder {
    border-style: dashed; border-color: var(--muted);
  }
  .card h2 .mode {
    font-size: 11px; font-weight: 600; letter-spacing: .04em; text-transform: uppercase;
    color: var(--muted); margin-left: 8px;
  }
  table { width: 100%; border-collapse: collapse; font-size: 12px; }
  th, td { text-align: left; padding: 8px 6px; border-bottom: 1px solid var(--border); vertical-align: top; }
  th { color: var(--muted); font-weight: 600; font-size: 11px; }
  .mono { font-family: var(--vscode-editor-font-family, monospace); font-size: 11px; }
  .banner {
    display: flex; gap: 10px; align-items: flex-start;
    padding: 10px 12px; border-radius: 8px; margin-bottom: 12px;
    border: 1px solid var(--border); background: rgba(110,168,255,.08);
  }
  .banner strong { display: block; margin-bottom: 4px; }
</style>
</head>
<body>
  <div class="top">
    <h1>Cyborg Journey</h1>
    <button class="ghost" id="refresh">Refresh</button>
    <button class="ghost" data-cmd="threedot.journey.start">Start / restart</button>
    <div class="chip">mode <strong>${activeTab === 'run' ? 'RUN' : 'Develop'}</strong></div>
  </div>

  <div class="tabs" role="tablist">
    <button class="tab ${activeTab === 'develop' ? 'active' : ''}" data-tab="develop" role="tab" aria-selected="${activeTab === 'develop'}">Develop</button>
    <button class="tab ${activeTab === 'run' ? 'active' : ''}" data-tab="run" role="tab" aria-selected="${activeTab === 'run'}">RUN</button>
  </div>
  <p class="tab-hint">
    <strong>Develop</strong> = syntax / coding help (journey spine, CID affordances).
    <strong>RUN</strong> = runtime assistance (deployed pod CID + Switchyard-backed help).
    Always know which meaning of threedot you are addressing.
  </p>

  <div class="pane ${activeTab === 'develop' ? 'active' : ''}" data-pane="develop" role="tabpanel">
    ${developPane}
  </div>
  <div class="pane ${activeTab === 'run' ? 'active' : ''}" data-pane="run" role="tabpanel">
    ${runPane}
  </div>

  <div class="footer">
    State: <code>.threedot/journey.json</code> (incl. <code>activeTab</code>) ·
    gates unlock only when prior step evidence exists ·
    Code altitude reuses … completion, embedCID, CodeLens, diagnostics, CID tree.
  </div>
  <script>
    const vscode = acquireVsCodeApi();
    document.getElementById('refresh')?.addEventListener('click', () => vscode.postMessage({ type: 'refresh' }));
    document.querySelectorAll('[data-cmd]').forEach((el) => {
      el.addEventListener('click', () => {
        if (el.disabled) return;
        vscode.postMessage({ type: 'runCommand', command: el.getAttribute('data-cmd') });
      });
    });
    document.querySelectorAll('[data-persona]').forEach((el) => {
      el.addEventListener('click', () => {
        vscode.postMessage({ type: 'selectPersona', persona: el.getAttribute('data-persona') });
      });
    });
    document.querySelectorAll('[data-tab]').forEach((el) => {
      el.addEventListener('click', () => {
        vscode.postMessage({ type: 'selectTab', tab: el.getAttribute('data-tab') });
      });
    });
  </script>
</body>
</html>`;
  }

  /** TAB 1 — Develop: existing journey spine UI (unchanged behavior). */
  private developHtml(state: JourneyState): string {
    const persona = state.persona;
    const spine: StepDef[] = persona ? spineFor(persona) : [];
    const stepsHtml = spine.map((s) => {
      const check = state.stepChecks[s.id];
      const st = check?.status ?? 'locked';
      const current = state.currentStep === s.id;
      const disabled = st === 'locked' ? 'disabled' : '';
      const badge = st.toUpperCase();
      return `
        <div class="step ${st} ${current ? 'current' : ''}">
          <div class="meta">
            <span class="idx">${s.index}</span>
            <span class="alt">${s.altitude}</span>
            <span class="badge ${st}">${badge}</span>
          </div>
          <h3>${esc(s.title)}</h3>
          <p>${esc(s.description)}</p>
          <button ${disabled} data-cmd="${esc(s.command)}">Run · ${esc(s.command.replace('threedot.', ''))}</button>
        </div>`;
    }).join('');

    const personaBar = persona
      ? `<div class="chip">persona <strong>${persona}</strong></div>
         <div class="chip">step <strong>${esc(state.currentStep ?? '—')}</strong></div>
         <div class="chip">altitude <strong>${esc(state.currentAltitude ?? '—')}</strong></div>
         <div class="chip">status <strong>${esc(state.status)}</strong></div>`
      : `<p class="muted">Select a developer persona to begin the six-step spine.</p>
         <div class="row">
           <button data-persona="rails">Developer_RAILS</button>
           <button data-persona="javascript">Developer_JavaScript</button>
         </div>`;

    return `
    <div class="banner">
      <div>
        <strong>Develop — syntax / coding help</strong>
        <span class="muted">Journey spine, CID binding, … completion, embedCID, diagnostics. Not the runtime path.</span>
      </div>
    </div>
    <div class="top">${personaBar}</div>
    <div id="steps">${stepsHtml || '<p class="muted">No spine yet — pick a persona.</p>'}</div>`;
  }

  /** TAB 2 — RUN: runtime-assistance scaffold (CID ops + Switchyard placeholder). */
  private runHtml(state: JourneyState): string {
    const cidState = loadCidState();
    const cid = cidState.cid;
    const ops = Array.isArray(cid.operations) ? cid.operations : [];
    const rows = ops.map((op: Op) => `
      <tr>
        <td><span class="mono">${esc(op.name)}</span></td>
        <td>${esc(op.role)}</td>
        <td>${esc(op.result?.shape ?? '—')}</td>
        <td class="muted">${esc(op.summary)}</td>
      </tr>`).join('');

    const taskChips = (state.taskRuns ?? []).slice(-5).map((t) =>
      `<div class="chip">${esc(String(t.name ?? 'task'))}</div>`
    ).join('') || '<span class="muted">No task runs yet — use deploy / verify / run-pod from Develop or Command Palette.</span>';

    return `
    <div class="banner">
      <div>
        <strong>RUN — runtime assistance</strong>
        <span class="muted">Operate against a deployed pod’s CID. Distinct from Develop (authoring). Switchyard-backed assistance is the next wire-up.</span>
      </div>
    </div>

    <div class="card">
      <h2>Deployed pod CID <span class="mode">runtime surface</span></h2>
      <div class="row">
        <div class="chip">title <strong>${esc(cid.title)}</strong></div>
        <div class="chip">source <strong>${esc(cidState.source)}</strong></div>
        <div class="chip">ops <strong>${ops.length}</strong></div>
      </div>
      <p class="mono muted" style="margin-top:8px">${esc(cid['@id'] || '(no @id)')}</p>
      ${cidState.error ? `<p style="color:#f14c4c">CID error: ${esc(cidState.error)}</p>` : ''}
      <table>
        <thead><tr><th>Operation</th><th>Role</th><th>Shape</th><th>Summary</th></tr></thead>
        <tbody>
          ${rows || '<tr><td colspan="4" class="muted">No operations — embed a CID (Develop) or open workspace .threedot/cid.json.</td></tr>'}
        </tbody>
      </table>
      <div class="row" style="margin-top:12px">
        <button data-cmd="threedot.openCID">Open CID</button>
        <button class="ghost" data-cmd="threedot.reloadCID">Reload CID</button>
        <button class="ghost" data-cmd="threedot.cpcp.verify">Verify pod</button>
        <button class="ghost" data-cmd="threedot.cpcp.deploy">Deploy</button>
        <button class="ghost" data-cmd="threedot.cpcp.run">Run pod</button>
      </div>
    </div>

    <div class="card">
      <h2>Recent task runs</h2>
      <div class="row">${taskChips}</div>
    </div>

    <div class="card placeholder">
      <h2>Runtime assistance — Switchyard-backed (coming)</h2>
      <p>
        Placeholder for live runtime help against the pod: route selection, envelope inspection,
        never-raise recovery, and Switchyard-backed session assist. <strong>Not wired yet</strong> —
        awaits pending Switchyard design. This tab exists so developers always know they are in
        <em>RUN</em> (runtime) rather than <em>Develop</em> (syntax/coding).
      </p>
      <p class="muted mono">status: scaffold · backend: switchyard (pending) · grounding: CID + never-raise</p>
    </div>`;
  }

  dispose(): void {
    JourneyPanel.current = undefined;
    this.panel.dispose();
    while (this.disposables.length) {
      const d = this.disposables.pop();
      d?.dispose();
    }
  }
}

function esc(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
