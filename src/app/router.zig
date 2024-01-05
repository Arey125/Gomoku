const std = @import("std");

const board = @import("../board/board.zig");

const Response = std.http.Server.Response;
const WriteError = std.http.Server.Response.WriteError;

const ComptimeStringMap = std.ComptimeStringMap;

const RequestHandler = *const fn (*Response) WriteError!void;

var allocator: std.mem.Allocator = undefined;

fn rootHandler(res: *Response) WriteError!void {
    var indexFile = std.fs.cwd().openFile("./public/index.html", .{}) catch unreachable;
    defer indexFile.close();

    const buf = indexFile.readToEndAlloc(allocator, 8096) catch unreachable;
    try res.writeAll(buf);
}

fn styleHandler(res: *Response) WriteError!void {
    var indexFile = std.fs.cwd().openFile("./public/style.css", .{}) catch unreachable;
    defer indexFile.close();
    const buf = indexFile.readToEndAlloc(allocator, 8096) catch unreachable;
    try res.writeAll(buf);
}

const routes = ComptimeStringMap(RequestHandler, .{
    .{ "/", rootHandler },
    .{ "/style.css", styleHandler },
    .{ "/board", board.handler },
});

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    board.init(alloc);
}

pub fn resolve(res: *Response) !void {
    const handler = routes.get(res.request.target) orelse {
        return;
    };
    try handler(res);
}
