/** vscode-free parsing of `threedot.op(...)` calls and CID shape checks. */

export interface ThreeCall {
  name: string;
  nameStart: number;
  nameEnd: number;
  argsStart: number;
  argsEnd: number;
  keys: string[];
  empty: boolean;
  positional: boolean;
}

export interface CallIssue {
  code: string;
  message: string;
  on: 'name' | 'args';
}

export interface OpLike {
  name: string;
  params?: { required?: string[]; closed?: boolean; properties?: Record<string, unknown> };
}

export function parseThreeCalls(line: string): ThreeCall[] {
  const out: ThreeCall[] = [];
  const re = /threedot\.([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(line)) !== null) {
    const name = m[1];
    const nameStart = m.index + 'threedot.'.length;
    const nameEnd = nameStart + name.length;
    const open = m.index + m[0].length - 1;
    const close = matchingParen(line, open);
    const argsEnd = close === -1 ? line.length : close;
    const argText = line.slice(open + 1, argsEnd);
    const keys = argKeys(argText);
    const trimmed = argText.trim();
    out.push({
      name,
      nameStart,
      nameEnd,
      argsStart: open + 1,
      argsEnd,
      keys,
      empty: trimmed.length === 0,
      positional: trimmed.length > 0 && keys.length === 0,
    });
    if (close === -1) { break; }
    re.lastIndex = close + 1;
  }
  return out;
}

export function issuesForCall(op: OpLike | undefined, call: ThreeCall): CallIssue[] {
  if (!op) {
    return [{
      code: 'threedot/unknown-capability',
      message: `threedot/unknown-capability: '${call.name}' is not in the Cyborg Interface Descriptor (CID).`,
      on: 'name',
    }];
  }
  if (call.positional) { return []; }
  const required = op.params?.required ?? [];
  const known = new Set(Object.keys(op.params?.properties ?? {}));
  required.forEach((r) => known.add(r));
  const issues: CallIssue[] = [];
  if (!call.empty) {
    for (const req of required) {
      if (!call.keys.includes(req)) {
        issues.push({
          code: 'threedot/missing-required',
          message: `threedot/missing-required: '${op.name}' needs ${req}.`,
          on: 'args',
        });
      }
    }
  } else if (required.length > 0) {
    issues.push({
      code: 'threedot/missing-required',
      message: `threedot/missing-required: '${op.name}' needs ${required.join(', ')}.`,
      on: 'args',
    });
  }
  if (op.params?.closed) {
    for (const key of call.keys) {
      if (!known.has(key)) {
        issues.push({
          code: 'threedot/unexpected-param',
          message: `threedot/unexpected-param: '${key}' is not in the closed shape for '${op.name}'.`,
          on: 'args',
        });
      }
    }
  }
  return issues;
}

export function findOp<T extends OpLike>(ops: T[], name: string): T | undefined {
  const n = name.toLowerCase();
  return ops.find((o) => o.name.toLowerCase() === n);
}

function argKeys(argText: string): string[] {
  const kw = [...argText.matchAll(/([A-Za-z_][A-Za-z0-9_]*)\s*=/g)].map((x) => x[1]);
  if (kw.length) { return unique(kw); }
  const obj = [...argText.matchAll(/([A-Za-z_][A-Za-z0-9_]*)\s*:/g)].map((x) => x[1]);
  return unique(obj);
}

function unique(xs: string[]): string[] {
  return [...new Set(xs)];
}

function matchingParen(s: string, open: number): number {
  let depth = 0;
  for (let i = open; i < s.length; i++) {
    const c = s[i];
    if (c === '(' || c === '{' || c === '[') { depth++; }
    else if (c === ')' || c === '}' || c === ']') {
      depth--;
      if (depth === 0) { return i; }
    }
  }
  return -1;
}

/**
 * Line index at which a top-level `import` may be inserted in a Python module.
 *
 * A string literal is a docstring ONLY when it is the module's first statement,
 * so inserting an import above one silently demotes it to a bare expression and
 * the docstring is lost. Skip, in order: a shebang, a PEP 263 encoding
 * declaration, leading comments and blank lines, then the docstring itself.
 */
export function pythonImportLine(text: string): number {
  const lines = text.split('\n');
  let i = 0;
  if (/^#!/.test(lines[0] ?? '')) { i += 1; }
  while (i < lines.length && i < 2 && /^\s*#.*coding[:=]/.test(lines[i])) { i += 1; }
  while (i < lines.length && (lines[i].trim() === '' || lines[i].trimStart().startsWith('#'))) { i += 1; }
  if (i >= lines.length) { return lines.length; }

  const open = /^\s*[rRuUbBfF]{0,2}("""|'''|"|')/.exec(lines[i]);
  if (!open) { return i; }
  const quote = open[1];
  if (lines[i].slice(open[0].length).includes(quote)) { return i + 1; }
  for (let j = i + 1; j < lines.length; j += 1) {
    if (lines[j].includes(quote)) { return j + 1; }
  }
  return i;
}
