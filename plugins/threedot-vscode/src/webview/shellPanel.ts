/** Thin webview shell — presentation only; all data from host via postMessage. */

import * as vscode from 'vscode';
import * as crypto from 'crypto';
import { CpcpClient, LiveProjection } from '../cpcp';

export class ShellPanel {
  public static current: ShellPanel | undefined;
  private readonly panel: vscode.WebviewPanel;
  private disposables: vscode.Disposable[] = [];

  private constructor(
    panel: vscode.WebviewPanel,
    private readonly cpcp: CpcpClient,
  ) {
    this.panel = panel;
    this.panel.onDidDispose(() => this.dispose(), null, this.disposables);
    this.panel.webview.onDidReceiveMessage((m) => { void this.onMessage(m); }, null, this.disposables);
    this.disposables.push(this.cpcp.onDidChange((p) => this.postProjection(p)));
    this.render();
    this.postProjection(this.cpcp.projection);
  }

  static show(cpcp: CpcpClient): ShellPanel {
    if (ShellPanel.current) {
      ShellPanel.current.panel.reveal(vscode.ViewColumn.Beside);
      ShellPanel.current.postProjection(cpcp.projection);
      return ShellPanel.current;
    }
    const panel = vscode.window.createWebviewPanel(
      'threedotShell',
      '3dot Shell (FRONT)',
      vscode.ViewColumn.Beside,
      { enableScripts: true, retainContextWhenHidden: true }
    );
    ShellPanel.current = new ShellPanel(panel, cpcp);
    return ShellPanel.current;
  }

  private postProjection(p: LiveProjection): void {
    void this.panel.webview.postMessage({
      type: 'projection',
      connected: p.connected,
      source: p.source,
      digest: p.digest,
      backUrl: p.backUrl,
      error: p.error,
      fetchedAt: p.fetchedAt,
      cid: p.cid,
      connectionState: this.cpcp.connectionState,
    });
  }

  private async onMessage(msg: {
    type: string;
    method?: string;
    params?: Record<string, unknown>;
    tab?: string;
  }): Promise<void> {
    switch (msg.type) {
      case 'ready':
        this.postProjection(this.cpcp.projection);
        break;
      case 'refresh': {
        const r = await this.cpcp.refresh();
        void this.panel.webview.postMessage({ type: 'rpcResult', action: 'refresh', envelope: r });
        break;
      }
      case 'pull': {
        const r = await this.cpcp.pull(msg.method || 'threedot.cid', msg.params || {});
        void this.panel.webview.postMessage({ type: 'rpcResult', action: 'pull', method: msg.method, envelope: r });
        break;
      }
      case 'push': {
        const opId = crypto.randomUUID();
        const r = await this.cpcp.push(msg.method || 'threedot.effect', msg.params || {}, opId);
        void this.panel.webview.postMessage({
          type: 'rpcResult',
          action: 'push',
          method: msg.method,
          operationId: opId,
          envelope: r,
        });
        break;
      }
      default:
        break;
    }
  }

  private render(): void {
    this.panel.webview.html = shellHtml();
  }

  dispose(): void {
    ShellPanel.current = undefined;
    this.panel.dispose();
    while (this.disposables.length) this.disposables.pop()?.dispose();
  }
}

function shellHtml(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>3dot Shell</title>
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
    --ok: #3dd68c;
    --bad: #f85149;
  }
  body { font-family: var(--vscode-font-family); color: var(--fg); background: var(--bg); margin: 0; padding: 16px; }
  h1 { font-size: 18px; margin: 0 0 8px; }
  h2 { font-size: 14px; margin: 0 0 8px; }
  .muted { color: var(--muted); font-size: 12px; }
  .row { display:flex; gap:8px; flex-wrap:wrap; align-items:center; margin: 8px 0; }
  .chip { font-size: 11px; border: 1px solid var(--border); border-radius: 999px; padding: 4px 10px; }
  .chip.on { border-color: var(--ok); color: var(--ok); }
  .chip.off { border-color: var(--bad); color: var(--bad); }
  button { background: var(--accent); color: var(--accent-fg); border: 0; border-radius: 6px; padding: 7px 12px; cursor: pointer; font-size: 12px; }
  button.ghost { background: transparent; color: var(--fg); border: 1px solid var(--border); }
  .tabs { display:flex; border-bottom: 1px solid var(--border); margin: 12px 0; }
  .tab { background: transparent; color: var(--muted); border: 0; border-bottom: 2px solid transparent; border-radius: 0; padding: 10px 14px; font-weight: 600; cursor: pointer; }
  .tab.active { color: var(--fg); border-bottom-color: var(--accent); }
  .pane { display:none; }
  .pane.active { display:block; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 10px; padding: 12px; margin: 8px 0; }
  table { width: 100%; border-collapse: collapse; font-size: 12px; }
  th, td { text-align: left; padding: 8px 6px; border-bottom: 1px solid var(--border); }
  th { color: var(--muted); font-size: 11px; }
  .banner { padding: 10px; border: 1px solid var(--border); border-radius: 8px; margin-bottom: 10px; background: rgba(110,168,255,.08); }
  code { font-size: 11px; }
</style>
</head>
<body>
  <div class="row">
    <h1>… front door · 3dot Shell</h1>
    <span id="conn" class="chip off">disconnected</span>
    <button class="ghost" id="refresh">Refresh from BACK</button>
  </div>
  <p class="muted">Thin FRONT shell — <strong>no authoritative data</strong>. Live CID/operations from BACK via CPCP. Seed <code>.threedot/cid.json</code> is discovery only.</p>
  <div class="row">
    <span class="chip">source <strong id="source">—</strong></span>
    <span class="chip">digest <strong id="digest">—</strong></span>
    <span class="chip">back <strong id="back">—</strong></span>
  </div>
  <div id="err" class="muted"></div>

  <div class="tabs">
    <button class="tab active" data-tab="develop">Develop</button>
    <button class="tab" data-tab="run">RUN</button>
  </div>

  <div class="pane active" data-pane="develop">
    <div class="banner"><strong>Develop</strong> — syntax / coding help from <em>live</em> CID projection.</div>
    <div class="card">
      <h2 id="cidTitle">CID</h2>
      <p class="muted" id="cidId"></p>
      <table>
        <thead><tr><th>Operation</th><th>Role</th><th>Shape</th><th>Summary</th></tr></thead>
        <tbody id="ops"></tbody>
      </table>
    </div>
  </div>

  <div class="pane" data-pane="run">
    <div class="banner"><strong>RUN</strong> — runtime assistance against live BACK (Switchyard / effects via CPCP PUSH).</div>
    <div class="card">
      <h2>Live connection</h2>
      <p class="muted">PUSH effects through the host CPCP client. Shell never mutates CID.</p>
      <div class="row">
        <button id="pullCtx">PULL threedot.context</button>
        <button id="pullOps">PULL threedot.operations</button>
        <button class="ghost" id="pushPing">PUSH threedot.effect (ping)</button>
      </div>
      <pre id="rpcOut" class="muted" style="white-space:pre-wrap;font-size:11px"></pre>
    </div>
  </div>

<script>
  const vscode = acquireVsCodeApi();
  let tab = 'develop';
  const $ = (id) => document.getElementById(id);

  document.querySelectorAll('[data-tab]').forEach((el) => {
    el.addEventListener('click', () => {
      tab = el.getAttribute('data-tab');
      document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.getAttribute('data-tab') === tab));
      document.querySelectorAll('.pane').forEach((p) => p.classList.toggle('active', p.getAttribute('data-pane') === tab));
    });
  });

  $('refresh').onclick = () => vscode.postMessage({ type: 'refresh' });
  $('pullCtx').onclick = () => vscode.postMessage({ type: 'pull', method: 'threedot.context', params: {} });
  $('pullOps').onclick = () => vscode.postMessage({ type: 'pull', method: 'threedot.operations', params: {} });
  $('pushPing').onclick = () => vscode.postMessage({
    type: 'push',
    method: 'threedot.effect',
    params: { shape: 'Note', body: { kind: 'ping' } }
  });

  window.addEventListener('message', (ev) => {
    const msg = ev.data;
    if (msg.type === 'projection') {
      const on = !!msg.connected;
      const conn = $('conn');
      conn.textContent = on ? 'connected' : (msg.connectionState || 'disconnected');
      conn.className = 'chip ' + (on ? 'on' : 'off');
      $('source').textContent = msg.source || '—';
      $('digest').textContent = (msg.digest || '—').slice(0, 18) + '…';
      $('back').textContent = msg.backUrl || '—';
      $('err').textContent = msg.error || '';
      const cid = msg.cid || { title: '', operations: [], '@id': '' };
      $('cidTitle').textContent = cid.title || 'CID';
      $('cidId').textContent = cid['@id'] || '';
      const ops = Array.isArray(cid.operations) ? cid.operations : [];
      $('ops').innerHTML = ops.map((op) =>
        '<tr><td><code>' + esc(op.name) + '</code></td><td>' + esc(op.role||'') +
        '</td><td>' + esc((op.result&&op.result.shape)||'—') +
        '</td><td class="muted">' + esc(op.summary||'') + '</td></tr>'
      ).join('') || '<tr><td colspan="4" class="muted">No operations — connect BACK</td></tr>';
    }
    if (msg.type === 'rpcResult') {
      $('rpcOut').textContent = JSON.stringify(msg.envelope, null, 2);
    }
  });

  function esc(s) {
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }

  vscode.postMessage({ type: 'ready' });
</script>
</body>
</html>`;
}
