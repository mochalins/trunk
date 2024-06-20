//! This module represents the entry point for the `trunk` CLI application.

const std = @import("std");
const args = @import("args");
const trunk = @import("trunk");

const command = @import("command.zig");

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

    if (options.verb) |verb| {
        switch (verb) {
            .init => {
                if (options.positionals.len > 1) {
                    // TODO
                    return 1;
                } else if (options.positionals.len == 1) {
                    try command.init.execute(options.positionals[0]);
                } else {
                    try command.init.execute(null);
                }
            },
            .@"cat-file" => {
                if (options.positionals.len != 2) {
                    // TODO
                    std.log.err("Requires 2 arguments", .{});
                    return 1;
                }

                const object_kind = trunk.Object.Kind.parse(
                    options.positionals[0],
                ) catch {
                    // TODO
                    std.log.err(
                        "Unknown object kind {s}",
                        .{options.positionals[0]},
                    );
                    return 1;
                };

                // TODO: Handle short hash, tag, etc...
                const hash = options.positionals[1];
                if (hash.len != 40) {
                    // TODO
                    std.log.err("Invalid hash length {s}", .{hash});
                    return 1;
                }

                try command.@"cat-file".execute(object_kind, @ptrCast(hash));
            },
            .@"hash-object" => |ho| {
                if (options.positionals.len != 1) {
                    // TODO
                    std.log.err("Requires 1 argument", .{});
                    return 1;
                }

                try command.@"hash-object".execute(
                    options.positionals[0],
                    ho.type,
                    ho.write,
                );
            },
        }
    }

    return 0;
}

test {}
