// SPDX-FileCopyrightText: 2026 SyoBoN <syobon@syobon.net>
//
// SPDX-License-Identifier: UPL-1.0

const std = @import("std");
const builtin = @import("builtin");

const platform = switch (builtin.os.tag) {
    .windows => @import("windows.zig"),
    .macos => @import("macos.zig"),
    else => @compileError("Target must be Windows or macOS"),
};

pub const request = platform.request;
pub const load = platform.load;
pub const unload = platform.unload;

test {
    std.testing.refAllDecls(@This());
}
