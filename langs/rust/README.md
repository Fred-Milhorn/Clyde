# Clide for Rust

Rust implementation of Clide, a library that turns annotated `Usage:` lines into fully validated command-line parsers.

## Overview

This implementation provides a Rust library and demo application that parses command-line arguments based on POSIX-style usage specifications. It follows the same specification as the Standard ML implementation, ensuring consistent behavior across languages.

## Features

- **Specification-driven parsing**: Define your CLI shape once in human-friendly usage strings
- **Type-aware validation**: Options and positionals are validated as `INT`, `BOOL`, `STR`, or `PATH` immediately
- **Default values**: Support for default values in both options and positionals
- **Repeatable options**: Options can be marked as repeatable with `+`
- **Multiple commands**: Support for multiple commands via multiple `Usage:` lines
- **Help generation**: Automatic help text generation with optional user documentation

## Usage Example

```rust
use clide::Clide;

let usage = vec![
    "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>".to_string(),
    "Usage: mytool init <path:PATH>".to_string(),
];

let parse = Clide::from_usage_lines(&usage)?;
let result = parse(&std::env::args().skip(1).collect::<Vec<_>>())?;

match result.command.as_str() {
    "serve" => {
        // Handle serve command
        let port: Option<&String> = result.options.iter()
            .find(|(k, _)| k == "--port")
            .map(|(_, v)| v.first())
            .flatten();
        // ...
    }
    "init" => {
        // Handle init command
    }
    _ => {}
}
```

## Building

### Requirements

- Rust 1.70+ (or latest stable)

### Build Commands

From the `langs/rust/` directory:

- `cargo build` – builds the library and demo in debug mode
- `cargo build --release` – builds optimized release binaries
- `cargo test` – runs the test suite
- `cargo run --bin clide-demo -- --help` – runs the demo application

### Quick Start

```bash
cd langs/rust
cargo build --release
./target/release/clide-demo --help
```

## Library Usage

Add to your `Cargo.toml`:

```toml
[dependencies]
clide = { path = "path/to/clide/lang/rust" }
```

Or if published to crates.io:

```toml
[dependencies]
clide = "0.1.4"
```

## API Reference

### `Clide::from_usage_lines(usage: &[String]) -> Result<Parser, ParseError>`

Parses usage lines and returns a parser function. The parser takes command-line arguments and returns a `ParseResult`.

### `Clide::help_of(usage: &[String]) -> Result<String, ParseError>`

Generates help text from usage lines.

### `Clide::help_with_docs(usage: &[String], docs: &[(String, String)]) -> Result<String, ParseError>`

Generates help text with user-provided documentation.

### `ParseResult`

```rust
pub struct ParseResult {
    pub command: String,
    pub options: Vec<(String, Vec<String>)>,
    pub positionals: Vec<(String, String)>,
    pub leftovers: Vec<String>,
}
```

## Error Types

- `ParseError`: Errors during usage string parsing (specification errors)
- `ArgError`: Errors during argument parsing (runtime errors)

## Project Layout

```text
langs/rust/
├── Cargo.toml           # Rust package configuration
├── src/
│   ├── lib.rs           # Main library API
│   ├── main.rs          # Demo application
│   ├── spec.rs          # Data structures
│   ├── parser.rs        # Usage string parser
│   ├── runtime.rs       # Argument parser
│   └── help.rs          # Help text generator
└── tests/
    └── clide_tests.rs   # Test suite
```

## Specification

This implementation follows the specification defined in `../../docs/specs/USAGE.md`. All language implementations should conform to this specification for consistency.

## License

MIT License – see `../../LICENSE` for details.
