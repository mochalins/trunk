const trunk = @import("trunk");

pub fn execute(worktree: ?[]const u8) !void {
    if (worktree) |path| {
        var repo = try trunk.Repository.create(
            path,
            null,
            trunk.Configuration.default,
        );
        repo.deinit();
    } else {
        var repo = try trunk.Repository.create(
            ".",
            null,
            trunk.Configuration.default,
        );
        repo.deinit();
    }
}
