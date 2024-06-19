const std = @import("std");

const Repository = @import("Repository.zig");
const Configuration = @import("Configuration.zig");

test {
    std.testing.refAllDecls(Repository);
    std.testing.refAllDecls(Configuration);
}
