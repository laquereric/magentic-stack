# 3dot tests — the two halves of the arc

Arc under test: **user → VS Code → 3dot plugin → Rails threedot features**.

The editor shell (VS Code) and the data plane (CPCP over `/_cpcp`) are exercised by two
complementary layers.

## 1. Data-plane arc — `test/integration/threedot_cpcp_arc_test.rb` (runnable today)

The plugin's `src/cpcp.ts` is `bootstrap → discover → pull → push` over a BACK's single
`/_cpcp` seam. This test drives that SAME arc with **mmg-browser** (headless Chrome / BiDi):
it lands on the BACK origin and runs same-origin `fetch()` calls to `/_cpcp` — exactly what
the plugin does — asserting the `docs/DEMO_USE_CASES.md` catalog against a live `rails-cpcp`
BACK (e.g. `rails-threedot-back`, or the `magentic-stack` mind-pod demo BACK).

```bash
# point at any running rails-cpcp BACK; run inside a bundle that has mmg-browser
BACK_URL=http://127.0.0.1:3025 bundle exec ruby test/integration/threedot_cpcp_arc_test.rb
```

Checks: discover CID · capabilities advertised · pull `note.list` by reference · push
`note.create` (governance receipt) · idempotent replay (no second Note) · missing-operationId
refusal (never-raise) · unknown-capability rejection · Level-8 governance journal PULL.
Proven **8/8 PASS** against the mind-pod BACK.

## 2. UI in the loop — `test/ui/` (`@vscode/test-electron`) — the NEXT STEP

This half drives the **real VS Code editor** with the extension loaded, so a test performs
actual UI actions and asserts the plugin responds. It runs the mocha suite *inside* a
launched VS Code instance.

```bash
npm install            # pulls @vscode/test-electron, mocha, glob (dev deps)
npm run test:ui        # compiles test/ui -> out-test/ and launches VS Code headless
```

Implemented rungs: the extension **activates**, registers `threedot.openShell` +
`threedot.embedCID` + `threedot.journey.start`, and **Open Shell (FRONT)** executes.

**Closing the loop (remaining next-step work in `extension.test.ts`):**
1. point `threedot.backUrl` at a live `rails-cpcp` BACK (boot the mind-pod demo),
2. `postMessage` a Develop/RUN intent into the shell webview,
3. assert the panel renders capabilities pulled from the **live CID**, and
4. open `test/fixtures/threedot_demo.py` and assert `three.` completions appear.

That yields a true end-to-end: **real UI action → plugin CPCP client → Rails features →
rendered result** — the UI and the data-plane arc joined in one loop.
