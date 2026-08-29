# shapes-level-8

Versioned OSI Level 8 protocol-profile shapes and reusable vocabulary.

Empty of TTL today (step 4). The runtime pin under `config.shape_root` is
untouched. This gem must not hold an application's routes, persistence,
adapter, or deployment.

**Rails-free.** Loads under a plain `ruby -e` with no `Rails` constant.

## Versioned entry point

```ruby
require "shapes-level-8"
Shapes::Level8.bundle("1")   # seam; catalog is empty until later steps
Shapes::Level8.catalog       # {}
```

A second application consumes this gem and does not fork protocol vocabulary.

See `docs/architecture/SHAPE_GEMS.md` and ADR 0041.
