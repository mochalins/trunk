const Configuration = @This();

const std = @import("std");

core: struct {
    repository_format_version: u1 = 0,
    filemode: bool = false,
    bare: bool = false,
} = .{},

pub fn init() Configuration {
    return .{};
}

pub fn parse(str: []const u8) !Configuration {
    _ = str;
    return .{};
}

pub fn parseFile(f: std.fs.File) !Configuration {
    _ = f;
    return .{};
}

pub fn write(self: Configuration, buf: []u8) ![]u8 {
    const core = try std.fmt.bufPrint(
        buf,
        "[core]\nrepositoryformatversion = {d}\nfilemode = {}\nbare = {}\n",
        .{
            self.core.repository_format_version,
            self.core.filemode,
            self.core.bare,
        },
    );
    return core;
}

test "Configuration.write" {
    var conf: Configuration = Configuration.init();
    var buf: [1024]u8 = undefined;
    const result = try conf.write(&buf);

    try std.testing.expectEqualSlices(
        u8,
        "[core]\nrepositoryformatversion = 0\nfilemode = false\nbare = false\n",
        result,
    );
}

pub fn writeFile(self: Configuration, file: std.fs.File) !void {
    try std.fmt.format(
        file.writer(),
        "[core]\nrepositoryformatversion = {d}\nfilemode = {}\nbare = {}\n",
        .{
            self.core.repository_format_version,
            self.core.filemode,
            self.core.bare,
        },
    );
}
