//! Clide help text generator

const std = @import("std");
const spec = @import("spec.zig");

pub fn render(allocator: std.mem.Allocator, spec_: *const spec.Spec) std.mem.Allocator.Error![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    try result.appendSlice("Usage:\n");

    for (spec_.commands) |cmd| {
        try result.appendSlice("  ");
        try result.appendSlice(cmd.name);
        try result.append(' ');

        // Filter out the command literal from items when rendering
        var items_to_render = std.ArrayList(spec.Item).init(allocator);
        defer items_to_render.deinit();

        for (cmd.items) |item| {
            // Skip if this is the command literal itself
            switch (item) {
                .required => |group| {
                    switch (group) {
                        .single => |atom| {
                            switch (atom) {
                                .lit => |lit| {
                                    if (std.mem.eql(u8, lit, cmd.name)) {
                                        continue;
                                    }
                                },
                                else => {},
                            }
                        },
                        .alt => |atoms| {
                            var skip = false;
                            for (atoms) |atom| {
                                switch (atom) {
                                    .lit => |lit| {
                                        if (std.mem.eql(u8, lit, cmd.name)) {
                                            skip = true;
                                            break;
                                        }
                                    },
                                    else => {},
                                }
                            }
                            if (skip) continue;
                        },
                    }
                },
                .optional => {},
            }
            try items_to_render.append(item);
        }

        for (items_to_render.items) |item| {
            const item_str = try showItem(allocator, item);
            defer allocator.free(item_str);
            try result.appendSlice(item_str);
            try result.append(' ');
        }

        try result.append('\n');
    }

    return try result.toOwnedSlice();
}

fn showItem(allocator: std.mem.Allocator, item: spec.Item) std.mem.Allocator.Error![]const u8 {
    const group_str = try showGroup(allocator, switch (item) {
        .required => |g| g,
        .optional => |g| g,
    });

    return switch (item) {
        .required => group_str,
        .optional => |_| blk: {
            const result = try std.fmt.allocPrint(allocator, "[{s}]", .{group_str});
            allocator.free(group_str);
            break :blk result;
        },
    };
}

fn showGroup(allocator: std.mem.Allocator, group: spec.Group) std.mem.Allocator.Error![]const u8 {
    switch (group) {
        .single => |atom| return showAtom(allocator, atom),
        .alt => |atoms| {
            var parts = std.ArrayList([]const u8).init(allocator);
            defer {
                for (parts.items) |part| {
                    allocator.free(part);
                }
                parts.deinit();
            }

            for (atoms) |atom| {
                const atom_str = try showAtom(allocator, atom);
                try parts.append(atom_str);
            }

            const result = try std.mem.join(allocator, "|", parts.items);
            return result;
        },
    }
}

fn showAtom(allocator: std.mem.Allocator, atom: spec.Atom) std.mem.Allocator.Error![]const u8 {
    return switch (atom) {
        .lit => |s| try allocator.dupe(u8, s),
        .opt_bool => |opt| blk: {
            if (opt.short) |short| {
                if (opt.long) |long| {
                    break :blk try std.fmt.allocPrint(allocator, "{s}|{s}", .{ short, long });
                } else {
                    break :blk try allocator.dupe(u8, short);
                }
            } else if (opt.long) |long| {
                break :blk try allocator.dupe(u8, long);
            } else {
                break :blk try allocator.dupe(u8, "--?");
            }
        },
        .opt_val => |opt| blk: {
            const name = opt.short orelse opt.long orelse "--?";
            const t = opt.ty.toString();
            const d = if (opt.default) |def| try std.fmt.allocPrint(allocator, ":{s}", .{def}) else try allocator.dupe(u8, "");
            defer if (opt.default != null) allocator.free(d);
            const plus = if (opt.allow_repeat) "+" else "";
            break :blk try std.fmt.allocPrint(allocator, "{s}={s}{s}{s}", .{ name, t, d, plus });
        },
        .pos => |pos| blk: {
            const t = pos.ty.toString();
            const d = if (pos.default) |def| try std.fmt.allocPrint(allocator, ":{s}", .{def}) else try allocator.dupe(u8, "");
            defer if (pos.default != null) allocator.free(d);
            break :blk try std.fmt.allocPrint(allocator, "<{s}:{s}{s}>", .{ pos.name, t, d });
        },
    };
}

pub fn keyStringOfAtom(allocator: std.mem.Allocator, atom: spec.Atom) std.mem.Allocator.Error![]const u8 {
    return switch (atom) {
        .opt_bool => |opt| blk: {
            if (opt.short) |short| {
                if (opt.long) |long| {
                    break :blk try std.fmt.allocPrint(allocator, "{s}, {s}", .{ short, long });
                } else {
                    break :blk try allocator.dupe(u8, short);
                }
            } else if (opt.long) |long| {
                break :blk try allocator.dupe(u8, long);
            } else {
                break :blk try allocator.dupe(u8, "--?");
            }
        },
        .opt_val => |opt| blk: {
            const base = if (opt.short) |short| blk2: {
                if (opt.long) |long| {
                    break :blk2 try std.fmt.allocPrint(allocator, "{s}, {s}", .{ short, long });
                } else {
                    break :blk2 try allocator.dupe(u8, short);
                }
            } else if (opt.long) |long| {
                try allocator.dupe(u8, long)
            } else {
                try allocator.dupe(u8, "--?")
            };
            defer allocator.free(base);
            const t = opt.ty.toString();
            const d = if (opt.default) |def| try std.fmt.allocPrint(allocator, ":{s}", .{def}) else try allocator.dupe(u8, "");
            defer if (opt.default != null) allocator.free(d);
            const plus = if (opt.allow_repeat) "+" else "";
            break :blk try std.fmt.allocPrint(allocator, "{s}={s}{s}{s}", .{ base, t, d, plus });
        },
        .pos => |pos| blk: {
            const t = pos.ty.toString();
            const d = if (pos.default) |def| try std.fmt.allocPrint(allocator, ":{s}", .{def}) else try allocator.dupe(u8, "");
            defer if (pos.default != null) allocator.free(d);
            break :blk try std.fmt.allocPrint(allocator, "<{s}:{s}{s}>", .{ pos.name, t, d });
        },
        .lit => |s| try allocator.dupe(u8, s),
    };
}

fn synthLine(allocator: std.mem.Allocator, atom: spec.Atom) std.mem.Allocator.Error!struct { []const u8, []const u8 } {
    const key = try keyStringOfAtom(allocator, atom);
    errdefer allocator.free(key);

    const desc = switch (atom) {
        .lit => try allocator.dupe(u8, "command"),
        .opt_bool => try allocator.dupe(u8, "boolean flag"),
        .opt_val => |opt| blk: {
            const t = opt.ty.toString();
            const d = if (opt.default) |def| try std.fmt.allocPrint(allocator, " (default {s})", .{def}) else try allocator.dupe(u8, "");
            defer if (opt.default != null) allocator.free(d);
            const rep = if (opt.allow_repeat) " (repeatable)" else "";
            break :blk try std.fmt.allocPrint(allocator, "value option {s}{s}{s}", .{ t, d, rep });
        },
        .pos => |pos| blk: {
            const t = pos.ty.toString();
            const d = if (pos.default) |def| try std.fmt.allocPrint(allocator, " (default {s})", .{def}) else try allocator.dupe(u8, "");
            defer if (pos.default != null) allocator.free(d);
            break :blk try std.fmt.allocPrint(allocator, "positional {s}{s}", .{ t, d });
        },
    };

    return .{ key, desc };
}

fn synthDocs(allocator: std.mem.Allocator, spec_: *const spec.Spec) std.mem.Allocator.Error![]const struct { []const u8, []const u8 } {
    var result = std.ArrayList(struct { []const u8, []const u8 }).init(allocator);

    for (spec_.commands) |cmd| {
        // Include leading command literal if present
        if (cmd.items.len > 0) {
            switch (cmd.items[0]) {
                .required => |group| {
                    switch (group) {
                        .single => |atom| {
                            switch (atom) {
                                .lit => |lit| {
                                    var found = false;
                                    for (result.items) |item| {
                                        if (std.mem.eql(u8, item.@"0", lit)) {
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found) {
                                        const key = try allocator.dupe(u8, lit);
                                        const desc = try allocator.dupe(u8, "command");
                                        try result.append(.{ key, desc });
                                    }
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }
                },
                .optional => {},
            }
        }

        // Collect all atoms
        var atoms = std.ArrayList(spec.Atom).init(allocator);
        defer atoms.deinit();

        for (cmd.items) |item| {
            switch (item) {
                .required => |group| {
                    switch (group) {
                        .single => |atom| try atoms.append(atom),
                        .alt => |alts| {
                            for (alts) |atom| {
                                try atoms.append(atom);
                            }
                        },
                    }
                },
                .optional => |group| {
                    switch (group) {
                        .single => |atom| try atoms.append(atom),
                        .alt => |alts| {
                            for (alts) |atom| {
                                try atoms.append(atom);
                            }
                        },
                    }
                },
            }
        }

        for (atoms.items) |atom| {
            const key_desc = try synthLine(allocator, atom);
            errdefer {
                allocator.free(key_desc.@"0");
                allocator.free(key_desc.@"1");
            }

            var found = false;
            for (result.items) |item| {
                if (std.mem.eql(u8, item.@"0", key_desc.@"0")) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                try result.append(key_desc);
            } else {
                allocator.free(key_desc.@"0");
                allocator.free(key_desc.@"1");
            }
        }
    }

    return try result.toOwnedSlice();
}

fn mergeDocs(allocator: std.mem.Allocator, user: []const struct { []const u8, []const u8 }, synth: []const struct { []const u8, []const u8 }) std.mem.Allocator.Error![]const struct { []const u8, []const u8 } {
    var result = std.ArrayList(struct { []const u8, []const u8 }).init(allocator);

    for (synth) |synth_item| {
        var found_user: ?[]const u8 = null;
        for (user) |user_item| {
            if (std.mem.eql(u8, user_item.@"0", synth_item.@"0")) {
                found_user = user_item.@"1";
                break;
            }
        }

        if (found_user) |desc| {
            const key = try allocator.dupe(u8, synth_item.@"0");
            const desc_owned = try allocator.dupe(u8, desc);
            try result.append(.{ key, desc_owned });
        } else {
            const key = try allocator.dupe(u8, synth_item.@"0");
            const desc = try allocator.dupe(u8, synth_item.@"1");
            try result.append(.{ key, desc });
        }
    }

    return try result.toOwnedSlice();
}

fn renderDocs(allocator: std.mem.Allocator, pairs: []const struct { []const u8, []const u8 }) std.mem.Allocator.Error![]const u8 {
    if (pairs.len == 0) {
        return try allocator.dupe(u8, "");
    }

    var max_len: usize = 0;
    for (pairs) |pair| {
        if (pair.@"0".len > max_len) {
            max_len = pair.@"0".len;
        }
    }

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    try result.appendSlice("Options & Arguments:\n");
    for (pairs) |pair| {
        try result.appendSlice("  ");
        try result.appendSlice(pair.@"0");
        const padding_len = max_len - pair.@"0".len;
        var i: usize = 0;
        while (i < padding_len) : (i += 1) {
            try result.append(' ');
        }
        try result.appendSlice("  -  ");
        try result.appendSlice(pair.@"1");
        try result.append('\n');
    }

    return try result.toOwnedSlice();
}

pub fn renderWithDocs(allocator: std.mem.Allocator, spec_: *const spec.Spec, user_docs: []const struct { []const u8, []const u8 }) std.mem.Allocator.Error![]const u8 {
    const usage = try render(allocator, spec_);
    defer allocator.free(usage);

    const synth = try synthDocs(allocator, spec_);
    defer {
        for (synth) |item| {
            allocator.free(item.@"0");
            allocator.free(item.@"1");
        }
        allocator.free(synth);
    }

    const merged = try mergeDocs(allocator, user_docs, synth);
    defer {
        for (merged) |item| {
            allocator.free(item.@"0");
            allocator.free(item.@"1");
        }
        allocator.free(merged);
    }

    const docs = try renderDocs(allocator, merged);
    defer allocator.free(docs);

    const result = try std.fmt.allocPrint(allocator, "{s}\n{s}", .{ usage, docs });
    return result;
}
