# vv-blob

Content-addressed blob storage in SQLite.

```ruby
store = Vv::Blob::Store.open(path: "db/blobs.sqlite3")

store.put("hello", content_type: "text/plain")
# => { ok: true, digest: "sha256:2cf24dba…", size: 5, stored: true }

store.put("hello")
# => { ok: true, digest: "sha256:2cf24dba…", size: 5, stored: false }

store.get("sha256:2cf24dba…")
# => { ok: true, bytes: "hello", content_type: "text/plain", size: 5, created_at: "…" }
```

## The digest is the key

Not a column beside one. Two things follow, and they are the reason to build it
this way:

**`put` is idempotent.** The same bytes twice is one row, and the caller gets the
same name back both times — with `stored: false` the second time, so a caller can
tell a write from a no-op rather than guessing.

**A name cannot drift from what it names.** This is the property a local Docker
image id does not have: the daemon reassigns it on every build, so it identifies
neither a release nor a rebuild on the same host. A sha256 over the bytes
identifies exactly one thing, forever, on any machine.

A caller therefore cannot supply a digest to `put`. Something that could name its
own blob could lie about it.

## Never raises

Every method returns `{ ok: true, … }` or `{ ok: false, reason:, because: }`.
That includes the case where the database cannot be opened at all: `Store.open`
returns a refusal object answering the same contract, so ignoring the failure
gets you a refusal from the next call rather than a `NoMethodError` three frames
away from the cause.

| refusal | when |
|---|---|
| `content_required` | `put(nil)` — nil is not a blob. `put("")` is fine; empty is content |
| `not_found` | `get` of a digest that was never stored |
| `store_unavailable` | the database could not be opened |
| `write_failed` / `read_failed` / `delete_failed` | SQLite said no |

## Deleting

`delete` removes the row for **every** holder of that digest, because they all
name the same bytes. It reports `deleted: true|false` so a no-op cannot be
mistaken for a removal. There is no reference counting; if you need one, it
belongs above this layer where the references actually live.

## Storage

One table, WAL journaling, a 5s busy timeout.

```sql
CREATE TABLE vv_blobs (
  digest       TEXT PRIMARY KEY,   -- sha256:…
  size         INTEGER NOT NULL,
  content_type TEXT,
  bytes        BLOB NOT NULL,
  created_at   TEXT NOT NULL
);
```

Binary is preserved exactly: bytes go in and come back `Encoding::BINARY`, which
the specs check with a payload containing nulls and high bytes.

## Tests

`bundle exec rspec` — 12 examples, 0 failures.
