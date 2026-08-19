import * as vscode from 'vscode';
import type { JourneyStateService } from './state';

/**
 * VS Code TaskProvider for CPCP pod lifecycle.
 * Tasks are declarative shells; real deploy/verify wiring is host-side.
 */
export class CpcpTaskProvider implements vscode.TaskProvider {
  static readonly type = 'threedot-cpcp';

  constructor(private readonly svc: JourneyStateService, private readonly log: vscode.OutputChannel) {}

  provideTasks(): vscode.Task[] {
    return [
      this.make('deploy', 'Deploy four-container CPCP pod', 'echo "[threedot] cpcp.deploy (FRONT/BACK/BackJob/GRAPH)"'),
      this.make('verify', 'Run mmg-cpcp-verify', 'echo "[threedot] cpcp.verify — mmg-cpcp-verify report"'),
      this.make('run-pod', 'Run CPCP pod locally', 'echo "[threedot] cpcp.run-pod"'),
    ];
  }

  resolveTask(task: vscode.Task): vscode.Task | undefined {
    const def = task.definition as { type: string; task?: string };
    if (def.type !== CpcpTaskProvider.type) { return undefined; }
    const name = def.task ?? 'run-pod';
    const map: Record<string, string> = {
      deploy: 'echo "[threedot] cpcp.deploy (FRONT/BACK/BackJob/GRAPH)"',
      verify: 'echo "[threedot] cpcp.verify — mmg-cpcp-verify report"',
      'run-pod': 'echo "[threedot] cpcp.run-pod"',
    };
    return this.make(name, task.name, map[name] ?? map['run-pod']);
  }

  private make(taskName: string, title: string, cmdline: string): vscode.Task {
    const def: vscode.TaskDefinition = { type: CpcpTaskProvider.type, task: taskName };
    const exec = new vscode.ShellExecution(cmdline);
    const task = new vscode.Task(def, vscode.TaskScope.Workspace, title, 'threedot', exec);
    task.group = vscode.TaskGroup.Build;
    task.presentationOptions = { reveal: vscode.TaskRevealKind.Always, panel: vscode.TaskPanelKind.Shared };
    this.log.appendLine(`task: provided ${taskName}`);
    return task;
  }
}

export async function runNamedTask(svc: JourneyStateService, taskName: string): Promise<void> {
  const tasks = await vscode.tasks.fetchTasks({ type: CpcpTaskProvider.type });
  let task = tasks.find((t) => (t.definition as { task?: string }).task === taskName);
  if (!task) {
    const provider = new CpcpTaskProvider(svc, vscode.window.createOutputChannel('3dot-tasks-tmp'));
    task = provider.provideTasks().find((t) => (t.definition as { task?: string }).task === taskName);
  }
  if (!task) {
    void vscode.window.showWarningMessage(`3dot: task ${taskName} not found`);
    return;
  }
  const exec = await vscode.tasks.executeTask(task);
  svc.addTaskRun({
    name: taskName,
    startedAt: new Date().toISOString(),
    execution: exec.task.name,
  });
}
