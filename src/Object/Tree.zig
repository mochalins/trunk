//! This module represents a Git Tree Object.
const Tree = @This();

const std = @import("std");
const Sha1 = @import("../hash.zig").Sha1;

allocator: std.mem.Allocator,
entries: []Entry,

pub const Entry = struct {
    /// POSIX file mode.
    mode: FileMode,
    /// Path of entry, with trailing separators stripped.
    path: []u8,
    /// Hash of entry.
    hash: Sha1,

    pub const FileMode = struct {
        kind: Kind,
        permissions: u32,
        pub const Kind = enum(u16) {
            file = 0o10,
            directory = 0o04,
        };

        pub fn write(self: @This(), writer: std.io.AnyWriter) !usize {
            switch (self.kind) {
                .file => try writer.writeAll("10"),
                .directory => try writer.writeAll("04"),
            }
            var perms_buf: [4]u8 = undefined;
            try writer.writeAll(std.fmt.bufPrintIntToSlice(
                &perms_buf,
                self.permissions,
                8,
                .lower,
                .{ .fill = '0', .width = 4 },
            ));
            return 6;
        }

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

    pub fn write(self: Entry, writer: std.io.AnyWriter) !usize {
        var out_len: usize = 0;
        out_len += try self.mode.write(writer);
        try writer.writeByte(' ');
        out_len += 1;
        try writer.writeAll(self.path);
        out_len += self.path.len;
        try writer.writeByte(0);
        out_len += 1;
        try self.hash.formatHexWriter(writer);
        out_len += Sha1.hex_length;
        try writer.writeByte('\n');
        out_len += 1;

        return out_len;
    }

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

        const path = path_split.first();
        result.entries[current_entry].path = try allocator.alloc(u8, path.len);
        @memcpy(result.entries[current_entry].path, path);

        result.entries[current_entry].hash =
            try Sha1.parseHex(path_split.rest());

        current_entry += 1;
    }

    return result;
}

/// Write to provided writer, returning number of bytes written if
/// successful.
pub fn write(self: Tree, writer: std.io.AnyWriter) !usize {
    var out_len: usize = 0;
    for (self.entries) |entry| {
        out_len += try entry.write(writer);
    }
    return out_len;
}

test {
    const test_lines =
        "103746 my_object_path\x00ae90f12eea699729ed24555e40b9fd669da12a12\n" ++
        "043436 my_other_object\x00e8bfe5af39579a7e4898bb23f3a76a72c368cee6\n";

    const parsed_tree: Tree = try Tree.parse(
        std.testing.allocator,
        test_lines,
    );
    defer parsed_tree.deinit();

    var write_tree_buf: [test_lines.len]u8 = undefined;
    var stream = std.io.fixedBufferStream(&write_tree_buf);
    const write_tree_len = try parsed_tree.write(stream.writer().any());
    try std.testing.expectEqualSlices(
        u8,
        test_lines,
        write_tree_buf[0..write_tree_len],
    );
}
