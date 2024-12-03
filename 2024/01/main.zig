const std = @import("std");

const LocationId = u32;
const LocationIdArrayList = std.ArrayListUnmanaged(LocationId);

fn parse_line(data: []const u8) ![2]LocationId {
    // retrieve exactly two non-space slices from the line data
    var entry_iterator = std.mem.tokenizeScalar(u8, data, ' ');
    const first_entry = entry_iterator.next() orelse {
        return error.InvalidFormat;
    };

    const second_entry = entry_iterator.next() orelse {
        return error.InvalidFormat;
    };

    std.debug.assert(entry_iterator.peek() == null);

    // convert slices to IDs
    const first_id = try std.fmt.parseInt(LocationId, first_entry, 10);
    const second_id = try std.fmt.parseInt(LocationId, second_entry, 10);

    // done
    return .{ first_id, second_id };
}

test "parse_line" {
    const sample_line = "81510   22869";
    const correct_ids: [2]LocationId = .{ 81510, 22869 };
    const parsed_ids = try parse_line(sample_line);
    try std.testing.expectEqual(correct_ids, parsed_ids);
}

const Input = struct {
    const Self = @This();

    allocator: std.mem.Allocator = undefined,
    left_ids: LocationIdArrayList = undefined,
    right_ids: LocationIdArrayList = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, data: []const u8) !usize {
        var left_ids: LocationIdArrayList = .{};
        var right_ids: LocationIdArrayList = .{};

        errdefer {
            left_ids.deinit(allocator);
            right_ids.deinit(allocator);
        }

        // parse input data
        var line_iterator = std.mem.tokenizeScalar(u8, data, '\n');
        while (line_iterator.next()) |line| {
            const line_ids = try parse_line(line);
            try left_ids.append(allocator, line_ids[0]);
            try right_ids.append(allocator, line_ids[1]);
        }

        std.debug.assert(left_ids.items.len == right_ids.items.len);

        // initialize input data struct
        self.* = .{
            .allocator = allocator,
            .left_ids = left_ids,
            .right_ids = right_ids,
        };

        // return total number of loaded IDs
        return self.left_ids.items.len;
    }

    pub fn deinit(self: *Self) void {
        self.left_ids.deinit(self.allocator);
        self.right_ids.deinit(self.allocator);
    }
};

test "input" {
    const sample_lines =
        \\41226   69190
        \\89318   10100
    ;

    var input: Input = .{};
    const loaded_ids = try input.init(std.testing.allocator, sample_lines);
    defer input.deinit();

    try std.testing.expectEqual(loaded_ids, 2);
    try std.testing.expectEqual(input.left_ids.items[0], 41226);
    try std.testing.expectEqual(input.left_ids.items[1], 89318);
    try std.testing.expectEqual(input.right_ids.items[0], 69190);
    try std.testing.expectEqual(input.right_ids.items[1], 10100);
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    // load input data
    var input: Input = .{};
    const loaded_ids = try input.init(allocator, input_data);
    defer input.deinit();

    std.debug.assert(loaded_ids == 1000);

    // sort each list of IDs in ascending order
    std.mem.sort(LocationId, input.left_ids.items, {}, comptime std.sort.asc(LocationId));
    std.mem.sort(LocationId, input.right_ids.items, {}, comptime std.sort.asc(LocationId));

    // calculate total difference between the two lists
    var difference_sum: usize = 0;
    for (input.left_ids.items, input.right_ids.items) |left_id, right_id| {
        const smallest = @min(left_id, right_id);
        const largest = @max(left_id, right_id);
        difference_sum += @intCast(largest - smallest);
    }

    return difference_sum;
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    // load input data
    var input: Input = .{};
    const loaded_ids = try input.init(allocator, input_data);
    defer input.deinit();

    std.debug.assert(loaded_ids == 1000);

    // calculate total similarity between the two lists
    var similarity_sum: usize = 0;
    for (input.left_ids.items) |left_id| {
        const right_ids_count = std.mem.count(LocationId, input.right_ids.items, &.{ left_id });
        similarity_sum += @intCast(left_id * right_ids_count);
    }

    return similarity_sum;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part1
    const difference = try part1(allocator, input_data);

    std.debug.assert(difference == 3574690);
    std.debug.print("total difference: {}\n", .{ difference });

    // part2
    const similarity = try part2(allocator, input_data);

    std.debug.assert(similarity == 22565391);
    std.debug.print("total similarity: {}\n", .{ similarity });
}
