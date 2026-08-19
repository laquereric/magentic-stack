import * as path from 'path';
import { runTests } from '@vscode/test-electron';

// UI-IN-THE-LOOP: launches a real VS Code instance with this extension loaded and runs the
// mocha suite INSIDE it, so the tests exercise the actual editor + 3dot commands/webview.
async function main() {
  try {
    const extensionDevelopmentPath = path.resolve(__dirname, '../../');
    const extensionTestsPath = path.resolve(__dirname, './suite/index');
    const fixture = path.resolve(__dirname, '../../test/fixtures');
    await runTests({ extensionDevelopmentPath, extensionTestsPath, launchArgs: [fixture, '--disable-extensions'] });
  } catch (err) {
    console.error('UI tests failed to run:', err);
    process.exit(1);
  }
}
main();
