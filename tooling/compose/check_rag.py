#!/usr/bin/env python3
"""The rag seam and its engine are what RagContainer.md says they are.

Mirrors check_nats / the graph assertions, because rag is the same shape: a
third-party store the pod does not fork, reached through a CPCP face the pod
does own.

  ENGINE (milvus)
    digest-pinned    an image without @sha256: is a moving floor
    unpublished      no ports: -- gRPC never leaves the docker network, which
                     is the whole reason the seam exists
    named volume     rag-data, so the index is not in the container layer
    no Zilliz Cloud  a cloud endpoint in compose means this is not local Milvus
                     at all, and the document that says "never a cloud
                     collection URL" would be describing something else

  SEAM (rag)
    ROLE=rag         a Rails role, not a second engine
    own route        routes.rb draws /_cpcp/rpc for it; the engine is NOT
                     mounted, because stock RpcController renders 200 for
                     everything and that is BACK's catalog anyway
    entrypoint       knows the role, or the container exits 2 at boot

FAILS CLOSED: finding no compose file, or no rag service in one, is an error.
A checker with an empty population reports success otherwise, which reads as
coverage it has not got.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from population import emit_population  # noqa: E402

ROOT = Path(os.environ["CHECK_ROOT"]) if os.environ.get("CHECK_ROOT") else Path(__file__).resolve().parents[2]
COMPOSES = (
    "runtimes/mind-pod/docker-compose.yml",
    "runtimes/mind-pod/app/extract/compose.yml",
)
ROUTES = ROOT / "runtimes/mind-pod/app/config/routes.rb"
ENTRYPOINT = ROOT / "runtimes/mind-pod/app/extract/entrypoint.sh"

# A managed endpoint is the one thing that would make "local Milvus" false.
CLOUD = re.compile(r"zillizcloud\.com|api\.zilliz\.com|cloud\.zilliz", re.I)

errors: list[str] = []


def service_block(text: str, name: str) -> str:
    m = re.search(rf"^  {re.escape(name)}:\s*$", text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    stop = re.search(r"^  \S", rest, re.M)
    return rest[: stop.start()] if stop else rest


def main() -> int:
    examined = 0
    populated, _pop = emit_population(len(COMPOSES), skipped_reason="no compose files")
    if not populated:
        return 1

    for rel in COMPOSES:
        p = ROOT / rel
        if not p.is_file():
            errors.append(f"missing {rel}")
            continue
        examined += 1
        text = p.read_text(encoding="utf-8", errors="replace")

        engine = service_block(text, "milvus")
        if not engine:
            errors.append(f"{rel} has no milvus service")
        else:
            if "@sha256:" not in engine:
                errors.append(f"{rel} milvus is not digest-pinned")
            if re.search(r"^\s+ports:", engine, re.M):
                errors.append(f"{rel} milvus is host-published; gRPC must not leave the docker network")
            if "rag-data:" not in engine:
                errors.append(f"{rel} milvus does not mount the rag-data volume")
            if "rag-data: {}" not in text:
                errors.append(f"{rel} does not declare the rag-data named volume")
            if CLOUD.search(engine):
                errors.append(f"{rel} milvus points at Zilliz Cloud; this is local Milvus or it is not rag")

        seam = service_block(text, "rag")
        if not seam:
            errors.append(f"{rel} has no rag service")
        else:
            if "ROLE: rag" not in seam:
                errors.append(f"{rel} rag is not ROLE=rag")
            if re.search(r"^\s+ports:", seam, re.M):
                errors.append(f"{rel} rag is host-published; the seam is in-pod")
            if "MILVUS_URL" not in seam:
                errors.append(f"{rel} rag has no MILVUS_URL; the seam cannot reach the engine")
            if CLOUD.search(seam):
                errors.append(f"{rel} rag points at Zilliz Cloud")

    examined += 1
    routes = ROUTES.read_text(encoding="utf-8", errors="replace") if ROUTES.is_file() else ""
    if 'when "rag"' not in routes:
        errors.append("routes.rb draws no ROLE=rag branch")
    elif "rag_cpcp#rpc" not in routes:
        errors.append("routes.rb ROLE=rag does not route /_cpcp/rpc to rag_cpcp")

    examined += 1
    entry = ENTRYPOINT.read_text(encoding="utf-8", errors="replace") if ENTRYPOINT.is_file() else ""
    if "\n  rag)" not in entry:
        errors.append("entrypoint.sh does not know ROLE=rag; the container exits 2 at boot")

    print("population: %d examined, 0 skipped" % examined)
    if errors:
        for e in errors:
            print("  FAIL %s" % e, file=sys.stderr)
        print("rag: FAIL (%d)" % len(errors), file=sys.stderr)
        return 1
    print("rag: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
