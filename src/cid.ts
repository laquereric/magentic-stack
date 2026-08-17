import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { findOp } from './parse';

export interface Op {
  '@id': string;
  name: string;
  role: 'context' | 'effect' | 'component' | 'token';
  summary: string;
  params?: { required?: string[]; closed?: boolean; properties?: Record<string, unknown> };
  result?: { shape?: string };
}
export interface Cid { '@context': string; '@id': string; title: string; operations: Op[]; }

export interface CidState {
  cid: Cid;
  path?: string;
  source: 'workspace' | 'default';
  error?: string;
}

export const DEFAULT_CID: Cid = {
  '@context': 'https://threedot.dev/context/v1',
  '@id': 'https://threedot.dev/cid/demo',
  title: 'Demo Cyborg Interface',
  operations: [
    { '@id': 'https://threedot.dev/op/getUser', name: 'getUser', role: 'context',
      summary: 'Read a user by id (Context, by reference).',
      params: { required: ['userId'], properties: { userId: { type: 'string' } } },
      result: { shape: 'User' } },
    { '@id': 'https://threedot.dev/op/searchDocs', name: 'searchDocs', role: 'context',
      summary: 'Search documents; returns bounded previews + @id references.',
      params: { required: ['query'], properties: { query: { type: 'string' } } },
      result: { shape: 'DocPreviewList' } },
    { '@id': 'https://threedot.dev/op/setStatus', name: 'setStatus', role: 'effect',
      summary: 'Propose a status change (typed Effect, closed shape, idempotent).',
      params: { closed: true, required: ['@id', 'status'], properties: { '@id': { type: 'iri' }, status: { enum: ['open', 'doing', 'done'] } } },
      result: { shape: 'Receipt' } },
    { '@id': 'https://threedot.dev/op/aciaCard', name: 'aciaCard', role: 'component',
      summary: 'A grounded ACIA card component (HTML surface).',
      params: { required: ['title', 'body'], properties: { title: { type: 'string' }, body: { type: 'string' } } },
      result: { shape: 'AciaNode' } },
    { '@id': 'https://threedot.dev/op/brandPrimary', name: 'brandPrimary', role: 'token',
      summary: 'A grounded design token (CSS custom property).',
      result: { shape: 'Color' } }
  ]
};

export function cidPath(): string | undefined {
  const ws = vscode.workspace.workspaceFolders?.[0];
  return ws ? path.join(ws.uri.fsPath, '.threedot', 'cid.json') : undefined;
}

export function loadCid(): Cid { return loadCidState().cid; }

export function loadCidState(): CidState {
  const p = cidPath();
  if (!p) { return { cid: DEFAULT_CID, source: 'default' }; }
  if (!fs.existsSync(p)) { return { cid: DEFAULT_CID, path: p, source: 'default' }; }
  try {
    const raw = JSON.parse(fs.readFileSync(p, 'utf8')) as Partial<Cid>;
    if (!Array.isArray(raw.operations)) {
      throw new Error('CID must have an operations array');
    }
    const cid: Cid = {
      '@context': String(raw['@context'] ?? ''),
      '@id': String(raw['@id'] ?? ''),
      title: String(raw.title ?? 'Cyborg Interface'),
      operations: raw.operations as Op[],
    };
    return { cid, path: p, source: 'workspace' };
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return { cid: DEFAULT_CID, path: p, source: 'default', error: message };
  }
}

export function opByName(cid: Cid, name: string): Op | undefined {
  return findOp(cid.operations, name);
}

export function hoverMarkdown(cid: Cid, op: Op): vscode.MarkdownString {
  const md = new vscode.MarkdownString();
  md.appendMarkdown(`**${op.name}** — _${op.role}_\n\n${op.summary}\n\n`);
  md.appendMarkdown(`- \`@id\`: ${op['@id']}\n- CID: ${cid.title}\n`);
  const required = op.params?.required ?? [];
  const props = Object.keys(op.params?.properties ?? {});
  if (props.length) {
    md.appendMarkdown(`- params: ${props.map((p) => required.includes(p) ? `**${p}**` : p).join(', ')}\n`);
  }
  if (op.result?.shape) { md.appendMarkdown(`- returns: \`${op.result.shape}\`\n`); }
  if (op.params?.closed) { md.appendMarkdown('- **closed shape** (extra params flagged while you type)\n'); }
  md.appendMarkdown('\n[Open CID](command:threedot.openCID)');
  md.isTrusted = true;
  return md;
}

export function signatureLabel(op: Op): string {
  const props = Object.keys(op.params?.properties ?? {});
  const required = new Set(op.params?.required ?? []);
  const inner = props.map((p) => required.has(p) ? p : `${p}?`).join(', ');
  const ret = op.result?.shape ? ` → ${op.result.shape}` : '';
  return `three.${op.name}(${inner})${ret}`;
}

export function opNameOffset(json: string, name: string): number {
  const needle = `"name": "${name}"`;
  const i = json.indexOf(needle);
  return i === -1 ? json.indexOf(`"name":"${name}"`) : i;
}

function props(op: Op): string[] { return Object.keys(op.params?.properties ?? {}); }
function cap(s: string): string { return s.charAt(0).toUpperCase() + s.slice(1); }

export function renderCall(op: Op, lang: string): string {
  const ps = props(op);
  const kw = ps.map((n, i) => `${n}=\${${i + 1}:${n}}`).join(', ');
  const obj = ps.map((n, i) => `${n}: \${${i + 1}:${n}}`).join(', ');
  const pos = ps.map((n, i) => `\${${i + 1}:${n}}`).join(', ');
  if (op.role === 'component' && lang === 'html') {
    return '<acia-card ref="' + op['@id'] + '" title="${1:title}">${2:body}</acia-card>';
  }
  if (op.role === 'token' && lang === 'css') {
    return 'var(--' + op.name + ')';
  }
  switch (lang) {
    case 'python': return `three.${op.name}(${kw})`;
    case 'ruby': return `three.${op.name}(${kw})`;
    case 'typescript':
    case 'javascript': return `await three.${op.name}({ ${obj} })`;
    case 'go': return `three.${cap(op.name)}(ctx, ${pos})`;
    case 'rust': return `three.${op.name}(${pos}).await?`;
    case 'java': return `three.${op.name}(${pos})`;
    default: return `three.${op.name}(${pos})`;
  }
}

export function pythonImportEdits(doc: vscode.TextDocument): vscode.TextEdit[] {
  if (doc.languageId !== 'python') { return []; }
  const text = doc.getText();
  if (/\bimport\s+three\b/.test(text) || /\bfrom\s+three\b/.test(text)) { return []; }
  return [vscode.TextEdit.insert(new vscode.Position(0, 0), 'import three\n')];
}
