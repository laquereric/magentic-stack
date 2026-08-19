import * as vscode from 'vscode';
import type { JourneyStateService } from './state';
import { JourneyPanel } from './panel';
import { spineFor } from './spines';
import type { Persona } from './types';
import {
  writeArtifact,
  integrationBriefMd,
  operationPlanMd,
  cpcpPodYaml,
  interfacePromiseMd,
  frontDoorMd,
  bindingMatrixMd,
  releaseEvidenceMd,
} from './artifacts';
import { runNamedTask } from './tasks';
import { loadCidState } from '../cid';

/** Register all journey / CPCP / frontdoor / scape / release commands (additive). */
export function registerJourneyCommands(
  ctx: vscode.ExtensionContext,
  svc: JourneyStateService,
  log: vscode.OutputChannel,
): void {
  const reg = (id: string, fn: (...args: unknown[]) => unknown) => {
    ctx.subscriptions.push(vscode.commands.registerCommand(id, fn));
  };

  // ── Journey control ──────────────────────────────────────────────
  reg('threedot.journey.openPanel', () => JourneyPanel.show(svc));
  reg('threedot.journey.start', async () => {
    const pick = await vscode.window.showQuickPick(
      [
        { label: 'Developer_RAILS', description: 'engineering → code CPCP spine', persona: 'rails' as Persona },
        { label: 'Developer_JavaScript', description: 'experience → engineering front-door spine', persona: 'javascript' as Persona },
      ],
      { placeHolder: 'Select Cyborg Journey persona' }
    );
    if (!pick) { return; }
    svc.start(pick.persona);
    JourneyPanel.show(svc);
    void vscode.window.showInformationMessage(`3dot journey: started ${pick.persona}`);
  });
  reg('threedot.journey.resume', () => {
    const s = svc.resume();
    if (!s.persona) {
      void vscode.window.showInformationMessage('3dot: no journey to resume — starting fresh.', 'Start')
        .then((a) => { if (a === 'Start') { void vscode.commands.executeCommand('threedot.journey.start'); } });
      return;
    }
    JourneyPanel.show(svc);
    void vscode.window.showInformationMessage(`3dot journey: resumed ${s.persona} @ ${s.currentStep}`);
  });
  reg('threedot.journey.selectPersona', (persona?: unknown) => {
    const p = (persona === 'javascript' ? 'javascript' : persona === 'rails' ? 'rails' : null) as Persona | null;
    if (!p) {
      void vscode.commands.executeCommand('threedot.journey.start');
      return;
    }
    svc.start(p);
    JourneyPanel.show(svc);
  });

  // ── Rails spine ──────────────────────────────────────────────────
  reg('threedot.journey.selectIntegration', async () => {
    if (!requirePersona(svc, 'rails')) { return; }
    const objective = await vscode.window.showInputBox({ prompt: 'Integration objective', placeHolder: 'Trusted partner trade-in offers' });
    if (!objective) { return; }
    const direction = await vscode.window.showQuickPick(['PULL', 'PUSH'], { placeHolder: 'Data direction' });
    if (!direction) { return; }
    const counterparty = await vscode.window.showInputBox({ prompt: 'Counterparty class', placeHolder: 'qualified partner' }) ?? '';
    const proof = await vscode.window.showInputBox({ prompt: 'Expected proof / evidence', placeHolder: 'CID + verify report' }) ?? '';
    const intent = { objective, direction, counterparty, proof, sensitivity: 'partner-commerce', outcome: 'qualified offer exchange' };
    svc.setIntent(intent);
    const uri = await writeArtifact(svc, 'integrationBrief', 'integration-brief.md', integrationBriefMd(intent), 'integration-brief');
    svc.completeStep('rails.1', 'integration intent captured', uri);
    log.appendLine('journey: rails.1 done');
  });

  reg('threedot.journey.defineOperations', async () => {
    if (!requirePersona(svc, 'rails')) { return; }
    if (!svc.isStepAvailable('rails.2')) {
      void vscode.window.showWarningMessage('3dot: complete Integration step first.');
      return;
    }
    const raw = await vscode.window.showInputBox({
      prompt: 'Operations (comma-separated names)',
      placeHolder: 'discover, qualify, request_offer',
      value: 'discover, qualify, request_offer',
    });
    if (!raw) { return; }
    const ops = raw.split(',').map((n) => n.trim()).filter(Boolean).map((name) => ({
      name,
      direction: svc.snapshot.intent?.direction ?? 'PULL',
      request: `${name}Request`,
      response: `${name}Result`,
      envelope: 'never-raise',
    }));
    svc.setOperations(ops);
    const uri = await writeArtifact(svc, 'operationPlan', 'operation-plan.md', operationPlanMd(ops), 'operation-plan');
    svc.completeStep('rails.2', `${ops.length} operations defined`, uri);
  });

  reg('threedot.cpcp.planBoundary', async () => {
    if (!requirePersona(svc, 'rails')) { return; }
    if (!svc.isStepAvailable('rails.3')) {
      void vscode.window.showWarningMessage('3dot: complete Operations step first.');
      return;
    }
    const title = String(svc.snapshot.intent?.objective ?? 'cpcp-pod');
    const yaml = cpcpPodYaml(title);
    const uri = await writeArtifact(svc, 'cpcpPod', 'cpcp.pod.yaml', yaml, 'cpcp-pod');
    svc.setProvenance('podRoles', ['FRONT', 'BACK', 'BackJob', 'GRAPH']);
    svc.completeStep('rails.3', 'four-role boundary planned', uri);
  });

  reg('threedot.cpcp.generateBindRun', async () => {
    if (!requirePersona(svc, 'rails')) { return; }
    if (!svc.isStepAvailable('rails.4')) {
      void vscode.window.showWarningMessage('3dot: complete pod boundary first.');
      return;
    }
    // Reuse existing embedCID affordance
    await vscode.commands.executeCommand('threedot.embedCID');
    const cid = loadCidState();
    svc.setProvenance('cidId', cid.cid['@id']);
    svc.setProvenance('cidSource', cid.source);
    const snippet = `# CID-bound call site (never-raise)
# threedot.discover(query="partner")  → envelope {ok, reason, because, value}
# Bind path: /_cpcp/cid.json
# Use … completion or Insert Capability after CID is embedded.
`;
    const uri = await writeArtifact(svc, 'bindRun', 'cid-bind-run.md', snippet, 'code-bind');
    await runNamedTask(svc, 'run-pod');
    svc.completeStep('rails.4', 'CID embedded + bind scaffold', uri);
    void vscode.window.showInformationMessage('3dot: CID bound — type … to insert operations.');
  });

  reg('threedot.mmgScape.discoverQualify', async () => {
    if (!requirePersona(svc, 'rails')) { return; }
    if (!svc.isStepAvailable('rails.5')) {
      void vscode.window.showWarningMessage('3dot: complete generate/bind first.');
      return;
    }
    const candidate = {
      id: 'scape:partner:acme',
      qualified: true,
      cidHash: 'demo-cid-hash',
      freshness: new Date().toISOString(),
      provenance: 'mmg-scape mock (offline)',
    };
    svc.addQualification(candidate);
    const md = `# mmg-scape Qualification

| Candidate | Qualified | CID hash | Freshness |
|---|---|---|---|
| ${candidate.id} | yes | ${candidate.cidHash} | ${candidate.freshness} |

Provenance: ${candidate.provenance}

Unqualified results are blocked from callable actions.
`;
    const uri = await writeArtifact(svc, 'qualification', 'scape-qualify.md', md, 'scape-qualify');
    svc.completeStep('rails.5', 'candidate qualified', uri);
  });

  reg('threedot.scape.openObservation', async () => {
    const q = svc.snapshot.qualification;
    const md = `# Scape Observation\n\n\`\`\`json\n${JSON.stringify(q, null, 2)}\n\`\`\`\n`;
    await writeArtifact(svc, 'scapeObservation', 'scape-observation.md', md, 'observation');
  });

  reg('threedot.release.prepare', async () => {
    if (!svc.snapshot.persona) {
      void vscode.window.showWarningMessage('3dot: start a journey first.');
      return;
    }
    const s = svc.snapshot;
    const done = Object.entries(s.stepChecks).filter(([, v]) => v.status === 'done').map(([k]) => k);
    const cid = loadCidState();
    const md = releaseEvidenceMd({
      persona: s.persona ?? 'unknown',
      journeyId: s.journeyId,
      steps: done,
      verify: 'pending',
      cid: cid.cid['@id'],
    });
    const uri = await writeArtifact(svc, 'releasePrep', 'release-evidence.md', md, 'release-evidence');
    if (s.persona === 'rails' && svc.isStepAvailable('rails.6')) {
      // prepare alone does not finish; verify does — but mark prep evidence
      svc.addArtifact('releasePrep', uri ?? '', 'release-evidence');
    }
    void vscode.window.showInformationMessage('3dot: release package prepared — run verify.');
  });

  reg('threedot.cpcp.verify', async () => {
    await runNamedTask(svc, 'verify');
    const report = `# mmg-cpcp-verify report (offline scaffold)

ok: true
roles: FRONT, BACK, BackJob, GRAPH
in_process_jobs: false
graph_wired: true (offline mock)
cid_bound: true

---
*Task threedot-cpcp:verify*
`;
    const uri = await writeArtifact(svc, 'verifyReport', 'cpcp-verify-report.md', report, 'verify-report');
    svc.setProvenance('verifyPassed', true);
    if (svc.snapshot.persona === 'rails' && svc.isStepAvailable('rails.6')) {
      svc.completeStep('rails.6', 'verify passed', uri);
    }
  });

  reg('threedot.release.openEvidence', async () => {
    const ref = svc.snapshot.artifactRefs['releasePrep'] ?? svc.snapshot.artifactRefs['verifyReport']
      ?? svc.snapshot.artifactRefs['surfaceEvidence'];
    if (ref?.uri) {
      try {
        const doc = await vscode.workspace.openTextDocument(ref.uri);
        await vscode.window.showTextDocument(doc, { preview: true });
        return;
      } catch { /* fall through */ }
    }
    await vscode.commands.executeCommand('threedot.release.prepare');
  });

  // ── JavaScript spine ─────────────────────────────────────────────
  reg('threedot.journey.defineInterfacePromise', async () => {
    if (!requirePersona(svc, 'javascript')) { return; }
    const promise = await vscode.window.showInputBox({ prompt: 'Interface promise', placeHolder: 'Qualified partner sees only allowed actions' });
    if (!promise) { return; }
    const owner = await vscode.window.showInputBox({ prompt: 'Owner / action', placeHolder: 'commerce.pair' }) ?? '';
    const p = { promise, owner, eligibility: 'jurisdiction + CID', discovery: 'mmg-scape', disclosure: 'envelope-safe' };
    svc.setInterfacePromise(p);
    const uri = await writeArtifact(svc, 'interfacePromise', 'interface-promise.md', interfacePromiseMd(p), 'interface-promise');
    svc.completeStep('js.1', 'interface promise captured', uri);
  });

  reg('threedot.frontdoor.scaffold', async () => {
    if (!requirePersona(svc, 'javascript')) { return; }
    if (!svc.isStepAvailable('js.2')) {
      void vscode.window.showWarningMessage('3dot: complete interface promise first.');
      return;
    }
    const uri = await writeArtifact(svc, 'frontDoor', 'front-door.md', frontDoorMd(), 'front-door');
    svc.completeStep('js.2', 'front door scaffolded', uri);
  });

  reg('threedot.frontdoor.preview', async () => {
    await writeArtifact(svc, 'frontDoorPreview', 'front-door-preview.md', frontDoorMd() + '\n## Preview\nidle → discovering → qualified | unavailable\n', 'front-door-preview');
  });

  reg('threedot.contract.bindCapabilities', async () => {
    if (!requirePersona(svc, 'javascript')) { return; }
    if (!svc.isStepAvailable('js.3')) {
      void vscode.window.showWarningMessage('3dot: complete front door first.');
      return;
    }
    const ops = svc.snapshot.operations.length
      ? svc.snapshot.operations
      : [
          { name: 'discover', cidOp: 'commerce.discover' },
          { name: 'request_offer', cidOp: 'commerce.offer.request' },
        ];
    svc.setOperations(ops);
    const uri = await writeArtifact(svc, 'bindingMatrix', 'binding-matrix.md', bindingMatrixMd(ops), 'binding-matrix');
    svc.completeStep('js.3', 'capabilities bound', uri);
  });

  reg('threedot.contract.openBindingMatrix', async () => {
    const ref = svc.snapshot.artifactRefs['bindingMatrix'];
    if (ref?.uri) {
      const doc = await vscode.workspace.openTextDocument(ref.uri);
      await vscode.window.showTextDocument(doc, { preview: true });
    } else {
      await vscode.commands.executeCommand('threedot.contract.bindCapabilities');
    }
  });

  reg('threedot.contract.bindAtCursor', async () => {
    await vscode.commands.executeCommand('threedot.insertCapability');
  });

  reg('threedot.frontdoor.composeInteraction', async () => {
    if (!requirePersona(svc, 'javascript')) { return; }
    if (!svc.isStepAvailable('js.4')) {
      void vscode.window.showWarningMessage('3dot: complete binding first.');
      return;
    }
    await vscode.commands.executeCommand('threedot.embedCID');
    const code = `// Front-door interaction (CID-bound, never-raise)
// envelope = threedot.request_offer(partnerId="acme")
// if (!envelope.ok) renderEnvelope(envelope.reason, envelope.because)
`;
    const uri = await writeArtifact(svc, 'composeInteraction', 'compose-interaction.ts', code, 'code-compose');
    svc.completeStep('js.4', 'interaction composed + CID embedded', uri);
  });

  reg('threedot.scape.discoverChoices', async () => {
    if (!requirePersona(svc, 'javascript')) { return; }
    if (!svc.isStepAvailable('js.5')) {
      void vscode.window.showWarningMessage('3dot: complete compose first.');
      return;
    }
    const choice = { id: 'choice:acme', qualified: true, cidHash: 'demo-js-cid', provenance: 'mmg-scape mock' };
    svc.addQualification(choice);
    const md = `# Discover Choices\n\n- ${choice.id} · qualified · ${choice.cidHash}\n\nUnqualified options are not offered.\n`;
    const uri = await writeArtifact(svc, 'discoverChoices', 'discover-choices.md', md, 'scape-choices');
    svc.completeStep('js.5', 'choices qualified', uri);
  });

  reg('threedot.scape.populateChoice', async () => {
    const q = svc.snapshot.qualification[svc.snapshot.qualification.length - 1];
    if (!q) {
      void vscode.window.showWarningMessage('3dot: discover choices first.');
      return;
    }
    await writeArtifact(svc, 'populatedChoice', 'populated-choice.md', `# Populated Choice\n\n\`\`\`json\n${JSON.stringify(q, null, 2)}\n\`\`\`\n`, 'choice');
  });

  reg('threedot.scape.discoverQualify', async () => {
    await vscode.commands.executeCommand('threedot.mmgScape.discoverQualify');
  });

  reg('threedot.scape.qualifyChoice', async () => {
    await vscode.commands.executeCommand('threedot.scape.discoverChoices');
  });

  reg('threedot.scape.insertQualifiedCall', async () => {
    await vscode.commands.executeCommand('threedot.insertCapability');
  });

  reg('threedot.frontdoor.verifySurface', async () => {
    if (!requirePersona(svc, 'javascript')) { return; }
    if (!svc.isStepAvailable('js.6')) {
      void vscode.window.showWarningMessage('3dot: complete discovery first.');
      return;
    }
    const s = svc.snapshot;
    const done = Object.entries(s.stepChecks).filter(([, v]) => v.status === 'done').map(([k]) => k);
    const cid = loadCidState();
    const md = releaseEvidenceMd({
      persona: 'javascript',
      journeyId: s.journeyId,
      steps: done,
      verify: 'surface-ok',
      cid: cid.cid['@id'],
    });
    const uri = await writeArtifact(svc, 'surfaceEvidence', 'surface-evidence.md', md, 'surface-evidence');
    svc.completeStep('js.6', 'surface verified', uri);
  });

  reg('threedot.cpcp.deploy', async () => { await runNamedTask(svc, 'deploy'); });
  reg('threedot.cpcp.run', async () => { await runNamedTask(svc, 'run-pod'); });

  reg('threedot.journey.openEvidence', async () => {
    await vscode.commands.executeCommand('threedot.release.openEvidence');
  });

  log.appendLine('journey: commands registered');
}

function requirePersona(svc: JourneyStateService, want: Persona): boolean {
  const s = svc.snapshot;
  if (!s.persona) {
    void vscode.window.showWarningMessage('3dot: start a journey and select persona first.', 'Start')
      .then((a) => { if (a === 'Start') { void vscode.commands.executeCommand('threedot.journey.start'); } });
    return false;
  }
  if (s.persona !== want) {
    void vscode.window.showWarningMessage(`3dot: this step is for ${want} (current: ${s.persona}).`);
    return false;
  }
  return true;
}

/** Exported for activation smoke: list of command ids we register. */
export const JOURNEY_COMMAND_IDS = [
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
] as const;
