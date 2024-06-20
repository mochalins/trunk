const std = @import("std");
const trunk = @import("trunk");

const util = @import("../util.zig");

pub fn execute(
    object_file: []const u8,
    kind: trunk.Object.Kind,
    save: bool,
) !void {
    var f = try std.fs.cwd().openFile(object_file, .{});
    var object: trunk.Object = undefined;

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();
    const allocator = arena.allocator();

    switch (kind) {
        .blob => {
            object.payload = .{ .blob = .{
                .allocator = allocator,
                .data = try f.readToEndAlloc(
                    allocator,
                    std.math.maxInt(usize),
                ),
            } };
            object.size = object.payload.blob.data.len;
        },
        else => return error.Unimplemented,
    }

    if (save) {
        var repository = try trunk.Repository.find(null);
        defer repository.deinit();
        // TODO
        return error.Unimplemented;
    } else {
        var contents = std.ArrayList(u8).init(allocator);
        _ = try object.write(contents.writer().any());
        var hash: [std.crypto.hash.Sha1.digest_length]u8 =
            undefined;
        std.crypto.hash.Sha1.hash(contents.items, &hash, .{});
        const formatter = std.fmt.fmtSliceHexLower(&hash);
        const stdout = std.io.getStdOut().writer();
        try formatter.format("{}", .{}, stdout);
        try stdout.print(util.newline, .{});
    }
}
