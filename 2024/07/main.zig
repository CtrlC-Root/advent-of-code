const std = @import("std");

const InputEquation = struct {
    const Self = @This();
    const Term = i64;
    const TermArray = std.BoundedArray(Term, 16);

    result: Term,
    terms: TermArray,

    pub fn parse(input_data: []const u8) !InputEquation {
        const index_colon = std.mem.indexOfScalar(u8, input_data, ':') orelse {
            return error.InvalidFormat;
        };

        const result = try std.fmt.parseInt(Term, input_data[0..index_colon], 10);

        var terms = try TermArray.init(0);
        var term_iterator = std.mem.tokenizeScalar(u8, input_data[(index_colon + 1)..], ' ');
        while (term_iterator.next()) |term_data| {
            const term = try std.fmt.parseInt(Term, term_data, 10);
            try terms.append(term);
        }

        return .{
            .result = result,
            .terms = terms,
        };
    }
};

const Input = struct {
    const Self = @This();

    equations: []InputEquation = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        var equations = std.ArrayList(InputEquation).init(allocator);
        errdefer equations.deinit();

        var line_iterator = std.mem.tokenizeScalar(u8, input_data, '\n');
        while (line_iterator.next()) |line| {
            const equation = try InputEquation.parse(line);
            try equations.append(equation);
        }

        self.* = .{
            .equations = try equations.toOwnedSlice(),
        };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.equations);
    }
};

test "input_parse" {
    const input_data =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, input_data);
    defer input.deinit(std.testing.allocator);

    try std.testing.expectEqual(9, input.equations.len);
    try std.testing.expectEqual(3267, input.equations[1].result);
    try std.testing.expect(std.mem.eql(
        InputEquation.Term,
        &.{ 81, 40, 27 },
        input.equations[1].terms.constSlice(),
    ));
}

fn validate_equation_part1(equation: *const InputEquation) bool {
    const Operator = enum(u8) {
        addition,
        multiplication,
    };

    const terms = equation.terms.constSlice();
    std.debug.assert(terms.len <= 16);

    var operators_array = std.BoundedArray(Operator, 16).init(0) catch unreachable;
    operators_array.appendNTimes(.addition, terms.len - 1) catch unreachable;
    const operators = operators_array.slice();

    const operator_fields = std.meta.fields(Operator);

    while (true) {
        // evaluate equation
        var result: InputEquation.Term = terms[0];
        for (operators, terms[1..]) |operator, term| {
            switch (operator) {
                .addition => { result += term; },
                .multiplication => { result *= term; },
            }
        }

        if (result == equation.result) {
            return true;
        }

        // calculate next combination
        for (0..operators.len) |operator_index| {
            const operator = &operators[operator_index];

            const current_value = @intFromEnum(operator.*);
            const next_value = (current_value + 1) % operator_fields.len;
            operator.* = @enumFromInt(next_value);

            if (next_value != 0) {
                break;
            }
        } else {
            // no more combinations
            return false;
        }
    }
}

test "validate_equation_part1" {
    const input_data =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, input_data);
    defer input.deinit(std.testing.allocator);

    const TestCase = struct {
        expected: bool,
        actual: bool,
    };

    const test_cases: []const TestCase = &.{
        .{ .expected = true,  .actual = validate_equation_part1(&input.equations[0]) },
        .{ .expected = true,  .actual = validate_equation_part1(&input.equations[1]) },
        .{ .expected = false, .actual = validate_equation_part1(&input.equations[2]) },
        .{ .expected = false, .actual = validate_equation_part1(&input.equations[3]) },
        .{ .expected = false, .actual = validate_equation_part1(&input.equations[4]) },
        .{ .expected = false, .actual = validate_equation_part1(&input.equations[5]) },
        .{ .expected = false, .actual = validate_equation_part1(&input.equations[6]) },
        .{ .expected = false, .actual = validate_equation_part1(&input.equations[7]) },
        .{ .expected = true,  .actual = validate_equation_part1(&input.equations[8]) },
    };

    for (test_cases) |test_case| {
        try std.testing.expectEqual(test_case.expected, test_case.actual);
    }
}

fn validate_equation_part2(equation: *const InputEquation) bool {
    const Operator = enum(u8) {
        addition,
        multiplication,
        concatenation,
    };

    const terms = equation.terms.constSlice();
    std.debug.assert(terms.len <= 16);

    var operators_array = std.BoundedArray(Operator, 16).init(0) catch unreachable;
    operators_array.appendNTimes(.addition, terms.len - 1) catch unreachable;
    const operators = operators_array.slice();

    const operator_fields = std.meta.fields(Operator);
    var concatenate_buffer: [256]u8 = undefined;

    while (true) {
        // evaluate equation
        var result: InputEquation.Term = terms[0];
        for (operators, terms[1..]) |operator, term| {
            switch (operator) {
                .addition => { result += term; },
                .multiplication => { result *= term; },
                .concatenation => {
                    const result_digits = std.fmt.bufPrint(&concatenate_buffer, "{d}{d}", .{ result, term }) catch unreachable;
                    result = std.fmt.parseInt(InputEquation.Term, result_digits, 10) catch unreachable;
                },
            }
        }

        if (result == equation.result) {
            return true;
        }

        // calculate next combination
        for (0..operators.len) |operator_index| {
            const operator = &operators[operator_index];

            const current_value = @intFromEnum(operator.*);
            const next_value = (current_value + 1) % operator_fields.len;
            operator.* = @enumFromInt(next_value);

            if (next_value != 0) {
                break;
            }
        } else {
            // no more combinations
            return false;
        }
    }
}

test "validate_equation_part2" {
    const input_data =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, input_data);
    defer input.deinit(std.testing.allocator);

    const TestCase = struct {
        expected: bool,
        actual: bool,
    };

    const test_cases: []const TestCase = &.{
        .{ .expected = true,  .actual = validate_equation_part2(&input.equations[0]) },
        .{ .expected = true,  .actual = validate_equation_part2(&input.equations[1]) },
        .{ .expected = false, .actual = validate_equation_part2(&input.equations[2]) },
        .{ .expected = true,  .actual = validate_equation_part2(&input.equations[3]) },
        .{ .expected = true,  .actual = validate_equation_part2(&input.equations[4]) },
        .{ .expected = false, .actual = validate_equation_part2(&input.equations[5]) },
        .{ .expected = true,  .actual = validate_equation_part2(&input.equations[6]) },
        .{ .expected = false, .actual = validate_equation_part2(&input.equations[7]) },
        .{ .expected = true,  .actual = validate_equation_part2(&input.equations[8]) },
    };

    for (test_cases) |test_case| {
        try std.testing.expectEqual(test_case.expected, test_case.actual);
    }
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !InputEquation.Term {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit(allocator);

    var total: InputEquation.Term = 0;
    for (input.equations) |*equation| {
        if (validate_equation_part1(equation)) {
            total += equation.result;
        }
    }

    return total;
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !InputEquation.Term {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit(allocator);

    var total: InputEquation.Term = 0;
    for (input.equations) |*equation| {
        if (validate_equation_part2(equation)) {
            total += equation.result;
        }
    }

    return total;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const total_part1 = try part1(allocator, input_data);

    try std.testing.expectEqual(12839601725877, total_part1);
    std.debug.print("total: {d}\n", .{total_part1});

    // part 2
    const total_part2 = try part2(allocator, input_data);

    // try std.testing.expectEqual(12839601725877, total_part2);
    std.debug.print("total: {d}\n", .{total_part2});
}
