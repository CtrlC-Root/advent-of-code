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

pub fn MatrixUnmanaged(comptime T: type) type {
    return struct {
        const Self = @This();
        const Index = usize;
        const Value = T;

        rows: Index = undefined,
        columns: Index = undefined,
        data: []Value = undefined,

        pub fn init(self: *Self, allocator: std.mem.Allocator, rows: Index, columns: Index) !void {
            const data = try allocator.alloc(Value, rows * columns);
            errdefer allocator.free(data);

            for (0..(rows * columns)) |index| {
                data[index] = 0;
            }

            self.* = .{
                .rows = rows,
                .columns = columns,
                .data = data,
            };
        }

        pub fn dupe(self: *Self, allocator: std.mem.Allocator, other: *const Self) !void {
            const data = try allocator.dupe(Value, other.data);
            errdefer allocator.free(data);

            self.* = .{
                .rows = other.rows,
                .columns = other.columns,
                .data = data,
            };
        }

        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.data);
        }

        pub fn get(self: Self, row: Index, column: Index) Value {
            std.debug.assert(row < self.rows);
            std.debug.assert(column < self.columns);

            const index = (row * self.columns) + column;
            return self.data[index];
        }

        pub fn set(self: *Self, row: Index, column: Index, value: Value) void {
            std.debug.assert(row < self.rows);
            std.debug.assert(column < self.columns);

            const index = (row * self.columns) + column;
            self.data[index] = value;
        }
    };
}

const IntMatrixUnmanaged = MatrixUnmanaged(Vec2d.Value);
const FloatMatrixUnmanaged = MatrixUnmanaged(f64);

// https://www.baeldung.com/cs/solving-system-linear-equations
fn solve(allocator: std.mem.Allocator, system: *const IntMatrixUnmanaged) !IntMatrixUnmanaged {
    // system matix: NxN coefficients, Nx1 results
    std.debug.assert(system.rows >= 2);
    std.debug.assert(system.columns == (system.rows + 1));

    var work: FloatMatrixUnmanaged = .{};
    try work.init(allocator, system.rows, system.columns);
    defer work.deinit(allocator);

    for (0..system.rows) |row| {
        for (0..system.columns) |column| {
            work.set(row, column, @floatFromInt(system.get(row, column)));
        }
    }

    // guassian elimination
    // https://en.wikipedia.org/wiki/Gaussian_elimination#Pseudocode
    for (0..work.rows) |i| {
        const pivot = work.get(i, i);
        if (work.get(i, i) == 0.0) {
            return error.SystemNotSolvable;
        }

        for ((i + 1)..work.rows) |j| {
            const ratio = work.get(j, i) / pivot;
            for (0..work.columns) |k| {
                work.set(j, k, work.get(j, k) - (ratio * work.get(i, k)));
            }
        }
    }

    // back substitution
    var results = FloatMatrixUnmanaged{};
    try results.init(allocator, work.rows, 1);
    defer results.deinit(allocator);

    for (0..work.rows) |reverse_i| {
        const i = work.rows - reverse_i - 1;

        var sum: FloatMatrixUnmanaged.Value = 0;
        for ((i + 1)..work.rows) |j| {
            sum += results.get(j, 0) * work.get(i, j);
        }

        results.set(i, 0, (1.0 / work.get(i, i)) * (work.get(i, work.columns - 1) - sum));
    }

    // convert results into integer matrix
    var solution = IntMatrixUnmanaged{};
    try solution.init(allocator, results.rows, 1);
    errdefer solution.deinit(allocator);

    for (0..results.rows) |row| {
        solution.set(row, 0, @intFromFloat(results.get(row, 0)));
    }

    return solution;
}

test "solve" {
    var system: IntMatrixUnmanaged = .{};
    try system.init(std.testing.allocator, 3, 4);
    defer system.deinit(std.testing.allocator);

    // 2x + 1y - 1z = 8
    system.set(0, 0, 2);
    system.set(0, 1, 1);
    system.set(0, 2, -1);
    system.set(0, 3, 8);

    // -3x - 1y + 2z = -11
    system.set(1, 0, -3);
    system.set(1, 1, -1);
    system.set(1, 2, 2);
    system.set(1, 3, -11);

    // -2x + 1y + 2x = -3
    system.set(2, 0, -2);
    system.set(2, 1, 1);
    system.set(2, 2, 2);
    system.set(2, 3, -3);

    const solution = try solve(std.testing.allocator, &system);
    defer solution.deinit(std.testing.allocator);

    try std.testing.expectEqual(system.rows, solution.rows);
    try std.testing.expectEqual(1, solution.columns);

    // x = 2, y = 3, z = -1
    try std.testing.expectEqual(2, solution.get(0, 0));
    try std.testing.expectEqual(3, solution.get(1, 0));
    try std.testing.expectEqual(-1, solution.get(2, 0));
}

const EvaluateMachineResults = struct {
    const Self = @This();

    press_a: IntMatrixUnmanaged.Value,
    press_b: IntMatrixUnmanaged.Value,
};

fn evaluate_machine(allocator: std.mem.Allocator, machine: *const Machine) !EvaluateMachineResults {
    // linear system of two equations with two unknowns (press_a and press_b)
    // (button_a.x * press_a) + (button_b.x * press_b) = prize.x
    // (button_a.y * press_a) + (button_b.y * press_b) = prize.y

    var system = IntMatrixUnmanaged{};
    try system.init(allocator, 2, 3);
    defer system.deinit(allocator);

    system.set(0, 0, machine.button_a.x);
    system.set(1, 0, machine.button_a.y);
    system.set(0, 1, machine.button_b.x);
    system.set(1, 1, machine.button_b.y);
    system.set(0, 2, machine.prize.x);
    system.set(1, 2, machine.prize.y);

    var output = try solve(allocator, &system);
    defer output.deinit(allocator);

    std.debug.assert(output.rows == system.rows);
    std.debug.assert(output.columns == 1);

    // XXX
    // const press_a = output.get(0, 0);
    // const press_b = output.get(1, 0);
    // const prize = Vec2d.sum(
    //     machine.button_a.multiplyScalar(press_a),
    //     machine.button_b.multiplyScalar(press_b),
    // );

    // std.debug.print("Ax{} + Bx{} = {}\n", .{ press_a, press_b, prize });
    // std.debug.assert(machine.prize.equals(prize));

    // system can be solved
    return .{
        .press_a = output.get(0, 0),
        .press_b = output.get(1, 0),
    };
}

test "evaluate_machine" {
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
            const results = evaluate_machine(std.testing.allocator, machine) catch |err| {
                try std.testing.expectEqual(error.SystemNotSolvable, err);
                break :determine_output Output.impossible;
            };

            if (results.press_a > 100 or results.press_b > 100) {
                break :determine_output Output.impossible;
            }

            break :determine_output Output{ .possible = results };
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
        const results = evaluate_machine(allocator, machine) catch {
            continue;
        };

        const actual_prize = Vec2d.sum(
            machine.button_a.multiplyScalar(results.press_a),
            machine.button_b.multiplyScalar(results.press_b),
        );

        if (!actual_prize.equals(machine.prize)) {
            continue;
        }

        if (results.press_a < 0 or results.press_a > 100 or results.press_b < 0 or results.press_b > 100) {
            unreachable;
        }

        const machine_cost = (3 * @as(usize, @intCast(results.press_a))) + (1 * @as(usize, @intCast(results.press_b)));
        total_cost += machine_cost;
    }

    return total_cost;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const tokens = try part1(allocator, input_data);

    // too high: 37513
    // too low: 22049

    // try std.testing.expectEqual(37513, tokens);
    std.debug.print("tokens: {d}\n", .{tokens});

    // part 2
    // const price_sides = try part2(allocator, input_data);

    // // try std.testing.expectEqual(897612, price_sides);
    // std.debug.print("price sides: {d}\n", .{price_sides});
}
