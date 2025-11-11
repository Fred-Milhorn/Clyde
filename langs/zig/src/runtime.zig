//! Clide runtime argument parser

const std = @import("std");
const spec = @import("spec.zig");

pub const ArgError = error{
    UnknownOption,
    MissingValue,
    MissingPositional,
    UnexpectedArgument,
    InvalidInt,
    InvalidBool,
    OutOfMemory,
};

pub const ParseResult = struct {
    command: []const u8,
    options: std.ArrayList(struct { []const u8, std.ArrayList([]const u8) }),
    positionals: std.ArrayList(struct { []const u8, []const u8 }),
    leftovers: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ParseResult) void {
        for (self.options.items) |*opt| {
            opt.@"1".deinit();
        }
        self.options.deinit();
        self.positionals.deinit();
        self.leftovers.deinit();
    }
};

pub fn chooseCommand(spec_: *const spec.Spec, argv: []const []const u8) *const spec.Command {
    if (argv.len == 0) {
        return &spec_.commands[0];
    }

    const first_arg = argv[0];
    for (spec_.commands) |*cmd| {
        if (firstLiteral(cmd)) |lit| {
            if (std.mem.eql(u8, lit, first_arg)) {
                return cmd;
            }
        }
    }

    return &spec_.commands[0];
}

fn firstLiteral(cmd: *const spec.Command) ?[]const u8 {
    for (cmd.items) |item| {
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

pub fn parseWith(allocator: std.mem.Allocator, cmd: *const spec.Command, argv: []const []const u8) ArgError!ParseResult {
    var seq = std.ArrayList(struct { bool, spec.Group }).init(allocator);
    defer seq.deinit();

    for (cmd.items) |item| {
        const is_optional = switch (item) {
            .required => false,
            .optional => true,
        };
        const group = switch (item) {
            .required => |g| g,
            .optional => |g| g,
        };
        try seq.append(.{ is_optional, group });
    }

    var atoms = std.ArrayList(spec.Atom).init(allocator);
    defer atoms.deinit();

    for (seq.items) |item| {
        const group = item.@"1";
        switch (group) {
            .single => |atom| try atoms.append(atom),
            .alt => |alts| {
                for (alts) |atom| {
                    try atoms.append(atom);
                }
            },
        }
    }

    // Build list of known options
    var known_opts = std.ArrayList([]const u8).init(allocator);
    defer known_opts.deinit();

    for (atoms.items) |atom| {
        switch (atom) {
            .opt_bool => |opt| {
                if (opt.long) |long| try known_opts.append(long);
                if (opt.short) |short| try known_opts.append(short);
            },
            .opt_val => |opt| {
                if (opt.long) |long| try known_opts.append(long);
                if (opt.short) |short| try known_opts.append(short);
            },
            else => {},
        }
    }

    // Build list of positionals
    var pos_list = std.ArrayList(struct { []const u8, spec.Type, ?[]const u8 }).init(allocator);
    defer pos_list.deinit();

    for (atoms.items) |atom| {
        switch (atom) {
            .pos => |pos| {
                try pos_list.append(.{ pos.name, pos.ty, pos.default });
            },
            else => {},
        }
    }

    var opts_map = std.ArrayList(struct { []const u8, std.ArrayList([]const u8) }).init(allocator);
    var pos_map = std.ArrayList(struct { []const u8, []const u8 }).init(allocator);
    var seen_pos: usize = 0;
    var leftovers = std.ArrayList([]const u8).init(allocator);

    var i: usize = 0;
    while (i < argv.len) {
        const arg = argv[i];

        if (std.mem.eql(u8, arg, "--")) {
            // Handle remaining positionals
            const remaining_pos = pos_list.items[seen_pos..];
            const rest = argv[(i + 1)..];

            for (remaining_pos, 0..) |pos_item, j| {
                if (j < rest.len) {
                    const val = try parseVal(allocator, pos_item.@"1", rest[j]);
                    const name_owned = try allocator.dupe(u8, pos_item.@"0");
                    try pos_map.append(.{ name_owned, val });
                    seen_pos += 1;
                } else if (pos_item.@"2") |default| {
                    const val = try parseVal(allocator, pos_item.@"1", default);
                    const name_owned = try allocator.dupe(u8, pos_item.@"0");
                    try pos_map.append(.{ name_owned, val });
                    seen_pos += 1;
                } else {
                    return error.MissingPositional;
                }
            }

            for (rest[remaining_pos.len..]) |leftover| {
                const leftover_owned = try allocator.dupe(u8, leftover);
                try leftovers.append(leftover_owned);
            }
            break;
        } else if (arg.len > 0 and arg[0] == '-') {
            const eq_pos = std.mem.indexOfScalar(u8, arg, '=');
            const name_part = if (eq_pos) |pos| arg[0..pos] else arg;
            const val_part = if (eq_pos) |pos| arg[(pos + 1)..] else null;

            var found = false;
            for (known_opts.items) |opt| {
                if (std.mem.eql(u8, opt, name_part)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                return error.UnknownOption;
            }

            // Find the option declaration
            var opt_decl: ?spec.Atom = null;
            for (atoms.items) |atom| {
                switch (atom) {
                    .opt_val => |opt| {
                        if ((opt.long != null and std.mem.eql(u8, opt.long.?, name_part)) or
                            (opt.short != null and std.mem.eql(u8, opt.short.?, name_part)))
                        {
                            opt_decl = atom;
                            break;
                        }
                    },
                    .opt_bool => |opt| {
                        if ((opt.long != null and std.mem.eql(u8, opt.long.?, name_part)) or
                            (opt.short != null and std.mem.eql(u8, opt.short.?, name_part)))
                        {
                            opt_decl = atom;
                            break;
                        }
                    },
                    else => {},
                }
            }

            if (opt_decl == null) {
                return error.UnknownOption;
            }

            switch (opt_decl.?) {
                .opt_bool => {
                    const name_owned = try allocator.dupe(u8, name_part);
                    const val_owned = try allocator.dupe(u8, "true");
                    addOpt(allocator, &opts_map, name_owned, val_owned) catch |e| {
                        allocator.free(name_owned);
                        allocator.free(val_owned);
                        return e;
                    };
                    i += 1;
                },
                .opt_val => |opt| {
                    const val = if (val_part) |v|
                        try parseVal(allocator, opt.ty, v)
                    else if (i + 1 < argv.len) {
                        i += 1;
                        try parseVal(allocator, opt.ty, argv[i])
                    } else {
                        return error.MissingValue;
                    };
                    const name_owned = try allocator.dupe(u8, name_part);
                    addOpt(allocator, &opts_map, name_owned, val) catch |e| {
                        allocator.free(name_owned);
                        return e;
                    };
                    i += 1;
                },
                else => unreachable,
            }
        } else {
            // Try to consume as literal
            var consumed = false;
            for (seq.items) |item| {
                if (item.@"0") { // optional
                    const group = item.@"1";
                    switch (group) {
                        .single => |atom| {
                            switch (atom) {
                                .lit => |lit| {
                                    if (std.mem.eql(u8, lit, arg)) {
                                        consumed = true;
                                        break;
                                    }
                                },
                                else => {},
                            }
                        },
                        .alt => |alts| {
                            for (alts) |atom| {
                                switch (atom) {
                                    .lit => |lit| {
                                        if (std.mem.eql(u8, lit, arg)) {
                                            consumed = true;
                                            break;
                                        }
                                    },
                                    else => {},
                                }
                            }
                            if (consumed) break;
                        },
                    }
                }
            }

            if (consumed) {
                i += 1;
                continue;
            }

            // Treat as positional
            if (seen_pos >= pos_list.items.len) {
                return error.UnexpectedArgument;
            }

            const pos_item = pos_list.items[seen_pos];
            const val = try parseVal(allocator, pos_item.@"1", arg);
            const name_owned = try allocator.dupe(u8, pos_item.@"0");
            try pos_map.append(.{ name_owned, val });
            seen_pos += 1;
            i += 1;
        }
    }

    // Add option defaults
    for (atoms.items) |atom| {
        switch (atom) {
            .opt_val => |opt| {
                const key = opt.long orelse opt.short orelse continue;
                var found = false;
                for (opts_map.items) |opt_item| {
                    if (std.mem.eql(u8, opt_item.@"0", key)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    if (opt.default) |default| {
                        const val = try parseVal(allocator, opt.ty, default);
                        const key_owned = try allocator.dupe(u8, key);
                        addOpt(allocator, &opts_map, key_owned, val) catch |e| {
                            allocator.free(key_owned);
                            return e;
                        };
                    }
                }
            },
            .opt_bool => |opt| {
                const key = opt.long orelse opt.short orelse continue;
                var found = false;
                for (opts_map.items) |opt_item| {
                    if (std.mem.eql(u8, opt_item.@"0", key)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    const val_owned = try allocator.dupe(u8, "false");
                    const key_owned = try allocator.dupe(u8, key);
                    addOpt(allocator, &opts_map, key_owned, val_owned) catch |e| {
                        allocator.free(key_owned);
                        allocator.free(val_owned);
                        return e;
                    };
                }
            },
            else => {},
        }
    }

    // Add positional defaults
    for (pos_list.items) |pos_item| {
        var found = false;
        for (pos_map.items) |pos_map_item| {
            if (std.mem.eql(u8, pos_map_item.@"0", pos_item.@"0")) {
                found = true;
                break;
            }
        }
        if (!found) {
            if (pos_item.@"2") |default| {
                const val = try parseVal(allocator, pos_item.@"1", default);
                const name_owned = try allocator.dupe(u8, pos_item.@"0");
                try pos_map.append(.{ name_owned, val });
            } else {
                return error.MissingPositional;
            }
        }
    }

    return ParseResult{
        .command = cmd.name,
        .options = opts_map,
        .positionals = pos_map,
        .leftovers = leftovers,
        .allocator = allocator,
    };
}

fn parseVal(allocator: std.mem.Allocator, ty: spec.Type, s: []const u8) ArgError![]const u8 {
    return switch (ty) {
        .int => {
            _ = std.fmt.parseInt(i64, s, 10) catch return error.InvalidInt;
            const owned = try allocator.dupe(u8, s);
            return owned;
        },
        .bool => {
            var lower_buf: [256]u8 = undefined;
            const lower = std.ascii.lowerString(&lower_buf, s);
            if (std.mem.eql(u8, lower, "true") or std.mem.eql(u8, lower, "false")) {
                const owned = try allocator.dupe(u8, lower);
                return owned;
            } else {
                return error.InvalidBool;
            }
        },
        .str, .path => {
            const owned = try allocator.dupe(u8, s);
            return owned;
        },
    };
}

fn addOpt(allocator: std.mem.Allocator, opts_map: *std.ArrayList(struct { []const u8, std.ArrayList([]const u8) }), key: []const u8, val: []const u8) ArgError!void {
    // key and val are already owned (duplicated) by the caller
    for (opts_map.items) |*opt| {
        if (std.mem.eql(u8, opt.@"0", key)) {
            try opt.@"1".append(val);
            return;
        }
    }
    var vals = std.ArrayList([]const u8).init(allocator);
    try vals.append(val);
    try opts_map.append(.{ key, vals });
}
