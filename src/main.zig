//! This module represents the entry point for the `trunk` CLI application.

const std = @import("std");
const args = @import("args");
const trunk = @import("trunk");

const Options = struct {};
const Commands = union(enum) {
    init: void,
    @"cat-file": void,
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
        }
    }

    return 0;
}

test {}
