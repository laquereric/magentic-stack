import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import * as crypto from 'crypto';
import { SCHEMA_VERSION, type JourneyState, type Persona, type StepCheck } from './types';
import { spineFor } from './spines';

const EMPTY: JourneyState = {
  schemaVersion: SCHEMA_VERSION,
  journeyId: '',
  persona: null,
  currentStep: null,
  currentAltitude: null,
  status: 'idle',
  operations: [],
  artifactRefs: {},
  qualification: [],
  taskRuns: [],
  stepChecks: {},
  provenance: {},
  updatedAt: new Date().toISOString(),
};

export class JourneyStateService {
  private state: JourneyState = { ...EMPTY, operations: [], artifactRefs: {}, qualification: [], taskRuns: [], stepChecks: {}, provenance: {} };
  private readonly emitter = new vscode.EventEmitter<JourneyState>();
  readonly onDidChange = this.emitter.event;

  constructor(private readonly log: vscode.OutputChannel) {}

  get snapshot(): JourneyState {
    return JSON.parse(JSON.stringify(this.state)) as JourneyState;
  }

  journeyPath(): string | undefined {
    const ws = vscode.workspace.workspaceFolders?.[0];
    return ws ? path.join(ws.uri.fsPath, '.threedot', 'journey.json') : undefined;
  }

  load(): JourneyState {
    const p = this.journeyPath();
    if (!p || !fs.existsSync(p)) {
      this.state = this.fresh();
      void this.syncContextKeys();
      return this.snapshot;
    }
    try {
      const raw = JSON.parse(fs.readFileSync(p, 'utf8')) as JourneyState;
      this.state = { ...EMPTY, ...raw, stepChecks: raw.stepChecks ?? {}, artifactRefs: raw.artifactRefs ?? {} };
      this.recomputeGates();
      void this.syncContextKeys();
      this.log.appendLine(`journey: loaded ${p} persona=${this.state.persona} step=${this.state.currentStep}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.log.appendLine(`journey: load error ${msg}`);
      this.state = this.fresh();
      void this.syncContextKeys();
    }
    return this.snapshot;
  }

  save(): void {
    const p = this.journeyPath();
    if (!p) { return; }
    fs.mkdirSync(path.dirname(p), { recursive: true });
    this.state.updatedAt = new Date().toISOString();
    fs.writeFileSync(p, JSON.stringify(this.state, null, 2));
    void this.syncContextKeys();
    this.emitter.fire(this.snapshot);
  }

  start(persona: Persona): JourneyState {
    const spine = spineFor(persona);
    const checks: Record<string, StepCheck> = {};
    for (const s of spine) {
      checks[s.id] = { status: s.index === 1 ? 'available' : 'locked' };
    }
    this.state = {
      ...this.fresh(),
      journeyId: `${persona}-${crypto.randomBytes(4).toString('hex')}`,
      persona,
      currentStep: spine[0].id,
      currentAltitude: spine[0].altitude,
      status: 'active',
      stepChecks: checks,
    };
    this.save();
    return this.snapshot;
  }

  resume(): JourneyState {
    this.load();
    if (this.state.status === 'idle' || !this.state.persona) {
      return this.snapshot;
    }
    this.state.status = 'active';
    this.recomputeGates();
    this.save();
    return this.snapshot;
  }

  completeStep(stepId: string, evidence?: string, artifactUri?: string): JourneyState {
    const persona = this.state.persona;
    if (!persona) { return this.snapshot; }
    const spine = spineFor(persona);
    const step = spine.find((s) => s.id === stepId);
    if (!step) { return this.snapshot; }

    this.state.stepChecks[stepId] = {
      status: 'done',
      completedAt: new Date().toISOString(),
      evidence,
      artifactUri,
    };

    // Unlock next
    const next = spine.find((s) => s.index === step.index + 1);
    if (next) {
      const cur = this.state.stepChecks[next.id];
      if (!cur || cur.status === 'locked') {
        this.state.stepChecks[next.id] = { status: 'available' };
      }
      this.state.currentStep = next.id;
      this.state.currentAltitude = next.altitude;
    } else {
      this.state.status = 'complete';
      this.state.currentStep = stepId;
      this.state.currentAltitude = step.altitude;
    }
    this.save();
    return this.snapshot;
  }

  setIntent(intent: Record<string, unknown>): void {
    this.state.intent = intent;
    this.save();
  }

  setInterfacePromise(p: Record<string, unknown>): void {
    this.state.interfacePromise = p;
    this.save();
  }

  setOperations(ops: Array<Record<string, unknown>>): void {
    this.state.operations = ops;
    this.save();
  }

  addArtifact(key: string, uri: string, kind: string, content?: string): void {
    const sha256 = content
      ? crypto.createHash('sha256').update(content).digest('hex')
      : undefined;
    this.state.artifactRefs[key] = { uri, kind, sha256 };
    this.save();
  }

  addQualification(q: Record<string, unknown>): void {
    this.state.qualification.push(q);
    this.save();
  }

  addTaskRun(run: Record<string, unknown>): void {
    this.state.taskRuns.push(run);
    this.save();
  }

  setProvenance(key: string, value: unknown): void {
    this.state.provenance[key] = value;
    this.save();
  }

  isStepAvailable(stepId: string): boolean {
    const c = this.state.stepChecks[stepId];
    return c?.status === 'available' || c?.status === 'done';
  }

  isStepDone(stepId: string): boolean {
    return this.state.stepChecks[stepId]?.status === 'done';
  }

  gateOk(gate: string): boolean {
    const persona = this.state.persona;
    if (!persona) { return false; }
    const spine = spineFor(persona);
    const step = spine.find((s) => s.gate === gate);
    if (!step) { return false; }
    return this.isStepDone(step.id);
  }

  /** Derive gate context keys from stepChecks. */
  recomputeGates(): void {
    // no-op body: stepChecks are source of truth; syncContextKeys reads them
  }

  async syncContextKeys(): Promise<void> {
    const s = this.state;
    await vscode.commands.executeCommand('setContext', 'threedot.journey.active', s.status === 'active' || s.status === 'complete');
    await vscode.commands.executeCommand('setContext', 'threedot.journey.persona', s.persona ?? '');
    await vscode.commands.executeCommand('setContext', 'threedot.journey.step', s.currentStep ?? '');
    await vscode.commands.executeCommand('setContext', 'threedot.journey.altitude', s.currentAltitude ?? '');
    await vscode.commands.executeCommand('setContext', 'threedot.journey.status', s.status);
    await vscode.commands.executeCommand('setContext', 'threedot.journey.gateOk', s.status === 'active' || s.status === 'complete');
    await vscode.commands.executeCommand('setContext', 'threedot.canAdvance', s.status === 'active');
    await vscode.commands.executeCommand('setContext', 'threedot.verify.passed', this.gateOk('verifyPassed') || this.gateOk('surfaceVerified'));
    await vscode.commands.executeCommand('setContext', 'threedot.scape.qualified', this.gateOk('scapeQualified') || this.gateOk('choicesQualified'));
  }

  private fresh(): JourneyState {
    return {
      schemaVersion: SCHEMA_VERSION,
      journeyId: '',
      persona: null,
      currentStep: null,
      currentAltitude: null,
      status: 'idle',
      operations: [],
      artifactRefs: {},
      qualification: [],
      taskRuns: [],
      stepChecks: {},
      provenance: {},
      updatedAt: new Date().toISOString(),
    };
  }
}
