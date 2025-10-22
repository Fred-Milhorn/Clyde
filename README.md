# Clide

Clide is a Standard ML library and demo application that turns annotated
`Usage:` lines into a fully validated command-line parser. It ships with a
self-contained build system (MLton + Make) and a lightweight test harness so you
can experiment with CLI specification driven parsing without relying on external
services.

## Rationale

- **Specification at the edge**: CLI shape is recorded once in human-friendly
   usage strings, then compiled to enforce flags, defaults, and positional
   arguments at runtime.
- **Type-aware parsing**: Options and positionals deserialize into `INT`,
   `BOOL`, `STR`, and `PATH` values immediately, surfacing `ArgError` on bad
   input instead of deferring validation.
- **Embeddable library**: The parsing engine lives under `lib/clide`, sealed by
   the `CLI_DERIVE` signature. The demo in `src/Main.sml` shows how to wire
   `Clide.fromUsageLines` and `Clide.helpWithDocs` into an application.

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

Running the bundled demo binary:

```bash
make prod
./build/CLIDE_DEMO-prod --help
```

## Build Targets

- `make dev` – builds `build/CLIDE_DEMO-dev` using the development MLB profile.
- `make prod` – builds the optimized production binary in `build/CLIDE_DEMO-prod`.
- `make test` – compiles the test runner (`build/CLIDE_DEMO-test`) and executes
   the suite in `test/`, covering parser defaults, repeatable options, error
   surfaces, and help rendering.
- `make run BIN=clide-demo PROFILE=dev ARGS='serve /tmp/app'` – convenience
   target to invoke a compiled binary with arguments.
- `make clean` – removes the `build/` directory (generated binaries and
   `build/vars.mk`).

## Project Layout

```text
├── Project.toml            # Build + profile configuration
├── Makefile                # MLton build orchestration
├── lib/clide/              # Reusable CLI derivation library
├── src/Main.sml            # Demo program wiring the library
├── test/                   # Expect-based unit tests (run with make test)
├── mlb/                    # MLton basis bundles for each profile
├── tools/toml2mk.py        # Generates build/vars.mk from Project.toml
└── docs/USAGE.md           # Reference for usage string semantics
```

## Requirements

- [MLton](https://mlton.org)
- Python 3.11+ (or 3.7+ with `tomli`) for the `toml2mk.py` helper
- POSIX `make`

## License

MIT License – see `lib/clide/LICENSE` for details.
