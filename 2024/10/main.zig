const std = @import("std");

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    _ = allocator;
    _ = input_data;

    std.debug.print("hello, world!\n", .{});

    // // part 1
    // const checksum_blocks = try part1(allocator, input_data);

    // try std.testing.expectEqual(6430446922192, checksum_blocks);
    // std.debug.print("checksum blocks: {d}\n", .{checksum_blocks});

    // // part 2
    // const checksum_files = try part2(allocator, input_data);

    // try std.testing.expectEqual(6460170593016, checksum_files);
    // std.debug.print("checksum files: {d}\n", .{checksum_files});
}
