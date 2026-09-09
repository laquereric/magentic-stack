#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mind"))
import mind_a2a


class MindA2aTest(unittest.TestCase):
    def test_wrap_uses_message_send_and_cpcp_part(self):
        wrapped = mind_a2a.wrap_cpcp({"jsonrpc": "2.0", "id": 1, "method": "note.list", "params": {}})
        self.assertEqual(wrapped["method"], "message/send")
        part = wrapped["params"]["message"]["parts"][0]
        self.assertEqual(part["data"]["cpcp"]["method"], "note.list")

    def test_unwrap_reads_artifact(self):
        inner = {"ok": True, "result": {"n": 1}}
        a2a = {"jsonrpc": "2.0", "result": {
            "status": {"state": "completed"},
            "artifacts": [{"parts": [{"kind": "data", "data": {"cpcp": inner}}]}],
        }}
        self.assertEqual(mind_a2a.unwrap_cpcp(a2a), inner)

    def test_unwrap_transport_refusal(self):
        out = mind_a2a.unwrap_cpcp({"ok": False, "reason": "nats_unreachable"})
        self.assertEqual(out["reason"], "nats_unreachable")


if __name__ == "__main__":
    unittest.main()
