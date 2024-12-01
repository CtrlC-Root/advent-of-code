const std = @import("std");

const input_data = @embedFile("./input");
const LocationID = u32;

fn parse_line(line_data: []const u8) ![2]LocationID {
    // retrieve exactly two non-space slices from the line data
    var entry_iterator = std.mem.tokenizeScalar(u8, line_data, ' ');
    const first_entry = entry_iterator.next() orelse {
        return error.InvalidFormat;
    };

    const second_entry = entry_iterator.next() orelse {
        return error.InvalidFormat;
    };

    std.debug.assert(entry_iterator.peek() == null);

    // convert slices to IDs
    const first_id = try std.fmt.parseInt(LocationID, first_entry, 10);
    const second_id = try std.fmt.parseInt(LocationID, second_entry, 10);

    // done
    return .{ first_id, second_id };
}

test "parse_line" {
    const correct_line = "81510   22869";
    const correct_ids: [2]LocationID = .{ 81510, 22869 };
    const parsed_ids = try parse_line(correct_line);
    try std.testing.expectEqual(correct_ids, parsed_ids);
}

pub fn main() !void {
    // create the general purpose allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    // load input data
    var left_ids = std.ArrayList(LocationID).init(allocator);
    defer left_ids.deinit();

    var right_ids = std.ArrayList(LocationID).init(allocator);
    defer right_ids.deinit();

    var line_iterator = std.mem.tokenizeScalar(u8, input_data, '\n');
    while (line_iterator.next()) |line| {
        const line_ids = try parse_line(line);
        try left_ids.append(line_ids[0]);
        try right_ids.append(line_ids[1]);
    }

    std.debug.assert(left_ids.items.len == right_ids.items.len);
    std.debug.print("loaded {} location IDs\n", .{ left_ids.items.len });

    // PART1
    std.mem.sort(LocationID, left_ids.items, {}, comptime std.sort.asc(LocationID));
    std.mem.sort(LocationID, right_ids.items, {}, comptime std.sort.asc(LocationID));

    var difference_sum: usize = 0;
    for (0..left_ids.items.len) |index| {
        const smallest = @min(left_ids.items[index], right_ids.items[index]);
        const largest = @max(left_ids.items[index], right_ids.items[index]);
        difference_sum += @intCast(largest - smallest);
    }

    std.debug.print("total difference: {}\n", .{ difference_sum });

    // PART2
    var similarity_sum: usize = 0;
    for (left_ids.items) |left_id| {
        const right_ids_count = std.mem.count(LocationID, right_ids.items, &.{ left_id });
        similarity_sum += @intCast(left_id * right_ids_count);
    }

    std.debug.print("total similarity: {}\n", .{ similarity_sum });
}
