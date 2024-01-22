const std = @import("std");

const Response = std.http.Server.Response;

pub fn handler(res: *Response) !void {
    try res.writeAll(@embedFile("lobby.html"));
}
