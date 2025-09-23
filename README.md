<!--
SPDX-FileCopyrightText: 2025 SyoBoN <syobon@syobon.net>

SPDX-License-Identifier: CC-BY-4.0
-->

# ukadll_zig

Zigで伺か用のDLLを作成する際、ZigとCとの橋渡しを楽にするパッケージ

## 使用例

```zig
const std = @import("std");
const ukadll = @import("ukadll");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

export const loadu = ukadll.load(_loadu);
export const load = ukadll.load(_load);
export const unload = ukadll.unload(_unload);
export const request = ukadll.request(_request, allocator);

fn _loadu(_: []const u8) !void {
    // リソースの読み込み等 (UTF-8版)
}

fn _load(_: []const u8) !void {
    // リソースの読み込み等 (CP932版)
}

fn _unload() void {
    // リソースの解放等
    _ = gpa.deinit();
}

fn _request(_: []const u8, _: std.mem.Allocator) [:0]const u8 {
    // リクエストの処理
    return "SHIORI/3.0 204 No Content\r\n\r\n";
}
```
