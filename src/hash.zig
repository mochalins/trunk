//! This module contains helpful functions and definitions for hashing.

const std = @import("std");

pub const Sha1 = struct {
    value: [std.crypto.hash.Sha1.digest_length]u8,

    pub const value_length = std.crypto.hash.Sha1.digest_length;
    pub const hex_length = std.crypto.hash.Sha1.digest_length * 2;

    pub const zero: Sha1 = .{
        .value = .{0} ** value_length,
    };

    pub fn hash(contents: []const u8) Sha1 {
        var result: Sha1 = .{
            .value = .{0} ** std.crypto.hash.Sha1.digest_length,
        };
        std.crypto.hash.Sha1.hash(contents, &result.value, .{});
        return result;
    }

    pub fn parseHex(hex_str: []const u8) ParseError!Sha1 {
        if (hex_str.len != std.crypto.hash.Sha1.digest_length * 2) {
            return ParseError.InvalidHashLength;
        }
        var result: Sha1 = .{
            .value = .{0} ** std.crypto.hash.Sha1.digest_length,
        };

        for (0..std.crypto.hash.Sha1.digest_length) |i| {
            result.value[i] = std.fmt.parseInt(
                u8,
                hex_str[i * 2 .. i * 2 + 2],
                16,
            ) catch |e| switch (e) {
                error.InvalidCharacter => return ParseError.InvalidCharacter,
                // Unreachable as 2-character hex string cannot overflow u8.
                error.Overflow => unreachable,
            };
        }

        return result;
    }

    pub fn formatHexWriter(
        self: Sha1,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        const formatter = std.fmt.fmtSliceHexLower(&self.value);
        try formatter.format("{}", .{}, writer);
    }

    pub fn formatHexBuf(self: Sha1, buf: []u8) FormatError![]const u8 {
        if (buf.len < std.crypto.hash.Sha1.digest_length * 2) {
            return FormatError.NoSpaceLeft;
        }

        const formatter = std.fmt.fmtSliceHexLower(&self.value);
        var buf_stream = std.io.fixedBufferStream(buf);
        // Cannot error as enough space in buffer guaranteed above.
        formatter.format("{}", .{}, buf_stream.writer()) catch unreachable;

        return buf[0 .. std.crypto.hash.Sha1.digest_length * 2];
    }
};

const FormatError = error{
    NoSpaceLeft,
};
const ParseError = error{
    InvalidCharacter,
    InvalidHashLength,
};
