# Research query — a RUBY path to WebDriver BiDi (follow-up for Manus)

**Date:** 2026-07-09
**For:** Manus deep-research (hand off manually — `research_delegate` browser-IO path
is down; quoting bug in `Mm::Research::ManusBrowserAdapter`).
**Follows:** [`Mozilla Browser Control (2025–2026)_ Architectural Recommendation.md`](Mozilla%20Browser%20Control%20(2025%E2%80%932026)_%20Architectural%20Recommendation.md)
(Manus’s answer) + [`MozillaBrowserControlQuery.md`](MozillaBrowserControlQuery.md) (the original query).

**Why this follow-up.** Manus’s recommendation picked **Selenium 4 (Python)** as
“lowest-friction” *only because the current `browser-harness` is Python*. But that
reasoning is backwards for us: **our substrate is Ruby/Rails.** A separate Python
daemon is a polyglot second runtime, a second supervised process, and an
out-of-Rails home for logic — exactly the shape our doctrine pushes back on
(“logic lives in Rails; a daemon offload is an optimization, not a default;
dangling out-of-Rails logic is a security problem”). We want the browser-control
transport **in Ruby**, ideally in-process in the Rails app (or a thin Ruby
effector), so it composes with the MCB boundary and the never-raise envelope
directly.

---

## Prompt (paste into Manus)

> **Give me the RUBY path to WebDriver BiDi browser control of Firefox — a
> concrete, current (2025–2026) recommendation, not Python. Assume the consuming
> application is a long-running Ruby/Rails process.**
>
> **Answer specifically:**
> 1. **`selenium-webdriver` (Ruby gem), current version.** Does its Ruby binding
>    expose WebDriver BiDi (the bidirectional/WebSocket features: `log.entryAdded`
>    console streaming, network interception, `browsingContext` DOM/mutation
>    events, `script.evaluate`, `input.performActions`)? Show the Ruby API for
>    enabling BiDi and subscribing to events — the Ruby equivalent of Python’s
>    `options.enable_bidi = True` + `driver.script.add_console_message_handler`.
>    If BiDi coverage in the Ruby binding lags Python, say exactly which modules
>    are missing in Ruby as of the current release.
> 2. **Ruby-native BiDi clients.** Is there any Ruby gem that speaks WebDriver
>    BiDi directly over a WebSocket (bypassing Selenium), or a maintained Ruby
>    WebSocket client one would build a thin BiDi client on? Assess maturity.
> 3. **Watir.** Does Watir (which wraps `selenium-webdriver`) surface BiDi events
>    ergonomically, or does it hide the bidirectional layer? Is it worth it over
>    raw `selenium-webdriver` for an event-driven agent loop?
> 4. **Ferrum / CDP note.** Confirm Ferrum is CDP-only and therefore Chrome-only —
>    and thus a dead end for Firefox, since Firefox removed CDP in early 2025.
>    Is there any Ruby BiDi analog to Ferrum for Firefox?
> 5. **Geckodriver vs. direct.** From Ruby, is the path `selenium-webdriver` →
>    geckodriver → Firefox (BiDi), or can Ruby attach to a
>    `--remote-debugging-port`/BiDi WebSocket that Firefox already exposes without
>    geckodriver? Which is more robust for a persistent session?
> 6. **Profile reuse in Ruby.** The Ruby code to launch/attach Firefox with the
>    operator’s EXISTING authenticated profile (`-profile <path>`, no throwaway
>    clone) so cookies/logins persist — the Ruby equivalent of the Python
>    `-profile` arg / `userDataDir`.
> 7. **In-process vs. sidecar.** Can this run inside the Rails process (a
>    long-lived driver object managed by the app), or must it be a separate
>    supervised Ruby process? Discuss thread-safety, the geckodriver child
>    process, connection lifecycle, and reconnect. Recommend the topology for a
>    Rails app that needs to drive a third-party chat UI (type prompt → submit →
>    await streamed completion → extract text + download links).
>
> **Deliverable:** a recommended Ruby stack (gem + versions), a Ruby control-loop
> sketch (attach → locate → input → submit → event-driven completion → extract),
> the profile-reuse snippet, and an explicit verdict: **is the Ruby BiDi path
> mature enough to replace a Python Selenium daemon today, or is Python still
> materially ahead** — and if so, by how much and in which modules.

---

## Substrate anchors (for grounding Manus’s answer against our reality)

- **Ruby 3.4 / Rails 8.1 substrate.** A Ruby transport composes with the MCB
  boundary + the never-raise `{ok:, reason:, because:}` envelope with no polyglot
  bridge.
- **Doctrine: logic in Rails; daemon-offload is an optimization, not a default.**
  A Python Selenium daemon is a second runtime + a second supervised process +
  out-of-Rails logic. Prefer in-Ruby unless Manus shows Python BiDi is materially
  ahead.
- **Effectors decide nothing.** If a sidecar is unavoidable, it must be a thin
  Ruby effector driven by an in-Rails decision service — not a smart daemon.
- **What it replaces.** `Mm::Research::ManusBrowserAdapter` — today an `Open3`
  shell-out to a Python `browser-harness` doing inline-JS selector guessing + a
  5s poll loop. The Ruby BiDi path should retire BOTH the shell-out and the
  poll-and-guess.
- **Constraint carried over:** reuse the operator’s logged-in Firefox profile; we
  never automate login.
