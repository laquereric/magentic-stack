import * as vscode from 'vscode';
import type { JourneyStateService } from './state';
import { spineFor } from './spines';
import type { JourneyState, StepDef } from './types';

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

  private async onMessage(msg: { type: string; command?: string; persona?: string }): Promise<void> {
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
      case 'refresh':
        this.svc.load();
        this.render();
        break;
      default:
        break;
    }
  }

  private html(state: JourneyState): string {
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
</style>
</head>
<body>
  <div class="top">
    <h1>Cyborg Journey</h1>
    <button class="ghost" id="refresh">Refresh</button>
    <button class="ghost" data-cmd="threedot.journey.start">Start / restart</button>
  </div>
  <div class="top">${personaBar}</div>
  <div id="steps">${stepsHtml || '<p class="muted">No spine yet — pick a persona.</p>'}</div>
  <div class="footer">
    State: <code>.threedot/journey.json</code> · gates unlock only when prior step evidence exists ·
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
  </script>
</body>
</html>`;
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
