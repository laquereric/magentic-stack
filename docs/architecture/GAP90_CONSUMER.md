# Gaps 90–91 — consumer declaration

Measured 2026-09-01 from `a81acb2`. Did not reverse
`rails-osi-level-8` → `shapes-application`. Did not relocate shapes.
Gap 91 is the owner's.

## Claude's four claims, re-derived

1. **Counts.** `grep -c '\[L8,'` = **13**. `grep -c '\[APP,'` = **18**.
   The 18 is occurrences, not `SHAPE_MAP` keys: `SHAPE_MAP` has **16**
   entries; the other two `[APP,` are inside `p9_operation_shapes` and
   `p11_operation_shapes`. Those two methods also resolve APP (P9/P11
   operations). Claim 1 holds as a grep; "SHAPE_MAP: 18 entries" is
   off by those two generator lines.

2. **Gemspec (before).** Only `rails` and `shapes-application`.
   `shapes-level-8` arrived via `shapes-application` line 18. Holds.

3. **Fallback.** `repo_root` is `__dir__` + four `..` =
   `gems/rails-osi-level-8/lib/rails_osi_level_8` → repo root.
   `gems/shapes-level-8` exists there, so resolve succeeds without a
   declaration inside this tree. Holds.

4. **`check_shape_gem_deps.py`.** Population 2 gemspecs; assertion is
   L8 must not depend on application. Engine not in population. Holds
   — that checker is not buggy.

## (a)

`rails-osi-level-8.gemspec` now `add_dependency "shapes-level-8", "= 0.0.0"`.
`Gemfile.lock` regenerated.

## (b) Fallback — chose an allowlist, not deletion

Deleting `repo_root` would make `bundle exec` from a checkout that
has not installed the path gems fail, which is how this tree actually
runs. Keep the fallback.

It must not silently stand in for a declaration:

- `SHAPE_GEMS = [APP, L8]`. `resolve` **raises** on any other name.
- Fallback only for names on that list, and only if
  `gems/<name>` exists; otherwise `LoadError` naming the missing
  declaration.
- `check_shape_consumer_deps.py` is what makes an undeclared
  consumer visible *inside* the monorepo.

Cost: a new shape gem is three edits (constant, gemspec, checker
population). That is the point.

Did not "fail when named-but-not-loaded": Bundler path gems are often
not in `loaded_specs` until required; that option would break the
same monorepo the fallback exists for.

## (c)

`tooling/shacl/check_shape_consumer_deps.py`. Population = consumer
gems whose Ruby names a shape gem. Today: 2 examined
(`rails-osi-level-8`, `shapes-application`). Wired into
`capture_shape_baseline.py`, `shacl-conformance.yml`,
`boundary-conformance.yml` (Part A3).

Plants: empty `CHECK_ROOT` exit 1; fake consumer naming L8 without
declaring it exit 1.
