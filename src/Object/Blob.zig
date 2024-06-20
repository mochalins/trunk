//! This module represents a Git Blob (Binary Large OBject) Object.
const Blob = @This();

const std = @import("std");

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

pub fn parse(allocator: std.mem.Allocator, str: []const u8) !Blob {
    const result: Blob = .{
        .allocator = allocator,
        .data = try allocator.alloc(u8, str.len),
    };
    @memcpy(result.data, str);
    return result;
}

/// Write to provided writer, returning number of bytes written if
/// successful.
pub fn write(self: Blob, writer: std.io.AnyWriter) !usize {
    try writer.writeAll(self.data);
    return self.data.len;
}
