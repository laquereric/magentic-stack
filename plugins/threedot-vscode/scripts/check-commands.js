#!/usr/bin/env node
/** Verify package.json contributes.commands match registered journey command ids + core. */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const contrib = new Set((pkg.contributes.commands || []).map((c) => c.command));

// Core + journey (from src/journey/commands.ts JOURNEY_COMMAND_IDS + extension.ts)
const required = [
  'threedot.embedCID',
  'threedot.showCapabilities',
  'threedot.insertCapability',
  'threedot.openCID',
  'threedot.reloadCID',
  'threedot.showLog',
  'threedot.openShell',
  'threedot.journey.openPanel',
  'threedot.journey.start',
  'threedot.journey.resume',
  'threedot.journey.selectPersona',
  'threedot.journey.selectIntegration',
  'threedot.journey.defineOperations',
  'threedot.journey.defineInterfacePromise',
  'threedot.journey.openEvidence',
  'threedot.cpcp.planBoundary',
  'threedot.cpcp.generateBindRun',
  'threedot.cpcp.verify',
  'threedot.cpcp.deploy',
  'threedot.cpcp.run',
  'threedot.mmgScape.discoverQualify',
  'threedot.scape.openObservation',
  'threedot.scape.discoverChoices',
  'threedot.scape.populateChoice',
  'threedot.scape.discoverQualify',
  'threedot.scape.qualifyChoice',
  'threedot.scape.insertQualifiedCall',
  'threedot.contract.bindCapabilities',
  'threedot.contract.openBindingMatrix',
  'threedot.contract.bindAtCursor',
  'threedot.frontdoor.scaffold',
  'threedot.frontdoor.preview',
  'threedot.frontdoor.composeInteraction',
  'threedot.frontdoor.verifySurface',
  'threedot.release.prepare',
  'threedot.release.openEvidence',
];

const missing = required.filter((id) => !contrib.has(id));
if (missing.length) {
  console.error('Missing contributes.commands:', missing.join(', '));
  process.exit(1);
}

// Ensure out/extension.js exports activate and mentions journey
const extOut = path.join(root, 'out', 'extension.js');
if (!fs.existsSync(extOut)) {
  console.error('out/extension.js missing — run npm run compile first');
  process.exit(1);
}
const body = fs.readFileSync(extOut, 'utf8');
if (!body.includes('activateJourney') && !body.includes('journey')) {
  console.error('compiled extension does not reference journey activation');
  process.exit(1);
}

// Count registerCommand in journey out
const journeyOut = path.join(root, 'out', 'journey', 'commands.js');
if (!fs.existsSync(journeyOut)) {
  console.error('out/journey/commands.js missing');
  process.exit(1);
}
const jbody = fs.readFileSync(journeyOut, 'utf8');
const regs = (jbody.match(/registerCommand/g) || []).length;
if (regs < 1) {
  console.error('no registerCommand in journey commands');
  process.exit(1);
}

console.log(`ok: ${contrib.size} contributes.commands; journey registerCommand present; tsc artifacts ok`);
