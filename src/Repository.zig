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

    result.config = try Configuration.read(config_file.reader().any());
    return result;
}

pub fn create(
    worktree: []const u8,
    git: ?[]const u8,
    config: Configuration,
) !Repository {
    var result: Repository = .{
        .worktree = try std.fs.cwd().makeOpenPath(worktree, .{}),
        .git = undefined,
        .config = config,
    };
    errdefer result.worktree.close();

    result.git = try std.fs.cwd().makeOpenPath(
        if (git) |path| path else ".git",
        .{},
    );
    errdefer result.git.close();

    result.git.makeDir("branches") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    result.git.makeDir("objects") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    var refs = try result.git.makeOpenPath("refs", .{});
    defer refs.close();
    refs.makeDir("tags") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };
    refs.makeDir("heads") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    const description = try result.git.createFile("description", .{});
    defer description.close();
    try description.writeAll(
        "Unnamed repository; " ++
            "edit this file 'description' to name the repository.\n",
    );

    const HEAD = try result.git.createFile("HEAD", .{});
    defer HEAD.close();
    try HEAD.writeAll("ref: refs/heads/master\n");

    const config_file = try result.git.createFile("config", .{});
    defer config_file.close();
    _ = try result.config.write(config_file.writer().any());

    return result;
}

/// Traverse upwards from the provided path to detect the closest `.git`
/// directory from which to recognize a `Repository`.
pub fn find(path: ?[]const u8) !Repository {
    var cwd: std.fs.Dir = if (path) |p|
        try std.fs.cwd().openDir(p, .{})
    else
        try std.fs.cwd().openDir(".", .{});
    errdefer cwd.close();

    var result: Repository = .{
        .worktree = undefined,
        .git = undefined,
        .config = undefined,
    };

    while (true) {
        const git_dir: ?std.fs.Dir = cwd.openDir(".git", .{}) catch null;
        if (git_dir) |dir| {
            result.worktree = cwd;
            result.git = dir;
            break;
        } else {
            const new_cwd = try cwd.openDir("..", .{});
            if (new_cwd.fd == cwd.fd) {
                return error.NoRepositoryFound;
            }
            cwd.close();
            cwd = new_cwd;
        }
    }
    errdefer {
        result.worktree.close();
        result.git.close();
    }

    const config_file = try result.git.openFile("config", .{});
    defer config_file.close();

    result.config = try Configuration.read(config_file.reader().any());

    return result;
}

pub fn deinit(self: *Repository) void {
    self.worktree.close();
    self.git.close();
}
