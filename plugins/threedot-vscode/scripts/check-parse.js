#!/usr/bin/env node
'use strict';
const assert = require('assert');
const { parseThreeCalls, issuesForCall } = require('../out/parse');

const calls = parseThreeCalls('x = threedot.catalogQuery(text="Helios")');
assert.equal(calls.length, 1);
assert.equal(calls[0].name, 'catalogQuery');
assert.deepEqual(calls[0].keys, ['text']);

const missing = issuesForCall(
  { name: 'catalogQuery', params: { required: ['text'], properties: { text: { type: 'string' } } } },
  parseThreeCalls('threedot.catalogQuery()')[0]
);
assert.equal(missing[0].code, 'threedot/missing-required');

const unknown = issuesForCall(undefined, parseThreeCalls('threedot.notAThing()')[0]);
assert.equal(unknown[0].code, 'threedot/unknown-capability');

const extra = issuesForCall(
  { name: 'triage', params: { closed: true, required: ['message'], properties: { message: { type: 'string' } } } },
  parseThreeCalls('threedot.triage(message="x", surprise=1)')[0]
);
assert.ok(extra.some((i) => i.code === 'threedot/unexpected-param'));

const ts = parseThreeCalls('await threedot.recommend({ request: "gpus" })');
assert.deepEqual(ts[0].keys, ['request']);

// pythonImportLine — an import must never land above a module docstring.
// Regression: mind_agent.py had `import threedot` inserted at line 0, which
// demoted its docstring to a bare expression and lost it.
const { pythonImportLine } = require('../out/parse');

const mindAgent = [
  '"""MIND cognition, expressed in NOOA.',
  '',
  'Second paragraph of the docstring.',
  '"""',
  'from nooa import Agent',
].join('\n');
assert.equal(pythonImportLine(mindAgent), 4, 'insert after a multi-line docstring');

assert.equal(pythonImportLine('"""One liner."""\nx = 1'), 1, 'single-line triple-quoted docstring');
assert.equal(pythonImportLine("'''One liner.'''\nx = 1"), 1, 'single-quoted triple docstring');
assert.equal(pythonImportLine('"Short docstring."\nx = 1'), 1, 'bare-quote docstring');
assert.equal(pythonImportLine('r"""Raw docstring."""\nx = 1'), 1, 'prefixed (raw) docstring');
assert.equal(pythonImportLine('from nooa import Agent\n'), 0, 'no docstring: line 0 is fine');
assert.equal(pythonImportLine('#!/usr/bin/env python\n"""Doc."""\nx = 1'), 2, 'shebang then docstring');
assert.equal(pythonImportLine('# -*- coding: utf-8 -*-\n"""Doc."""\nx = 1'), 2, 'encoding decl then docstring');
assert.equal(pythonImportLine('# a comment\n\n"""Doc."""\nx = 1'), 3, 'leading comments then docstring');
assert.equal(pythonImportLine('x = "not a docstring"\n'), 0, 'assignment is not a docstring');
assert.equal(pythonImportLine('"""unterminated\nx = 1'), 0, 'unterminated docstring: do not move');

console.log('check-parse: ok');
