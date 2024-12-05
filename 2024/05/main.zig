const std = @import("std");

const PageNumber = u8;
const PageNumberArrayListUnmanaged = std.ArrayListUnmanaged(PageNumber);
const PageRuleHashMapUnmanaged = std.AutoHashMapUnmanaged(PageNumber, PageNumberArrayListUnmanaged);

const ArrayRange = struct {
    start: usize,
    end: usize,
};

const ManualUpdateArrayListUnmanaged = std.ArrayListUnmanaged(ArrayRange);

const Input = struct {
    const Self = @This();

    page_before: PageRuleHashMapUnmanaged = undefined,
    page_after: PageRuleHashMapUnmanaged = undefined,

    manual_updates_pages: PageNumberArrayListUnmanaged = undefined,
    manual_updates_ranges: ManualUpdateArrayListUnmanaged = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        var page_before: PageRuleHashMapUnmanaged = .{};
        var page_after: PageRuleHashMapUnmanaged = .{};
        var manual_updates_pages: PageNumberArrayListUnmanaged = .{};
        var manual_updates_ranges: ManualUpdateArrayListUnmanaged = .{};

        errdefer {
            var page_before_iterator = page_before.valueIterator();
            while (page_before_iterator.next()) |page_numbers| {
                page_numbers.deinit(allocator);
            }

            var page_after_iterator = page_after.valueIterator();
            while (page_after_iterator.next()) |page_numbers| {
                page_numbers.deinit(allocator);
            }

            page_before.deinit(allocator);
            page_after.deinit(allocator);
            manual_updates_pages.deinit(allocator);
            manual_updates_ranges.deinit(allocator);
        }

        const blank_line_index = std.mem.indexOf(u8, input_data, "\n\n") orelse {
            return error.InvalidFormat;
        };

        var page_line_iterator = std.mem.tokenizeScalar(u8, input_data[0..blank_line_index], '\n');
        while (page_line_iterator.next()) |line| {
            const separator_index = std.mem.indexOfScalar(u8, line, '|') orelse {
                return error.InvalidFormat;
            };

            const first_page = try std.fmt.parseInt(PageNumber, line[0..separator_index], 10);
            const second_page = try std.fmt.parseInt(PageNumber, line[(separator_index + 1)..], 10);

            const before_entry = try page_before.getOrPutValue(allocator, first_page, .{});
            try before_entry.value_ptr.*.append(allocator, second_page);

            const after_entry = try page_after.getOrPutValue(allocator, second_page, .{});
            try after_entry.value_ptr.*.append(allocator, first_page);
        }

        var manual_line_iterator = std.mem.tokenizeScalar(u8, input_data[(blank_line_index + 1)..], '\n');
        while (manual_line_iterator.next()) |line| {
            const start_index = manual_updates_pages.items.len;

            var part_iterator = std.mem.tokenizeScalar(u8, line, ',');
            while (part_iterator.next()) |part| {
                const page = try std.fmt.parseInt(PageNumber, part, 10);
                try manual_updates_pages.append(allocator, page);
            }

            const end_index = manual_updates_pages.items.len;
            try manual_updates_ranges.append(allocator, .{ .start = start_index, .end = end_index });
        }

        self.* = .{
            .page_before = page_before,
            .page_after = page_after,
            .manual_updates_pages = manual_updates_pages,
            .manual_updates_ranges = manual_updates_ranges,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        var page_before_iterator = self.page_before.valueIterator();
        while (page_before_iterator.next()) |page_numbers| {
            page_numbers.deinit(allocator);
        }

        var page_after_iterator = self.page_after.valueIterator();
        while (page_after_iterator.next()) |page_numbers| {
            page_numbers.deinit(allocator);
        }

        self.page_before.deinit(allocator);
        self.page_after.deinit(allocator);
        self.manual_updates_pages.deinit(allocator);
        self.manual_updates_ranges.deinit(allocator);
    }

    pub fn manualSlice(self: *Self, manual_update: usize) []PageNumber {
        std.debug.assert(manual_update < self.manual_updates_ranges.items.len);
        const range = self.manual_updates_ranges.items[manual_update];
        return self.manual_updates_pages.items[range.start..range.end];
    }

    pub fn constManualSlice(self: Self, manual_update: usize) []const PageNumber {
        std.debug.assert(manual_update < self.manual_updates_ranges.items.len);
        const range = self.manual_updates_ranges.items[manual_update];
        return self.manual_updates_pages.items[range.start..range.end];
    }
};

test "input_parse" {
    const sample_input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, sample_input);
    defer input.deinit(std.testing.allocator);

    try std.testing.expectEqual(6, input.page_before.count());
    try std.testing.expectEqual(6, input.page_after.count());
    try std.testing.expectEqual(26, input.manual_updates_pages.items.len);
    try std.testing.expectEqual(6, input.manual_updates_ranges.items.len);

    try std.testing.expect(std.mem.eql(PageNumber, &.{ 13, 61, 47, 29, 53, 75 }, input.page_before.getPtr(97).?.items));
    try std.testing.expect(std.mem.eql(PageNumber, &.{ 47, 75, 61, 97 }, input.page_after.getPtr(53).?.items));

    try std.testing.expect(std.mem.eql(PageNumber, &.{ 75, 47, 61, 53, 29 }, input.constManualSlice(0)));
    try std.testing.expect(std.mem.eql(PageNumber, &.{ 97, 13, 75, 29, 47 }, input.constManualSlice(5)));
}

fn manual_update_valid(input: *const Input, manual_update: usize) bool {
    const pages = input.constManualSlice(manual_update);
    for (0..pages.len) |index| {
        const current_page = pages[index];

        const pages_before: []const PageNumber = if (input.page_before.get(current_page)) |page_array| page_array.items else &.{};
        for (pages[0..index]) |page| {
            if (std.mem.indexOfScalar(PageNumber, pages_before, page)) |_| {
                return false;
            }
        }

        const pages_after: []const PageNumber = if (input.page_after.get(current_page)) |page_array| page_array.items else &.{};
        for (pages[(index + 1)..]) |page| {
            if (std.mem.indexOfScalar(PageNumber, pages_after, page)) |_| {
                return false;
            }
        }
    }

    return true;
}

test "part1_example" {
    const sample_input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, sample_input);
    defer input.deinit(std.testing.allocator);

    // identify valid manual updates
    const update_valid_expected: [6]bool = .{
        true,
        true,
        true,
        false,
        false,
        false,
    };

    for (0..update_valid_expected.len) |index| {
        try std.testing.expectEqual(
            update_valid_expected[index],
            manual_update_valid(&input, index),
        );
    }

    // middle number sum
    // TODO: 143
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit(allocator);

    var total: usize = 0;
    for (0..input.manual_updates_ranges.items.len) |index| {
        if (manual_update_valid(&input, index)) {
            const manual_update = input.constManualSlice(index);

            std.debug.assert(manual_update.len % 2 == 1);
            const middle_page = manual_update[@divFloor(manual_update.len, 2)];

            total += @intCast(middle_page);
        }
    }

    return total;
}

fn manual_update_less_than(input: *const Input, lhs: PageNumber, rhs: PageNumber) bool {
    const pages_before = if (input.page_before.get(lhs)) |pages_array| pages_array.items else &.{};
    const less_than = if (std.mem.indexOfScalar(PageNumber, pages_before, rhs)) |_| true else false;

    return less_than;
}

fn manual_update_fix(input: *Input, manual_update: usize) void {
    const pages = input.manualSlice(manual_update);
    std.sort.block(
        PageNumber,
        pages,
        input,
        manual_update_less_than,
    );
}

test "part2_example" {
    const sample_input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, sample_input);
    defer input.deinit(std.testing.allocator);

    // fix manual updates
    manual_update_fix(&input, 3);
    try std.testing.expect(std.mem.eql(PageNumber, input.constManualSlice(3), &.{ 97, 75, 47, 61, 53 }));

    manual_update_fix(&input, 4);
    try std.testing.expect(std.mem.eql(PageNumber, input.constManualSlice(4), &.{ 61, 29, 13 }));

    manual_update_fix(&input, 5);
    try std.testing.expect(std.mem.eql(PageNumber, input.constManualSlice(5), &.{ 97, 75, 47, 29, 13 }));

    // middle number sum
    // TODO: 123
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit(allocator);

    var total: usize = 0;
    for (0..input.manual_updates_ranges.items.len) |index| {
        if (manual_update_valid(&input, index)) {
            continue;
        }

        manual_update_fix(&input, index);
        const manual_update = input.constManualSlice(index);

        std.debug.assert(manual_update.len % 2 == 1);
        const middle_page = manual_update[@divFloor(manual_update.len, 2)];

        total += @intCast(middle_page);
    }

    return total;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const total_valid = try part1(allocator, input_data);

    std.debug.assert(total_valid == 7365);
    std.debug.print("total valid: {d}\n", .{total_valid});

    // part 2
    const total_invalid = try part2(allocator, input_data);

    std.debug.assert(total_invalid == 5770);
    std.debug.print("total invalid: {d}\n", .{total_invalid});
}
