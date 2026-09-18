// SPDX-FileCopyrightText: 2026 SyoBoN <syobon@syobon.net>
//
// SPDX-License-Identifier: UPL-1.0

const std = @import("std");
const builtin = @import("builtin");

pub fn request(gpa: std.mem.Allocator, comptime f: fn (std.mem.Allocator, []const u8) [:0]const u8) fn (*anyopaque, *i32) callconv(.c) ?*anyopaque {
    return struct {
        fn request(h: *anyopaque, len: *i32) callconv(.c) ?*anyopaque {
            defer std.c.free(h);

            var arena = std.heap.ArenaAllocator.init(gpa);
            defer arena.deinit();

            const allocator = arena.allocator();

            const body = voidToString(h, len.*);
            const res = f(allocator, body);

            const maybe_ptr = std.c.malloc(res.len + 1); // sentinel込み
            if (maybe_ptr) |ptr| {
                const p: [*]u8 = @ptrCast(ptr);
                @memcpy(p, res);
                p[res.len] = 0; // 念のため手動で0終端
                len.* = @intCast(res.len);
            }
            return maybe_ptr;
        }
    }.request;
}

fn request_test(_: std.mem.Allocator, req: []const u8) [:0]const u8 {
    std.log.info("Received a request: {s}\n", .{req});
    return "OK";
}
test "Check request" {
    const allocator = std.testing.allocator;

    const len = 3;
    var c_len: i32 = @intCast(len);
    const ptr = std.c.malloc(len + 1).?;
    const p: [*]u8 = @ptrCast(ptr);
    @memcpy(p, "GET");
    p[len] = 0;

    const r = request(allocator, request_test);
    const res = r(ptr, &c_len).?;
    defer std.c.free(res);

    const res_str = voidToString(res, 2);
    std.log.info("Received a response: {s}\n", .{res_str});

    try std.testing.expectEqual(res_str.len, @as(usize, @intCast(c_len)));
}

pub fn load(comptime f: fn ([]const u8) anyerror!void) fn (*anyopaque, i32) callconv(.c) i32 {
    return struct {
        fn load(h: *anyopaque, len: i32) callconv(.c) i32 {
            defer std.c.free(h);

            const str = voidToString(h, len);
            f(str) catch return boolToInt(false);
            return boolToInt(true);
        }
    }.load;
}

fn load_test(v: []const u8) !void {
    std.log.info("{s}\n", .{v});
}
test "Check load" {
    const len = 13;
    const c_len: i32 = @intCast(len);
    const ptr = std.c.malloc(len + 1).?;
    const p: [*]u8 = @ptrCast(ptr);
    @memcpy(p, "Hello, World!");
    p[len] = 0;

    const l = load(load_test);
    try std.testing.expect(l(ptr, c_len) == 1);
}

pub fn unload(comptime f: fn () void) fn () callconv(.c) i32 {
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

fn voidToString(h: *anyopaque, len: i32) []const u8 {
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
