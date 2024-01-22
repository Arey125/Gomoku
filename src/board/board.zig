const std = @import("std");
const config = @import("config.zig");
const winChecker = @import("winChecker.zig");

const MAP_WIDTH = config.MAP_WIDTH;

const Response = std.http.Server.Response;

var allocator: std.mem.Allocator = undefined;
var mutex = std.Thread.Mutex{};

var map: [MAP_WIDTH][MAP_WIDTH]u8 = .{.{' '} ** MAP_WIDTH} ** MAP_WIDTH;

var players = [_]?u32{ null, null };
var current_player: usize = 0;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    winChecker.init(&map);
}

pub fn isPlaying(ip: u32) bool {
    for (players) |player| {
        if (player == ip) {
            return true;
        }
    }
    return false;
}

pub fn addPlayer(ip: u32) void {
    if (players[0] == null) {
        players[0] = ip;
    } else if (players[1] == null) {
        players[1] = ip;
    }
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

    const winnerOptional = winChecker.checkForWin();

    try res.writer().print(@embedFile("./header.html"), .{mark});
    try res.writer().writeAll("<div class=\"board-cells\">");

    const can_make_move = player_index == current_player and winnerOptional == null;

    const hx_attr = if (can_make_move) " hx-post=\"board\" hx-target=\"#board\" hx-include=\"find input\"" else "";

    for (map, 0..) |line, row| {
        for (line, 0..) |cell, col| {
            const cell_hx_attr = if (can_make_move and cell == ' ') hx_attr else "";
            const class = if (cell == ' ') "cell-empty" else "cell-marked";
            try res.writer().print(@embedFile("./cell.html"), .{ class, cell_hx_attr, cell, col, row });
        }
    }
    try res.writer().writeAll("</div>");
    if (winnerOptional) |winner| {
        try res.writer().print(@embedFile("./win.html"), .{winner});
    }
}

pub fn restartHandler(res: *Response) !void {
    _ = res;
    @memset(&map, .{' '} ** MAP_WIDTH);
}
