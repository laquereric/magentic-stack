/** Durable journey state for .threedot/journey.json */

export type Persona = 'rails' | 'javascript';
export type Altitude = 'mission' | 'experience' | 'engineering' | 'code';
export type JourneyStatus = 'idle' | 'active' | 'blocked' | 'complete';
export type StepStatus = 'locked' | 'available' | 'done' | 'blocked';
/** Top-level Journey pane: Develop = coding spine; RUN = runtime assistance. */
export type JourneyTab = 'develop' | 'run';

export interface StepDef {
  id: string;
  index: number;
  title: string;
  altitude: Altitude;
  /** Primary command that advances this step */
  command: string;
  /** Related commands (secondary actions) */
  related?: string[];
  gate: string;
  description: string;
}

export interface StepCheck {
  status: StepStatus;
  completedAt?: string;
  evidence?: string;
  artifactUri?: string;
}

export interface JourneyState {
  schemaVersion: number;
  journeyId: string;
  persona: Persona | null;
  currentStep: string | null;
  currentAltitude: Altitude | null;
  status: JourneyStatus;
  /** Active top-level tab in the Journey webview (develop | run). */
  activeTab?: JourneyTab;
  intent?: Record<string, unknown>;
  interfacePromise?: Record<string, unknown>;
  operations: Array<Record<string, unknown>>;
  artifactRefs: Record<string, { uri: string; kind: string; sha256?: string }>;
  qualification: Array<Record<string, unknown>>;
  taskRuns: Array<Record<string, unknown>>;
  stepChecks: Record<string, StepCheck>;
  provenance: Record<string, unknown>;
  updatedAt: string;
}

export const SCHEMA_VERSION = 1;
