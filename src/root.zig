// SPDX-FileCopyrightText: 2025 SyoBoN <syobon@syobon.net>
//
// SPDX-License-Identifier: UPL-1.0

const std = @import("std");
const builtin = @import("builtin");
const win32 = @import("win32");

const GMEM_FIXED = win32.system.memory.GMEM_FIXED;
const globalAlloc = win32.system.memory.GlobalAlloc;
const globalFree = win32.system.memory.GlobalFree;

pub fn request(comptime f: fn ([]const u8, std.mem.Allocator) [:0]const u8, gpa: std.mem.Allocator) fn (*anyopaque, *c_long) callconv(.c) *anyopaque {
    return struct {
        fn request(h: *anyopaque, len: *c_long) callconv(.c) *anyopaque {
            defer _ = globalFree(@intCast(@intFromPtr(h)));

            var arena = std.heap.ArenaAllocator.init(gpa);
            defer arena.deinit();

            const allocator = arena.allocator();

            const body = hglobalToString(h, len.*);
            const res = f(body, allocator);
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

fn request_test(req: []const u8, _: std.mem.Allocator) [:0]const u8 {
    std.log.info("Received a request: {s}\n", .{req});
    return "OK";
}
test "Check request" {
    if (comptime builtin.target.os.tag == .windows) {
        const allocator = std.testing.allocator;

        const len = 3;
        var c_len: c_long = len;
        const addr: usize = @intCast(globalAlloc(GMEM_FIXED, len + 1));
        const ptr: [*]u8 = @ptrFromInt(addr);
        @memcpy(ptr, "GET");
        ptr[len + 1] = 0;

        const r = request(request_test, allocator);
        const res = r(ptr, &c_len);
        const res_str = hglobalToString(res, 2);
        std.log.info("Received a response: {s}\n", .{res_str});
    } else {
        std.log.warn("Target OS is not Windows, skipping a test for `request`.\n", .{});
    }
}

pub fn load(comptime f: fn ([]const u8) anyerror!void) fn (*anyopaque, c_long) callconv(.c) c_int {
    return struct {
        fn load(h: *anyopaque, len: c_long) callconv(.c) c_int {
            defer _ = globalFree(@intCast(@intFromPtr(h)));

            const str = hglobalToString(h, len);
            f(str) catch return boolToInt(false);
            return boolToInt(true);
        }
    }.load;
}

fn load_test(v: []const u8) !void {
    std.log.info("{s}\n", .{v});
}
test "Check load" {
    if (comptime builtin.target.os.tag == .windows) {
        const l = load(load_test);

        const len = 13;
        const addr: usize = @intCast(globalAlloc(GMEM_FIXED, len + 1));
        const ptr: [*]u8 = @ptrFromInt(addr);
        @memcpy(ptr, "Hello, World!");
        ptr[len + 1] = 0;

        try std.testing.expect(l(ptr, len) == 1);
    } else {
        std.log.warn("Target OS is not Windows, skipping a test for `load`.\n", .{});
    }
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
    std.log.info("Goodbye, World!\n", .{});
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
