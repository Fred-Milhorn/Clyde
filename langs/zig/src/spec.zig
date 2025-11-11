//! Clide specification data structures

const std = @import("std");

pub const Type = enum {
    int,
    bool,
    str,
    path,

    pub fn fromStr(s: []const u8) !Type {
        if (std.mem.eql(u8, s, "INT")) return .int;
        if (std.mem.eql(u8, s, "BOOL")) return .bool;
        if (std.mem.eql(u8, s, "STR")) return .str;
        if (std.mem.eql(u8, s, "PATH")) return .path;
        return error.UnknownType;
    }

    pub fn toString(self: Type) []const u8 {
        return switch (self) {
            .int => "INT",
            .bool => "BOOL",
            .str => "STR",
            .path => "PATH",
        };
    }
};

pub const Atom = union(enum) {
    lit: []const u8,
    opt_bool: OptBool,
    opt_val: OptVal,
    pos: Pos,

    pub const OptBool = struct {
        long: ?[]const u8,
        short: ?[]const u8,
    };

    pub const OptVal = struct {
        long: ?[]const u8,
        short: ?[]const u8,
        ty: Type,
        default: ?[]const u8,
        allow_repeat: bool,
    };

    pub const Pos = struct {
        name: []const u8,
        ty: Type,
        default: ?[]const u8,
    };
};

pub const Group = union(enum) {
    single: Atom,
    alt: []const Atom,

    pub fn atoms(self: *const Group, allocator: std.mem.Allocator) ![]const Atom {
        switch (self.*) {
            .single => |a| {
                const result = try allocator.alloc(Atom, 1);
                result[0] = a;
                return result;
            },
            .alt => |atoms| return atoms,
        }
    }
};

pub const Item = union(enum) {
    required: Group,
    optional: Group,
};

pub const Command = struct {
    name: []const u8,
    items: []const Item,
};

pub const Spec = struct {
    prog: []const u8,
    commands: []const Command,
};
