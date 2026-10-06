import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "starlink"
SERVICE = "SpaceX.API.Device.Device/Handle"


class StarlinkCLITest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        private = Path(self.temp.name)
        self.args_file = private / "grpcurl.args"
        self.fake = private / "grpcurl"
        self.fake.write_text(
            """#!/bin/sh
: > "$GRPCURL_ARGS_FILE"
for arg do
    printf '%s\\n' "$arg" >> "$GRPCURL_ARGS_FILE"
done
printf '%s' "${GRPCURL_STDERR-}" >&2
printf '%s' "${GRPCURL_RESPONSE-}"
exit "${GRPCURL_EXIT-0}"
"""
        )
        self.fake.chmod(0o700)
        for command in ("cat", "dirname", "jq", "tr"):
            target = shutil.which(command)
            self.assertIsNotNone(target, f"test dependency not found: {command}")
            (private / command).symlink_to(target)
        self.env = {
            **os.environ,
            "PATH": str(private),
            "GRPCURL_ARGS_FILE": str(self.args_file),
            "GRPCURL_RESPONSE": '{"wifiGetStatus":{"clients":[]}}',
        }

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, *args, response=None, env=None, timeout=3):
        run_env = {**self.env, **(env or {})}
        if response is not None:
            run_env["GRPCURL_RESPONSE"] = response
        return subprocess.run(
            [str(CLI), *args],
            cwd=ROOT,
            env=run_env,
            text=True,
            capture_output=True,
            timeout=timeout,
        )

    def grpcurl_args(self):
        return self.args_file.read_text().splitlines()

    def assert_request(self, router):
        args = self.grpcurl_args()
        self.assertEqual(args[0], "-plaintext")
        self.assertEqual(args[-2:], [router, SERVICE])
        self.assertEqual(json.loads(args[args.index("-d") + 1]), {"getStatus": {}})
        timeout_flag = next(flag for flag in ("-max-time", "--max-time") if flag in args)
        self.assertLessEqual(float(args[args.index(timeout_flag) + 1]), 10)
        self.assertEqual(len(args), 7)

    def test_default_table_normalizes_and_sorts_hostnames(self):
        response = json.dumps(
            {
                "wifiGetStatus": {
                    "clients": [
                        {"name": "zeta", "ipAddress": "10.0.0.10", "macAddress": "aa"},
                        {"name": "Alpha", "ipAddress": "10.0.0.2", "macAddress": "bb"},
                        {"name": "", "ipAddress": None, "macAddress": ""},
                    ]
                }
            }
        )
        result = self.run_cli(response=response)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Hostname", result.stdout)
        self.assertLess(result.stdout.index("(Unknown)"), result.stdout.index("Alpha"))
        self.assertLess(result.stdout.index("Alpha"), result.stdout.index("zeta"))
        self.assertIn("(No IP)", result.stdout)
        self.assertIn("(No MAC)", result.stdout)
        self.assert_request("192.168.1.1:9000")

        alias = self.run_cli("-s", "HOSTNAME", "--json", response=response)
        self.assertEqual(alias.returncode, 0, alias.stderr)
        self.assertEqual([client["hostname"] for client in json.loads(alias.stdout)], ["(Unknown)", "Alpha", "zeta"])

    def test_json_ip_sort_is_natural_and_preserves_raw_values(self):
        raw_name = "odd\x1b[31m\tname\nnext"
        clients = [
            {"name": "ten", "ipAddress": "10.0.0.10", "macAddress": "10"},
            {"name": "v6", "ipAddress": "fe80::1", "macAddress": "v6"},
            {"name": "two", "ipAddress": "10.0.0.2", "macAddress": "2"},
            {"name": raw_name, "ipAddress": "", "macAddress": ""},
        ]
        result = self.run_cli(
            "--json", "--sort", "IP", response=json.dumps({"wifiGetStatus": {"clients": clients}})
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            [
                {"hostname": "two", "ip": "10.0.0.2", "mac": "2"},
                {"hostname": "ten", "ip": "10.0.0.10", "mac": "10"},
                {"hostname": raw_name, "ip": "(No IP)", "mac": "(No MAC)"},
                {"hostname": "v6", "ip": "fe80::1", "mac": "v6"},
            ],
        )
        self.assertIn("\\u001b", result.stdout)

        table = self.run_cli("--sort", "ip", response=json.dumps({"wifiGetStatus": {"clients": clients}}))
        self.assertEqual(table.returncode, 0, table.stderr)
        self.assertNotIn("\x1b", table.stdout)
        self.assertNotIn("\tname", table.stdout)
        self.assertNotIn("name\nnext", table.stdout)

    def test_empty_or_omitted_clients_is_success(self):
        for response in (
            '{"wifiGetStatus":{"clients":[]}}',
            '{"wifiGetStatus":{}}',
            '{"wifiGetStatus":{"clients":null}}',
        ):
            with self.subTest(response=response):
                result = self.run_cli("--json", response=response)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), [])

    def test_bad_responses_are_rejected(self):
        responses = {
            "empty response": "",
            "malformed JSON": "{",
            "multiple responses": '{"wifiGetStatus":{}}\n{"wifiGetStatus":{}}',
            "scalar root": "1",
            "missing status": '{"other":{}}',
            "scalar status": '{"wifiGetStatus":1}',
            "non-array clients": '{"wifiGetStatus":{"clients":false}}',
            "non-object client": '{"wifiGetStatus":{"clients":[1]}}',
            "non-string hostname": '{"wifiGetStatus":{"clients":[{"name":1}]}}',
            "non-string IP": '{"wifiGetStatus":{"clients":[{"ipAddress":1}]}}',
            "non-string MAC": '{"wifiGetStatus":{"clients":[{"macAddress":1}]}}',
        }
        for label, response in responses.items():
            with self.subTest(label=label):
                result = self.run_cli("--json", response=response)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr.strip())

    def test_grpcurl_failure_is_reported(self):
        result = self.run_cli(env={"GRPCURL_EXIT": "7", "GRPCURL_STDERR": "router unavailable\x1b]52;spoof\x07"})

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cannot query router", result.stderr)
        self.assertNotIn("router unavailable", result.stderr)
        self.assertNotIn("\x1b", result.stderr)
        self.assertNotIn("\x07", result.stderr)

    def test_router_precedence_and_valid_forms(self):
        cases = [
            ([], {}, "192.168.1.1:9000"),
            ([], {"STARLINK_ROUTER": "router.local:1234"}, "router.local:1234"),
            (["--router", "10.0.0.1:443"], {"STARLINK_ROUTER": "ignored:1"}, "10.0.0.1:443"),
            (["--router", "[2001:db8::1]:9000"], {}, "[2001:db8::1]:9000"),
        ]
        for args, env, expected in cases:
            with self.subTest(router=expected):
                result = self.run_cli(*args, "--json", env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assert_request(expected)

    def test_invalid_arguments_fail_before_grpcurl(self):
        cases = [
            ["--sort"],
            ["--sort", "serial"],
            ["--unknown"],
            ["--router", "host"],
            ["--router", "host:0"],
            ["--router", "host:65536"],
            ["--router", "host:not-a-port"],
            ["--router", ":9000"],
            ["--router", "http://host:9000"],
            ["--router", "2001:db8::1:9000"],
            ["--router", "[2001:db8::1]"],
        ]
        for args in cases:
            with self.subTest(args=args):
                self.args_file.unlink(missing_ok=True)
                result = self.run_cli(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(result.stderr.strip())
                self.assertFalse(self.args_file.exists())

    def test_help_and_version_do_not_call_grpcurl(self):
        for flag, expected in (("--help", "Usage:"), ("--version", "0.0.2")):
            with self.subTest(flag=flag):
                self.args_file.unlink(missing_ok=True)
                result = self.run_cli(flag, env={"GRPCURL_EXIT": "99"})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(expected, result.stdout)
                self.assertFalse(self.args_file.exists())

    def test_missing_dependencies_are_reported_before_launch(self):
        isolated_path = str(self.fake.parent)
        (self.fake.parent / "jq").unlink()
        result = self.run_cli(env={"PATH": isolated_path})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing dependency: jq", result.stderr)
        self.assertIn("Homebrew or APT", result.stderr)
        self.assertFalse(self.args_file.exists())

        self.fake.unlink()
        result = self.run_cli(env={"PATH": isolated_path})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing dependency: grpcurl", result.stderr)
        self.assertFalse(self.args_file.exists())

if __name__ == "__main__":
    unittest.main()
