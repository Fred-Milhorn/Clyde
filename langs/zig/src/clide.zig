//! Clide: Augmented POSIX Usage -> argv parser for Zig
//!
//! Clide turns annotated `Usage:` lines into fully validated command-line parsers.

const std = @import("std");
const spec = @import("spec.zig");
const parser = @import("parser.zig");
const runtime = @import("runtime.zig");
const help = @import("help.zig");

pub const Type = spec.Type;
pub const ParseError = parser.ParseError;
pub const ArgError = runtime.ArgError;
pub const ParseResult = runtime.ParseResult;

/// Main Clide API
pub const Clide = struct {
    /// Parse usage lines and return a parser function
    pub fn fromUsageLines(allocator: std.mem.Allocator, usage: []const []const u8) ParseError!struct {
        allocator: std.mem.Allocator,
        spec: spec.Spec,

        pub fn parse(self: *@This(), argv: []const []const u8) ArgError!ParseResult {
            const cmd = runtime.chooseCommand(&self.spec, argv);
            return runtime.parseWith(self.allocator, cmd, argv);
        }

        pub fn deinit(self: *@This()) void {
            // Free spec memory
            self.allocator.free(self.spec.prog);
            for (self.spec.commands) |cmd| {
                self.allocator.free(cmd.name);
                // Free items - they contain atoms that may need freeing
                // For now, we'll just free the items array
                self.allocator.free(cmd.items);
            }
            self.allocator.free(self.spec.commands);
        }
    } {
        const spec_ = try parser.fromLines(allocator, usage);
        return .{
            .allocator = allocator,
            .spec = spec_,
        };
    }

    /// Render help text from usage lines
    pub fn helpOf(allocator: std.mem.Allocator, usage: []const []const u8) ParseError![]const u8 {
        const spec_ = try parser.fromLines(allocator, usage);
        defer {
            allocator.free(spec_.prog);
            for (spec_.commands) |cmd| {
                allocator.free(cmd.name);
                allocator.free(cmd.items);
            }
            allocator.free(spec_.commands);
        }
        return help.render(allocator, &spec_);
    }

    /// Render help text with user-provided documentation
    pub fn helpWithDocs(allocator: std.mem.Allocator, usage: []const []const u8, docs: []const struct { []const u8, []const u8 }) ParseError![]const u8 {
        const spec_ = try parser.fromLines(allocator, usage);
        defer {
            allocator.free(spec_.prog);
            for (spec_.commands) |cmd| {
                allocator.free(cmd.name);
                allocator.free(cmd.items);
            }
            allocator.free(spec_.commands);
        }
        return help.renderWithDocs(allocator, &spec_, docs);
    }
};
