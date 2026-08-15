import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { Cid, Op, loadCid, cidPath, renderCall, DEFAULT_CID } from './cid';

const LANGS = ['python', 'typescript', 'javascript', 'go', 'rust', 'java', 'ruby', 'html', 'css'];
const SELECTOR: vscode.DocumentSelector = LANGS.map((language) => ({ language }));
let CID: Cid;

export function activate(ctx: vscode.ExtensionContext): void {
  CID = loadCid();

  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
  const refreshStatus = (): void => {
    status.text = `$(kebab-horizontal) 3dot: ${CID.operations.length} caps`;
    status.tooltip = 'threedot.dev — Cyborg Interface. Type … in code, or click to view capabilities.';
    status.command = 'threedot.showCapabilities';
    status.show();
  };
  refreshStatus();
  ctx.subscriptions.push(status);

  const tree = new CapsProvider(() => CID);
  ctx.subscriptions.push(vscode.window.registerTreeDataProvider('threedotCaps', tree));

  ctx.subscriptions.push(
    vscode.languages.registerCompletionItemProvider(SELECTOR, new DotProvider(() => CID), '.', '…')
  );
  ctx.subscriptions.push(
    vscode.languages.registerHoverProvider(SELECTOR, new CyborgHover(() => CID))
  );

  const diag = vscode.languages.createDiagnosticCollection('threedot');
  ctx.subscriptions.push(diag);
  const validate = (doc: vscode.TextDocument): void => runDiagnostics(doc, CID, diag);
  ctx.subscriptions.push(vscode.workspace.onDidChangeTextDocument((e) => validate(e.document)));
  ctx.subscriptions.push(vscode.workspace.onDidOpenTextDocument(validate));
  if (vscode.window.activeTextEditor) { validate(vscode.window.activeTextEditor.document); }

  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.showCapabilities', () =>
    vscode.commands.executeCommand('threedotCaps.focus')));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.embedCID', async () => {
    await embedCid();
    CID = loadCid(); refreshStatus(); tree.refresh();
  }));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.insertCapability', () => insertPick(CID)));
  ctx.subscriptions.push(vscode.commands.registerCommand('threedot.insertOp', (op: Op) => insertOp(op)));

  const p = cidPath();
  if (p && !fs.existsSync(p)) {
    void vscode.window.showInformationMessage(
      '3dot: no Cyborg Interface Descriptor (CID) found. Embed a starter CID?', 'Embed CID'
    ).then((a) => { if (a === 'Embed CID') { void vscode.commands.executeCommand('threedot.embedCID'); } });
  }
}

export function deactivate(): void { /* no-op */ }

// Type … (or ..) to summon the CID capabilities as language-native snippets.
class DotProvider implements vscode.CompletionItemProvider {
  constructor(private readonly get: () => Cid) {}
  provideCompletionItems(doc: vscode.TextDocument, pos: vscode.Position): vscode.CompletionItem[] {
    const line = doc.lineAt(pos).text.slice(0, pos.character);
    const m = line.match(/(\.\.|…)$/);
    if (!m) { return []; }
    const range = new vscode.Range(pos.translate(0, -m[0].length), pos);
    return this.get().operations.map((op) => {
      const it = new vscode.CompletionItem(`… ${op.name}`, vscode.CompletionItemKind.Method);
      it.detail = `${op.role} · ${op.summary}`;
      it.documentation = new vscode.MarkdownString('`' + op['@id'] + '`\n\n' + op.summary);
      it.range = range;
      it.insertText = new vscode.SnippetString(renderCall(op, doc.languageId));
      it.sortText = op.name;
      return it;
    });
  }
}

class CyborgHover implements vscode.HoverProvider {
  constructor(private readonly get: () => Cid) {}
  provideHover(doc: vscode.TextDocument, pos: vscode.Position): vscode.Hover | undefined {
    const range = doc.getWordRangeAtPosition(pos);
    if (!range) { return undefined; }
    const cid = this.get();
    const op = cid.operations.find((o) => o.name === doc.getText(range));
    if (!op) { return undefined; }
    const md = new vscode.MarkdownString();
    md.appendMarkdown(`**${op.name}** — _${op.role}_\n\n${op.summary}\n\n`);
    md.appendMarkdown('- `@id`: ' + op['@id'] + '\n- `@context`: ' + cid['@context'] + '\n');
    if (op.result?.shape) { md.appendMarkdown('- result shape: `' + op.result.shape + '`\n'); }
    if (op.params?.closed) { md.appendMarkdown('- **closed shape** (validated at edit time)\n'); }
    return new vscode.Hover(md, range);
  }
}

class CapItem extends vscode.TreeItem {
  constructor(public readonly op: Op) {
    super(op.name, vscode.TreeItemCollapsibleState.None);
    this.description = op.role;
    this.tooltip = new vscode.MarkdownString('`' + op['@id'] + '`\n\n' + op.summary);
    this.iconPath = new vscode.ThemeIcon(iconFor(op.role));
    this.command = { command: 'threedot.insertOp', title: 'Insert', arguments: [op] };
  }
}
class CapsProvider implements vscode.TreeDataProvider<CapItem> {
  private readonly emitter = new vscode.EventEmitter<void>();
  readonly onDidChangeTreeData = this.emitter.event;
  constructor(private readonly get: () => Cid) {}
  refresh(): void { this.emitter.fire(); }
  getTreeItem(e: CapItem): vscode.TreeItem { return e; }
  getChildren(): CapItem[] { return this.get().operations.map((op) => new CapItem(op)); }
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

// Edit-time validation against the CID: flag three.<op>() calls not in the descriptor.
function runDiagnostics(doc: vscode.TextDocument, cid: Cid, coll: vscode.DiagnosticCollection): void {
  if (!LANGS.includes(doc.languageId)) { coll.delete(doc.uri); return; }
  const names = new Set(cid.operations.map((o) => o.name.toLowerCase()));
  const diags: vscode.Diagnostic[] = [];
  const re = /three\.([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  for (let i = 0; i < doc.lineCount; i++) {
    const text = doc.lineAt(i).text;
    let m: RegExpExecArray | null;
    while ((m = re.exec(text)) !== null) {
      const name = m[1];
      if (!names.has(name.toLowerCase())) {
        const s = m.index + 'three.'.length;
        const d = new vscode.Diagnostic(
          new vscode.Range(i, s, i, s + name.length),
          `three/unknown-capability: '${name}' is not in the Cyborg Interface Descriptor (CID).`,
          vscode.DiagnosticSeverity.Warning
        );
        d.code = 'three/unknown-capability';
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

async function insertPick(cid: Cid): Promise<void> {
  const pick = await vscode.window.showQuickPick(
    cid.operations.map((op) => ({ label: '… ' + op.name, description: op.role, detail: op.summary, op })),
    { placeHolder: 'Insert a Cyborg capability' }
  );
  if (pick) { await insertOp(pick.op); }
}

async function insertOp(op: Op): Promise<void> {
  const ed = vscode.window.activeTextEditor;
  if (!ed) { void vscode.window.showWarningMessage('3dot: open a file to insert into.'); return; }
  await ed.insertSnippet(new vscode.SnippetString(renderCall(op, ed.document.languageId)));
}
