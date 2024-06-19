//! This module represents the entry point for the `trunk` CLI application.

const std = @import("std");
const args = @import("args");
const trunk = @import("trunk");

const command = @import("command.zig");

const Options = struct {};
const Commands = union(enum) {
    init: void,
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
        }
    }

    return 0;
}

test {
    std.testing.refAllDeclsRecursive(command);
}
