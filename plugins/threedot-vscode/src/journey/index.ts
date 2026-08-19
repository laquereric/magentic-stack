import * as vscode from 'vscode';
import { JourneyStateService } from './state';
import { registerJourneyCommands, JOURNEY_COMMAND_IDS } from './commands';
import { CpcpTaskProvider } from './tasks';
import { JourneyPanel } from './panel';

export { JOURNEY_COMMAND_IDS, JourneyStateService, JourneyPanel };

/** Additive activation: journey wizard on top of existing CID affordances. */
export function activateJourney(ctx: vscode.ExtensionContext, log: vscode.OutputChannel): JourneyStateService {
  const svc = new JourneyStateService(log);
  svc.load();
  registerJourneyCommands(ctx, svc, log);
  ctx.subscriptions.push(
    vscode.tasks.registerTaskProvider(CpcpTaskProvider.type, new CpcpTaskProvider(svc, log))
  );

  // Status bar breadcrumb for journey
  const bar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 90);
  const paint = (): void => {
    const s = svc.snapshot;
    if (!s.persona || s.status === 'idle') {
      bar.text = '$(map) 3dot journey';
      bar.tooltip = 'Start Cyborg Journey';
      bar.command = 'threedot.journey.start';
    } else {
      bar.text = `$(map) ${s.persona} · ${s.currentAltitude ?? '—'} · ${s.currentStep ?? ''}`;
      bar.tooltip = `Cyborg Journey ${s.status}\nClick to open panel`;
      bar.command = 'threedot.journey.openPanel';
    }
    bar.show();
  };
  paint();
  ctx.subscriptions.push(bar);
  ctx.subscriptions.push(svc.onDidChange(() => paint()));

  // Watch journey.json
  const folder = vscode.workspace.workspaceFolders?.[0];
  if (folder) {
    const watcher = vscode.workspace.createFileSystemWatcher(
      new vscode.RelativePattern(folder, '.threedot/journey.json')
    );
    watcher.onDidChange(() => { svc.load(); JourneyPanel.current?.render(); });
    watcher.onDidCreate(() => { svc.load(); });
    watcher.onDidDelete(() => { svc.load(); });
    ctx.subscriptions.push(watcher);
  }

  log.appendLine(`journey: activated (${JOURNEY_COMMAND_IDS.length} commands)`);
  return svc;
}
