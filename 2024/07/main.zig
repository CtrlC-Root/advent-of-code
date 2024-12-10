const std = @import("std");

const InputEquation = struct {
    const Self = @This();
    const Term = i64;
    const TermArray = std.BoundedArray(Term, 8);

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

// fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
//     var input: Input = .{};
//     try input.init(allocator, input_data);
//     defer input.deinit(allocator);

//     var total: isize = 0;
//     for (input.equations) |equation| {
//         if (solve_equation(equation)) {
//             total += equation.result;
//         }
//     }

//     return total;
// }

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    _ = allocator;
    _ = input_data;
    std.debug.print("hello, world!\n", .{});

    // part 1
    // const total = try part1(allocator, input_data);

    // try std.testing.expectEqual(1111, total);
    // std.debug.print("total: {d}\n", .{total});

    // part 2
    // const possible_loops = try part2(allocator, input_data);

    // try std.testing.expectEqual(2162, possible_loops);
    // std.debug.print("possible loops: {d}\n", .{possible_loops});
}
