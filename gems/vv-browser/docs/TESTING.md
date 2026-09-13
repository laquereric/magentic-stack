# vv-browser two-level harness

RSpec tests **procedures** (pure: flatten console/network, JS snippets, digest shape).
Cucumber composes those same procedures as **steps** and drives the live canvas.

```
RSpec leaf          Cucumber step
----------------    ---------------------------------
flatten_console     Then javascript errors include
getter_errors       Then there is no Fabric type-getter error
digest?             Then the save status is a blob digest
click_button_text   When I apply the "Poster" template
click_id            When I click the element "addHeading"
board_snapshot_js   Then fabric is present / canvas has objects
throw_fixture_html  Given a fixture page that throws
```

## Unit

```bash
bundle exec rspec spec/vv/browser/procedures_spec.rb
```

No chromedriver required.

## Integration (6 use-cases)

```bash
bundle exec cucumber                          # UC6 always; UC1–UC5 skip if FRONT down
BOARD_URL=http://127.0.0.1:14001/ bundle exec cucumber --tags @live
```

From the overlay: `shared-ai-space-app/bin/cuke`.

`tmp/mmg_browser_console.rb` is deprecated; it wraps `Procedures.probe`.
