"""Clide tests"""

import unittest
from clide import Clide, ArgError, ParseError


class TestClide(unittest.TestCase):

    def test_serve_parse(self):
        usage = [
            "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
            "Usage: mytool init <path:PATH>",
        ]

        parse = Clide.from_usage_lines(usage)
        result = parse([
            "serve",
            "--port",
            "9090",
            "--tls",
            "--root",
            "/srv/www",
            "-v",
            "/app",
            "--",
            "leftover",
        ])

        self.assertEqual(result.command, "serve")

        port_vals = next((v for k, v in result.options if k == "--port"), None)
        self.assertIsNotNone(port_vals)
        self.assertEqual(port_vals, ["9090"])

        tls_vals = next((v for k, v in result.options if k == "--tls"), None)
        self.assertIsNotNone(tls_vals)
        self.assertEqual(tls_vals, ["true"])

        dir_val = next((v for k, v in result.positionals if k == "dir"), None)
        self.assertIsNotNone(dir_val)
        self.assertEqual(dir_val, "/app")

        self.assertEqual(result.leftovers, ["leftover"])

    def test_serve_defaults(self):
        usage = [
            "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
            "Usage: mytool init <path:PATH>",
        ]

        parse = Clide.from_usage_lines(usage)
        result = parse(["serve", "/workdir"])

        port_vals = next((v for k, v in result.options if k == "--port"), None)
        self.assertIsNotNone(port_vals)
        self.assertEqual(port_vals, ["8080"])

        tls_vals = next((v for k, v in result.options if k == "--tls"), None)
        self.assertIsNotNone(tls_vals)
        self.assertEqual(tls_vals, ["false"])

        verbose_vals = next((v for k, v in result.options if k == "--verbose"), None)
        self.assertIsNotNone(verbose_vals)
        self.assertEqual(verbose_vals, ["false"])

    def test_repeating_option(self):
        usage = [
            "Usage: build [--include=PATH+] <dir:PATH>",
        ]

        parse = Clide.from_usage_lines(usage)
        result = parse([
            "--include",
            "src",
            "--include",
            "lib",
            "project",
        ])

        self.assertEqual(result.command, "_")

        include_vals = next((v for k, v in result.options if k == "--include"), None)
        self.assertIsNotNone(include_vals)
        self.assertEqual(include_vals, ["src", "lib"])

    def test_unknown_option(self):
        usage = [
            "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
            "Usage: mytool init <path:PATH>",
        ]

        parse = Clide.from_usage_lines(usage)
        with self.assertRaises(ArgError) as context:
            parse(["serve", "--bogus", "/app"])

        self.assertIn("Unknown option", str(context.exception))

    def test_spec_error(self):
        with self.assertRaises(ParseError):
            Clide.from_usage_lines(["Usage: tool <unterminated"])

    def test_help_output(self):
        usage = [
            "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
            "Usage: mytool init <path:PATH>",
        ]

        docs = [
            ("serve", "Start the HTTP server"),
            ("init", "Initialize a project directory"),
            ("-v, --verbose", "Verbose logging"),
            ("--port=INT:8080", "TCP port"),
            ("--tls", "Enable TLS"),
            ("--root=PATH", "Document root"),
            ("<dir:PATH>", "Application directory"),
            ("<path:PATH>", "Project directory"),
        ]

        help_text = Clide.help_with_docs(usage, docs)
        self.assertIn("--port=INT:8080", help_text)
        self.assertIn("-v", help_text)
        self.assertIn("--verbose", help_text)
        self.assertIn("serve", help_text)


if __name__ == "__main__":
    unittest.main()
