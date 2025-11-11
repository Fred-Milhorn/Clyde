//! Clide usage string parser

const std = @import("std");
const spec = @import("spec.zig");

pub const ParseError = error{
    NoUsageLines,
    InvalidUsageLine,
    UnterminatedPositional,
    BadOption,
    BadPositional,
    UnknownType,
    OutOfMemory,
};

pub fn fromLines(allocator: std.mem.Allocator, lines: []const []const u8) ParseError!spec.Spec {
    if (lines.len == 0) {
        return error.NoUsageLines;
    }

    var parsed = std.ArrayList(struct { []const u8, []spec.Item }).init(allocator);
    defer parsed.deinit();

    for (lines) |line| {
        const parsed_line = try parseUsageLine(allocator, line);
        try parsed.append(parsed_line);
    }

    const prog = parsed.items[0].@"0";

    var commands = std.ArrayList(spec.Command).init(allocator);
    for (parsed.items) |item| {
        const name = firstLitAfterProg(item.@"1") orelse "_";
        const name_owned = try allocator.dupe(u8, name);
        try commands.append(.{
            .name = name_owned,
            .items = item.@"1",
        });
    }

    const prog_owned = try allocator.dupe(u8, prog);
    const commands_owned = try commands.toOwnedSlice();

    return spec.Spec{
        .prog = prog_owned,
        .commands = commands_owned,
    };
}

fn parseUsageLine(allocator: std.mem.Allocator, line: []const u8) ParseError!struct { []const u8, []spec.Item } {
    var tokens = std.ArrayList([]const u8).init(allocator);
    defer tokens.deinit();

    var iter = std.mem.tokenizeScalar(u8, line, ' ');
    while (iter.next()) |token| {
        try tokens.append(token);
    }

    if (tokens.items.len < 2 or !std.mem.eql(u8, tokens.items[0], "Usage:")) {
        return error.InvalidUsageLine;
    }

    const prog = tokens.items[1];
    var items = std.ArrayList(spec.Item).init(allocator);

    for (tokens.items[2..]) |token| {
        const item = try parseGroupToken(allocator, token);
        try items.append(item);
    }

    return .{ prog, try items.toOwnedSlice() };
}

fn parseGroupToken(allocator: std.mem.Allocator, token: []const u8) ParseError!spec.Item {
    if (token.len >= 2 and token[0] == '[' and token[token.len - 1] == ']') {
        const inner = token[1..(token.len - 1)];
        var alts = std.ArrayList(spec.Atom).init(allocator);

        var iter = std.mem.splitScalar(u8, inner, '|');
        while (iter.next()) |alt| {
            const atom = try atomOf(allocator, alt);
            try alts.append(atom);
        }

        const atoms = try alts.toOwnedSlice();
        const group = if (atoms.len == 1) blk: {
            const single_atom = atoms[0];
            allocator.free(atoms);
            break :blk spec.Group{ .single = single_atom };
        } else
            spec.Group{ .alt = atoms };

        return spec.Item{ .optional = group };
    } else {
        const atom = try atomOf(allocator, token);
        const group = spec.Group{ .single = atom };
        return spec.Item{ .required = group };
    }
}

fn atomOf(allocator: std.mem.Allocator, token: []const u8) ParseError!spec.Atom {
    _ = allocator;
    if (token.len > 0 and token[0] == '<') {
        if (token.len < 2 or token[token.len - 1] != '>') {
            return error.UnterminatedPositional;
        }
        return parsePos(token);
    } else if (isLong(token) or isShort(token) or std.mem.indexOfScalar(u8, token, '=') != null) {
        return parseOption(token);
    } else {
        return spec.Atom{ .lit = token };
    }
}

fn parseOption(token: []const u8) ParseError!spec.Atom {
    const eq_pos = std.mem.indexOfScalar(u8, token, '=');
    const name_part = if (eq_pos) |pos| token[0..pos] else token;
    const val_part = if (eq_pos) |pos| token[(pos + 1)..] else null;

    const long_opt: ?[]const u8 = if (isLong(name_part)) name_part else null;
    const short_opt: ?[]const u8 = if (isShort(name_part)) name_part else null;

    if (long_opt == null and short_opt == null) {
        return error.BadOption;
    }

    if (val_part == null) {
        return spec.Atom{
            .opt_bool = .{
                .long = long_opt,
                .short = short_opt,
            },
        };
    }

    const allow_repeat = val_part.?.len > 0 and val_part.?[val_part.?.len - 1] == '+';
    const core = if (allow_repeat) val_part.?[0..(val_part.?.len - 1)] else val_part.?;

    const colon_pos = std.mem.indexOfScalar(u8, core, ':');
    const ty_str = if (colon_pos) |pos| core[0..pos] else core;
    const default = if (colon_pos) |pos| core[(pos + 1)..] else null;

    const ty = try spec.Type.fromStr(ty_str);

    return spec.Atom{
        .opt_val = .{
            .long = long_opt,
            .short = short_opt,
            .ty = ty,
            .default = default,
            .allow_repeat = allow_repeat,
        },
    };
}

fn parsePos(token: []const u8) ParseError!spec.Atom {
    if (token.len < 2 or token[0] != '<' or token[token.len - 1] != '>') {
        return error.BadPositional;
    }

    const inside = token[1..(token.len - 1)];
    const colon1 = std.mem.indexOfScalar(u8, inside, ':') orelse return error.BadPositional;
    const colon2 = std.mem.indexOfScalarPos(u8, inside, colon1 + 1, ':');

    const name = inside[0..colon1];
    const ty_str = if (colon2) |c2| inside[(colon1 + 1)..c2] else inside[(colon1 + 1)..];
    const default = if (colon2) |c2| inside[(c2 + 1)..] else null;

    const ty = try spec.Type.fromStr(ty_str);
    return spec.Atom{
        .pos = .{
            .name = name,
            .ty = ty,
            .default = default,
        },
    };
}

fn isShort(s: []const u8) bool {
    return s.len == 2 and s[0] == '-' and s[1] != '-';
}

fn isLong(s: []const u8) bool {
    return s.len >= 3 and s[0] == '-' and s[1] == '-';
}

fn firstLitAfterProg(items: []const spec.Item) ?[]const u8 {
    for (items) |item| {
        switch (item) {
            .required => |group| {
                switch (group) {
                    .single => |atom| {
                        switch (atom) {
                            .lit => |lit| return lit,
                            else => {},
                        }
                    },
                    .alt => |atoms| {
                        for (atoms) |atom| {
                            switch (atom) {
                                .lit => |lit| return lit,
                                else => {},
                            }
                        }
                    },
                }
            },
            .optional => {},
        }
    }
    return null;
}
