const std = @import("std");
const args = @import("args");

const Repository = @import("Repository.zig");

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
                    var repo =
                        try Repository.create(options.positionals[0], null);
                    repo.deinit();
                } else {
                    var repo = try Repository.create(".", null);
                    repo.deinit();
                }
            },
        }
    }

    return 0;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
