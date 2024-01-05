const std = @import("std");
const http = std.http;
const log = std.log;

const router = @import("./router.zig");

var gpa_struct = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_struct.allocator();

const server_addr = "127.0.0.1";
const server_port = 8000;

pub fn run() !void {
    var server = http.Server.init(gpa, .{ .reuse_address = true });
    defer server.deinit();

    router.init(gpa);

    log.info("Listening on http://{s}:{d}", .{ server_addr, server_port });

    const address = std.net.Address.parseIp(server_addr, server_port) catch unreachable;
    try server.listen(address);

    outer: while (true) {
        var response = try server.accept(.{
            .allocator = gpa,
        });
        defer response.deinit();

        while (response.reset() != .closing) {
            response.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            try handleRequest(&response);
        }
    }
}

fn handleRequest(response: *http.Server.Response) !void {
    log.info("{s} {s}", .{ @tagName(response.request.method), response.request.target });

    const body = try response.reader().readAllAlloc(gpa, 8192);
    defer gpa.free(body);

    if (response.request.headers.contains("connection")) {
        try response.headers.append("connection", "keep-alive");
    }

    response.transfer_encoding = .chunked;

    try response.do();
    if (response.request.method != .HEAD) {
        try router.resolve(response);
        try response.finish();
    }
}
