# Clide for Python

Python implementation of Clide, a library that turns annotated `Usage:` lines into fully validated command-line parsers.

## Overview

This implementation provides a Python library and demo application that parses command-line arguments based on POSIX-style usage specifications. It follows the same specification as the Standard ML and Rust implementations, ensuring consistent behavior across languages.

## Features

- **Specification-driven parsing**: Define your CLI shape once in human-friendly usage strings
- **Type-aware validation**: Options and positionals are validated as `INT`, `BOOL`, `STR`, or `PATH` immediately
- **Default values**: Support for default values in both options and positionals
- **Repeatable options**: Options can be marked as repeatable with `+`
- **Multiple commands**: Support for multiple commands via multiple `Usage:` lines
- **Help generation**: Automatic help text generation with optional user documentation

## Usage Example

```python
from clide import Clide

usage = [
    "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
    "Usage: mytool init <path:PATH>",
]

parse = Clide.from_usage_lines(usage)
result = parse(sys.argv[1:])

if result.command == "serve":
    # Handle serve command
    port_vals = next((v for k, v in result.options if k == "--port"), None)
    if port_vals:
        port = int(port_vals[0])
    # ...
elif result.command == "init":
    # Handle init command
    path = next((v for k, v in result.positionals if k == "path"), None)
    # ...
```

## Requirements

- Python 3.7+

## Installation

### Development Installation

From the `langs/python/` directory:

```bash
pip install -e .
```

### Using as a Library

Add to your `pyproject.toml`:

```toml
[dependencies]
clide = { path = "path/to/clide/langs/python" }
```

Or if published to PyPI:

```toml
[dependencies]
clide = "0.1.4"
```

## Building and Testing

### Running Tests

```bash
cd langs/python
python -m pytest tests/
```

Or using unittest:

```bash
cd langs/python
python -m unittest tests.clide_tests
```

### Running the Demo

```bash
cd langs/python
python demo.py --help
python demo.py serve --port 9090 /app
```

## API Reference

### `Clide.from_usage_lines(usage: List[str]) -> Callable[[List[str]], ParseResult]`

Parses usage lines and returns a parser function. The parser takes command-line arguments and returns a `ParseResult`.

### `Clide.help_of(usage: List[str]) -> str`

Generates help text from usage lines.

### `Clide.help_with_docs(usage: List[str], docs: List[Tuple[str, str]]) -> str`

Generates help text with user-provided documentation.

### `ParseResult`

```python
class ParseResult:
    command: str
    options: List[Tuple[str, List[str]]]  # (option_name, [values])
    positionals: List[Tuple[str, str]]     # (positional_name, value)
    leftovers: List[str]                   # Arguments after --
```

## Error Types

- `ParseError`: Errors during usage string parsing (specification errors)
- `ArgError`: Errors during argument parsing (runtime errors)

## Project Layout

```text
langs/python/
├── pyproject.toml        # Python package configuration
├── clide/                # Main package
│   ├── __init__.py       # Main library API
│   ├── spec.py           # Data structures
│   ├── parser.py         # Usage string parser
│   ├── runtime.py        # Argument parser
│   └── help.py           # Help text generator
├── demo.py               # Demo application
└── tests/
    ├── __init__.py
    └── clide_tests.py    # Test suite
```

## Specification

This implementation follows the specification defined in `../../docs/specs/USAGE.md`. All language implementations should conform to this specification for consistency.

## License

MIT License – see `../../LICENSE` for details.
