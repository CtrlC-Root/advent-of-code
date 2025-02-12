const std = @import("std");

pub fn part1(allocator: std.mem.Allocator, input_data: []const u8) !i64 {
    _ = allocator;
    _ = input_data;

    return 0;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const part1_result = try part1(allocator, input_data);

    // try std.testing.expectEqual(14869099597, part1_result);
    std.debug.print("Part1: {d}\n", .{part1_result});

    // part 2
    // const price_sides = try part2(allocator, input_data);

    // try std.testing.expectEqual(897612, price_sides);
    // std.debug.print("price sides: {d}\n", .{price_sides});
}
