// SPDX-FileCopyrightText: 2025 SyoBoN <syobon@syobon.net>
//
// SPDX-License-Identifier: UPL-1.0

const std = @import("std");
const builtin = @import("builtin");
const win32 = @import("zigwin32");

const GMEM_FIXED = win32.system.memory.GMEM_FIXED;
const globalAlloc = win32.system.memory.GlobalAlloc;

pub fn request(comptime f: fn ([]const u8) [:0]const u8) fn (*anyopaque, *c_long) callconv(.c) *anyopaque {
    return struct {
        fn request(h: *anyopaque, len: *c_long) callconv(.c) *anyopaque {
            const body = hglobalToString(h, len.*);
            const res = f(body);
            const res_len = res.len + 1; // .lenはsentinelを無視するので+1

            const addr: usize = @intCast(globalAlloc(GMEM_FIXED, res_len));
            const ptr: [*]u8 = @ptrFromInt(addr);
            @memcpy(ptr, res);
            ptr[res_len] = 0; // 念のため手動で0終端
            len.* = @intCast(res.len); // lenにはsentinelを含まない
            return @ptrCast(ptr);
        }
    }.request;
}

fn request_test(req: []const u8) [:0]const u8 {
    std.debug.print("Received a request: {s}\n", .{req});
    return "OK";
}
test "Check request" {
    if (comptime builtin.target.os.tag == .windows) {
        const r = request(request_test);
        const body = "GET";
        var len: c_long = @intCast(body.len);
        const res = r(@constCast(body), &len);
        const res_str = hglobalToString(res, len);
        std.debug.print("Received a response: {s}\n", .{res_str});
    } else {
        std.debug.print("Target OS is not Windows, skipping a test for `request`.\n", .{});
    }
}

pub fn load(comptime f: fn ([]const u8) anyerror!void) fn (*anyopaque, c_long) callconv(.c) c_int {
    return struct {
        fn load(h: *anyopaque, len: c_long) callconv(.c) c_int {
            const str = hglobalToString(h, len);
            f(str) catch return boolToInt(false);
            return boolToInt(true);
        }
    }.load;
}

fn load_test(v: []const u8) bool {
    std.debug.print("{s}\n", .{v});
    return true;
}
test "Check load" {
    const l = load(load_test);

    const message = "Hello, World!";
    const len: c_long = message.len;
    try std.testing.expect(l(@constCast(message), len) == 1);
}

pub fn unload(comptime f: fn () void) fn () callconv(.c) c_int {
    return struct {
        fn unload() callconv(.c) c_int {
            f();
            return boolToInt(true);
        }
    }.unload;
}

fn unload_test() void {
    std.debug.print("Goodbye, World!\n", .{});
}
test "Check unload" {
    const ul = unload(unload_test);

    try std.testing.expect(ul() == 1);
}

fn hglobalToString(h: *anyopaque, len: c_long) []const u8 {
    const z_len: usize = @intCast(len);
    const ptr: [*]const u8 = @ptrCast(h);
    return ptr[0..z_len];
}

fn boolToInt(b: bool) c_int {
    if (b) {
        return 1;
    } else {
        return 0;
    }
}
