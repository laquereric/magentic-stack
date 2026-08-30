# shapes-application

Application accepted request/response contracts, under explicit application
identifiers. mind-pod contracts live in `contracts/mind-pod/`. Must not hold
protocol profiles another app would reuse unchanged.

**Rails-free.** Loads under a plain `ruby -e` with no `Rails` constant.
Depends on `shapes-level-8`. Must not be depended on by `shapes-level-8`.

## Family layout

```
contracts/mind-pod/         this repo's application contract (empty)
contracts/folkcoder-pod/    second Magentic surface; slot reserved
```

A FolkCoder-pod contract lands beside mind-pod. It is not reclassified
into `shapes-level-8`, and mind-pod's operation shapes are not published
as protocol vocabulary.

## Versioned entry point

```ruby
require "shapes-application"
Shapes::Application.bundle(application: "mind-pod", version: "1")
Shapes::Application::APPLICATIONS  # ["mind-pod", "folkcoder-pod"]
```

See `docs/architecture/SHAPE_GEMS.md` (second-application scenario) and ADR 0041.
