import * as assert from 'assert';
import * as vscode from 'vscode';

// Arc under test: user -> VS Code -> 3dot plugin -> (Rails threedot features).
// This is the UI half of the loop: it drives the REAL editor. The CPCP data-plane half
// lives in test/integration/threedot_cpcp_arc_test.rb (mmg-browser). Together they cover
// the whole arc; a future rung wires the webview to a live BACK for a true end-to-end.
function threedot(): vscode.Extension<unknown> {
  const ext = vscode.extensions.all.find((e) => (e.packageJSON?.name === 'threedot'));
  assert.ok(ext, '3dot extension not found in the test VS Code instance');
  return ext!;
}

suite('3dot extension — UI in the loop', () => {
  test('activates', async () => {
    const ext = threedot();
    await ext.activate();
    assert.strictEqual(ext.isActive, true);
  });

  test('registers the FRONT shell + core commands', async () => {
    await threedot().activate();
    const cmds = await vscode.commands.getCommands(true);
    for (const id of ['threedot.openShell', 'threedot.embedCID', 'threedot.journey.start']) {
      assert.ok(cmds.includes(id), `command not registered: ${id}`);
    }
  });

  test('Open Shell (FRONT) executes without throwing', async () => {
    await threedot().activate();
    await vscode.commands.executeCommand('threedot.openShell');
    // A webview panel should now exist; deeper assertions are the next rung (below).
  });

  // NEXT STEP (documented in test/README.md): drive the webview end-to-end —
  //   1. point threedot.backUrl at a live rails-cpcp BACK (boot the mind-pod demo),
  //   2. postMessage a Develop/RUN intent into the shell webview,
  //   3. assert the panel renders capabilities pulled from the live CID, and
  //   4. open test/fixtures/threedot_demo.py and assert `three.` completions appear.
  // This closes the loop: real UI action -> plugin CPCP client -> Rails features -> rendered result.
});
