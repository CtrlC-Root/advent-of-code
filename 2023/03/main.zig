const std = @import("std");

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !i64 {
    const Position = struct {
        x: i32,
        y: i32,
    };

    const Number = struct {
        value: i32,
        x1: i32,
        x2: i32,
        y: i32,
    };

    var numbers = std.ArrayList(Number).init(allocator);
    defer numbers.deinit();

    var symbols = std.AutoHashMap(Position, u8).init(allocator);
    defer symbols.deinit();

    var digits = std.ArrayList(u8).init(allocator);
    defer digits.deinit();

    const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
    var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');

    var y: i32 = 0;
    while (line_iterator.next()) |line| {
        var x: i32 = 0;

        for (line) |character| {
            if (std.ascii.isDigit(character)) {
                try digits.append(character);
            } else {
                if (digits.items.len > 0) {
                    const value = try std.fmt.parseInt(i32, digits.items, 10);
                    try numbers.append(.{
                        .value = value,
                        .x1 = x - @as(i32, @intCast(digits.items.len)),
                        .x2 = x - 1,
                        .y = y,
                    });

                    //std.debug.print("number: {}\n", .{ numbers.items[numbers.items.len - 1] });
                    digits.clearAndFree();
                }

                if (character != '.') {
                    //std.debug.print("symbol: {}, {}, {}\n", .{ x, y, character });
                    try symbols.putNoClobber(.{ .x = x, .y = y }, character);
                }
            }

            x += 1;
        }

        if (digits.items.len > 0) {
            const value = try std.fmt.parseInt(i32, digits.items, 10);
            try numbers.append(.{
                .value = value,
                .x1 = x - @as(i32, @intCast(digits.items.len)),
                .x2 = x - 1,
                .y = y,
            });

            digits.clearAndFree();
        }

        y += 1;
    }

    // count numbers adjacent to a symbol
    var total: i64 = 0;
    check_number: for (numbers.items) |number| {
        const offset_x: usize = @as(usize, @intCast(number.x2 - number.x1)) + 3;

        for (0..offset_x) |delta_x| {
            const cx: i32 = number.x1 - 1 + @as(i32, @intCast(delta_x));

            for (0..3) |delta_y| {
                const cy: i32 = number.y - 1 + @as(i32, @intCast(delta_y));

                if (symbols.contains(.{ .x = cx, .y = cy })) {
                    //std.debug.print("number {} next to symbol at {d}, {d}\n", .{ number.value, cx, cy });
                    total += number.value;
                    continue :check_number;
                }
            }
        }
    }

    return total;
}

test "part1 sample" {
    const sample_input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const total = try part1(std.testing.allocator, sample_input);
    try std.testing.expectEqual(4361, total);
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !i64 {
    const Position = struct {
        x: i32,
        y: i32,
    };

    const Number = struct {
        value: i32,
        x1: i32,
        x2: i32,
        y: i32,
    };

    var numbers = std.ArrayList(Number).init(allocator);
    defer numbers.deinit();

    var symbols = std.AutoHashMap(Position, u8).init(allocator);
    defer symbols.deinit();

    var digits = std.ArrayList(u8).init(allocator);
    defer digits.deinit();

    const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
    var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');

    var y: i32 = 0;
    while (line_iterator.next()) |line| {
        var x: i32 = 0;

        for (line) |character| {
            if (std.ascii.isDigit(character)) {
                try digits.append(character);
            } else {
                if (digits.items.len > 0) {
                    const value = try std.fmt.parseInt(i32, digits.items, 10);
                    try numbers.append(.{
                        .value = value,
                        .x1 = x - @as(i32, @intCast(digits.items.len)),
                        .x2 = x - 1,
                        .y = y,
                    });

                    //std.debug.print("number: {}\n", .{ numbers.items[numbers.items.len - 1] });
                    digits.clearAndFree();
                }

                if (character != '.') {
                    //std.debug.print("symbol: {}, {}, {}\n", .{ x, y, character });
                    try symbols.putNoClobber(.{ .x = x, .y = y }, character);
                }
            }

            x += 1;
        }

        if (digits.items.len > 0) {
            const value = try std.fmt.parseInt(i32, digits.items, 10);
            try numbers.append(.{
                .value = value,
                .x1 = x - @as(i32, @intCast(digits.items.len)),
                .x2 = x - 1,
                .y = y,
            });

            digits.clearAndFree();
        }

        y += 1;
    }

    // count numbers adjacent to a symbol
    var total: i64 = 0;

    var symbol_iterator = symbols.iterator();
    while (symbol_iterator.next()) |entry| {
        if (entry.value_ptr.* != '*') {
            continue;
        }

        var neighbors = std.ArrayList(Number).init(allocator);
        defer neighbors.deinit();

        var index: usize = 0;
        check_number: while (index < numbers.items.len) {
            const number = &numbers.items[index];
            for (0..@as(usize, @intCast(number.x2 - number.x1 + 3))) |dx| {
                for (0..3) |dy| {
                    const nx = number.x1 - 1 + @as(i32, @intCast(dx));
                    const ny = number.y - 1 + @as(i32, @intCast(dy));

                    if (entry.key_ptr.*.x == nx and entry.key_ptr.*.y == ny) {
                        try neighbors.append(number.*);
                        _ = numbers.swapRemove(index);
                        continue :check_number;
                    }
                }
            }

            index += 1;
        }

        if (neighbors.items.len > 1) {
            var gear_ratio: i64 = neighbors.items[0].value;
            for (neighbors.items[1..]) |number| {
                gear_ratio *= number.value;
            }

            total += gear_ratio;
        }
    }

    return total;
}

test "part2 sample" {
    const sample_input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const total = try part2(std.testing.allocator, sample_input);
    try std.testing.expectEqual(467835, total);
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const part1_result = try part1(allocator, input_data);

    try std.testing.expectEqual(514969, part1_result); // too high
    std.debug.print("part1 total: {d}\n", .{part1_result});

    // part 2
    const part2_result = try part2(allocator, input_data);

    // try std.testing.expectEqual(897612, price_sides);
    std.debug.print("part2 total: {d}\n", .{part2_result});
}
