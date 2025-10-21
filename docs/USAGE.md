# Clide — Augmented POSIX Usage → argv parser for SML

Version **v0.1.4**

## Overview

Clide turns annotated `Usage:` lines into a working, type-aware argv parser for Standard ML (MLton).
It balances the readability of standard usage with enough structure to auto-derive a parser.

## Features

- POSIX-like syntax with `[optional]`, `<positional>`, `[-s|--long]`
- Types: `INT`, `BOOL`, `STR`, `PATH`
- Defaults via `:default` (e.g., `--port=INT:8080`)
- Repeatable options with `+` (e.g., `--include=PATH+`)
- Multiple commands via multiple `Usage:` lines
- `helpWithDocs` renders aligned two-column docs, merging `-s, --long`

## Spec Example

```text
Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>
Usage: mytool init <path:PATH>
```

## Help Output Example

```text
Usage:
  serve [-v|--verbose] [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>
  init <path:PATH>

Options & Arguments:
  serve               -  Start the HTTP server
  init                -  Initialize a project directory
  -v, --verbose       -  Verbose logging
  --port=INT:8080     -  TCP port to listen on
  --tls               -  Enable TLS
  --root=PATH         -  Document root for static files
  <dir:PATH>          -  Application directory
  <path:PATH>         -  Project directory
```

## Minimal Integration

```sml
val usage = [
  "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
  "Usage: mytool init <path:PATH>"
]
val parse = Clide.fromUsageLines usage
val res = parse (CommandLine.arguments ())
```

For detailed integration steps, see the README and smlpkg manifests.
