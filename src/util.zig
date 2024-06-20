const builtin = @import("builtin");

pub const newline = if (builtin.os.tag == .windows) "\r\n" else "\n";
