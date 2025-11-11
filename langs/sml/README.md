# Clide for Standard ML

Standard ML implementation of Clide, a library that turns annotated `Usage:` lines into fully validated command-line parsers.

## Overview

This implementation provides a Standard ML library and demo application that parses command-line arguments based on POSIX-style usage specifications. It ships with a self-contained build system (MLton + Make) and a lightweight test harness.

## Rationale

- **Specification at the edge**: CLI shape is recorded once in human-friendly usage strings, then compiled to enforce flags, defaults, and positional arguments at runtime.
- **Type-aware parsing**: Options and positionals deserialize into `INT`, `BOOL`, `STR`, and `PATH` values immediately, surfacing `ArgError` on bad input instead of deferring validation.
- **Embeddable library**: The parsing engine lives under `lib/clide`, sealed by the `CLI_DERIVE` signature. The demo in `src/Main.sml` shows how to wire `Clide.fromUsageLines` and `Clide.helpWithDocs` into an application.

## Usage Example

```sml
val usage = [
   "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
   "Usage: mytool init <path:PATH>"
]

val docs = [
   ("serve", "Start the HTTP server"),
   ("-v, --verbose", "Verbose logging")
]

val parse = Clide.fromUsageLines usage

case parse (CommandLine.arguments ()) of
   {command = "serve", options, positionals, leftovers} =>
      (* act on parsed values *)
| result => (* handle other commands *)
```

## Building

### Requirements

- [MLton](https://mlton.org)
- Python 3.11+ (or 3.7+ with `tomli`) for the `tools/toml2mk.py` helper
- POSIX `make`

### Build Targets

From the `langs/sml/` directory:

- `make dev` – builds `build/CLIDE_DEMO-dev` using the development MLB profile.
- `make prod` – builds the optimized production binary in `build/CLIDE_DEMO-prod`.
- `make test` – compiles the test runner (`build/CLIDE_DEMO-test`) and executes the suite in `test/`, covering parser defaults, repeatable options, error surfaces, and help rendering.
- `make run BIN=clide-demo PROFILE=dev ARGS='serve /tmp/app'` – convenience target to invoke a compiled binary with arguments.
- `make clean` – removes the `build/` directory (generated binaries and `build/vars.mk`).

### Quick Start

```bash
cd langs/sml
make prod
./build/clide-prod --help
```

## Project Layout

```text
langs/sml/
├── Project.toml            # Build + profile configuration
├── Makefile                # MLton build orchestration
├── lib/clide/              # Reusable CLI derivation library
│   ├── src/                # Library source files
│   ├── clide.mlb           # MLton basis file
│   └── README.md           # Library documentation
├── src/Main.sml            # Demo program wiring the library
├── test/                   # Expect-based unit tests (run with make test)
├── mlb/                    # MLton basis bundles for each profile
└── tools/toml2mk.py        # Generates build/vars.mk from Project.toml
```

## Library Usage

Include in your MLB:

```sml
local
  $(SML_LIB)/basis/basis.mlb
  lib/clide/clide.mlb
in
  src/Main.sml
end
```

Usage in code:

```sml
val parse = Clide.fromUsageLines usage
val res = parse (CommandLine.arguments ())
```

See `lib/clide/src` for implementation details and `docs/specs/USAGE.md` (in the project root) for the usage string specification.

## License

MIT License – see `lib/clide/LICENSE` for details.
