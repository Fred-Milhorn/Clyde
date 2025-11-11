# Clide

Clide is a multi-language library that turns annotated `Usage:` lines into fully validated command-line parsers. Each language implementation provides a consistent API for parsing command-line arguments based on POSIX-style usage specifications.

## Overview

Clide provides a specification-driven approach to CLI parsing:

- **Specification at the edge**: CLI shape is recorded once in human-friendly usage strings, then compiled to enforce flags, defaults, and positional arguments at runtime.
- **Type-aware parsing**: Options and positionals deserialize into typed values (`INT`, `BOOL`, `STR`, `PATH`) immediately, surfacing errors on bad input instead of deferring validation.
- **Consistent API**: All language implementations follow the same specification, ensuring predictable behavior across languages.

## Language Implementations

### Standard ML (SML)

The original implementation in Standard ML (MLton). See [`langs/sml/README.md`](langs/sml/README.md) for details.

**Quick Start:**
```bash
cd langs/sml
make prod
./build/clide-prod --help
```

### Rust

A Rust implementation with the same API and behavior. See [`langs/rust/README.md`](langs/rust/README.md) for details.

**Quick Start:**
```bash
cd langs/rust
cargo build --release
./target/release/clide-demo --help
```

### Python

A Python implementation with the same API and behavior. See [`langs/python/README.md`](langs/python/README.md) for details.

**Quick Start:**
```bash
cd langs/python
python3 demo.py --help
```

### Zig

A Zig implementation with the same API and behavior. See [`langs/zig/README.md`](langs/zig/README.md) for details.

**Quick Start:**
```bash
cd langs/zig
zig build
./zig-out/bin/clide-demo --help
```

## Specification

The core specification for Clide usage strings is documented in [`docs/specs/USAGE.md`](docs/specs/USAGE.md). This specification defines:

- Usage string syntax and semantics
- Type annotations (`INT`, `BOOL`, `STR`, `PATH`)
- Default value syntax
- Flag and positional argument parsing rules
- Help text generation conventions

All language implementations should conform to this specification.

## Project Layout

```text
├── docs/
│   └── specs/              # Shared specification documentation
│       └── USAGE.md        # Usage string specification
├── langs/                  # Language-specific implementations
│   ├── sml/                # Standard ML implementation
│   │   ├── lib/clide/      # Reusable CLI derivation library
│   │   ├── src/            # Demo application
│   │   ├── test/           # Test suite
│   │   ├── mlb/            # MLton basis bundles
│   │   ├── Makefile        # Build system
│   │   └── Project.toml    # Build configuration
│   ├── rust/               # Rust implementation
│   │   ├── src/            # Library and demo source
│   │   ├── tests/          # Test suite
│   │   ├── Cargo.toml      # Rust package configuration
│   │   └── README.md       # Rust-specific documentation
│   ├── python/             # Python implementation
│   │   ├── clide/          # Main package
│   │   ├── demo.py         # Demo application
│   │   ├── tests/          # Test suite
│   │   ├── pyproject.toml  # Python package configuration
│   │   └── README.md       # Python-specific documentation
│   └── zig/                 # Zig implementation
│       ├── src/            # Library and demo source
│       ├── tests/          # Test suite
│       ├── build.zig       # Zig build configuration
│       └── README.md       # Zig-specific documentation
└── LICENSE                 # Project license
```

## Contributing

When adding a new language implementation:

1. Create a new directory under `langs/` (e.g., `langs/rust/`)
2. Implement the parser according to the specification in `docs/specs/USAGE.md`
3. Include tests that verify conformance to the specification
4. Add a `README.md` in the language directory explaining how to build and use it
5. Update this README to list the new implementation

## License

MIT License – see `LICENSE` for details.
