# translation-board-pod application contract

Slot for the StewardshipTranslation board (`app-oriented-translation`), the
third Magentic surface. It consumes `shapes-level-8` protocol vocabulary and
ships its own contracts here. It does not import mind-pod's routes by sharing
mind-pod's operation shapes.

The application lives in its own repo and builds as a thin overlay on this
substrate's base image (ADR 0063). This directory is the substrate side of that
seam: where its accepted request/response contracts land when they exist.

Empty of TTL, and stays that way. The application's shapes live in the
application repo (`contracts/translation-board-pod/` in app-oriented-translation),
not here -- ADR 0063 amendment 2026-09-04. Holding six application shapes in this
tree failed seven substrate gates at once, each correctly demanding the substrate
enumerate them in its own manifests, which is the substrate naming its consumers.

This directory names the application identifier and reserves it. That is all it
is for.

Domain model the contracts will be written against:
[`TRANSLATION_BOARD_MODEL.md`](../../../../docs/architecture/TRANSLATION_BOARD_MODEL.md).
