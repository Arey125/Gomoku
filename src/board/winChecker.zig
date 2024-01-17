const config = @import("config.zig");

const MAP_WIDTH = config.MAP_WIDTH;

var map: *[MAP_WIDTH][MAP_WIDTH]u8 = undefined;

pub fn init(_map: *[MAP_WIDTH][MAP_WIDTH]u8) void {
    map = _map;
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

pub fn checkForWin() ?u8 {
    if (checkForWinForMark('X')) {
        return 'X';
    }
    if (checkForWinForMark('O')) {
        return 'O';
    }
    return null;
}
