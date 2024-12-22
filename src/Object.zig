//! This module represents a Git Object.
const Object = @This();

const std = @import("std");

size: usize,
payload: Payload,

pub fn parse(allocator: std.mem.Allocator, str: []const u8) !Object {
    var result: Object = undefined;
    var current_str = str;

    var kind: Kind = undefined;
    for (str, 0..) |c, i| {
        if (c == ' ') {
            kind = try Kind.parse(str[0..i]);
            current_str = str[i + 1 ..];
            break;
        } else if (i >= 7) {
            return error.InvalidHeader;
        }
    } else {
        return error.InvalidHeader;
    }

    for (current_str, 0..) |c, i| {
        if (c == '\x00') {
            result.size = try std.fmt.parseInt(usize, current_str[0..i], 10);
            current_str = current_str[i + 1 ..];
            break;
        } else if (i >= 20) {
            return error.InvalidHeader;
        }
    } else {
        return error.InvalidHeader;
    }

    if (result.size != current_str.len) {
        return error.InvalidContentLength;
    }

    switch (kind) {
        .blob => result.payload = .{
            .blob = try Blob.parse(allocator, current_str),
        },
        .commit => result.payload = .{
            .commit = try Commit.parse(allocator, current_str),
        },
        .tag => return error.Unimplemented,
        .tree => return error.Unimplemented,
    }

    return result;
}

/// Write to provided writer, returning number of bytes written if successful.
pub fn write(self: Object, writer: std.io.AnyWriter) !usize {
    var bytes_written: usize = 0;

    const object_type_str = @tagName(self.payload);
    try writer.writeAll(object_type_str);
    bytes_written += object_type_str.len;

    try writer.print(" {d}\x00", .{self.size});
    bytes_written += @intCast(std.fmt.count(" {d}\x00", .{self.size}));

    switch (self.payload) {
        inline else => |p| {
            const payload_bytes = try p.write(writer);
            std.debug.assert(payload_bytes == self.size);
            bytes_written += payload_bytes;
        },
    }

    return bytes_written;
}

pub fn deinit(self: Object) void {
    switch (self.payload) {
        inline else => |p| p.deinit(),
    }
}

pub const Kind = enum {
    blob,
    commit,
    tag,
    tree,

    pub fn parse(tag: []const u8) !@This() {
        const kind_type = @typeInfo(@This()).@"enum";
        inline for (kind_type.fields) |field| {
            if (std.mem.eql(u8, field.name, tag)) {
                return @enumFromInt(field.value);
            }
        }
        return error.InvalidObjectKind;
    }
};

pub const Payload = union(Kind) {
    blob: Blob,
    commit: Commit,
    tag: Tag,
    tree: Tree,
};
pub const Blob = @import("Object/Blob.zig");
pub const Commit = @import("Object/Commit.zig");
pub const Tag = @import("Object/Tag.zig");
pub const Tree = @import("Object/Tree.zig");
