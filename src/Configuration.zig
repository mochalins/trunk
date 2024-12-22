const Configuration = @This();

const std = @import("std");
const builtin = @import("builtin");

core: struct {
    repositoryformatversion: ?u1 = null,
    filemode: ?bool = null,
    bare: ?bool = null,
    logallrefupdates: ?bool = null,
    ignorecase: ?bool = null,
    precomposeunicode: ?bool = null,
} = .{},

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

pub fn parse(str: []const u8) !Configuration {
    // TODO
    _ = str;
    return .{};
}

pub fn read(reader: std.io.AnyReader) !Configuration {
    // TODO
    _ = reader;
    return .{};
}

/// Write the configuration as an INI to the provided writer. Return the number
/// of bytes written if successful.
pub fn write(self: Configuration, writer: std.io.AnyWriter) !usize {
    var written_bytes: usize = 0;
    inline for (@typeInfo(Configuration).@"struct".fields) |section| {
        const section_value = @field(self, section.name);
        switch (@typeInfo(section.type)) {
            .optional => |o| {
                switch (@typeInfo(o.child)) {
                    .Struct => |s| {
                        if (section_value) |section_val| {
                            try writer.print("[{s}]\n", .{section.name});
                            written_bytes += section.name.len + 3;

                            inline for (s.fields) |field| {
                                const field_value =
                                    @field(section_val, field.name);
                                if (field_value != null) {
                                    try writer.print(
                                        "\t{s} = {?}\n",
                                        .{ field.name, field_value },
                                    );
                                    written_bytes += @intCast(std.fmt.count(
                                        "\t{s} = {?}\n",
                                        .{ field.name, field_value },
                                    ));
                                }
                            }
                        }
                    },
                    else => {
                        @compileError("Invalid section type in Configuration");
                    },
                }
            },
            .@"struct" => |s| {
                try writer.print("[{s}]\n", .{section.name});
                written_bytes += section.name.len + 3;

                inline for (s.fields) |field| {
                    const field_value = @field(section_value, field.name);
                    if (field_value != null) {
                        try writer.print(
                            "\t{s} = {?}\n",
                            .{ field.name, field_value },
                        );
                        written_bytes += @intCast(std.fmt.count(
                            "\t{s} = {?}\n",
                            .{ field.name, field_value },
                        ));
                    }
                }
            },
            else => {
                @compileError("Invalid section type in Configuration");
            },
        }
    }
    return written_bytes;
}
