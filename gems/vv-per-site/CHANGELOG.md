# Changelog

## 0.1.0

* Rails engine with an `ancestry` hierarchy for OKF docs (`vv_per_site_okf_nodes`).
* Per-site CTA table (`vv_per_site_sites`, `vv_per_site_ctas`) binding a particular site onto CTA leaves.
* `rake vv_per_site:okf:sync` converts `docs/` → `data/seed/docs` YAML and loads it into AR.
