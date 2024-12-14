const std = @import("std");

const Vec2d = struct {
    const Self = @This();
    const Value = i64;

    x: Value = 0,
    y: Value = 0,

    pub fn equals(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn multiplyScalar(self: Self, coefficient: Value) Self {
        return .{
            .x = std.math.mul(Value, coefficient, self.x) catch unreachable,
            .y = std.math.mul(Value, coefficient, self.y) catch unreachable,
        };
    }

    pub fn sum(self: Self, other: Self) Self {
        return .{
            .x = std.math.add(Value, self.x, other.x) catch unreachable,
            .y = std.math.add(Value, self.y, other.y) catch unreachable,
        };
    }

    // pub fn difference(self: Self, other: Self) Self {
    //     return .{
    //         .x = std.math.sub(Value, self.x, other.x) catch unreachable,
    //         .y = std.math.sub(Value, self.y, other.y) catch unreachable,
    //     };
    // }
};

const Machine = struct {
    const Self = @This();

    button_a: Vec2d = .{},
    button_b: Vec2d = .{},
    prize: Vec2d = .{},

    pub fn equals(self: Self, other: Self) bool {
        const button_a = self.button_a.equals(other.button_a);
        const button_b = self.button_b.equals(other.button_b);
        const prize = self.prize.equals(other.prize);

        return (button_a and button_b and prize);
    }

    fn parse_button_line(input_data: []const u8) !Vec2d {
        const colon_index = std.mem.indexOfScalar(u8, input_data, ':') orelse {
            return error.InvalidFormat;
        };

        const comma_index = std.mem.indexOfScalarPos(u8, input_data, colon_index, ',') orelse {
            return error.InvalidFormat;
        };

        std.debug.assert(comma_index > colon_index);

        const first_part = std.mem.trim(u8, input_data[(colon_index + 1)..comma_index], &.{' '});
        std.debug.assert(std.mem.eql(u8, first_part[0..2], "X+"));
        const value_x = try std.fmt.parseInt(Vec2d.Value, first_part[2..], 10);

        const second_part = std.mem.trim(u8, input_data[(comma_index + 1)..], &.{' '});
        std.debug.assert(std.mem.eql(u8, second_part[0..2], "Y+"));
        const value_y = try std.fmt.parseInt(Vec2d.Value, second_part[2..], 10);

        return .{ .x = value_x, .y = value_y };
    }

    fn parse_prize_line(input_data: []const u8) !Vec2d {
        const colon_index = std.mem.indexOfScalar(u8, input_data, ':') orelse {
            return error.InvalidFormat;
        };

        const comma_index = std.mem.indexOfScalarPos(u8, input_data, colon_index, ',') orelse {
            return error.InvalidFormat;
        };

        std.debug.assert(comma_index > colon_index);

        const first_part = std.mem.trim(u8, input_data[(colon_index + 1)..comma_index], &.{' '});
        std.debug.assert(std.mem.eql(u8, first_part[0..2], "X="));
        const value_x = try std.fmt.parseInt(Vec2d.Value, first_part[2..], 10);

        const second_part = std.mem.trim(u8, input_data[(comma_index + 1)..], &.{' '});
        std.debug.assert(std.mem.eql(u8, second_part[0..2], "Y="));
        const value_y = try std.fmt.parseInt(Vec2d.Value, second_part[2..], 10);

        return .{ .x = value_x, .y = value_y };
    }

    pub fn parse(self: *Self, input_data: []const u8) !void {
        var line_iterator = std.mem.tokenizeScalar(u8, input_data, '\n');
        const first_line = line_iterator.next() orelse {
            return error.InvalidFormat;
        };

        const second_line = line_iterator.next() orelse {
            return error.InvalidFormat;
        };

        const third_line = line_iterator.next() orelse {
            return error.InvalidFormat;
        };

        if (line_iterator.next() != null) {
            return error.InvalidFormat;
        }

        const button_a = try Self.parse_button_line(first_line);
        const button_b = try Self.parse_button_line(second_line);
        const prize = try Self.parse_prize_line(third_line);

        self.* = .{
            .button_a = button_a,
            .button_b = button_b,
            .prize = prize,
        };
    }
};

const Input = struct {
    const Self = @This();
    const MachineArrayList = std.ArrayListUnmanaged(Machine);

    allocator: std.mem.Allocator = undefined,
    machines: MachineArrayList = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        var machines = MachineArrayList{};
        errdefer machines.deinit(allocator);

        var block_iterator = std.mem.splitSequence(u8, input_data, "\n\n");
        while (block_iterator.next()) |block_data| {
            var machine: Machine = .{};
            try machine.parse(block_data);
            try machines.append(allocator, machine);
        }

        self.* = .{
            .allocator = allocator,
            .machines = machines,
        };
    }

    pub fn deinit(self: *Self) void {
        self.machines.deinit(self.allocator);
    }
};

test "input_parse" {
    const single_machine_data =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
    ;

    var single_machine = Machine{};
    try single_machine.parse(single_machine_data);
    try std.testing.expectEqual(94, single_machine.button_a.x);
    try std.testing.expectEqual(34, single_machine.button_a.y);
    try std.testing.expectEqual(22, single_machine.button_b.x);
    try std.testing.expectEqual(67, single_machine.button_b.y);
    try std.testing.expectEqual(8400, single_machine.prize.x);
    try std.testing.expectEqual(5400, single_machine.prize.y);

    const multiple_machines_data =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;

    var input = Input{};
    try input.init(std.testing.allocator, multiple_machines_data);
    defer input.deinit();

    try std.testing.expectEqual(4, input.machines.items.len);
    try std.testing.expect(input.machines.items[1].equals(.{
        .button_a = .{ .x = 26, .y = 66 },
        .button_b = .{ .x = 67, .y = 21 },
        .prize = .{ .x = 12748, .y = 12176 },
    }));
}

const EvaluateMachineResults = struct {
    const Self = @This();

    press_a: usize,
    press_b: usize,
};

fn evaluate_machine_part1(machine: *const Machine) ?EvaluateMachineResults {
    for (0..101) |press_a| {
        for (0..101) |press_b| {
            const results: EvaluateMachineResults = .{ .press_a = press_a, .press_b = press_b };
            const target = Vec2d.sum(
                machine.button_a.multiplyScalar(@intCast(results.press_a)),
                machine.button_b.multiplyScalar(@intCast(results.press_b)),
            );

            if (target.equals(machine.prize)) {
                return results;
            }
        }
    }

    return null;
}

test "evaluate_machine_part1" {
    const multiple_machines_data =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;

    var input = Input{};
    try input.init(std.testing.allocator, multiple_machines_data);
    defer input.deinit();

    const Output = union(enum) {
        impossible: void,
        possible: EvaluateMachineResults,
    };

    const expected_outputs: []const Output = &.{
        Output{ .possible = .{ .press_a = 80, .press_b = 40 } },
        Output.impossible,
        Output{ .possible = .{ .press_a = 38, .press_b = 86 } },
        Output.impossible,
    };

    try std.testing.expectEqual(expected_outputs.len, input.machines.items.len);
    for (expected_outputs, input.machines.items) |expected_output, *machine| {
        const actual_output: Output = determine_output: {
            if (evaluate_machine_part1(machine)) |results| {
                break :determine_output Output{ .possible = results };
            } else {
                break :determine_output Output.impossible;
            }
        };

        try std.testing.expectEqualDeep(expected_output, actual_output);
    }
}

pub fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input = Input{};
    try input.init(allocator, input_data);
    defer input.deinit();

    try std.testing.expectEqual(320, input.machines.items.len);

    var total_cost: usize = 0;
    for (input.machines.items) |*machine| {
        if (evaluate_machine_part1(machine)) |results| {
            const machine_cost = (3 * @as(usize, @intCast(results.press_a))) + (1 * @as(usize, @intCast(results.press_b)));
            total_cost += machine_cost;
        }
    }

    return total_cost;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const tokens = try part1(allocator, input_data);

    try std.testing.expectEqual(34393, tokens);
    std.debug.print("tokens: {d}\n", .{tokens});

    // part 2
    // const price_sides = try part2(allocator, input_data);

    // // try std.testing.expectEqual(897612, price_sides);
    // std.debug.print("price sides: {d}\n", .{price_sides});
}
