const Configuration = @This();

const std = @import("std");
const builtin = @import("builtin");

core: ?struct {
    repositoryformatversion: ?u1 = null,
    filemode: ?bool = null,
    bare: ?bool = null,
    logallrefupdates: ?bool = null,
    ignorecase: ?bool = null,
    precomposeunicode: ?bool = null,
} = null,

pub const default: Configuration = .{
    .core = .{
        .repositoryformatversion = 0,
        .filemode = true,
        .bare = false,
        .logallrefupdates = true,
        .ignorecase = if (builtin.os.tag.isDarwin() or
            builtin.os.tag == .windows) true else null,
        .precomposeunicode = if (builtin.os.tag.isDarwin()) true else null,
    },
};

pub fn read(reader: std.io.AnyReader) !Configuration {
    // TODO
    _ = reader;
    return .{};
}

pub fn write(self: Configuration, writer: std.io.AnyWriter) !usize {
    var written_bytes: usize = 0;
    inline for (@typeInfo(Configuration).Struct.fields) |section| {
        const section_value = @field(self, section.name);
        if (section_value != null) {
            try writer.print("[{s}]\n", .{section.name});
            written_bytes += section.name.len + 3;

            const _section_type = @typeInfo(section.type);
            const section_type = @typeInfo(_section_type.Optional.child);

            inline for (section_type.Struct.fields) |field| {
                const field_value = @field(section_value.?, field.name);
                if (field_value != null) {
                    try writer.print(
                        "\t{s} = {?}\n",
                        .{ field.name, field_value },
                    );
                    written_bytes += std.fmt.count(
                        "\t{s} = {?}\n",
                        .{ field.name, field_value },
                    );
                }
            }
        }
    }
    return written_bytes;
}

test "Configuration.write" {
    var conf: Configuration = default;
    var buf: [1024]u8 = undefined;
    var buffer_writer = std.io.fixedBufferStream(&buf);
    const result = buf[0..try conf.write(buffer_writer.writer().any())];

    try std.testing.expectEqualSlices(
        u8,
        "[core]\n" ++
            "\trepositoryformatversion = 0\n" ++
            "\tfilemode = true\n" ++
            "\tbare = false\n" ++
            "\tlogallrefupdates = true\n",
        result,
    );
}
