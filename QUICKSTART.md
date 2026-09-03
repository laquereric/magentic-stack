# QUICKSTART

**Get the threedot VS Code extension connected to the Rails backend in 6 steps.**

This guide demonstrates the full architecture: VS Code FRONT → CPCP → Rails BACK → live CID.

---

## Prerequisites

- **macOS** (tested) or Linux
- **Docker Desktop** running (required)
- **Git** (required)
- **Ruby 3.3+** with Bundler (required)
- **Node.js 20+** with npm (required)
- **Rust** with Cargo (required)

**Check your system:**

```bash
bin/prereq
```

The bootstrap script runs this check automatically and will tell you what's missing.

---

## Demo Sequence

### 1. Clone the repository

```bash
git clone https://github.com/laquereric/magentic-stack.git
cd magentic-stack
```

### 2. Open VS Code

```bash
code .
```

Open the `magentic-stack` folder in VS Code (or Cursor).

### 3. Install the threedot extension

**Option A: From source (development)**

1. Open the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`)
2. Run **Tasks: Run Task**
3. Select **Install threedot Extension (dev)** (or press `F5` to launch the Extension Development Host)

**Option B: From VSIX package**

```bash
cd plugins/threedot-vscode
npm install
npm run compile
code --install-extension threedot-*.vsix  # (build VSIX first if needed)
```

**Option C: Marketplace** *(when published)*

Search for "threedot" in the Extensions view and install.

### 4. See 'disconnected' in threedot pane

After the extension activates:

1. Open the **3dot** activity view (sidebar icon or `Cmd+Shift+P` → **3dot: Open Shell**)
2. The status bar (bottom left) shows: **`$(debug-disconnect) 3dot: disconnected`**
3. The shell panel displays: **"No BACK URL configured"**

This is expected — the extension has no Rails backend to connect to yet.

### 5. Run bootstrap

From the workspace root, run the bootstrap script to install dependencies and start the demo:

```bash
./bootstrap
```

**What bootstrap does:**

- Installs Ruby gems (workspace Bundler)
- Installs Node.js dependencies for the VS Code extension  
- Compiles TypeScript for the extension
- Builds and starts the **mind-pod demo app** in Docker (6 containers: FRONT/BACK/BACKJOB,
  MIND — the NOOA agent, which reaches Effect only through BACK's `/_cpcp` seam — plus
  SWITCH, the SwitchYard LLM plane, and GRAPH, an Oxigraph RDF projection of the
  Rails models)
- **Set a provider key in the vault UI at `http://localhost:13003`** (slot
  `switchyard.<vendor>`, e.g. `switchyard.openai`; the switch reads it from
  vault — row 11 slice A). No local model ships with the pod, so
  **cognition requires a key and the completion path does egress**. NOOA's
  contract is a tool call, so the model must be tool-capable: until one is configured
  switch refuses with `no_capable_model` and MIND logs `mind_error` each cycle. It
  does **not** degrade to a fallback — nothing leaves the machine, but nothing thinks
  either. MIND itself holds no key and names no model — SwitchYard decides.
- **Auto routing (default).** Routing is decided from declared capability and price,
  not by reading your prompt: no model sees the text in order to choose where it
  goes. Pinning an on-device router model is optional — point `OLLAMA_URL` at a
  runtime you run yourself to re-enable the local, zero-egress path, which still
  bypasses the egress gate entirely.
- **Add OpenAI or Anthropic** in the UI: paste a key, optionally set a model
  (sensible defaults are prefilled). Anthropic is translated to and from its
  Messages API, tool calls included.
- **Keys persist.** Provider keys you add in the UI are written to `.agent/secrets/`
  at the repo root (gitignored), bind-mounted into the container — so
  `bin/docker-containers down` does not destroy them. Delete that file yourself to
  remove them.
- **Known limit:** the small local models tested (`llama3.2:1b`, `qwen2.5:3b`) do
  not satisfy NOOA's structured-output contract, so with no key configured a MIND
  cognition cycle will not complete. Auto routing sends tool-calling work to a
  remote source as soon as one has a key.
- The demo FRONT web page runs at **`http://localhost:13000`**
- Host CPCP (BACK) is at **`http://localhost:13002/_cpcp`**. FRONT is
  route-gated off `/_cpcp`; curling `:13000/_cpcp` 404s.

The mind-pod app exposes CPCP on BACK (`rails-cpcp` directly) and does NOT mount `rails-threedot-back`.

**After bootstrap completes:**

With `.threedot/cid.json` created and the demo running:

1. **Reload the VS Code window**: `Cmd+Shift+P` → **Developer: Reload Window**
2. Open the **3dot Shell**: `Cmd+Shift+P` → **3dot: Open Shell (FRONT)**
3. The extension discovers the BACK via `.threedot/cid.json` 
4. Status bar updates to show connection state

**Current behavior (mind-pod backend):**

- The mind-pod app provides CPCP at `/_cpcp/rpc` but does NOT have `/threedot/shell`
- The shell panel will show the **fallback HTML** (because `/threedot/shell` returns 404)
- You can still interact with CPCP operations via the extension's CPCP client
- To see the full shell integration, you'd need to mount `rails-threedot-back` in the app

**Verify CPCP connectivity:**

```bash
# Check the CPCP endpoint is live (BACK, not FRONT)
curl http://localhost:13002/_cpcp/up

# Pull a CID operation
curl -X POST http://localhost:13002/_cpcp/rpc \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"note.list","params":{},"id":1}'
```
```

This tells the threedot extension where to find the CPCP backend.

### 6. See 'connected' in threedot pane

Once the Rails server is running:

1. Open the **3dot Shell** again: `Cmd+Shift+P` → **3dot: Open Shell**
2. The extension auto-discovers the BACK via `.threedot/cid.json` and fetches the live CID
3. Status bar update (Current Demo)

```
┌─────────────────────────┐
│  VS Code Extension      │  1. Discovers BACK via .threedot/cid.json
│  plugins/threedot-vscode│  2. Attempts /threedot/shell (404 → fallback)
└────────────┬────────────┘  3. Interacts via CPCP client ↔ /_cpcp/rpc
             │ HTTP
             │
             ▼
┌─────────────────────────┐
│  Mind-Pod Demo (Docker) │  FRONT http://localhost:13000  (web page)
│  runtimes/mind-pod/app  │  BACK  http://localhost:13002/_cpcp
├─────────────────────────┤  BACKJOB (reconciler)
│  rails-cpcp on BACK     │
│  (NOT threedot-back)    │
└─────────────────────────┘
             │
             ▼
┌─────────────────────────┐
│  Note / Reconciliation  │  AR models projected via RailsCpcp
│  (sqlite3)              │  Operations: note.list, note.create, etc.
└─────────────────────────┘
```

**To use the full threedot-back shell integration**, mount `rails-threedot-back` in a host app and add the CID/Operation AR models.          ▼
┌─────────────────────────┐
│  Rails BACK             │  Serves:
│  plugins/threedot-back  │  - /threedot/shell (webview HTML)
│  (mounted in host app)  │  - /_cpcp (CPCP seam, via rails-cpcp)
└─────────────────────────┘  - /_cpcp/cid.json (live CID projection)
             │
             ▼
┌─────────────────────────┐
│  ActiveRecord CID       │  CID root (AR model)
│  Operations, Shapes     │  has_many :operations, :capabilities
└─────────────────────────┘
```

**To use the full threedot-back shell integration**, mount `rails-threedot-back` in a host app and add the CID/Operation AR models.

---

## What's Next

- **Explore the mind-pod demo:** Open http://localhost:13000 and create notes through the CPCP boundary
- **Check container status:** `bin/docker-containers status`
- **Stop the demo:** `bin/docker-containers down`
- **Restart the demo:** `bin/docker-containers up`
- **Mount threedot-back:** To see the full shell HTML integration, add `rails-threedot-back` to a Rails app and configure the CID AR models
- **Read the docs:** `docs/architecture/OVERVIEW.md` explains the full OSI Level 8 stack

---

## Troubleshooting

**"3dot: disconnected" after bootstrap**

1. Verify FRONT: `curl http://localhost:13000/up` and BACK: `curl http://localhost:13002/_cpcp/up`
2. Check `.threedot/cid.json` exists and has `backUrl: "http://localhost:13002"`
3. Reload the extension: `Cmd+Shift+P` → **Developer: Reload Window**
4. Check the 3dot log: `Cmd+Shift+P` → **3dot: Show Log**

**Shell shows "Failed to load shell from BACK"**

This is expected for the mind-pod demo (it doesn't mount `rails-threedot-back`). The shell falls back to inline HTML but CPCP operations still work. To get full shell integration:

1. Mount `rails-threedot-back` in a Rails app
2. Add routes: `mount RailsThreedotBack::Engine, at: "/threedot"`
3. Configure CID AR models and operations

**Completions don't appear**

The mind-pod demo uses `rails-cpcp` operations (like `note.list`) not the threedot CID format. To enable completions:

1. Mount `rails-threedot-back` in your Rails app
2. Define CID operations in the AR schema
3. Ensure operations are served at `/_cpcp/cid.json`
4. Reload VS Code window

---

## License

Apache-2.0 — see `LICENSE`

**Governed by:** `GOVERNANCE.md` | **Contributing:** `CONTRIBUTING.md`
