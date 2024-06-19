const Repository = @This();

const std = @import("std");
const Configuration = @import("Configuration.zig");

worktree: std.fs.Dir,
git: std.fs.Dir,
config: Configuration,

pub fn init(worktree: []const u8, git: ?[]const u8) !Repository {
    var result: Repository = .{
        .worktree = try std.fs.cwd().openDir(worktree, .{
            .iterate = true,
        }),
        .git = undefined,
        .config = undefined,
    };
    errdefer result.worktree.close();

    if (git) |path| {
        result.git = try std.fs.cwd().openDir(path, .{});
    } else {
        result.git = try result.worktree.openDir(".git", .{});
    }
    errdefer result.git.close();

    const config_file = try result.git.openFile("config", .{});
    defer config_file.close();

    result.config = try Configuration.parseFile(config_file);
    return result;
}

pub fn create(worktree: []const u8, git: ?[]const u8) !Repository {
    var result: Repository = .{
        .worktree = try std.fs.cwd().makeOpenPath(worktree, .{
            .iterate = true,
        }),
        .git = undefined,
        .config = Configuration.init(),
    };
    errdefer result.worktree.close();

    var worktree_it = result.worktree.iterate();
    if (try worktree_it.next()) |_| {
        return error.DirectoryNotEmpty;
    }

    if (git) |path| {
        result.git = try std.fs.cwd().makeOpenPath(path, .{});
    } else {
        try result.worktree.makeDir(".git");
        result.git = try result.worktree.openDir(".git", .{});
    }
    errdefer result.git.close();

    try result.git.makeDir("branches");
    try result.git.makeDir("objects");
    try result.git.makeDir("refs");
    var refs = try result.git.openDir("refs", .{});
    defer refs.close();
    try refs.makeDir("tags");
    try refs.makeDir("heads");

    const description = try result.git.createFile("description", .{});
    defer description.close();
    try description.writeAll(
        "Unnamed repository; edit this file 'description' to name the repository.\n",
    );

    const HEAD = try result.git.createFile("HEAD", .{});
    defer HEAD.close();
    try HEAD.writeAll("ref: refs/heads/master\n");

    const config_file = try result.git.createFile("config", .{});
    defer config_file.close();
    try result.config.writeFile(config_file);

    return result;
}

pub fn deinit(self: *Repository) void {
    self.worktree.close();
    self.git.close();
}
