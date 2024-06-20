//! This module represents the entry point for the `trunk` CLI application.

const builtin = @import("builtin");
const std = @import("std");
const args = @import("args");
const trunk = @import("trunk");

const newline = if (builtin.os.tag == .windows) "\r\n" else "\n";

const Options = struct {};
const Commands = union(enum) {
    init: void,
    @"cat-file": void,
    @"hash-object": struct {
        type: trunk.Object.Kind = .blob,
        write: bool = false,

        pub const shorthands = .{
            .t = "type",
            .w = "write",
        };
    },
};

pub fn main() !u8 {
    const options = args.parseWithVerbForCurrentProcess(
        Options,
        Commands,
        std.heap.page_allocator,
        .print,
    ) catch return 1;
    defer options.deinit();

    const stdout = std.io.getStdOut().writer();

    if (options.verb) |verb| {
        switch (verb) {
            .init => {
                if (options.positionals.len > 1) {
                    // TODO
                    return 1;
                } else if (options.positionals.len == 1) {
                    var repo = try trunk.Repository.create(
                        options.positionals[0],
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
            },
            .@"cat-file" => {
                if (options.positionals.len != 2) {
                    // TODO
                    std.log.err("Requires 2 arguments", .{});
                    return 1;
                }
                var object_kind: ?trunk.Object.Kind = undefined;
                const kinds_type = @typeInfo(trunk.Object.Kind).Enum;
                inline for (kinds_type.fields) |field| {
                    if (std.mem.eql(u8, field.name, options.positionals[0])) {
                        object_kind = @enumFromInt(field.value);
                    }
                }

                if (object_kind == null) {
                    // TODO
                    std.log.err(
                        "Unknown object kind {s}",
                        .{options.positionals[0]},
                    );
                    return 1;
                }

                var repository = try trunk.Repository.find(null);
                defer repository.deinit();

                // TODO: Handle short hash, tag, etc...
                const hash = options.positionals[1];
                if (hash.len < 3) {
                    // TODO
                    std.log.err("Invalid hash length {s}", .{hash});
                    return 1;
                }
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

                if (object.payload != object_kind.?) {
                    return error.InvalidFile;
                }

                switch (object.payload) {
                    inline else => |p| _ = try p.write(stdout.any()),
                }
            },
            .@"hash-object" => |command| {
                if (options.positionals.len != 1) {
                    // TODO
                    std.log.err("Requires 1 argument", .{});
                    return 1;
                }

                var f = try std.fs.cwd().openFile(options.positionals[0], .{});
                var object: trunk.Object = undefined;

                var arena = std.heap.ArenaAllocator.init(
                    std.heap.page_allocator,
                );
                defer arena.deinit();
                const allocator = arena.allocator();

                switch (command.type) {
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

                if (command.write) {
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
                    try formatter.format("{}", .{}, stdout);
                    try stdout.print(newline, .{});
                }
            },
        }
    }

    return 0;
}

test {}
