# Clide — Zig Implementation

A Zig implementation of Clide, a library that turns annotated `Usage:` lines into fully validated command-line parsers.

## Overview

This implementation provides the same API and behavior as the other language implementations (SML, Rust, Python), following the specification in [`docs/specs/USAGE.md`](../../docs/specs/USAGE.md).

## Quick Start

### Building

```bash
cd langs/zig
zig build
```

This will:
- Build the library (`libclide.a`)
- Build the demo executable (`zig-out/bin/clide-demo`)
- Run tests

### Running the Demo

```bash
./zig-out/bin/clide-demo --help
```

### Using in Your Project

Add this to your `build.zig`:

```zig
const clide = b.addStaticLibrary(.{
    .name = "clide",
    .root_source_file = b.path("path/to/clide/src/clide.zig"),
    .target = target,
    .optimize = optimize,
});
exe.linkLibrary(clide);
```

Then in your code:

```zig
const clide = @import("clide");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const usage = [_][]const u8{
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] <dir:PATH>",
        "Usage: mytool init <path:PATH>",
    };

    var parser = try clide.Clide.fromUsageLines(allocator, &usage);
    defer parser.deinit();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const result = try parser.parse(args[1..]);
    defer result.deinit();

    // Use result.command, result.options, result.positionals, result.leftovers
}
```

## API

### `Clide.fromUsageLines(allocator, usage)`

Parses usage lines and returns a parser struct.

**Parameters:**
- `allocator`: Memory allocator to use
- `usage`: Slice of usage strings (e.g., `[]const []const u8`)

**Returns:** A parser struct with a `parse()` method and `deinit()` method.

### `Clide.helpOf(allocator, usage)`

Renders basic help text from usage lines.

**Returns:** Allocated string (caller must free).

### `Clide.helpWithDocs(allocator, usage, docs)`

Renders help text with user-provided documentation.

**Parameters:**
- `docs`: Slice of `struct { []const u8, []const u8 }` pairs (key, description)

**Returns:** Allocated string (caller must free).

### `ParseResult`

Result of parsing command-line arguments:

- `command`: The matched command name
- `options`: List of `struct { []const u8, std.ArrayList([]const u8) }` (option name, values)
- `positionals`: List of `struct { []const u8, []const u8 }` (name, value)
- `leftovers`: Arguments after `--`
- `deinit()`: Free all allocated memory

## Error Handling

The library uses Zig's error handling:

- `ParseError`: Errors during usage string parsing
- `ArgError`: Errors during argument parsing

## Memory Management

All strings returned by the library are allocated using the provided allocator. The caller is responsible for freeing:

- Strings returned by `helpOf()` and `helpWithDocs()`
- Memory managed by `ParseResult.deinit()`
- Memory managed by parser `deinit()`

## Testing

Run tests with:

```bash
zig build test
```

## License

MIT License — see `LICENSE` for details.
