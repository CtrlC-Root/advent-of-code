const std = @import("std");

pub fn parse_input(allocator: std.mem.Allocator, input_data: []const u8) ![]const u64 {
    var numbers = std.ArrayList(u64).init(allocator);
    defer numbers.deinit();

    const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
    var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');
    while (line_iterator.next()) |line| {
        const number = try std.fmt.parseInt(u64, line, 10);
        try numbers.append(number);
    }

    return numbers.toOwnedSlice();
}

pub fn compute_next_secret_number(value: u64) u64 {
    var next_value = value;

    const term1 = next_value * 64;
    next_value = next_value ^ term1; // mix
    next_value = next_value % 16777216; // prune

    const term2 = @divFloor(next_value, 32);
    next_value = next_value ^ term2; // mix
    next_value = next_value % 16777216; // prune

    const term3 = next_value * 2048;
    next_value = next_value ^ term3; // mix
    next_value = next_value % 16777216; // prune

    return next_value;
}

test "compute_next_secret_number" {
    const sample_secret_numbers: []const u64 = &.{
        123,
        15887950,
        16495136,
        527345,
        704524,
        1553684,
        12683156,
        11100544,
        12249484,
        7753432,
        5908254,
    };

    for (
        sample_secret_numbers[0..(sample_secret_numbers.len - 1)],
        sample_secret_numbers[1..sample_secret_numbers.len],
    ) |initial, expected| {
        const actual = compute_next_secret_number(initial);
        try std.testing.expectEqual(expected, actual);
    }
}

pub fn compute_term(initial_number: u64, term: u64) u64 {
    var secret_number = initial_number;
    for (0..term) |_| {
        secret_number = compute_next_secret_number(secret_number);
    }

    return secret_number;
}

test "compute_term" {
    const TestCase = struct {
        initial: u64,
        computed: u64,
    };

    const test_cases: []const TestCase = &.{
        .{ .initial = 1, .computed = 8685429 },
        .{ .initial = 10, .computed = 4700978 },
        .{ .initial = 100, .computed = 15273692 },
        .{ .initial = 2024, .computed = 8667524 },
    };

    for (test_cases) |test_case| {
        const actual = compute_term(test_case.initial, 2000);
        try std.testing.expectEqual(test_case.computed, actual);
    }
}

pub fn part1(allocator: std.mem.Allocator, input_data: []const u8) !u64 {
    const initial_numbers = try parse_input(allocator, input_data);
    defer allocator.free(initial_numbers);

    std.debug.assert(initial_numbers.len == 1787);

    var total_sum: u64 = 0;
    for (initial_numbers) |initial_number| {
        total_sum += compute_term(initial_number, 2000);
    }

    return total_sum;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const sum_2000 = try part1(allocator, input_data);

    try std.testing.expectEqual(14869099597, sum_2000);
    std.debug.print("Sum 2000: {d}\n", .{sum_2000});

    // part 2
    // const price_sides = try part2(allocator, input_data);

    // // try std.testing.expectEqual(897612, price_sides);
    // std.debug.print("price sides: {d}\n", .{price_sides});
}
