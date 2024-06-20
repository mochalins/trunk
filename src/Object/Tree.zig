//! This module represents a Git Tree Object.
const Tree = @This();

const std = @import("std");

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
