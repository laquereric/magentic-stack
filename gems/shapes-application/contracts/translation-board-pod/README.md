# translation-board-pod application contract

Slot for the StewardshipTranslation board (`app-oriented-translation`), the
third Magentic surface. It consumes `shapes-level-8` protocol vocabulary and
ships its own contracts here. It does not import mind-pod's routes by sharing
mind-pod's operation shapes.

The application lives in its own repo and builds as a thin overlay on this
substrate's base image (ADR 0063). This directory is the substrate side of that
seam: where its accepted request/response contracts land when they exist.

Empty of TTL. The directory exists so the application can land beside mind-pod
and folkcoder-pod without any of the three being reclassified.

Domain model the contracts will be written against:
[`TRANSLATION_BOARD_MODEL.md`](../../../../docs/architecture/TRANSLATION_BOARD_MODEL.md).
