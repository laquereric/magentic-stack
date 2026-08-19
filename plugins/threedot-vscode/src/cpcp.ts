/** CPCP client — FRONT talks to rails-threedot-back over /_cpcp. Never mutates live CID. */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { Cid, DEFAULT_CID, Op } from './cid';

export type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'error';

export interface BootstrapSeed {
  backUrl?: string;
  cpcpPath?: string;
  /** Seed may carry a title/@id for display but is NOT live authority. */
  title?: string;
  '@id'?: string;
}

export interface Envelope {
  ok: boolean;
  reason?: string;
  because?: string;
  value?: unknown;
  result?: unknown;
  error?: { reason?: string; because?: string };
  id?: string | number | null;
}

export interface LiveProjection {
  cid: Cid;
  digest: string;
  source: 'live' | 'default' | 'seed-fallback';
  connected: boolean;
  backUrl?: string;
  error?: string;
  fetchedAt?: string;
}

export class CpcpClient {
  private backUrl = '';
  private cpcpPath = '/_cpcp';
  private cached: LiveProjection = {
    cid: DEFAULT_CID,
    digest: digestCid(DEFAULT_CID),
    source: 'default',
    connected: false,
  };
  private state: ConnectionState = 'disconnected';
  private readonly emitter = new vscode.EventEmitter<LiveProjection>();
  readonly onDidChange = this.emitter.event;

  get projection(): LiveProjection {
    return { ...this.cached, cid: this.cached.cid };
  }

  get connectionState(): ConnectionState {
    return this.state;
  }

  /** Read .threedot/cid.json ONLY for discovery (back URL). Honor threedot.backUrl. */
  bootstrap(): BootstrapSeed {
    const setting = vscode.workspace.getConfiguration('threedot').get<string>('backUrl', '');
    const seed = readSeedFile();
    const backUrl = (setting || seed.backUrl || '').replace(/\/$/, '');
    const cpcpPath = seed.cpcpPath || '/_cpcp';
    this.backUrl = backUrl;
    this.cpcpPath = cpcpPath.startsWith('/') ? cpcpPath : `/${cpcpPath}`;
    return { ...seed, backUrl, cpcpPath: this.cpcpPath };
  }

  /** GET <back>/_cpcp/cid.json → live CID. Never writes the live CID to disk. */
  async discover(): Promise<Envelope> {
    if (!this.backUrl) {
      this.state = 'disconnected';
      this.cached = {
        cid: DEFAULT_CID,
        digest: digestCid(DEFAULT_CID),
        source: 'default',
        connected: false,
        error: 'no backUrl (set threedot.backUrl or .threedot/cid.json seed)',
      };
      this.emitter.fire(this.projection);
      return { ok: false, reason: 'no_back', because: this.cached.error };
    }
    this.state = 'connecting';
    try {
      const url = `${this.backUrl}${this.cpcpPath}/cid.json`;
      const res = await fetch(url, { method: 'GET', headers: { accept: 'application/json' } });
      const text = await res.text();
      let body: unknown;
      try {
        body = JSON.parse(text);
      } catch {
        throw new Error(`non-JSON cid.json (${res.status})`);
      }
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const cid = normalizeCid(body);
      const dig = digestCid(cid);
      this.cached = {
        cid,
        digest: dig,
        source: 'live',
        connected: true,
        backUrl: this.backUrl,
        fetchedAt: new Date().toISOString(),
      };
      this.state = 'connected';
      this.emitter.fire(this.projection);
      return { ok: true, value: cid };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.state = 'error';
      // Keep last good cache if any; else default. Shell NEVER mutates live CID.
      if (this.cached.source !== 'live') {
        this.cached = {
          cid: DEFAULT_CID,
          digest: digestCid(DEFAULT_CID),
          source: 'seed-fallback',
          connected: false,
          backUrl: this.backUrl,
          error: msg,
        };
      } else {
        this.cached = { ...this.cached, connected: false, error: msg };
      }
      this.emitter.fire(this.projection);
      return { ok: false, reason: 'discover_failed', because: msg };
    }
  }

  /** POST Context reads: threedot.cid / threedot.operations / threedot.context */
  async pull(method: string, params: Record<string, unknown> = {}): Promise<Envelope> {
    return this.rpc(method, params);
  }

  /** POST Effects: threedot.effect (idempotent via operationId). */
  async push(
    method: string,
    params: Record<string, unknown>,
    operationId: string
  ): Promise<Envelope> {
    return this.rpc(method, { ...params, operationId });
  }

  async refresh(): Promise<Envelope> {
    this.bootstrap();
    const d = await this.discover();
    if (!d.ok) return d;
    const ops = await this.pull('threedot.operations', {});
    if (ops.ok) {
      const value = (ops.value ?? ops.result) as { operations?: Op[] } | Op[] | undefined;
      const list = Array.isArray(value)
        ? value
        : value && Array.isArray(value.operations)
          ? value.operations
          : null;
      if (list) {
        const cid = { ...this.cached.cid, operations: list };
        this.cached = {
          ...this.cached,
          cid,
          digest: digestCid(cid),
          fetchedAt: new Date().toISOString(),
        };
        this.emitter.fire(this.projection);
      }
    }
    return d;
  }

  private async rpc(method: string, params: Record<string, unknown>): Promise<Envelope> {
    if (!this.backUrl) {
      return { ok: false, reason: 'no_back', because: 'BACK not configured' };
    }
    try {
      const url = `${this.backUrl}${this.cpcpPath}/rpc`;
      const id = crypto.randomUUID();
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json', accept: 'application/json' },
        body: JSON.stringify({
          jsonrpc: '2.0',
          method,
          params,
          id,
        }),
      });
      const text = await res.text();
      let body: Record<string, unknown>;
      try {
        body = JSON.parse(text) as Record<string, unknown>;
      } catch {
        return { ok: false, reason: 'bad_json', because: `HTTP ${res.status}` };
      }
      // Never-raise: domain refusal inside result, or top-level ok:false
      if (body && typeof body === 'object' && 'result' in body) {
        const result = body.result as Record<string, unknown>;
        if (result && result.ok === false) {
          return {
            ok: false,
            reason: String(result.reason ?? 'refused'),
            because: String(result.because ?? ''),
            value: result,
            id: body.id as string | number | null,
          };
        }
        return {
          ok: true,
          value: result?.value ?? result,
          result,
          id: body.id as string | number | null,
        };
      }
      if (body && body.ok === false) {
        const err = (body.error as { reason?: string; because?: string }) || {};
        return {
          ok: false,
          reason: String(body.reason ?? err.reason ?? 'error'),
          because: String(body.because ?? err.because ?? ''),
        };
      }
      if (body && body.error) {
        const err = body.error as { message?: string; code?: number };
        return {
          ok: false,
          reason: 'rpc_error',
          because: err.message || String(err.code ?? 'error'),
        };
      }
      return { ok: true, value: body };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.cached = { ...this.cached, connected: false, error: msg };
      this.state = 'error';
      this.emitter.fire(this.projection);
      return { ok: false, reason: 'network', because: msg };
    }
  }
}

function readSeedFile(): BootstrapSeed {
  const ws = vscode.workspace.workspaceFolders?.[0];
  if (!ws) return {};
  const p = path.join(ws.uri.fsPath, '.threedot', 'cid.json');
  if (!fs.existsSync(p)) return {};
  try {
    const raw = JSON.parse(fs.readFileSync(p, 'utf8')) as Record<string, unknown>;
    return {
      backUrl: typeof raw.backUrl === 'string' ? raw.backUrl
        : typeof raw.back_url === 'string' ? raw.back_url
          : typeof raw.cpcpBaseUrl === 'string' ? raw.cpcpBaseUrl
            : undefined,
      cpcpPath: typeof raw.cpcpPath === 'string' ? raw.cpcpPath : undefined,
      title: typeof raw.title === 'string' ? raw.title : undefined,
      '@id': typeof raw['@id'] === 'string' ? raw['@id'] : undefined,
    };
  } catch {
    return {};
  }
}

export function normalizeCid(raw: unknown): Cid {
  const r = (raw && typeof raw === 'object' ? raw : {}) as Partial<Cid> & { operations?: Op[] };
  if (!Array.isArray(r.operations)) {
    return DEFAULT_CID;
  }
  return {
    '@context': String(r['@context'] ?? 'https://threedot.dev/context/v1'),
    '@id': String(r['@id'] ?? 'https://threedot.dev/cid/live'),
    title: String(r.title ?? 'Live Cyborg Interface'),
    operations: r.operations,
  };
}

export function digestCid(cid: Cid): string {
  const body = JSON.stringify({
    '@id': cid['@id'],
    title: cid.title,
    operations: cid.operations.map((o) => ({ name: o.name, '@id': o['@id'], role: o.role })),
  });
  return 'sha256:' + crypto.createHash('sha256').update(body).digest('hex');
}

/** Singleton used by language features + shell. */
let client: CpcpClient | undefined;
export function getCpcpClient(): CpcpClient {
  if (!client) client = new CpcpClient();
  return client;
}
