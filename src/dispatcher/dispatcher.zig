const std = @import("std");

const board = @import("../board/board.zig");

const Response = std.http.Server.Response;

pub fn handler(res: *Response) !void {
    if (board.isPlaying(res.address.in.sa.addr)) {
        try res.writeAll(@embedFile("dispatch_board.html"));
        return;
    }
    try res.writeAll(@embedFile("dispatch_lobby.html"));
}
