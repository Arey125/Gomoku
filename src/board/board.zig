const std = @import("std");

const Response = std.http.Server.Response;

var allocator: std.mem.Allocator = undefined;

var map = [_][10]u8{[_]u8{' '} ** 10} ** 10;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn handler(res: *Response) !void {
    for (map, 0..) |line, row| {
        for (line, 0..) |cell, col| {
            res.writer().print(@embedFile("./cell.html"), .{ cell, col, row }) catch unreachable;
        }
    }
}
