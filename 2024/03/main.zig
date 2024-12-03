const std = @import("std");

const MultiplyOperands = struct {
    a: u32,
    b: u32,
};

const Instruction = union(enum) {
    do: void,
    dont: void,
    multiply: MultiplyOperands,
};

const ParseResult = struct {
    index: usize,
    instruction: Instruction,
};

fn parse_mul(data: []const u8) !ParseResult {
    if (data.len < 8) {
        return error.InvalidFormat;
    }

    if (!std.mem.eql(u8, data[0..4], "mul(")) {
        return error.InvalidFormat;
    }

    var index: usize = 4;
    while (index < data.len and std.ascii.isDigit(data[index])) {
        index += 1;
    }

    if (index - 4 > 3) {
        return error.ValueTooLarge;
    }

    const first_value = std.fmt.parseInt(u32, data[4..index], 10) catch {
        return error.InvalidFormat;
    };

    if (data[index] != ',') {
        return error.InvalidFormat;
    }

    index += 1;
    const separator_index = index;

    while (index < data.len and std.ascii.isDigit(data[index])) {
        index += 1;
    }

    if (index - separator_index > 3) {
        return error.ValueTooLarge;
    }

    const second_value = std.fmt.parseInt(u32, data[separator_index..index], 10) catch {
        return error.InvalidFormat;
    };

    if (data[index] != ')') {
        return error.InvalidFormat;
    }

    return .{
        .index = index + 1,
        .instruction = Instruction{
            .multiply = .{
                .a = first_value,
                .b = second_value,
            },
        },
    };
}

test "parse_mul" {
    const data_valid = "mul(123,456)";
    const result = try parse_mul(data_valid);
    try std.testing.expectEqual(result.index, data_valid.len);
    try std.testing.expectEqual(result.instruction, Instruction{ .multiply = .{ .a = 123, .b = 456 } });

    const data_values_too_large = "mul(1234,5)";
    try std.testing.expectError(error.ValueTooLarge, parse_mul(data_values_too_large));
}

fn parse_instruction(data: []const u8) !ParseResult {
    const do_instruction = "do()";
    if (data.len >= do_instruction.len and std.mem.eql(u8, data[0..do_instruction.len], do_instruction)) {
        return .{
            .index = do_instruction.len,
            .instruction = Instruction.do,
        };
    }

    const dont_instruction = "don't()";
    if (data.len >= dont_instruction.len and std.mem.eql(u8, data[0..dont_instruction.len], dont_instruction)) {
        return .{
            .index = dont_instruction.len,
            .instruction = Instruction.dont,
        };
    }

    return try parse_mul(data);
}

test "parse_instruction" {
    const data_do = "do()";
    const result_do = try parse_instruction(data_do);
    try std.testing.expectEqual(result_do.index, data_do.len);
    try std.testing.expectEqual(result_do.instruction, Instruction.do);

    const data_dont = "don't()";
    const result_dont = try parse_instruction(data_dont);
    try std.testing.expectEqual(result_dont.index, data_dont.len);
    try std.testing.expectEqual(result_dont.instruction, Instruction.dont);
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    _ = allocator;

    var index = std.mem.indexOf(u8, input_data, "mul(") orelse {
        // no multiply instructions at all
        return 0;
    };

    var multiply_sum: usize = 0;
    while (index < input_data.len) {
        const result = parse_mul(input_data[index..]) catch {
            const next_index = std.mem.indexOfPos(u8, input_data, index + 1, "mul(") orelse {
                // no multiply instructions
                break;
            };

            index = next_index;
            continue;
        };

        index += result.index;
        switch (result.instruction) {
            .multiply => |operands| {
                multiply_sum += @as(usize, @intCast(operands.a)) * @as(usize, @intCast(operands.b));
            },
            else => unreachable,
        }
    }

    return multiply_sum;
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    _ = allocator;

    var multiply_sum: usize = 0;
    var multiply_enabled: bool = true;

    var index: usize = 0;
    while (index < input_data.len) {
        const result = parse_instruction(input_data[index..]) catch {
            index += 1;
            continue;
        };

        index += result.index;
        switch (result.instruction) {
            .multiply => |operands| {
                if (multiply_enabled) {
                    multiply_sum += @as(usize, @intCast(operands.a)) * @as(usize, @intCast(operands.b));
                }
            },
            .do => {
                multiply_enabled = true;
            },
            .dont => {
                multiply_enabled = false;
            }
        }
    }

    return multiply_sum;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const result_all = try part1(allocator, input_data);

    std.debug.assert(result_all == 178794710);
    std.debug.print("result all: {d}\n", .{ result_all });

    // part 2
    const result_conditional = try part2(allocator, input_data);

    std.debug.assert(result_conditional == 76729637);
    std.debug.print("result conditional: {d}\n", .{ result_conditional });
}
