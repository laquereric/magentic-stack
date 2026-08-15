import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

export interface Op {
  '@id': string;
  name: string;
  role: 'context' | 'effect' | 'component' | 'token';
  summary: string;
  params?: { required?: string[]; closed?: boolean; properties?: Record<string, unknown> };
  result?: { shape?: string };
}
export interface Cid { '@context': string; '@id': string; title: string; operations: Op[]; }

// Bundled starter Cyborg Interface Descriptor (also written by "Embed CID").
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

export function loadCid(): Cid {
  const p = cidPath();
  if (p) {
    try { return JSON.parse(fs.readFileSync(p, 'utf8')) as Cid; } catch { /* use default */ }
  }
  return DEFAULT_CID;
}

function props(op: Op): string[] { return Object.keys(op.params?.properties ?? {}); }
function cap(s: string): string { return s.charAt(0).toUpperCase() + s.slice(1); }

// One grounded operation -> an idiomatic, typed "simple [language] API" snippet.
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
