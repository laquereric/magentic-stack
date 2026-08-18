# grammar/conformance/  🟢 OWN IT

Profile 1–8 conformance suites. Each profile ships with **valid** and **invalid**
example calls so implementers can prove interoperability both ways.

CI runs these as SHACL gates (see [`../../.github/workflows/shacl-conformance.yml`](../../.github/workflows/shacl-conformance.yml)).
A release cannot pass its gate without green conformance for the profiles it claims.

```
conformance/
  profile-1/ ... profile-8/     # per-profile valid/ and invalid/ fixtures
```
