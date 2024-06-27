//! This module represents a Git Tree Object.
const Tree = @This();

const std = @import("std");
const h = @import("../hash.zig");

allocator: std.mem.Allocator,
entries: []Entry,

pub const Entry = struct {
    /// POSIX file mode.
    mode: FileMode,
    /// Path of entry, with trailing separators stripped.
    path: []const u8,
    /// Hash of entry.
    hash: h.Sha1,

    pub const FileMode = struct {
        kind: Kind,
        permissions: u32,
        pub const Kind = enum(u16) {
            file = 0o10,
            directory = 0o04,
        };

        pub fn parse(str: []const u8) !@This() {
            if (str.len > 6 or str.len < 5) {
                return error.InvalidFileMode;
            }
            var result: @This() = .{
                .kind = undefined,
                .permissions = 0,
            };

            const kind_len = str.len - 4;

            result.kind = @enumFromInt(
                try std.fmt.parseInt(u16, str[0..kind_len], 8),
            );
            result.permissions = try std.fmt.parseInt(u32, str[kind_len..], 8);

            return result;
        }
    };

    pub fn less(_: void, a: @This(), b: @This()) bool {
        const a_len: usize = a.path.len +
            @as(usize, if (a.mode.kind == .directory) 1 else 0);
        const b_len: usize = a.path.len +
            @as(usize, if (b.mode.kind == .directory) 1 else 0);

        for (0..@min(a_len, b_len)) |i| {
            const a_byte: u8 = if (i < a.path.len) a.path[i] else '/';
            const b_byte: u8 = if (i < b.path.len) b.path[i] else '/';
            if (a_byte < b_byte) {
                return true;
            } else if (b_byte > a_byte) {
                return false;
            }
        }

        return a_len < b_len;
    }
};

pub fn deinit(self: Tree) void {
    if (self.entries.len > 0) {
        for (self.entries) |entry| {
            if (entry.path.len > 0) {
                self.allocator.free(entry.path);
            }
        }
        self.allocator.free(self.entries);
    }
}

pub fn parse(allocator: std.mem.Allocator, str: []const u8) !Tree {
    var result: Tree = .{
        .allocator = allocator,
        .entries = &.{},
    };

    var it = std.mem.splitScalar(u8, str, '\n');

    // Determine number of entries to allocate.
    var num_entries: usize = 0;
    while (it.next()) |line| {
        if (line.len > 0) {
            num_entries += 1;
        }
    }
    it.reset();

    result.entries = try allocator.alloc(Entry, num_entries);
    errdefer allocator.free(result.entries);

    // Parse entries.
    var current_entry: usize = 0;
    while (it.next()) |line| {
        if (line.len == 0) continue;
        var mode_split = std.mem.splitScalar(u8, line, ' ');
        result.entries[current_entry].mode =
            try Entry.FileMode.parse(mode_split.first());

        const rem_line = mode_split.rest();
        var path_split = std.mem.splitScalar(u8, rem_line, 0);

        result.entries[current_entry].path = path_split.first();
        result.entries[current_entry].hash =
            try h.Sha1.parseHex(path_split.rest());

        current_entry += 1;
    }

    return result;
}

/// Write to provided writer, returning number of bytes written if
/// successful.
pub fn write(self: Tree, writer: std.io.AnyWriter) !usize {
    _ = self;
    _ = writer;
    return 0;
}
