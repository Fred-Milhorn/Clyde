//! Clide demo application

const std = @import("std");
const clide = @import("clide.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const usage = [_][]const u8{
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
        "Usage: mytool init <path:PATH>",
    };

    const docs = [_]struct { []const u8, []const u8 }{
        .{ "serve", "Start the HTTP server" },
        .{ "init", "Initialize a project directory" },
        .{ "-v, --verbose", "Verbose logging" },
        .{ "--port=INT:8080", "TCP port to listen on" },
        .{ "--tls", "Enable TLS" },
        .{ "--root=PATH", "Document root for static files" },
        .{ "<dir:PATH>", "Application directory" },
        .{ "<path:PATH>", "Project directory" },
    };

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        const help_text = try clide.Clide.helpWithDocs(allocator, &usage, &docs);
        defer allocator.free(help_text);
        std.debug.print("{s}\n", .{help_text});
        std.process.exit(0);
    }

    const argv = args[1..];
    var wants_help = false;
    for (argv) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            wants_help = true;
            break;
        }
    }

    if (wants_help) {
        const help_text = try clide.Clide.helpWithDocs(allocator, &usage, &docs);
        defer allocator.free(help_text);
        std.debug.print("{s}\n", .{help_text});
        std.process.exit(0);
    }

    var parser = try clide.Clide.fromUsageLines(allocator, &usage);
    defer parser.deinit();

    const result = parser.parse(argv) catch |err| {
        const stderr = std.io.getStdErr().writer();
        switch (err) {
            error.UnknownOption => try stderr.print("Error: Unknown option\n\n", .{}),
            error.MissingValue => try stderr.print("Error: Missing value\n\n", .{}),
            error.MissingPositional => try stderr.print("Error: Missing positional argument\n\n", .{}),
            error.UnexpectedArgument => try stderr.print("Error: Unexpected argument\n\n", .{}),
            error.InvalidInt => try stderr.print("Error: Invalid integer\n\n", .{}),
            error.InvalidBool => try stderr.print("Error: Invalid boolean\n\n", .{}),
            error.OutOfMemory => try stderr.print("Error: Out of memory\n\n", .{}),
        }
        const help_text = clide.Clide.helpWithDocs(allocator, &usage, &docs) catch |e| {
            _ = e;
            std.process.exit(1);
        };
        defer allocator.free(help_text);
        try stderr.print("{s}\n", .{help_text});
        std.process.exit(1);
    };
    defer result.deinit();

    std.debug.print("command: {s}\n", .{result.command});

    for (result.options.items) |opt| {
        std.debug.print("{s} = ", .{opt.@"0"});
        for (opt.@"1".items, 0..) |val, i| {
            if (i > 0) std.debug.print(", ", .{});
            std.debug.print("{s}", .{val});
        }
        std.debug.print("\n", .{});
    }

    for (result.positionals.items) |pos| {
        std.debug.print("{s} = {s}\n", .{ pos.@"0", pos.@"1" });
    }

    if (result.leftovers.items.len > 0) {
        std.debug.print("--- leftovers ---\n", .{});
        for (result.leftovers.items) |leftover| {
            std.debug.print("{s}\n", .{leftover});
        }
    }
}
