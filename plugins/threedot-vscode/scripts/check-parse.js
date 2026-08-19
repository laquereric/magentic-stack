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

console.log('check-parse: ok');
