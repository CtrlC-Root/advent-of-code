const std = @import("std");

const RangeMap = struct {
    const Self = @This();

    const Value = i64;
    const Range = struct {
        destination: Self.Value,
        source: Self.Value,
        length: Self.Value,
    };

    name: []const u8 = undefined,
    ranges: []Range = undefined,

    pub fn initWithInput(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        var ranges = std.ArrayList(Self.Range).init(allocator);
        errdefer ranges.deinit();

        var line_iterator = std.mem.tokenizeScalar(u8, input_data, '\n');
        const first_line = line_iterator.next() orelse return error.InvalidSyntax;
        if (!std.mem.endsWith(u8, first_line, " map:")) {
            return error.InvalidSyntax;
        }

        while (line_iterator.next()) |line| {
            var range: Self.Range = undefined;
            var number_iterator = std.mem.tokenizeScalar(u8, line, ' ');

            const first_value = number_iterator.next() orelse return error.InvalidSyntax;
            range.destination = try std.fmt.parseInt(Self.Value, first_value, 10);

            const second_value = number_iterator.next() orelse return error.InvalidSyntax;
            range.source = try std.fmt.parseInt(Self.Value, second_value, 10);

            const third_value = number_iterator.next() orelse return error.InvalidSyntax;
            range.length = try std.fmt.parseInt(Self.Value, third_value, 10);

            if (number_iterator.next()) |_| {
                return error.InvalidSyntax;
            }

            try ranges.append(range);
        }

        const owned_name = try allocator.dupe(u8, first_line[0..(first_line.len - 5)]);
        errdefer allocator.free(owned_name);

        const owned_ranges = try ranges.toOwnedSlice();
        errdefer allocator.free(owned_ranges);

        self.* = .{
            .name = owned_name,
            .ranges = owned_ranges,
        };
    }

    pub fn transform(self: Self, input: Self.Value) Self.Value {
        for (self.ranges) |range| {
            if (input >= range.source and input < (range.source + range.length)) {
                return range.destination + (input - range.source);
            }
        }

        return input;
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.ranges);
    }
};

test "RangeMap.initWithInput()" {
    const sample_input =
        \\sample input map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
    ;

    var range_map: RangeMap = .{};
    try range_map.initWithInput(std.testing.allocator, sample_input);
    defer range_map.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u8, range_map.name, "sample input");
    try std.testing.expectEqualSlices(
        RangeMap.Range,
        range_map.ranges,
        &.{
            .{ .destination = 0, .source = 15, .length = 37 },
            .{ .destination = 37, .source = 52, .length = 2 },
            .{ .destination = 39, .source = 0, .length = 15 },
        },
    );
}

const Input = struct {
    const Self = @This();

    seeds: []RangeMap.Value = undefined,
    ranges: std.StringHashMapUnmanaged(RangeMap) = undefined,

    pub fn initWithInput(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        var section_iterator = std.mem.tokenizeSequence(u8, std.mem.trim(u8, input_data, &std.ascii.whitespace), "\n\n");
        const first_section = section_iterator.next() orelse return error.InvalidSyntax;
        if (!std.mem.startsWith(u8, first_section, "seeds: ")) {
            return error.InvalidSyntax;
        }

        var seeds = std.ArrayList(RangeMap.Value).init(allocator);
        errdefer seeds.deinit();

        var value_iterator = std.mem.tokenizeScalar(u8, first_section[7..], ' ');
        while (value_iterator.next()) |value| {
            const seed = try std.fmt.parseInt(RangeMap.Value, value, 10);
            try seeds.append(seed);
        }

        var ranges: std.StringHashMapUnmanaged(RangeMap) = .empty;
        errdefer {
            var range_iterator = ranges.valueIterator();
            while (range_iterator.next()) |range| {
                range.deinit(allocator);
            }

            ranges.deinit(allocator);
        }

        while (section_iterator.next()) |section_data| {
            var range: RangeMap = .{};
            try range.initWithInput(allocator, section_data);
            errdefer range.deinit(allocator);

            try ranges.putNoClobber(allocator, range.name, range);
        }

        const owned_seeds = try seeds.toOwnedSlice();
        self.* = .{
            .seeds = owned_seeds,
            .ranges = ranges,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.seeds);

        var range_iterator = self.ranges.valueIterator();
        while (range_iterator.next()) |range| {
            range.deinit(allocator);
        }

        self.ranges.deinit(allocator);
    }
};

test "Input.initWithInput" {
    const sample_input =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    var input: Input = .{};
    try input.initWithInput(std.testing.allocator, sample_input);
    defer input.deinit(std.testing.allocator);

    const expected_range_names: []const []const u8 = &.{
        "seed-to-soil",
        "soil-to-fertilizer",
        "fertilizer-to-water",
        "water-to-light",
        "light-to-temperature",
        "temperature-to-humidity",
        "humidity-to-location",
    };

    for (expected_range_names) |expected_range_name| {
        try std.testing.expect(input.ranges.contains(expected_range_name));
    }
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !i64 {
    var input: Input = .{};
    try input.initWithInput(allocator, input_data);
    defer input.deinit(allocator);

    const range_names: []const []const u8 = &.{
        "seed-to-soil",
        "soil-to-fertilizer",
        "fertilizer-to-water",
        "water-to-light",
        "light-to-temperature",
        "temperature-to-humidity",
        "humidity-to-location",
    };

    var lowest_location: RangeMap.Value = std.math.maxInt(RangeMap.Value);
    for (input.seeds) |seed| {
        var value = seed;
        for (range_names) |range_name| {
            const range = input.ranges.getPtr(range_name) orelse return error.InvalidInput;
            value = range.transform(value);
        }

        lowest_location = @min(lowest_location, value);
    }

    return lowest_location;
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !i64 {
    var input: Input = .{};
    try input.initWithInput(allocator, input_data);
    defer input.deinit(allocator);

    const range_names: []const []const u8 = &.{
        "seed-to-soil",
        "soil-to-fertilizer",
        "fertilizer-to-water",
        "water-to-light",
        "light-to-temperature",
        "temperature-to-humidity",
        "humidity-to-location",
    };

    var lowest_location: RangeMap.Value = std.math.maxInt(RangeMap.Value);
    for (0..@divFloor(input.seeds.len, 2)) |index| {
        const start = input.seeds[index * 2];
        const length = input.seeds[(index * 2) + 1];

        for (@intCast(start)..@intCast(start + length)) |seed| {
            var value: RangeMap.Value = @intCast(seed);
            for (range_names) |range_name| {
                const range = input.ranges.getPtr(range_name) orelse return error.InvalidInput;
                value = range.transform(value);
            }

            lowest_location = @min(lowest_location, value);
        }
    }

    return lowest_location;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const part1_result = try part1(allocator, input_data);

    try std.testing.expectEqual(51580674, part1_result);
    std.debug.print("part1: {d}\n", .{part1_result});

    // part 2
    const part2_result = try part2(allocator, input_data);

    try std.testing.expectEqual(99751240, part2_result);
    std.debug.print("part2 total: {d}\n", .{part2_result});
}
