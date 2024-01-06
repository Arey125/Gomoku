const std = @import("std");

const Response = std.http.Server.Response;

var allocator: std.mem.Allocator = undefined;
var mutex = std.Thread.Mutex{};

var map = [_][10]u8{[_]u8{' '} ** 10} ** 10;

var players = [_]?u32{ null, null };
var current_player: usize = 0;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn handler(res: *Response) !void {
    mutex.lock();
    defer mutex.unlock();

    if (players[0] == null) {
        players[0] = res.address.in.sa.addr;
    } else if (players[1] == null) {
        players[1] = res.address.in.sa.addr;
    }

    const player_index: usize = if (players[0] == res.address.in.sa.addr) 0 else 1;
    const mark: u8 = if (player_index == 0) 'X' else 'O';

    if (res.request.method == .POST) {
        const body = res.reader().readAllAlloc(allocator, 8192) catch unreachable;
        defer allocator.free(body);

        const equal_sign_pos = std.mem.indexOf(u8, body, "=") orelse unreachable;
        const col = std.fmt.parseInt(usize, body[equal_sign_pos + 1 .. equal_sign_pos + 2], 10) catch unreachable;
        const row = std.fmt.parseInt(usize, body[equal_sign_pos + 5 .. equal_sign_pos + 6], 10) catch unreachable;
        std.log.info("{x} placed {c} at [{}, {}]", .{ res.address.in.sa.addr, mark, row, col });

        if (map[row][col] == ' ') {
            map[row][col] = mark;
            current_player = (current_player + 1) % 2;
        } else {
            std.log.err("{x} tried to place {c} at [{}, {}]", .{ res.address.in.sa.addr, mark, row, col });
        }
    }

    try res.writer().print(@embedFile("./header.html"), .{mark});
    try res.writer().writeAll("<div class=\"board-cells\">");

    const can_make_move = player_index == current_player;

    const hx_attr = if (can_make_move) " hx-post=\"board\" hx-target=\"#board\" hx-include=\"find input\"" else "";

    for (map, 0..) |line, row| {
        for (line, 0..) |cell, col| {
            try res.writer().print(@embedFile("./cell.html"), .{ hx_attr, cell, col, row });
        }
    }
    try res.writer().writeAll("</div>");
}
