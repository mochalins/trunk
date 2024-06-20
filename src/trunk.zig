//! A Zig implementation of the Git core methods.

const std = @import("std");

pub const Repository = @import("Repository.zig");
pub const Configuration = @import("Configuration.zig");
pub const Object = @import("Object.zig");

pub const hash = @import("hash.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
