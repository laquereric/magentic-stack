#!/usr/bin/env python3
"""Stdlib NATS request-reply against a throwaway TCP stand-in. No nats-server."""
from __future__ import annotations

import os
import socket
import sys
import threading
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mind"))
from mind_nats import request


def standin(payload: bytes):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 0))
    server.listen(1)
    port = server.getsockname()[1]
    captured = {}

    def run():
        conn, _ = server.accept()
        try:
            conn.sendall(b'INFO {"server_id":"test"}\r\n')
            buf = b""
            deadline = time.time() + 2
            while time.time() < deadline:
                conn.settimeout(0.5)
                try:
                    chunk = conn.recv(4096)
                except socket.timeout:
                    continue
                if not chunk:
                    break
                buf += chunk
                if b"\r\n" in buf and (b"PUB " in buf or b"HPUB " in buf):
                    captured["raw"] = buf
                    # Reply on whatever inbox the client SUB'd.
                    inbox = None
                    for line in buf.split(b"\r\n"):
                        if line.startswith(b"SUB "):
                            inbox = line.split()[1]
                            break
                    if inbox:
                        conn.sendall(b"MSG %s 1 %d\r\n" % (inbox, len(payload)))
                        conn.sendall(payload + b"\r\n")
                    time.sleep(0.1)
                    break
        finally:
            try:
                conn.shutdown(socket.SHUT_WR)
            except OSError:
                pass
            conn.close()
            server.close()

    t = threading.Thread(target=run, daemon=True)
    t.start()
    time.sleep(0.05)
    return port, t, captured


class MindNatsTest(unittest.TestCase):
    def test_request_reply(self):
        os.environ["MM_NATS_DEBUG"] = "1"
        try:
            port, thread, captured = standin(b'{"ok":true}')
            out = request("nats://127.0.0.1:%d" % port, "cpcp.back.rpc", b'{"method":"x"}', timeout=2)
            thread.join(2)
            self.assertEqual(out, b'{"ok":true}')
            self.assertIn(b"cpcp.back.rpc", captured.get("raw", b""))
        finally:
            os.environ.pop("MM_NATS_DEBUG", None)

    def test_unreachable_is_none(self):
        self.assertIsNone(request("nats://127.0.0.1:1", "cpcp.back.rpc", b"{}", timeout=0.2))


if __name__ == "__main__":
    unittest.main()
