//! This module represents a Git Object.
const Object = @This();

const std = @import("std");

size: usize,
payload: Payload,

pub fn parse(allocator: std.mem.Allocator, str: []const u8) !Object {
    var result: Object = undefined;
    var current_str = str;

    const kind_type = @typeInfo(Kind).Enum;
    var kind: Kind = undefined;
    for (str[0..7], 0..) |c, i| {
        if (c == ' ') {
            inline for (kind_type.fields) |field| {
                if (std.mem.eql(u8, field.name, str[0..i])) {
                    kind = @enumFromInt(field.value);
                }
            }
            current_str = str[i + 1 ..];
            break;
        }
    } else {
        return error.InvalidHeader;
    }

    for (current_str[0..20], 0..) |c, i| {
        if (c == '\x00') {
            result.size = try std.fmt.parseInt(usize, current_str[0..i], 10);
            current_str = current_str[i + 1 ..];
            break;
        }
    } else {
        return error.InvalidHeader;
    }

    if (result.size != current_str.len) {
        return error.InvalidContentLength;
    }

    switch (kind) {
        .blob => {
            result.payload = .{ .blob = .{
                .allocator = allocator,
                .data = try allocator.alloc(u8, result.size),
            } };
            @memcpy(result.payload.blob.data, current_str);
        },
        .commit => return error.Unimplemented,
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
};

pub const Payload = union(Kind) {
    blob: Blob,
    commit: Commit,
    tag: Tag,
    tree: Tree,
};

pub const Blob = struct {
    allocator: std.mem.Allocator,
    data: []u8,

    pub fn init(allocator: std.mem.Allocator) Blob {
        return .{
            .allocator = allocator,
            .data = &.{},
        };
    }

    pub fn deinit(self: Blob) void {
        self.allocator.free(self.data);
    }

    /// Write to provided writer, returning number of bytes written if
    /// successful.
    pub fn write(self: Blob, writer: std.io.AnyWriter) !usize {
        try writer.writeAll(self.data);
        return self.data.len;
    }
};

pub const Commit = struct {
    pub fn deinit(self: Commit) void {
        _ = self;
    }

    /// Write to provided writer, returning number of bytes written if
    /// successful.
    pub fn write(self: Commit, writer: std.io.AnyWriter) !usize {
        _ = self;
        _ = writer;
        return 0;
    }
};

pub const Tag = struct {
    pub fn deinit(self: Tag) void {
        _ = self;
    }

    /// Write to provided writer, returning number of bytes written if
    /// successful.
    pub fn write(self: Tag, writer: std.io.AnyWriter) !usize {
        _ = self;
        _ = writer;
        return 0;
    }
};

pub const Tree = struct {
    pub fn deinit(self: Tree) void {
        _ = self;
    }

    /// Write to provided writer, returning number of bytes written if
    /// successful.
    pub fn write(self: Tree, writer: std.io.AnyWriter) !usize {
        _ = self;
        _ = writer;
        return 0;
    }
};
