const std = @import("std");

fn parse_card(allocator: std.mem.Allocator, line_data: []const u8) !i64 {
    const colon_index = std.mem.indexOf(u8, line_data, ":") orelse return error.InvalidCardFormat;
    const separator_index = std.mem.indexOfPos(u8, line_data, colon_index + 1, "|") orelse return error.InvalidCardFormat;

    var winning_numbers = std.AutoHashMap(i64, void).init(allocator);
    defer winning_numbers.deinit();

    var data_iterator = std.mem.splitScalar(u8, line_data[(separator_index + 1)..], ' ');
    while (data_iterator.next()) |raw_data| {
        if (raw_data.len == 0) {
            continue;
        }

        const number = try std.fmt.parseInt(i64, raw_data, 10);
        try winning_numbers.putNoClobber(number, {});
    }

    var matches: i64 = 0;
    data_iterator = std.mem.splitScalar(u8, line_data[(colon_index + 2)..(separator_index - 1)], ' ');
    while (data_iterator.next()) |raw_data| {
        if (raw_data.len == 0) {
            continue;
        }

        const number = try std.fmt.parseInt(i64, raw_data, 10);
        if (winning_numbers.contains(number)) {
            matches += 1;
        }
    }

    if (matches == 0) {
        return 0;
    } else {
        return std.math.pow(i64, 2, matches - 1);
    }
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !i64 {
    const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
    var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');

    var total: i64 = 0;
    while (line_iterator.next()) |line| {
        total += try parse_card(allocator, line);
    }

    return total;
}

test "part1 sample" {
    const sample_input =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    var card_actual_values = std.ArrayList(i64).init(std.testing.allocator);
    defer card_actual_values.deinit();

    var line_iterator = std.mem.splitScalar(u8, std.mem.trim(u8, sample_input, "\n"), '\n');
    while (line_iterator.next()) |line| {
        const value = try parse_card(std.testing.allocator, line);
        try card_actual_values.append(value);
    }

    const card_expected_values: []const i64 = &.{8, 2, 2, 1, 0, 0};
    try std.testing.expectEqualSlices(i64, card_expected_values, card_actual_values.items);

    const total = try part1(std.testing.allocator, sample_input);
    try std.testing.expectEqual(13, total);
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const part1_result = try part1(allocator, input_data);

    try std.testing.expectEqual(21138, part1_result);
    std.debug.print("part1: {d}\n", .{part1_result});

    // part 2
    // const part2_result = try part2(allocator, input_data);

    // try std.testing.expectEqual(897612, price_sides);
    // std.debug.print("part2 total: {d}\n", .{part2_result});
}
