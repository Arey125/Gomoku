const std = @import("std");

const Response = std.http.Server.Response;

var allocator: std.mem.Allocator = undefined;

var map = [_][10]u8{[_]u8{' '} ** 10} ** 10;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn handler(res: *Response) !void {
    if (res.request.method == .POST) {
        const body = res.reader().readAllAlloc(allocator, 8192) catch unreachable;
        defer allocator.free(body);

        const equal_sign_pos = std.mem.indexOf(u8, body, "=") orelse unreachable;
        const col = std.fmt.parseInt(usize, body[equal_sign_pos + 1 .. equal_sign_pos + 2], 10) catch unreachable;
        const row = std.fmt.parseInt(usize, body[equal_sign_pos + 5 .. equal_sign_pos + 6], 10) catch unreachable;

        map[row][col] = 'X';
    }

    for (map, 0..) |line, row| {
        for (line, 0..) |cell, col| {
            res.writer().print(@embedFile("./cell.html"), .{ cell, col, row }) catch unreachable;
        }
    }
}
