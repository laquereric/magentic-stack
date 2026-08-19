import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import {
  Cid, CidState, Op, loadCidState, cidPath, renderCall, DEFAULT_CID,
  hoverMarkdown, signatureLabel, opNameOffset, opByName, pythonImportEdits,
  setLiveCidState,
} from './cid';
import { issuesForCall, parseThreeCalls } from './parse';
import { activateJourney } from './journey';
import { getCpcpClient } from './cpcp';
import { ShellPanel } from './webview/shellPanel';

const LANGS = ['python', 'typescript', 'javascript', 'go', 'rust', 'java', 'ruby', 'html', 'css'];
const SELECTOR: vscode.DocumentSelector = LANGS.map((language) => ({ language }));
const ROLES: Op['role'][] = ['context', 'effect', 'component', 'token'];

let state: CidState;
const log = vscode.window.createOutputChannel('3dot');

export function activate(ctx: vscode.ExtensionContext): void {
  state = loadCidState();
  logLoad();

  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
  const lineStatus = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 80);
  const tree = new CapsProvider(() => state.cid);
  const diag = vscode.languages.createDiagnosticCollection('threedot');
  const lenses = new vscode.EventEmitter<void>();
  const inlays = new vscode.EventEmitter<void>();
  const labelDeco = vscode.window.createTextEditorDecorationType({});

  const refreshStatus = (): void => {
    const n = state.cid.operations.length;
    const live = state.source === 'live';
    const connected = !!state.connected;
    if (live && connected) {
      status.text = `$(radio-tower) 3dot: live · ${shortTitle(state.cid.title)} · ${n}`;
      status.backgroundColor = undefined;
      status.tooltip = `LIVE CID from BACK\n${state.backUrl}\n${state.digest}\nClick to open shell`;
      status.command = 'threedot.openShell';
    } else if (live && !connected) {
      status.text = `$(debug-disconnect) 3dot: disconnected · ${n}`;
      status.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
      status.tooltip = `BACK unreachable\n${state.error || ''}\nCached digest: ${state.digest || '—'}\nClick to retry / open shell`;
      status.command = 'threedot.openShell';
    } else if (state.error && state.source !== 'workspace') {
      status.text = '$(error) 3dot: CID error';
      status.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
      status.tooltip = `${state.error}\nClick to open shell / seed`;
      status.command = 'threedot.openShell';
    } else if (state.source === 'default') {
      status.text = `$(kebab-horizontal) 3dot: default · ${n}`;
      status.backgroundColor = undefined;
      status.tooltip = 'No live BACK. Set threedot.backUrl or seed .threedot/cid.json (discovery only).';
      status.command = 'threedot.openShell';
    } else {
      status.text = `$(kebab-horizontal) 3dot: seed · ${shortTitle(state.cid.title)} · ${n}`;
      status.backgroundColor = undefined;
      status.tooltip = `Using seed file (not live)\n${state.path}\nConnect BACK for authoritative CID`;
      status.command = 'threedot.openShell';
    }
    status.show();
  };
  const refreshLine = (): void => {
    const ed = vscode.window.activeTextEditor;
    if (!ed) { lineStatus.hide(); return; }
    const text = ed.document.lineAt(ed.selection.active.line).text;
    for (const call of parseThreeCalls(text)) {
      const op = opByName(state.cid, call.name);
      if (op) {
        lineStatus.text = `$(symbol-method) ${callLabel(op)}`;
        lineStatus.tooltip = op.summary;
        lineStatus.command = 'threedot.openCID';
        lineStatus.show();
        return;
      }
    }
    lineStatus.hide();
  };

  const validate = (doc: vscode.TextDocument): void => runDiagnostics(doc, state.cid, diag);
  const validateAll = (): void => {
    for (const doc of vscode.workspace.textDocuments) { validate(doc); }
  };
  const paintCallLabels = (): void => {
    const mode = callLabelMode();
    const want = mode === 'endOfLine' || mode === 'both' || mode === 'inlay';
    for (const ed of vscode.window.visibleTextEditors) {
      const lang = ed.document.languageId;
      const pyish = LANGS.includes(lang) || ed.document.fileName.endsWith('.py');
      if (!pyish || !want) {
        ed.setDecorations(labelDeco, []);
        continue;
      }
      const opts: vscode.DecorationOptions[] = [];
      const doc = ed.document;
      for (let i = 0; i < doc.lineCount; i++) {
        const text = doc.lineAt(i).text;
        for (const call of parseThreeCalls(text)) {
          const op = opByName(state.cid, call.name);
          if (!op) { continue; }
          const end = Math.min(Math.max(call.argsEnd + 1, call.nameEnd), text.length);
          opts.push({
            range: new vscode.Range(i, 0, i, end),
            renderOptions: {
              after: {
                contentText: `  ${callLabel(op)}`,
                margin: '0 0 0 1.2em',
                color: new vscode.ThemeColor('editorInlayHint.foreground'),
                backgroundColor: new vscode.ThemeColor('editorInlayHint.background'),
                fontStyle: 'italic',
              },
            },
            hoverMessage: new vscode.MarkdownString(op.summary),
          });
        }
      }
      log.appendLine(`labels: ${ed.document.fileName} lang=${lang} n=${opts.length} cid=${state.source}`);
      ed.setDecorations(labelDeco, opts);
    }
  };
  const reload = (announce = false): void => {
    state = loadCidState();
    logLoad();
    refreshStatus();
    tree.refresh();
    lenses.fire();
    inlays.fire();
    validateAll();
    paintCallLabels();
    refreshLine();
    if (announce && state.error && !state.connected) {
      void vscode.window.showWarningMessage(`3dot: ${state.error}`, 'Open Shell')
        .then((a) => { if (a === 'Open Shell') { void vscode.commands.executeCommand('threedot.openShell'); } });
    }
  };

  const cpcp = getCpcpClient();
  const applyLive = (): void => {
    const p = cpcp.projection;
    setLiveCidState({
      cid: p.cid,
      source: p.source === 'live' || p.connected ? 'live' : (p.source === 'default' ? 'default' : 'live'),
      connected: p.connected,
      digest: p.digest,
      backUrl: p.backUrl,
      error: p.error,
    });
    reload(false);
  };
  cpcp.bootstrap();
  ctx.subscriptions.push(cpcp.onDidChange(() => applyLive()));
  void cpcp.refresh().then(() => applyLive());

  refreshStatus();
  log.appendLine(`activate ${ctx.extension.packageJSON.version} workspace=${vscode.workspace.workspaceFolders?.[0]?.uri.fsPath ?? '(none)'}`);
  if (!ctx.globalState.get('threedot.welcomed.0.0.7')) {
    void vscode.window.showInformationMessage(
      `3dot ${ctx.extension.packageJSON.version}: thin FRONT shell — live CID from BACK over CPCP`
    );
    void ctx.globalState.update('threedot.welcomed.0.0.7', true);
  }
  ctx.subscriptions.push(status, lineStatus, diag, log, lenses, inlays, labelDeco);
  ctx.subscriptions.push(vscode.window.registerTreeDataProvider('threedotCaps', tree));
  ctx.subscriptions.push(
    vscode.languages.registerCompletionItemProvider(SELECTOR, new DotProvider(() => state.cid), '.', '…')
  );
  ctx.subscriptions.push(vscode.languages.registerHoverProvider(SELECTOR, new CyborgHover(() => state)));
  ctx.subscriptions.push(vscode.languages.registerDefinitionProvider(SELECTOR, new CidDefinition(() => state)));
  ctx.subscriptions.push(vscode.languages.registerSignatureHelpProvider(
    SELECTOR, new CidSignature(() => state.cid), '(', ',', '='
  ));
  ctx.subscriptions.push(vscode.languages.registerCodeLensProvider(SELECTOR, new CidLenses(() => state.cid, lenses.event)));
  ctx.subscriptions.push(vscode.languages.registerInlayHintsProvider(SELECTOR, new CidInlays(() => state.cid, inlays.event)));
  ctx.subscriptions.push(vscode.workspace.onDidChangeTextDocument((e) => {
    validate(e.document);
    paintCallLabels();
  }));
  ctx.subscriptions.push(vscode.workspace.onDidOpenTextDocument(validate));
  ctx.subscriptions.push(vscode.window.onDidChangeActiveTextEditor(() => {
    paintCallLabels();
    refreshLine();
  }));
  ctx.subscriptions.push(vscode.window.onDidChangeTextEditorSelection(() => refreshLine()));
  ctx.subscriptions.push(vscode.window.onDidChangeVisibleTextEditors(() => paintCallLabels()));
  ctx.subscriptions.push(vscode.workspace.onDidOpenTextDocument(() => {
    validateAll();
    paintCallLabels();
  }));
  ctx.subscriptions.push(vscode.workspace.onDidChangeConfiguration((e) => {
    if (e.affectsConfiguration('threedot.callLabels')) {
      lenses.fire();
      inlays.fire();
      paintCallLabels();
    }
  }));
  validateAll();
  paintCallLabels();
  refreshLine();
  setTimeout(() => { paintCallLabels(); refreshLine(); }, 250);
  setTimeout(() => { paintCallLabels(); refreshLine(); }, 1500);

  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.showCapabilities', () =>
    vscode.commands.executeCommand('threedotCaps.focus')));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.embedCID', async () => {
    await embedCid();
    reload();
  }));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.insertCapability', () => insertPick(state.cid)));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.insertOp', (op: Op) => insertOp(op)));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.openCID', () => openCid()));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.reloadCID', async () => {
    await cpcp.refresh();
    applyLive();
    void vscode.window.setStatusBarMessage('3dot: refreshed live CID from BACK', 2000);
  }));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.showLog', () => log.show(true)));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.openShell', () => {
    ShellPanel.show(cpcp);
  }));

  // Additive: Cyborg Journey wizard (walkthrough + webview + gates + tasks).
  // Does not replace completion/hover/CodeLens/diagnostics/embedCID/tree.
  activateJourney(ctx, log);

  const folder = vscode.workspace.workspaceFolders?.[0];
  if (folder) {
    const watcher = vscode.workspace.createFileSystemWatcher(
      new vscode.RelativePattern(folder, '.threedot/cid.json')
    );
    watcher.onDidChange(() => reload(true));
    watcher.onDidCreate(() => reload(true));
    watcher.onDidDelete(() => reload());
    ctx.subscriptions.push(watcher);
  }

  // Seed is discovery-only; live CID comes from BACK.
  const seed = cidPath();
  if (seed && !fs.existsSync(seed) && !vscode.workspace.getConfiguration('threedot').get('backUrl')) {
    void vscode.window.showInformationMessage(
      '3dot: set threedot.backUrl or add a discovery seed .threedot/cid.json (backUrl only).',
      'Open Shell'
    ).then((a) => { if (a === 'Open Shell') { void vscode.commands.executeCommand('threedot.openShell'); } });
  }
}

export function deactivate(): void { /* no-op */ }

function logLoad(): void {
  if (state.error) {
    log.appendLine(`CID error at ${state.path}: ${state.error} (using default)`);
  } else if (state.source === 'workspace') {
    log.appendLine(`loaded ${state.path} — ${state.cid.title} (${state.cid.operations.length} ops)`);
  } else {
    log.appendLine(`no workspace CID; using starter (${state.cid.operations.length} ops)`);
  }
}

function shortTitle(title: string): string {
  const cut = title.split(/[—–-]/)[0].trim();
  return cut.length <= 24 ? cut : cut.slice(0, 23) + '…';
}

class DotProvider implements vscode.CompletionItemProvider {
  constructor(private readonly get: () => Cid) {}
  provideCompletionItems(doc: vscode.TextDocument, pos: vscode.Position): vscode.CompletionItem[] {
    const line = doc.lineAt(pos).text.slice(0, pos.character);
    const ellipsis = line.match(/(\.\.|…)$/);
    const threeDot = line.match(/threedot\.([A-Za-z_][A-Za-z0-9_]*)?$/);
    if (!ellipsis && !threeDot) { return []; }

    let range: vscode.Range;
    let prefix = '';
    if (ellipsis) {
      range = new vscode.Range(pos.translate(0, -ellipsis[0].length), pos);
    } else {
      const typed = threeDot![1] ?? '';
      prefix = typed.toLowerCase();
      const start = pos.character - typed.length;
      range = new vscode.Range(pos.line, start, pos.line, pos.character);
    }

    const imports = maybeImports(doc);
    return this.get().operations
      .filter((op) => !prefix || op.name.toLowerCase().startsWith(prefix))
      .map((op) => {
        const it = new vscode.CompletionItem(`… ${op.name}`, vscode.CompletionItemKind.Method);
        it.detail = `${op.role} · ${op.result?.shape ?? 'void'} · ${op.summary}`;
        it.documentation = hoverMarkdown(this.get(), op);
        it.range = range;
        it.insertText = new vscode.SnippetString(
          ellipsis ? renderCall(op, doc.languageId) : renderCall(op, doc.languageId).replace(/^threedot\./, '')
        );
        it.sortText = `${op.role}-${op.name}`;
        it.filterText = op.name;
        if (imports.length) { it.additionalTextEdits = imports; }
        return it;
      });
  }
}

class CyborgHover implements vscode.HoverProvider {
  constructor(private readonly get: () => CidState) {}
  provideHover(doc: vscode.TextDocument, pos: vscode.Position): vscode.Hover | undefined {
    const range = doc.getWordRangeAtPosition(pos);
    if (!range) { return undefined; }
    const st = this.get();
    const op = opByName(st.cid, doc.getText(range));
    if (!op) { return undefined; }
    return new vscode.Hover(hoverMarkdown(st.cid, op), range);
  }
}

class CidDefinition implements vscode.DefinitionProvider {
  constructor(private readonly get: () => CidState) {}
  provideDefinition(doc: vscode.TextDocument, pos: vscode.Position): vscode.Definition | undefined {
    const range = doc.getWordRangeAtPosition(pos);
    if (!range) { return undefined; }
    const st = this.get();
    if (!st.path || st.source !== 'workspace') { return undefined; }
    const op = opByName(st.cid, doc.getText(range));
    if (!op) { return undefined; }
    let json: string;
    try { json = fs.readFileSync(st.path, 'utf8'); } catch { return undefined; }
    const offset = opNameOffset(json, op.name);
    if (offset < 0) { return undefined; }
    const before = json.slice(0, offset);
    const line = before.split('\n').length - 1;
    const col = before.length - before.lastIndexOf('\n') - 1;
    return new vscode.Location(vscode.Uri.file(st.path), new vscode.Position(line, col));
  }
}

class CidSignature implements vscode.SignatureHelpProvider {
  constructor(private readonly get: () => Cid) {}
  provideSignatureHelp(doc: vscode.TextDocument, pos: vscode.Position): vscode.SignatureHelp | undefined {
    const line = doc.lineAt(pos).text.slice(0, pos.character);
    const m = line.match(/three\.([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*$/);
    if (!m) { return undefined; }
    const op = opByName(this.get(), m[1]);
    if (!op) { return undefined; }
    const help = new vscode.SignatureHelp();
    const info = new vscode.SignatureInformation(signatureLabel(op), op.summary);
    const props = Object.keys(op.params?.properties ?? {});
    info.parameters = props.map((p) => new vscode.ParameterInformation(p));
    const commas = (line.slice(line.lastIndexOf('(') + 1).match(/,/g) ?? []).length;
    help.signatures = [info];
    help.activeParameter = Math.min(commas, Math.max(props.length - 1, 0));
    return help;
  }
}

class CidLenses implements vscode.CodeLensProvider {
  constructor(
    private readonly get: () => Cid,
    readonly onDidChangeCodeLenses: vscode.Event<void>,
  ) {}
  provideCodeLenses(doc: vscode.TextDocument): vscode.CodeLens[] {
    const mode = callLabelMode();
    if (mode !== 'codelens' && mode !== 'both') { return []; }
    const cid = this.get();
    const lenses: vscode.CodeLens[] = [];
    for (let i = 0; i < doc.lineCount; i++) {
      const text = doc.lineAt(i).text;
      for (const call of parseThreeCalls(text)) {
        const op = opByName(cid, call.name);
        if (!op) { continue; }
        const range = new vscode.Range(i, call.nameStart, i, call.nameEnd);
        const shape = op.result?.shape ? ` → ${op.result.shape}` : '';
        lenses.push(new vscode.CodeLens(range, {
          title: `3dot · ${op.role}${shape}`,
          command: 'threedot.openCID',
          tooltip: op.summary,
        }));
      }
    }
    return lenses;
  }
}

class CidInlays implements vscode.InlayHintsProvider {
  constructor(
    private readonly get: () => Cid,
    readonly onDidChangeInlayHints: vscode.Event<void>,
  ) {}
  provideInlayHints(doc: vscode.TextDocument): vscode.InlayHint[] {
    const mode = callLabelMode();
    if (mode !== 'inlay' && mode !== 'both' && mode !== 'endOfLine') { return []; }
    const cid = this.get();
    const hints: vscode.InlayHint[] = [];
    for (let i = 0; i < doc.lineCount; i++) {
      const text = doc.lineAt(i).text;
      for (const call of parseThreeCalls(text)) {
        const op = opByName(cid, call.name);
        if (!op) { continue; }
        const col = Math.min(Math.max(call.argsEnd + 1, call.nameEnd), text.length);
        const hint = new vscode.InlayHint(
          new vscode.Position(i, col),
          callLabel(op),
          vscode.InlayHintKind.Type
        );
        hint.paddingLeft = true;
        hint.tooltip = op.summary;
        hints.push(hint);
      }
    }
    return hints;
  }
}

type TreeNode = RoleItem | CapItem;

class RoleItem extends vscode.TreeItem {
  constructor(public readonly role: Op['role'], count: number) {
    super(`${role} (${count})`, vscode.TreeItemCollapsibleState.Expanded);
    this.contextValue = 'role';
    this.iconPath = new vscode.ThemeIcon(iconFor(role));
  }
}

class CapItem extends vscode.TreeItem {
  constructor(public readonly op: Op) {
    super(op.name, vscode.TreeItemCollapsibleState.None);
    this.description = op.result?.shape ?? op.role;
    this.tooltip = new vscode.MarkdownString('`' + op['@id'] + '`\n\n' + op.summary);
    this.iconPath = new vscode.ThemeIcon(iconFor(op.role));
    this.command = { command: 'threedot.insertOp', title: 'Insert', arguments: [op] };
    this.contextValue = 'op';
  }
}

class CapsProvider implements vscode.TreeDataProvider<TreeNode> {
  private readonly emitter = new vscode.EventEmitter<void>();
  readonly onDidChangeTreeData = this.emitter.event;
  constructor(private readonly get: () => Cid) {}
  refresh(): void { this.emitter.fire(); }
  getTreeItem(e: TreeNode): vscode.TreeItem { return e; }
  getChildren(e?: TreeNode): TreeNode[] {
    const ops = this.get().operations;
    if (!e) {
      return ROLES
        .map((role) => ({ role, n: ops.filter((o) => o.role === role).length }))
        .filter((x) => x.n > 0)
        .map((x) => new RoleItem(x.role, x.n));
    }
    if (e instanceof RoleItem) {
      return ops.filter((o) => o.role === e.role).map((op) => new CapItem(op));
    }
    return [];
  }
}

function callLabel(op: Op): string {
  const shape = op.result?.shape ? ` → ${op.result.shape}` : '';
  return `3dot · ${op.role}${shape}`;
}

function callLabelMode(): string {
  return vscode.workspace.getConfiguration('threedot').get<string>('callLabels', 'endOfLine');
}

function maybeImports(doc: vscode.TextDocument): vscode.TextEdit[] {
  if (!vscode.workspace.getConfiguration('threedot').get<boolean>('autoImport', true)) { return []; }
  return pythonImportEdits(doc);
}

function iconFor(role: string): string {
  switch (role) {
    case 'context': return 'book';
    case 'effect': return 'zap';
    case 'component': return 'symbol-structure';
    case 'token': return 'symbol-color';
    default: return 'circle-small';
  }
}

function runDiagnostics(doc: vscode.TextDocument, cid: Cid, coll: vscode.DiagnosticCollection): void {
  if (!LANGS.includes(doc.languageId)) { coll.delete(doc.uri); return; }
  const diags: vscode.Diagnostic[] = [];
  for (let i = 0; i < doc.lineCount; i++) {
    const text = doc.lineAt(i).text;
    for (const call of parseThreeCalls(text)) {
      const op = opByName(cid, call.name);
      for (const issue of issuesForCall(op, call)) {
        const start = issue.on === 'name' ? call.nameStart : call.argsStart;
        const end = issue.on === 'name' ? call.nameEnd : Math.max(call.argsEnd, call.argsStart + 1);
        const d = new vscode.Diagnostic(
          new vscode.Range(i, start, i, end),
          issue.message,
          issue.code === 'threedot/unknown-capability' ? vscode.DiagnosticSeverity.Warning : vscode.DiagnosticSeverity.Information
        );
        d.code = issue.code;
        d.source = '3dot';
        diags.push(d);
      }
    }
  }
  coll.set(doc.uri, diags);
}

async function embedCid(): Promise<void> {
  const ws = vscode.workspace.workspaceFolders?.[0];
  if (!ws) { void vscode.window.showWarningMessage('3dot: open a folder first, then embed a CID.'); return; }
  const dir = path.join(ws.uri.fsPath, '.threedot');
  fs.mkdirSync(dir, { recursive: true });
  const p = path.join(dir, 'cid.json');
  if (!fs.existsSync(p)) { fs.writeFileSync(p, JSON.stringify(DEFAULT_CID, null, 2)); }
  const d = await vscode.workspace.openTextDocument(p);
  await vscode.window.showTextDocument(d);
  void vscode.window.showInformationMessage('3dot: embedded .threedot/cid.json — now type … in your code.');
}

async function openCid(): Promise<void> {
  const p = state.path ?? cidPath();
  if (!p) { void vscode.window.showWarningMessage('3dot: open a folder first.'); return; }
  if (!fs.existsSync(p)) {
    void vscode.window.showInformationMessage('3dot: no CID yet. Embed one?', 'Embed CID')
      .then((a) => { if (a === 'Embed CID') { void vscode.commands.executeCommand('threedot.embedCID'); } });
    return;
  }
  const d = await vscode.workspace.openTextDocument(p);
  await vscode.window.showTextDocument(d, { preview: true });
}

async function insertPick(cid: Cid): Promise<void> {
  const pick = await vscode.window.showQuickPick(
    cid.operations.map((op) => ({
      label: '… ' + op.name,
      description: `${op.role}${op.result?.shape ? ' → ' + op.result.shape : ''}`,
      detail: op.summary,
      op,
    })),
    { placeHolder: 'Insert a Cyborg capability', matchOnDescription: true, matchOnDetail: true }
  );
  if (pick) { await insertOp(pick.op); }
}

async function insertOp(op: Op): Promise<void> {
  const ed = vscode.window.activeTextEditor;
  if (!ed) { void vscode.window.showWarningMessage('3dot: open a file to insert into.'); return; }
  const imports = maybeImports(ed.document);
  if (imports.length) {
    await ed.edit((b) => { for (const t of imports) { b.insert(t.range.start, t.newText); } });
  }
  await ed.insertSnippet(new vscode.SnippetString(renderCall(op, ed.document.languageId)));
}
