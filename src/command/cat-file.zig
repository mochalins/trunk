const std = @import("std");
const trunk = @import("trunk");

// TODO: Handle short hash, tag, etc...
pub fn execute(object_kind: trunk.Object.Kind, hash: *const [40]u8) !void {
    var repository = try trunk.Repository.find(null);
    defer repository.deinit();
    var objects_dir = try repository.git.openDir("objects", .{});
    defer objects_dir.close();
    var object_dir = try objects_dir.openDir(hash[0..2], .{});
    defer object_dir.close();
    var object_file = try object_dir.openFile(hash[2..], .{});
    defer object_file.close();

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();
    const allocator = arena.allocator();

    var contents = std.ArrayList(u8).init(allocator);
    try std.compress.zlib.decompress(
        object_file.reader(),
        contents.writer(),
    );

    var object = try trunk.Object.parse(allocator, contents.items);
    defer object.deinit();

    if (object.payload != object_kind) {
        return error.InvalidFile;
    }

    const stdout = std.io.getStdOut().writer();
    switch (object.payload) {
        inline else => |p| _ = try p.write(stdout.any()),
    }
}
