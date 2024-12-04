const std = @import("std");

fn MatrixUnmanaged(comptime T: type) type {
    return struct {
        const Self = @This();
        const Data = T;

        width: usize = undefined,
        height: usize = undefined,
        data: []Data = undefined,

        pub fn init(self: *Self, allocator: std.mem.Allocator, width: usize, height: usize) !void {
            const data = try allocator.alloc(Data, width * height);

            self.* = .{
                .width = width,
                .height = height,
                .data = data,
            };
        }

        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }

        pub fn rowSlice(self: *Self, row: usize) []Data {
            std.debug.assert(row < self.height);

            const offset = row * self.width;
            return self.data[offset..(offset + self.width)];
        }

        pub fn constRowSlice(self: Self, row: usize) []const Data {
            std.debug.assert(row < self.height);

            const offset = row * self.width;
            return self.data[offset..(offset + self.width)];
        }

        pub fn get(self: Self, row: usize, column: usize) Data {
            std.debug.assert(row < self.height);
            std.debug.assert(column < self.width);

            const index = (row * self.width) + column;
            return self.data[index];
        }

        pub fn set(self: *Self, row: usize, column: usize, value: Data) void {
            std.debug.assert(row < self.height);
            std.debug.assert(column < self.width);

            const index = (row * self.width) + column;
            self.data[index] = value;
        }
    };
}

const ByteMatrixUnmanaged = MatrixUnmanaged(u8);

const SEARCH_FORWARD = "XMAS";
const SEARCH_BACKWARD = "SAMX";

fn create_vertical_matrix(comptime data: []const u8) *const ByteMatrixUnmanaged {
    return &.{
        .width = 1,
        .height = data.len,
        .data = @constCast(data),
    };
}

const XMAS_VERTICAL_FORWARD = create_vertical_matrix(SEARCH_FORWARD);
const XMAS_VERTICAL_BACKWARD = create_vertical_matrix(SEARCH_BACKWARD);

fn create_horizontal_matrix(comptime data: []const u8) *const ByteMatrixUnmanaged {
    return &.{
        .width = data.len,
        .height = 1,
        .data = @constCast(data),
    };
}

const XMAS_HORIZONTAL_FORWARD = create_horizontal_matrix(SEARCH_FORWARD);
const XMAS_HORIZONTAL_BACKWARD = create_horizontal_matrix(SEARCH_BACKWARD);

fn create_diagonal_down_data(
    comptime data: []const u8,
    comptime default: u8,
) [data.len * data.len]u8 {
    var buffer: [data.len * data.len]u8 = undefined;
    for (0..data.len) |row| {
        for (0..data.len) |column| {
            const index = (row * data.len) + column;
            const value: u8 = if (row == column) data[row] else default;
            buffer[index] = value;
        }
    }

    return buffer;
}

const XMAS_DIAGONAL_DOWN_FORWARD_DATA = create_diagonal_down_data(SEARCH_FORWARD, 0);
const XMAS_DIAGONAL_DOWN_FORWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_FORWARD.len,
    .height = SEARCH_FORWARD.len,
    .data = @constCast(&XMAS_DIAGONAL_DOWN_FORWARD_DATA),
};

const XMAS_DIAGONAL_DOWN_BACKWARD_DATA = create_diagonal_down_data(SEARCH_BACKWARD, 0);
const XMAS_DIAGONAL_DOWN_BACKWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_BACKWARD.len,
    .height = SEARCH_BACKWARD.len,
    .data = @constCast(&XMAS_DIAGONAL_DOWN_BACKWARD_DATA),
};

fn create_diagonal_up_data(
    comptime data: []const u8,
    comptime default: u8,
) [data.len * data.len]u8 {
    var buffer: [data.len * data.len]u8 = undefined;
    for (0..data.len) |row| {
        for (0..data.len) |column| {
            const index = (row * data.len) + column;
            const value: u8 = if (row == (data.len - column - 1)) data[row] else default;
            buffer[index] = value;
        }
    }

    return buffer;
}

const XMAS_DIAGONAL_UP_FORWARD_DATA = create_diagonal_down_data(SEARCH_FORWARD, 0);
const XMAS_DIAGONAL_UP_FORWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_FORWARD.len,
    .height = SEARCH_FORWARD.len,
    .data = @constCast(&XMAS_DIAGONAL_UP_FORWARD_DATA),
};

const XMAS_DIAGONAL_UP_BACKWARD_DATA = create_diagonal_down_data(SEARCH_BACKWARD, 0);
const XMAS_DIAGONAL_UP_BACKWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_BACKWARD.len,
    .height = SEARCH_BACKWARD.len,
    .data = @constCast(&XMAS_DIAGONAL_UP_BACKWARD_DATA),
};

fn parse_input(allocator: std.mem.Allocator, input_data: []const u8) !ByteMatrixUnmanaged {
    // XXX
    const index_first_newline = std.mem.indexOfScalar(u8, input_data, '\n') orelse {
        return error.InvalidFormat;
    };

    const newlines = std.mem.count(u8, input_data, &.{'\n'});

    std.debug.assert(index_first_newline > 0 and index_first_newline < 256);
    std.debug.assert(newlines > 0 and newlines < 256);

    // XXX
    var matrix: ByteMatrixUnmanaged = .{};
    try matrix.init(allocator, index_first_newline, newlines + 1);
    errdefer matrix.deinit(allocator);

    var line_count: usize = 0;
    var line_iterator = std.mem.splitScalar(u8, input_data, '\n');
    while (line_iterator.next()) |line| {
        const matrix_line = matrix.rowSlice(line_count);
        std.mem.copyForwards(u8, matrix_line, line);
        line_count += 1;
    }

    // XXX
    return matrix;
}

fn count_overlap(
    haystack: *const ByteMatrixUnmanaged,
    needle: *const ByteMatrixUnmanaged,
    needle_mask: u8,
) usize {
    std.debug.assert(haystack.width > 0 and haystack.height > 0);
    std.debug.assert(needle.width > 0 and needle.height > 0);
    std.debug.assert(needle.width <= haystack.width);
    std.debug.assert(needle.height <= haystack.height);

    var count: usize = 0;
    for (0..(haystack.height - needle.height + 1)) |row_offset| {
        for (0..(haystack.width - needle.width + 1)) |column_offset| {
            const matches: bool = check: {
                for (0..needle.height) |row| {
                    const haystack_row = haystack.constRowSlice(row_offset + row);
                    const needle_row = needle.constRowSlice(row);

                    for (0..needle.width) |column| {
                        const haystack_value = &haystack_row[column_offset + column];
                        const needle_value = &needle_row[column];

                        //std.debug.print("H({d}, {d}) = {}\n", .{ row_offset + row, column_offset + column, haystack_value.* });
                        //std.debug.print("N({d}, {d}) = {}\n", .{ row, column, needle_value.* });

                        if (needle_value.* == needle_mask) {
                            continue;
                        }

                        if (needle_value.* != haystack_value.*) {
                            //std.debug.print("BREAK\n", .{});
                            break :check false;
                        }
                    }
                }

                break :check true;
            };

            // std.debug.print("H({d}, {d}): {}\n", .{ row_offset, column_offset, matches });
            if (matches) {
                count += 1;
            }
        }
    }

    return count;
}

test "second_example" {
    // parse input
    const sample_input =
        \\....XXMAS.
        \\.SAMXMS...
        \\...S..A...
        \\..A.A.MS.X
        \\XMASAMX.MM
        \\X.....XA.A
        \\S.S.S.S.SS
        \\.A.A.A.A.A
        \\..M.M.M.MM
        \\.X.X.XMASX
    ;

    const sample_matrix = try parse_input(std.testing.allocator, sample_input);
    defer sample_matrix.deinit(std.testing.allocator);

    try std.testing.expectEqual(10, sample_matrix.width);
    try std.testing.expectEqual(10, sample_matrix.height);

    const sample_input_first_line = sample_input[0..sample_matrix.width];
    const sample_matrix_first_row = sample_matrix.constRowSlice(0);
    try std.testing.expect(std.mem.eql(u8, sample_input_first_line, sample_matrix_first_row));

    const sample_input_last_line = sample_input[(sample_input.len - sample_matrix.width)..];
    const sample_matrix_last_row = sample_matrix.constRowSlice(sample_matrix.height - 1);
    try std.testing.expect(std.mem.eql(u8, sample_input_last_line, sample_matrix_last_row));

    // count words
    const CountPair = struct {
        expected: usize,
        actual: usize,
    };

    const counts: []const CountPair = &.{
        .{ .expected = 1, .actual = count_overlap(&sample_matrix, XMAS_VERTICAL_FORWARD, 0) },
        .{ .expected = 2, .actual = count_overlap(&sample_matrix, XMAS_VERTICAL_BACKWARD, 0) },
        .{ .expected = 3, .actual = count_overlap(&sample_matrix, XMAS_HORIZONTAL_FORWARD, 0) },
        .{ .expected = 2, .actual = count_overlap(&sample_matrix, XMAS_HORIZONTAL_BACKWARD, 0) },
        .{ .expected = 1, .actual = count_overlap(&sample_matrix, XMAS_DIAGONAL_DOWN_FORWARD, 0) },
        .{ .expected = 4, .actual = count_overlap(&sample_matrix, XMAS_DIAGONAL_DOWN_BACKWARD, 0) },
        .{ .expected = 1, .actual = count_overlap(&sample_matrix, XMAS_DIAGONAL_UP_FORWARD, 0) },
        .{ .expected = 4, .actual = count_overlap(&sample_matrix, XMAS_DIAGONAL_UP_BACKWARD, 0) },
    };

    var total_count: usize = 0;
    for (counts) |count| {
        try std.testing.expectEqual(count.expected, count.actual);
        total_count += count.actual;
    }

    try std.testing.expectEqual(18, total_count);
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    const search_matrix = try parse_input(allocator, input_data);
    defer search_matrix.deinit(allocator);

    const counts: []const usize = &.{
        count_overlap(&search_matrix, XMAS_VERTICAL_FORWARD, 0),
        count_overlap(&search_matrix, XMAS_VERTICAL_BACKWARD, 0),
        count_overlap(&search_matrix, XMAS_HORIZONTAL_FORWARD, 0),
        count_overlap(&search_matrix, XMAS_HORIZONTAL_BACKWARD, 0),
        count_overlap(&search_matrix, XMAS_DIAGONAL_DOWN_FORWARD, 0),
        count_overlap(&search_matrix, XMAS_DIAGONAL_DOWN_BACKWARD, 0),
        count_overlap(&search_matrix, XMAS_DIAGONAL_UP_FORWARD, 0),
        count_overlap(&search_matrix, XMAS_DIAGONAL_UP_BACKWARD, 0),
    };

    var total_count: usize = 0;
    for (counts) |count| {
        total_count += count;
    }

    return total_count;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const count = try part1(allocator, input_data);

    std.debug.assert(count == 2718);
    std.debug.print("count: {d}\n", .{ count });

    // // part 2
    // const result_conditional = try part2(allocator, input_data);

    // std.debug.assert(result_conditional == 76729637);
    // std.debug.print("result conditional: {d}\n", .{ result_conditional });
}
