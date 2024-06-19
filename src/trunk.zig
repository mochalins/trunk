//! A Zig implementation of the Git core methods.

const std = @import("std");

pub const Repository = @import("Repository.zig");
pub const Configuration = @import("Configuration.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
