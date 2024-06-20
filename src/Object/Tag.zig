//! This module represents a Git Tag Object.
const Tag = @This();

const std = @import("std");

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
