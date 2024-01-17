const std = @import("std");

const Response = std.http.Server.Response;

var allocator: std.mem.Allocator = undefined;
var mutex = std.Thread.Mutex{};

const MAP_WIDTH = 10;

var map = [_][MAP_WIDTH]u8{[_]u8{' '} ** MAP_WIDTH} ** MAP_WIDTH;

var players = [_]?u32{ null, null };
var current_player: usize = 0;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

fn checkMaskForWin(mask: u32) bool {
    var check_mask = mask;
    for (0..4) |_| {
        check_mask >>= 1;
        check_mask &= mask;
    }
    return check_mask != 0;
}

fn getMark(row: usize, col: usize) u8 {
    if (row >= MAP_WIDTH or col >= MAP_WIDTH) {
        return ' ';
    }
    return map[row][col];
}

fn checkForWinForMark(mark: u8) bool {
    for (0..MAP_WIDTH) |i| {
        var horizontal_mask: u32 = 0;
        var vertical_mask: u32 = 0;

        for (0..MAP_WIDTH) |j| {
            horizontal_mask <<= 1;
            vertical_mask <<= 1;

            if (map[i][j] == mark) {
                horizontal_mask |= 1;
            }
            if (map[j][i] == mark) {
                vertical_mask |= 1;
            }
        }

        if (checkMaskForWin(horizontal_mask) or checkMaskForWin(vertical_mask)) {
            return true;
        }
    }
    for (0..(2 * MAP_WIDTH - 1)) |i| {
        var diagonal_mask: u32 = 0;
        var anti_diagonal_mask: u32 = 0;

        for (0..(2 * MAP_WIDTH - 1)) |j| {
            diagonal_mask <<= 1;
            anti_diagonal_mask <<= 1;

            if (i >= j and getMark(i - j, j) == mark) {
                diagonal_mask |= 1;
            }
            if (i >= j and getMark(2 * MAP_WIDTH - 2 - i + j, j) == mark) {
                anti_diagonal_mask |= 1;
            }
        }
        if (checkMaskForWin(diagonal_mask) or checkMaskForWin(anti_diagonal_mask)) {
            return true;
        }
    }
    return false;
}

fn checkForWin() ?u8 {
    if (checkForWinForMark('X')) {
        return 'X';
    }
    if (checkForWinForMark('O')) {
        return 'O';
    }
    return null;
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
    if (checkForWin()) |winner| {
        try res.writer().print(@embedFile("./win.html"), .{winner});
    }
}
