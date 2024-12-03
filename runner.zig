const std = @import("std");

const solution_2024_01 = @import("2024/01/main.zig");
const solution_2024_02 = @import("2024/02/main.zig");
const solution_2024_03 = @import("2024/03/main.zig");

test {
    std.testing.refAllDecls(@This());
}

const Solution = struct {
    const Self = @This();

    year: u16,
    day: u8,
    main: *const fn () anyerror!void,
};

const solutions = std.StaticStringMap(Solution).initComptime(&.{
    .{ "2024-01", .{ .year = 2024, .day = 1, .main = &solution_2024_01.main }},
    .{ "2024-02", .{ .year = 2024, .day = 2, .main = &solution_2024_02.main }},
    .{ "2024-03", .{ .year = 2024, .day = 3, .main = &solution_2024_03.main }},
});

pub fn main() !void {
    // create the general purpose allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    // XXX
    var argument_iterator = try std.process.argsWithAllocator(allocator);
    defer argument_iterator.deinit();

    const program_name = argument_iterator.next() orelse {
        std.debug.print("program name not found in arguments\n", .{});
        return error.InvalidArguments;
    };

    _ = program_name;

    const solution_name = argument_iterator.next() orelse {
        std.debug.print("solution name not found in arguments\n", .{});
        return error.InvalidArguments;
    };

    std.debug.assert(argument_iterator.next() == null);

    // XXX
    const solution = solutions.get(solution_name) orelse {
        std.debug.print("invalid solution: {s}\n", .{ solution_name });
        return error.InvalidSolution;
    };

    try solution.main();
}
