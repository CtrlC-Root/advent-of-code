const std = @import("std");

const input_data = @embedFile("input");

const ParseResult = struct {
    index: usize,
    a: u32,
    b: u32,
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
        .a = first_value,
        .b = second_value,
    };
}

test "parse_mul" {
    const data_valid = "mul(123,456)";
    const result = try parse_mul(data_valid);
    try std.testing.expectEqual(result.index, data_valid.len);
    try std.testing.expectEqual(result.a, 123);
    try std.testing.expectEqual(result.b, 456);

    const data_values_too_large = "mul(1234,5)";
    try std.testing.expectError(error.ValueTooLarge, parse_mul(data_values_too_large));
}

fn part1(allocator: std.mem.Allocator) !usize {
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
        multiply_sum += @as(usize, @intCast(result.a)) * @as(usize, @intCast(result.b));
    }

    return multiply_sum;
}

pub fn main() !void {
    // create the general purpose allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    // part 1
    const result = try part1(allocator);

    std.debug.assert(result == 178794710);
    std.debug.print("result: {d}\n", .{ result });

    // part 2
    // TODO
}
