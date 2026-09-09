"""Stdlib NATS request-reply for in-pod CPCP (ADR 0065).

harness.py is stdlib-only; nats-py would pull a dep into the distroless
image. The NATS protocol is CONNECT/PUB/SUB/MSG over TCP. This module
implements enough of that for one request-reply with an optional
Authorization header. Never raises across the boundary: request()
returns bytes or None.
"""
from __future__ import annotations

import os
import socket
import uuid
from urllib.parse import urlparse


def request(url: str, subject: str, payload: bytes, timeout: float = 30.0,
            authorization: str | None = None) -> bytes | None:
    """PUB payload on subject, wait for one MSG on an inbox. None on any failure."""
    try:
        parsed = urlparse(url)
        host = parsed.hostname or "nats"
        port = parsed.port or 4222
        inbox = "_INBOX.%s" % uuid.uuid4().hex
        sock = socket.create_connection((host, port), timeout=min(3.0, timeout))
        sock.settimeout(timeout)
        try:
            _handshake(sock)
            _send(sock, b"SUB %s 1\r\n" % inbox.encode())
            _pub(sock, subject, payload, reply=inbox, authorization=authorization)
            return _read_msg(sock)
        finally:
            try:
                sock.close()
            except OSError:
                pass
    except Exception:
        if os.environ.get("MM_NATS_DEBUG"):
            raise
        return None


def request_env(subject: str, payload: bytes, timeout: float = 30.0,
                authorization: str | None = None) -> bytes | None:
    url = os.environ.get("MM_NATS_URL", "").strip()
    if not url:
        return None
    return request(url, subject, payload, timeout=timeout, authorization=authorization)


def _handshake(sock: socket.socket) -> None:
    _read_info(sock)
    connect = b'CONNECT {"verbose":false,"pedantic":false,"tls_required":false,"name":"mind","lang":"python"}\r\n'
    _send(sock, connect)


def _read_info(sock: socket.socket) -> None:
    buf = b""
    while b"\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("nats closed during INFO")
        buf += chunk
        if len(buf) > 65536:
            raise ConnectionError("nats INFO too large")
    line, _rest = buf.split(b"\r\n", 1)
    if not line.upper().startswith(b"INFO"):
        raise ConnectionError("expected INFO, got %r" % line[:80])


def _pub(sock: socket.socket, subject: str, payload: bytes, reply: str,
         authorization: str | None) -> None:
    if authorization:
        hdr = ("NATS/1.0\r\nAuthorization: %s\r\n\r\n" % authorization).encode()
        total = len(hdr) + len(payload)
        _send(sock, b"HPUB %s %s %d %d\r\n" % (
            subject.encode(), reply.encode(), len(hdr), total))
        _send(sock, hdr + payload + b"\r\n")
        return
    _send(sock, b"PUB %s %s %d\r\n" % (subject.encode(), reply.encode(), len(payload)))
    _send(sock, payload + b"\r\n")


def _send(sock: socket.socket, data: bytes) -> None:
    sock.sendall(data)


def _read_msg(sock: socket.socket) -> bytes:
    buf = b""
    while True:
        try:
            chunk = sock.recv(4096)
        except ConnectionResetError:
            chunk = b""
        if not chunk:
            raise ConnectionError("nats closed waiting for MSG")
        buf += chunk
        while True:
            if buf.startswith(b"PING\r\n"):
                _send(sock, b"PONG\r\n")
                buf = buf[6:]
                continue
            if buf.startswith(b"+OK\r\n"):
                buf = buf[5:]
                continue
            if buf.startswith(b"-ERR"):
                nl = buf.find(b"\r\n")
                if nl < 0:
                    break
                raise ConnectionError(buf[:nl].decode("utf-8", "replace"))
            if buf.upper().startswith(b"MSG ") or buf.upper().startswith(b"HMSG "):
                nl = buf.find(b"\r\n")
                if nl < 0:
                    break
                line = buf[:nl].decode("ascii", "replace")
                parts = line.split()
                rest = buf[nl + 2:]
                if line.upper().startswith("HMSG"):
                    hlen = int(parts[-2])
                    total = int(parts[-1])
                    if len(rest) < total + 2:
                        break
                    return rest[hlen:total]
                size = int(parts[-1])
                if len(rest) < size + 2:
                    break
                return rest[:size]
            # Unknown control line: skip to next CRLF if present.
            nl = buf.find(b"\r\n")
            if nl < 0:
                break
            buf = buf[nl + 2:]
