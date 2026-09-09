#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mind"))
import mind_a2a


class MindA2aTest(unittest.TestCase):
    def test_wrap_is_jsonld_grant_not_nested_jsonrpc(self):
        wrapped = mind_a2a.wrap_cpcp({"jsonrpc": "2.0", "id": 1, "method": "note.list", "params": {}})
        self.assertEqual(wrapped["method"], "message/send")
        part = wrapped["params"]["message"]["parts"][0]
        self.assertEqual(part["mediaType"], "application/ld+json")
        data = part["data"]
        self.assertIn("@context", data)
        self.assertEqual(data["method"], "note.list")
        self.assertNotIn("jsonrpc", data)
        self.assertNotIn("cpcp", data)

    def test_wrap_push_sets_effect_and_operation_id(self):
        wrapped = mind_a2a.wrap_cpcp({
            "method": "note.create", "params": {}, "operationId": "op-1"
        })
        data = wrapped["params"]["message"]["parts"][0]["data"]
        self.assertIn("Effect", data["type"])
        self.assertEqual(data["operationId"], "op-1")

    def test_unwrap_reads_jsonld_artifact(self):
        inner = {"@context": {"@vocab": "https://w3id.org/cpcp/ns#"}, "ok": True, "result": {"n": 1}}
        a2a = {"jsonrpc": "2.0", "result": {
            "status": {"state": "completed"},
            "artifacts": [{"parts": [{"type": "DataPart", "data": inner}]}],
        }}
        self.assertEqual(mind_a2a.unwrap_cpcp(a2a)["ok"], True)
        self.assertEqual(mind_a2a.unwrap_cpcp(a2a)["result"], {"n": 1})

    def test_unwrap_rejects_retired_nest(self):
        a2a = {"jsonrpc": "2.0", "result": {
            "artifacts": [{"parts": [{"data": {"cpcp": {"jsonrpc": "2.0", "ok": True}}}]}],
        }}
        self.assertEqual(mind_a2a.unwrap_cpcp(a2a)["reason"], "a2a_json_not_jsonld")


if __name__ == "__main__":
    unittest.main()
