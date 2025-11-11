const std = @import("std");
const clide = @import("clide.zig");
const testing = std.testing;

test "basic parsing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const usage = [_][]const u8{
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
        "Usage: mytool init <path:PATH>",
    };

    var parser = try clide.Clide.fromUsageLines(allocator, &usage);
    defer parser.deinit();

    const argv = [_][]const u8{ "serve", "--port", "9090", "/tmp/app" };
    const result = try parser.parse(&argv);
    defer result.deinit();

    try testing.expectEqualStrings("serve", result.command);
    var found_port = false;
    for (result.options.items) |opt| {
        if (std.mem.eql(u8, opt.@"0", "--port")) {
            try testing.expect(opt.@"1".items.len == 1);
            try testing.expectEqualStrings("9090", opt.@"1".items[0]);
            found_port = true;
            break;
        }
    }
    try testing.expect(found_port);
}

test "defaults" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const usage = [_][]const u8{
        "Usage: mytool [-v|--verbose] serve [--port=INT:8080] [--tls] [--root=PATH] <dir:PATH>",
    };

    var parser = try clide.Clide.fromUsageLines(allocator, &usage);
    defer parser.deinit();

    const argv = [_][]const u8{ "serve", "/workdir" };
    const result = try parser.parse(&argv);
    defer result.deinit();

    var found_port = false;
    for (result.options.items) |opt| {
        if (std.mem.eql(u8, opt.@"0", "--port")) {
            try testing.expect(opt.@"1".items.len == 1);
            try testing.expectEqualStrings("8080", opt.@"1".items[0]);
            found_port = true;
            break;
        }
    }
    try testing.expect(found_port);
}

test "repeating option" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const usage = [_][]const u8{
        "Usage: build [--include=PATH+] <dir:PATH>",
    };

    var parser = try clide.Clide.fromUsageLines(allocator, &usage);
    defer parser.deinit();

    const argv = [_][]const u8{ "--include", "src", "--include", "lib", "project" };
    const result = try parser.parse(&argv);
    defer result.deinit();

    var found_include = false;
    for (result.options.items) |opt| {
        if (std.mem.eql(u8, opt.@"0", "--include")) {
            try testing.expect(opt.@"1".items.len == 2);
            try testing.expectEqualStrings("src", opt.@"1".items[0]);
            try testing.expectEqualStrings("lib", opt.@"1".items[1]);
            found_include = true;
            break;
        }
    }
    try testing.expect(found_include);
}

test "help output" {
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
    };

    const help_text = try clide.Clide.helpWithDocs(allocator, &usage, &docs);
    defer allocator.free(help_text);

    try testing.expect(std.mem.indexOf(u8, help_text, "--port=INT:8080") != null);
    try testing.expect(std.mem.indexOf(u8, help_text, "-v") != null);
    try testing.expect(std.mem.indexOf(u8, help_text, "--verbose") != null);
    try testing.expect(std.mem.indexOf(u8, help_text, "serve") != null);
}
