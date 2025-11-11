#!/usr/bin/env python3
"""Clide demo application"""

import sys
from clide import Clide


def main():
    usage = [
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
        "Usage: mytool init <path:PATH>",
    ]

    docs = [
        ("serve", "Start the HTTP server"),
        ("init", "Initialize a project directory"),
        ("-v, --verbose", "Verbose logging"),
        ("--port=INT:8080", "TCP port to listen on"),
        ("--tls", "Enable TLS"),
        ("--root=PATH", "Document root for static files"),
        ("<dir:PATH>", "Application directory"),
        ("<path:PATH>", "Project directory"),
    ]

    args = sys.argv[1:]

    wants_help = "--help" in args or "-h" in args

    if wants_help:
        try:
            help_text = Clide.help_with_docs(usage, docs)
            print(help_text)
            sys.exit(0)
        except Exception as e:
            print(f"Error parsing usage: {e}", file=sys.stderr)
            sys.exit(1)

    try:
        parse = Clide.from_usage_lines(usage)
        result = parse(args)

        print(f"command: {result.command}")

        for key, values in result.options:
            print(f"{key} = {values}")

        for key, value in result.positionals:
            print(f"{key} = {value}")

        if result.leftovers:
            print("--- leftovers ---")
            for arg in result.leftovers:
                print(arg)

        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}\n", file=sys.stderr)
        try:
            help_text = Clide.help_with_docs(usage, docs)
            print(help_text)
        except Exception:
            pass
        sys.exit(1)


if __name__ == "__main__":
    main()
