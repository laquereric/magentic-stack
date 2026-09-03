# tooling/githooks/

Versioned Git hooks. `bin/install-hooks` sets `core.hooksPath` here.

`pre-push` refuses a push to `main` unless `bin/sweep` is green.
See [`../../docs/architecture/ROW114.md`](../../docs/architecture/ROW114.md).
