const std = @import("std");
const http = std.http;
const log = std.log;

const router = @import("./router.zig");

var gpa_struct = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_struct.allocator();

const server_addr = "192.168.0.16";
const server_port = 8080;

pub fn run() !void {
    var server = http.Server.init(gpa, .{ .reuse_address = true, .reuse_port = true });
    defer server.deinit();

    router.init(gpa);

    log.info("Listening on http://{s}:{d}", .{ server_addr, server_port });

    const address = std.net.Address.parseIp(server_addr, server_port) catch unreachable;
    try server.listen(address);

    var threads: [256]std.Thread = undefined;

    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, (struct {
            fn apply(serv: *http.Server) !void {
                while (true) {
                    var response = try serv.accept(.{
                        .allocator = gpa,
                    });

                    log.debug("Accepted connection {}", .{response.address});
                    defer log.debug("Closed connection {}", .{response.address});
                    defer response.deinit();

                    while (response.reset() != .closing) {
                        response.wait() catch |err| switch (err) {
                            error.HttpHeadersInvalid => return,
                            error.EndOfStream => continue,
                            else => return,
                        };

                        try handleRequest(&response);
                    }
                }
            }
        }).apply, .{&server});
    }

    for (&threads) |*thread| {
        thread.join();
    }
}

fn handleRequest(response: *http.Server.Response) !void {
    log.info("{s} {s}", .{ @tagName(response.request.method), response.request.target });

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
