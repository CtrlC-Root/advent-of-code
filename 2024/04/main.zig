const std = @import("std");

// COMMON DATA TYPES
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

// PART 1 DATA
const SEARCH_XMAS_FORWARD = "XMAS";
const SEARCH_XMAS_BACKWARD = "SAMX";

fn create_vertical_matrix(comptime data: []const u8) *const ByteMatrixUnmanaged {
    return &.{
        .width = 1,
        .height = data.len,
        .data = @constCast(data),
    };
}

const XMAS_VERTICAL_FORWARD = create_vertical_matrix(SEARCH_XMAS_FORWARD);
const XMAS_VERTICAL_BACKWARD = create_vertical_matrix(SEARCH_XMAS_BACKWARD);

fn create_horizontal_matrix(comptime data: []const u8) *const ByteMatrixUnmanaged {
    return &.{
        .width = data.len,
        .height = 1,
        .data = @constCast(data),
    };
}

const XMAS_HORIZONTAL_FORWARD = create_horizontal_matrix(SEARCH_XMAS_FORWARD);
const XMAS_HORIZONTAL_BACKWARD = create_horizontal_matrix(SEARCH_XMAS_BACKWARD);

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

const XMAS_DIAGONAL_DOWN_FORWARD_DATA = create_diagonal_down_data(SEARCH_XMAS_FORWARD, 0);
const XMAS_DIAGONAL_DOWN_FORWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_XMAS_FORWARD.len,
    .height = SEARCH_XMAS_FORWARD.len,
    .data = @constCast(&XMAS_DIAGONAL_DOWN_FORWARD_DATA),
};

const XMAS_DIAGONAL_DOWN_BACKWARD_DATA = create_diagonal_down_data(SEARCH_XMAS_BACKWARD, 0);
const XMAS_DIAGONAL_DOWN_BACKWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_XMAS_BACKWARD.len,
    .height = SEARCH_XMAS_BACKWARD.len,
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

const XMAS_DIAGONAL_UP_FORWARD_DATA = create_diagonal_down_data(SEARCH_XMAS_FORWARD, 0);
const XMAS_DIAGONAL_UP_FORWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_XMAS_FORWARD.len,
    .height = SEARCH_XMAS_FORWARD.len,
    .data = @constCast(&XMAS_DIAGONAL_UP_FORWARD_DATA),
};

const XMAS_DIAGONAL_UP_BACKWARD_DATA = create_diagonal_down_data(SEARCH_XMAS_BACKWARD, 0);
const XMAS_DIAGONAL_UP_BACKWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_XMAS_BACKWARD.len,
    .height = SEARCH_XMAS_BACKWARD.len,
    .data = @constCast(&XMAS_DIAGONAL_UP_BACKWARD_DATA),
};

// PART 2 DATA
const SEARCH_MAS_FORWARD = "MAS";
const SEARCH_MAS_BACKWARD = "SAM";

fn create_cross_horizontal_data(
    comptime data: []const u8,
    comptime default: u8,
) [data.len * data.len]u8 {
    var buffer: [data.len * data.len]u8 = undefined;
    for (0..data.len) |row| {
        for (0..data.len) |column| {
            const index = (row * data.len) + column;
            const value: u8 = if (row == column or row == (data.len - column - 1)) data[column] else default;
            buffer[index] = value;
        }
    }

    return buffer;
}

const MAS_CROSS_HORIZONTAL_FORWARD_DATA = create_cross_horizontal_data(SEARCH_MAS_FORWARD, 0);
const MAS_CROSS_HORIZONTAL_FORWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_MAS_FORWARD.len,
    .height = SEARCH_MAS_FORWARD.len,
    .data = @constCast(&MAS_CROSS_HORIZONTAL_FORWARD_DATA),
};

const MAS_CROSS_HORIZONTAL_BACKWARD_DATA = create_cross_horizontal_data(SEARCH_MAS_BACKWARD, 0);
const MAS_CROSS_HORIZONTAL_BACKWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_MAS_BACKWARD.len,
    .height = SEARCH_MAS_BACKWARD.len,
    .data = @constCast(&MAS_CROSS_HORIZONTAL_BACKWARD_DATA),
};

fn create_cross_vertical_data(
    comptime data: []const u8,
    comptime default: u8,
) [data.len * data.len]u8 {
    var buffer: [data.len * data.len]u8 = undefined;
    for (0..data.len) |row| {
        for (0..data.len) |column| {
            const index = (row * data.len) + column;
            const value: u8 = if (row == column or row == (data.len - column - 1)) data[row] else default;
            buffer[index] = value;
        }
    }

    return buffer;
}

const MAS_CROSS_VERTICAL_FORWARD_DATA = create_cross_vertical_data(SEARCH_MAS_FORWARD, 0);
const MAS_CROSS_VERTICAL_FORWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_MAS_FORWARD.len,
    .height = SEARCH_MAS_FORWARD.len,
    .data = @constCast(&MAS_CROSS_VERTICAL_FORWARD_DATA),
};

const MAS_CROSS_VERTICAL_BACKWARD_DATA = create_cross_vertical_data(SEARCH_MAS_BACKWARD, 0);
const MAS_CROSS_VERTICAL_BACKWARD: *const ByteMatrixUnmanaged = &.{
    .width = SEARCH_MAS_BACKWARD.len,
    .height = SEARCH_MAS_BACKWARD.len,
    .data = @constCast(&MAS_CROSS_VERTICAL_BACKWARD_DATA),
};

// COMMON ALGORITHMS
fn parse_input(allocator: std.mem.Allocator, input_data: []const u8) !ByteMatrixUnmanaged {
    // look for newlines to determine matrix dimensions
    const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
    const index_first_newline = std.mem.indexOfScalar(u8, trimmed_input, '\n') orelse {
        return error.InvalidFormat;
    };

    const newlines = std.mem.count(u8, trimmed_input, &.{'\n'});

    std.debug.assert(index_first_newline > 0 and index_first_newline < 256);
    std.debug.assert(newlines > 0 and newlines < 256);

    // allocate and initialize matrix
    var matrix: ByteMatrixUnmanaged = .{};
    try matrix.init(allocator, index_first_newline, newlines + 1);
    errdefer matrix.deinit(allocator);

    // copy input data into matrix data one line at a time
    var line_count: usize = 0;
    var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');
    while (line_iterator.next()) |line| {
        std.mem.copyForwards(u8, matrix.rowSlice(line_count), line);
        line_count += 1;
    }

    // return matrix with caller owned memory
    return matrix;
}

test "parse_input" {
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

    // sliding needle sized window over haystack
    for (0..(haystack.height - needle.height + 1)) |row_offset| {
        for (0..(haystack.width - needle.width + 1)) |column_offset| {
            // check if needle matches haystack at window position
            const matches: bool = check: {
                for (0..needle.height) |row| {
                    const haystack_row = haystack.constRowSlice(row_offset + row);
                    const needle_row = needle.constRowSlice(row);

                    for (0..needle.width) |column| {
                        const haystack_value = &haystack_row[column_offset + column];
                        const needle_value = &needle_row[column];

                        // ignore needle mask values
                        if (needle_value.* == needle_mask) {
                            continue;
                        }

                        if (needle_value.* != haystack_value.*) {
                            break :check false;
                        }
                    }
                }

                break :check true;
            };

            if (matches) {
                count += 1;
            }
        }
    }

    return count;
}

test "part1_example" {
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

test "part2_example" {
    const sample_input =
        \\.M.S......
        \\..A..MSMS.
        \\.M.S.MAA..
        \\..A.ASMSM.
        \\.M.S.M....
        \\..........
        \\S.S.S.S.S.
        \\.A.A.A.A..
        \\M.M.M.M.M.
        \\..........
    ;

    const sample_matrix = try parse_input(std.testing.allocator, sample_input);
    defer sample_matrix.deinit(std.testing.allocator);

    const CountPair = struct {
        expected: usize,
        actual: usize,
    };

    const counts: []const CountPair = &.{
        .{ .expected = 1, .actual = count_overlap(&sample_matrix, MAS_CROSS_VERTICAL_FORWARD, 0) },
        .{ .expected = 5, .actual = count_overlap(&sample_matrix, MAS_CROSS_VERTICAL_BACKWARD, 0) },
        .{ .expected = 2, .actual = count_overlap(&sample_matrix, MAS_CROSS_HORIZONTAL_FORWARD, 0) },
        .{ .expected = 1, .actual = count_overlap(&sample_matrix, MAS_CROSS_HORIZONTAL_BACKWARD, 0) },
    };

    var total_count: usize = 0;
    for (counts) |count| {
        try std.testing.expectEqual(count.expected, count.actual);
        total_count += count.actual;
    }

    try std.testing.expectEqual(9, total_count);
}

// IMPLEMENTATION
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

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    const search_matrix = try parse_input(allocator, input_data);
    defer search_matrix.deinit(allocator);

    const counts: []const usize = &.{
        count_overlap(&search_matrix, MAS_CROSS_VERTICAL_FORWARD, 0),
        count_overlap(&search_matrix, MAS_CROSS_VERTICAL_BACKWARD, 0),
        count_overlap(&search_matrix, MAS_CROSS_HORIZONTAL_FORWARD, 0),
        count_overlap(&search_matrix, MAS_CROSS_HORIZONTAL_BACKWARD, 0),
    };

    var total_count: usize = 0;
    for (counts) |count| {
        total_count += count;
    }

    return total_count;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const xmas_count = try part1(allocator, input_data);

    std.debug.assert(xmas_count == 2718);
    std.debug.print("XMAS count: {d}\n", .{xmas_count});

    // part 2
    const mas_count = try part2(allocator, input_data);

    std.debug.assert(mas_count == 2046);
    std.debug.print("MAS count: {d}\n", .{mas_count});
}
