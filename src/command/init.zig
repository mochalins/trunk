const std = @import("std");
const trunk = @import("trunk");
const util = @import("../util.zig");

pub fn execute(worktree: ?[]const u8) !void {
    const worktree_path: []const u8 = if (worktree) |path| path else ".";

    var dir = std.fs.cwd().openDir(worktree_path, .{}) catch null;
    defer if (dir) |*d| d.close();
    const existing: bool = if (dir) |d| b: {
        var res: bool = true;
        d.access(".git", .{}) catch {
            res = false;
        };
        break :b res;
    } else false;

    var repo = try trunk.Repository.create(
        worktree_path,
        null,
        trunk.Configuration.default,
    );
    defer repo.deinit();

    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (existing) {
        try stdout.print(
            "Reinitialized existing Git repository in {s}/{s}",
            .{ try repo.git.realpathAlloc(allocator, "."), util.newline },
        );
    } else {
        try stdout.print(
            "Initialized empty Git repository in {s}/{s}",
            .{ try repo.git.realpathAlloc(allocator, "."), util.newline },
        );
    }
    try stdout.print("", .{});
}
