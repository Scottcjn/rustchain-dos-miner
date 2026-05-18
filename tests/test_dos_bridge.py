import importlib.util
import pathlib
import sys
import tempfile
import types
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]

fake_requests = types.SimpleNamespace(post=None)
fake_urllib3 = types.SimpleNamespace(disable_warnings=lambda: None)
sys.modules["requests"] = fake_requests
sys.modules["urllib3"] = fake_urllib3

spec = importlib.util.spec_from_file_location("dos_bridge", ROOT / "dos_bridge.py")
dos_bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dos_bridge)


class Response:
    def __init__(self, status_code, text=""):
        self.status_code = status_code
        self.text = text


class DosBridgeTests(unittest.TestCase):
    def test_parse_attest_file_reads_key_value_pairs(self):
        with tempfile.NamedTemporaryFile("w", delete=False) as handle:
            handle.write("WALLET=dos-wallet\n")
            handle.write("LAYERS_PASSED=7/7\n")
            handle.write("IGNORED LINE\n")
            handle.write("ENTROPY_SCORE=42\n")
            path = handle.name

        try:
            parsed = dos_bridge.parse_attest_file(path)
        finally:
            pathlib.Path(path).unlink()

        self.assertEqual(
            parsed,
            {
                "WALLET": "dos-wallet",
                "LAYERS_PASSED": "7/7",
                "ENTROPY_SCORE": "42",
            },
        )

    def test_parse_attest_file_returns_empty_dict_for_missing_file(self):
        self.assertEqual(dos_bridge.parse_attest_file("/no/such/ATTEST.TXT"), {})

    def test_submit_attestation_builds_payload_and_stops_after_success(self):
        calls = []

        def post(url, json, timeout, verify):
            calls.append((url, json, timeout, verify))
            return Response(200, "accepted")

        dos_bridge.requests.post = post
        dos_bridge.NODES = ["https://node-one.test", "https://node-two.test"]
        dos_bridge.time.time = lambda: 1234.5

        result = dos_bridge.submit_attestation(
            {
                "WALLET": "wallet-123",
                "LAYERS_PASSED": "7/7",
                "EMULATOR_DETECTED": "YES",
                "ENTROPY_SCORE": "73",
            }
        )

        self.assertTrue(result)
        self.assertEqual(len(calls), 1)
        url, payload, timeout, verify = calls[0]
        self.assertEqual(url, "https://node-one.test/attest/submit")
        self.assertEqual(timeout, 10)
        self.assertFalse(verify)
        self.assertEqual(payload["miner"], "wallet-123")
        self.assertEqual(payload["nonce"], 1234500)
        self.assertEqual(payload["report"]["layers_passed"], "7/7")
        self.assertTrue(payload["report"]["emulator_detected"])
        self.assertEqual(payload["report"]["entropy_score"], 73)
        self.assertEqual(payload["device"]["device_arch"], "8086")
        self.assertTrue(payload["fingerprint"]["all_passed"])

    def test_submit_attestation_uses_safe_defaults_and_handles_failures(self):
        calls = []

        def post(url, json, timeout, verify):
            calls.append(json)
            return Response(500, "fail")

        dos_bridge.requests.post = post
        dos_bridge.NODES = ["http://failing-node.test"]
        dos_bridge.time.time = lambda: 1.0

        result = dos_bridge.submit_attestation(
            {
                "LAYERS_PASSED": "3/7",
                "EMULATOR_DETECTED": "true",
                "ENTROPY_SCORE": "not-a-number",
            }
        )

        self.assertFalse(result)
        self.assertEqual(calls[0]["miner"], "unknown")
        self.assertTrue(calls[0]["report"]["emulator_detected"])
        self.assertEqual(calls[0]["report"]["entropy_score"], 0)
        self.assertFalse(calls[0]["fingerprint"]["all_passed"])


if __name__ == "__main__":
    unittest.main()
