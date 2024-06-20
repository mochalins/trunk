//! This module represents a Git Commit Object.
const Commit = @This();

const std = @import("std");
const hash = @import("../hash.zig");

allocator: std.mem.Allocator,
tree: hash.Sha1,
parents: []hash.Sha1,
author: []u8,
committer: []u8,
gpgsig: []u8,
message: []u8,

pub fn deinit(self: Commit) void {
    if (self.parents.len > 0) self.allocator.free(self.parents);
    if (self.author.len > 0) self.allocator.free(self.author);
    if (self.committer.len > 0) self.allocator.free(self.committer);
    if (self.gpgsig.len > 0) self.allocator.free(self.gpgsig);
    if (self.message.len > 0) self.allocator.free(self.message);
}

pub fn parse(allocator: std.mem.Allocator, str: []const u8) !Commit {
    var result: Commit = .{
        .allocator = allocator,
        .tree = hash.Sha1.zero,
        .parents = &.{},
        .author = &.{},
        .committer = &.{},
        .gpgsig = &.{},
        .message = &.{},
    };

    const CommitKey = enum {
        tree,
        parent,
        author,
        committer,
        gpgsig,

        pub fn parse(tag: []const u8) !@This() {
            const cp_type_info = @typeInfo(@This()).Enum;
            inline for (cp_type_info.fields) |field| {
                if (std.mem.eql(u8, field.name, tag)) {
                    return @enumFromInt(field.value);
                }
            }

            return error.InvalidCommitKey;
        }
    };

    var lines = std.mem.splitScalar(u8, str, '\n');
    var line_start_index: usize = 0;
    var parents = std.ArrayList(hash.Sha1).init(allocator);
    defer parents.deinit();
    var current_key: ?CommitKey = null;
    var gpg_sig_start: ?usize = null;
    var gpg_sig_end: usize = 0;
    var gpg_sig_size: usize = 0;
    var message: ?[]const u8 = null;
    while (lines.next()) |line| {
        // Set index of next line. Must be set at end of current line, as the
        // next call to `lines.next()` will set the `index`.
        defer if (lines.index) |index| {
            line_start_index = index;
        };

        // Remainder of file is commit message, if next line is not a
        // continuation.
        if (line.len == 0) {
            message = lines.rest();
            if (current_key) |key| {
                if (key == .gpgsig) {
                    gpg_sig_start = line_start_index;
                }
            }
            continue;
        }

        // Line is continuation.
        if (line[0] == ' ') {
            if (message) |_| {
                message = null;
            }

            if (current_key) |key| {
                if (key != .gpgsig) {
                    return error.InvalidContinuationLine;
                }
            } else {
                return error.InvalidContinuationLine;
            }

            const stripped_line = std.mem.trimLeft(u8, line, " ");
            if (stripped_line.len == 0) {
                if (gpg_sig_start == null) {
                    gpg_sig_start = line_start_index;
                    continue;
                } else {
                    return error.InvalidContinuationLine;
                }
            }

            // GPG signature end
            if (stripped_line[0] == '-') {
                gpg_sig_end = line_start_index;
                current_key = null;
                continue;
            }

            gpg_sig_size += stripped_line.len;
        }
        // Line is a key-value.
        else {
            // Start of commit message.
            if (message) |m| {
                result.message = try allocator.alloc(u8, m.len);
                errdefer allocator.free(result.message);
                @memcpy(result.message, m);
                break;
            }

            current_key = null;
            var value: []const u8 = undefined;
            for (line, 0..) |c, i| {
                if (c == ' ') {
                    current_key = try CommitKey.parse(line[0..i]);
                    value = line[i + 1 ..];
                    break;
                }
            } else {
                return error.InvalidLine;
            }
            switch (current_key.?) {
                .tree => {
                    result.tree = try hash.Sha1.parseHex(value);
                },
                .parent => {
                    try parents.append(try hash.Sha1.parseHex(value));
                },
                .author => {
                    if (result.author.len > 0) {
                        // Ignore multiple authors rather than throwing an
                        // error to support some tools that erroneously emit
                        // multiple authors.
                        continue;
                    }
                    result.author = try allocator.alloc(u8, value.len);
                    errdefer allocator.free(result.author);
                    @memcpy(result.author, value);
                },
                .committer => {
                    if (result.committer.len > 0) {
                        return error.InvalidMultipleCommitters;
                    }
                    result.committer = try allocator.alloc(u8, value.len);
                    errdefer allocator.free(result.committer);
                    @memcpy(result.committer, value);
                },
                .gpgsig => {
                    // First line containing `gpgsig` key is just the start of
                    // signature header, can be skipped.
                    continue;
                },
            }
        }
    }

    if (parents.items.len > 0) {
        result.parents = try parents.toOwnedSlice();
    }

    if (gpg_sig_start) |start| {
        if (gpg_sig_size == 0) {
            return error.InvalidGpgSignature;
        }
        var gpg_lines = std.mem.splitScalar(u8, str[start..gpg_sig_end], '\n');
        result.gpgsig = try allocator.alloc(u8, gpg_sig_size);
        errdefer allocator.free(result.gpgsig);
        var buf_index: usize = 0;
        while (gpg_lines.next()) |line| {
            const stripped_line = std.mem.trimLeft(u8, line, " ");
            @memcpy(
                result.gpgsig[buf_index..][0..stripped_line.len],
                stripped_line,
            );
            buf_index += stripped_line.len;
        }
    }

    return result;
}

/// Write to provided writer, returning number of bytes written if
/// successful.
pub fn write(self: Commit, writer: std.io.AnyWriter) !usize {
    var write_size: usize = 0;

    // Tree should always be first field.
    try writer.writeAll("tree ");
    write_size += 5;

    try self.tree.formatHexWriter(writer);
    write_size += hash.Sha1.hex_length;

    try writer.writeAll("\n");
    write_size += 1;

    for (self.parents) |parent| {
        try writer.writeAll("parent ");
        write_size += 7;
        try parent.formatHexWriter(writer);
        write_size += hash.Sha1.hex_length;

        try writer.writeAll("\n");
        write_size += 1;
    }
    if (self.author.len > 0) {
        try writer.print("author {s}\n", .{self.author});
        write_size += 8 + self.author.len;
    }
    if (self.committer.len > 0) {
        try writer.print("committer {s}\n", .{self.committer});
        write_size += 11 + self.committer.len;
    }
    if (self.gpgsig.len > 0) {
        try writer.writeAll("gpgsig -----BEGIN PGP SIGNATURE-----\n \n");
        write_size += 39;

        var line_i: usize = 0;
        for (self.gpgsig, 0..) |c, i| {
            if (line_i == 0) {
                try writer.writeByte(' ');
                write_size += 1;
            }
            try writer.writeByte(c);
            write_size += 1;

            // Write last 5 characters on own line.
            if (i == self.gpgsig.len - 6) {
                try writer.writeByte('\n');
                line_i = 0;
                write_size += 1;
                continue;
            }

            line_i += 1;
            // Write to new line on 64th character.
            if (line_i == 64) {
                try writer.writeByte('\n');
                line_i = 0;
                write_size += 1;
            }
        }
        if (line_i != 0) {
            try writer.writeByte('\n');
            write_size += 1;
        }

        try writer.writeAll(" -----END PGP SIGNATURE-----\n");
        write_size += 29;
    }
    if (self.message.len > 0) {
        try writer.writeByte('\n');
        try writer.writeAll(self.message);
        write_size += 1 + self.message.len;
    }

    return write_size;
}

test {
    const commit_string: []const u8 =
        \\tree 29ff16c9c14e2652b22f8b78bb08a5a07930c147
        \\parent 206941306e8a8af65b66eaaaea388a7ae24d49a0
        \\author Thibault Polge <thibault@thb.lt> 1527025023 +0200
        \\committer Thibault Polge <thibault@thb.lt> 1527025044 +0200
        \\gpgsig -----BEGIN PGP SIGNATURE-----
        \\ 
        \\ iQIzBAABCAAdFiEExwXquOM8bWb4Q2zVGxM2FxoLkGQFAlsEjZQACgkQGxM2FxoL
        \\ kGQdcBAAqPP+ln4nGDd2gETXjvOpOxLzIMEw4A9gU6CzWzm+oB8mEIKyaH0UFIPh
        \\ rNUZ1j7/ZGFNeBDtT55LPdPIQw4KKlcf6kC8MPWP3qSu3xHqx12C5zyai2duFZUU
        \\ wqOt9iCFCscFQYqKs3xsHI+ncQb+PGjVZA8+jPw7nrPIkeSXQV2aZb1E68wa2YIL
        \\ 3eYgTUKz34cB6tAq9YwHnZpyPx8UJCZGkshpJmgtZ3mCbtQaO17LoihnqPn4UOMr
        \\ V75R/7FjSuPLS8NaZF4wfi52btXMSxO/u7GuoJkzJscP3p4qtwe6Rl9dc1XC8P7k
        \\ NIbGZ5Yg5cEPcfmhgXFOhQZkD0yxcJqBUcoFpnp2vu5XJl2E5I/quIyVxUXi6O6c
        \\ /obspcvace4wy8uO0bdVhc4nJ+Rla4InVSJaUaBeiHTW8kReSFYyMmDCzLjGIu1q
        \\ doU61OM3Zv1ptsLu3gUE6GU27iWYj2RWN3e3HE4Sbd89IFwLXNdSuM0ifDLZk7AQ
        \\ WBhRhipCCgZhkj9g2NEk7jRVslti1NdN5zoQLaJNqSwO1MtxTmJ15Ksk3QP6kfLB
        \\ Q52UWybBzpaP9HEd4XnR+HuQ4k2K0ns2KgNImsNvIyFwbpMUyUWLMPimaV1DWUXo
        \\ 5SBjDB/V/W2JBFR+XKHFJeFwYhj7DD/ocsGr4ZMx/lgc8rjIBkI=
        \\ =lgTX
        \\ -----END PGP SIGNATURE-----
        \\
        \\Create first draft
    ;

    const tree = try hash.Sha1.parseHex(
        "29ff16c9c14e2652b22f8b78bb08a5a07930c147",
    );
    const parents: [1]hash.Sha1 = .{try hash.Sha1.parseHex(
        "206941306e8a8af65b66eaaaea388a7ae24d49a0",
    )};
    const author = "Thibault Polge <thibault@thb.lt> 1527025023 +0200";
    const committer = "Thibault Polge <thibault@thb.lt> 1527025044 +0200";
    const gpgsig =
        "iQIzBAABCAAdFiEExwXquOM8bWb4Q2zVGxM2FxoLkGQFAlsEjZQACgkQGxM2FxoL" ++
        "kGQdcBAAqPP+ln4nGDd2gETXjvOpOxLzIMEw4A9gU6CzWzm+oB8mEIKyaH0UFIPh" ++
        "rNUZ1j7/ZGFNeBDtT55LPdPIQw4KKlcf6kC8MPWP3qSu3xHqx12C5zyai2duFZUU" ++
        "wqOt9iCFCscFQYqKs3xsHI+ncQb+PGjVZA8+jPw7nrPIkeSXQV2aZb1E68wa2YIL" ++
        "3eYgTUKz34cB6tAq9YwHnZpyPx8UJCZGkshpJmgtZ3mCbtQaO17LoihnqPn4UOMr" ++
        "V75R/7FjSuPLS8NaZF4wfi52btXMSxO/u7GuoJkzJscP3p4qtwe6Rl9dc1XC8P7k" ++
        "NIbGZ5Yg5cEPcfmhgXFOhQZkD0yxcJqBUcoFpnp2vu5XJl2E5I/quIyVxUXi6O6c" ++
        "/obspcvace4wy8uO0bdVhc4nJ+Rla4InVSJaUaBeiHTW8kReSFYyMmDCzLjGIu1q" ++
        "doU61OM3Zv1ptsLu3gUE6GU27iWYj2RWN3e3HE4Sbd89IFwLXNdSuM0ifDLZk7AQ" ++
        "WBhRhipCCgZhkj9g2NEk7jRVslti1NdN5zoQLaJNqSwO1MtxTmJ15Ksk3QP6kfLB" ++
        "Q52UWybBzpaP9HEd4XnR+HuQ4k2K0ns2KgNImsNvIyFwbpMUyUWLMPimaV1DWUXo" ++
        "5SBjDB/V/W2JBFR+XKHFJeFwYhj7DD/ocsGr4ZMx/lgc8rjIBkI=" ++
        "=lgTX";
    const message = "Create first draft";

    const parsed_commit = try Commit.parse(
        std.testing.allocator,
        commit_string,
    );
    defer parsed_commit.deinit();

    try std.testing.expectEqualSlices(
        u8,
        &tree.value,
        &parsed_commit.tree.value,
    );
    try std.testing.expectEqualSlices(u8, author, parsed_commit.author);
    try std.testing.expectEqualSlices(u8, committer, parsed_commit.committer);
    try std.testing.expectEqualSlices(u8, gpgsig, parsed_commit.gpgsig);
    try std.testing.expectEqualSlices(u8, message, parsed_commit.message);
    try std.testing.expectEqual(1, parsed_commit.parents.len);
    try std.testing.expectEqualSlices(
        u8,
        &parents[0].value,
        &parsed_commit.parents[0].value,
    );

    var commit_write: [commit_string.len]u8 = undefined;
    var bufstream = std.io.fixedBufferStream(&commit_write);
    const write_len = try parsed_commit.write(bufstream.writer().any());

    try std.testing.expectEqualSlices(
        u8,
        commit_string,
        commit_write[0..write_len],
    );
}
