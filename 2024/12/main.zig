const std = @import("std");

const Position = struct {
    const Self = @This();

    x: usize,
    y: usize,

    pub fn equals(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const Map = struct {
    const Self = @This();
    const Data = u8;

    allocator: std.mem.Allocator = undefined,
    width: usize = undefined,
    height: usize = undefined,
    data: []Data = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, width: usize, height: usize, default: Data) !void {
        const data = try allocator.alloc(Data, width * height);
        for (0..(width * height)) |index| {
            data[index] = default;
        }

        self.* = .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .data = data,
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.data);
    }

    pub fn get(self: Self, x: usize, y: usize) Data {
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);

        const index = (y * self.width) + x;
        return self.data[index];
    }

    pub fn set(self: *Self, x: usize, y: usize, value: Data) void {
        std.debug.assert(x < self.width);
        std.debug.assert(y < self.height);

        const index = (y * self.width) + x;
        self.data[index] = value;
    }

    pub fn containsPosition(self: Self, position: Position) bool {
        return (position.x < self.width and position.y < self.height);
    }

    pub fn getPosition(self: Self, position: Position) ?Data {
        return if (self.containsPosition(position)) self.get(position.x, position.y) else null;
    }

    pub fn setPosition(self: *Self, position: Position, value: Data) void {
        std.debug.assert(self.containsPosition(position));
        self.set(position.x, position.y, value);
    }
};

fn parse_map(allocator: std.mem.Allocator, input_data: []const u8) !Map {
    // look for newlines to determine map dimensions
    const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
    const index_first_newline = std.mem.indexOfScalar(u8, trimmed_input, '\n') orelse {
        return error.InvalidFormat;
    };

    const newlines = std.mem.count(u8, trimmed_input, &.{'\n'});

    std.debug.assert(index_first_newline > 0 and index_first_newline < 256);
    std.debug.assert(newlines > 0 and newlines < 256);

    // create map
    var map: Map = .{};
    try map.init(allocator, index_first_newline, newlines + 1, 0);
    errdefer map.deinit();

    // load map data
    var row: usize = 0;
    var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');

    while (line_iterator.next()) |line| {
        for (0..line.len) |column| {
            const value = line[column];
            map.set(column, row, value);
        }

        row += 1;
    }

    return map;
}

test "parse_map" {
    const input_data =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    try std.testing.expectEqual(4, map.width);
    try std.testing.expectEqual(4, map.height);
}

const RegionUnmanaged = struct {
    const Self = @This();

    data: Map.Data,
    border: usize,
    positions: []Position,

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
    }
};

fn detect_region(
    allocator: std.mem.Allocator,
    map: *const Map,
    initial_position: Position,
) !RegionUnmanaged {
    const region_data = map.getPosition(initial_position) orelse unreachable;

    var search_positions = std.ArrayList(Position).init(allocator);
    defer search_positions.deinit();

    var found_positions = std.AutoHashMap(Position, usize).init(allocator);
    defer found_positions.deinit();

    var neighbor_positions = try std.BoundedArray(Position, 4).init(0);

    try search_positions.append(initial_position);
    while (search_positions.items.len > 0) {
        const position = search_positions.orderedRemove(0);
        if (found_positions.contains(position)) {
            continue;
        }

        var position_borders: usize = 0;
        neighbor_positions.resize(0) catch unreachable;

        if (position.x > 0) {
            neighbor_positions.append(.{ .x = position.x - 1, .y = position.y }) catch unreachable;
        } else {
            position_borders += 1;
        }

        if (position.x < (map.width - 1)) {
            neighbor_positions.append(.{ .x = position.x + 1, .y = position.y }) catch unreachable;
        } else {
            position_borders += 1;
        }

        if (position.y > 0) {
            neighbor_positions.append(.{ .x = position.x, .y = position.y - 1 }) catch unreachable;
        } else {
            position_borders += 1;
        }

        if (position.y < (map.height - 1)) {
            neighbor_positions.append(.{ .x = position.x, .y = position.y + 1 }) catch unreachable;
        } else {
            position_borders += 1;
        }

        for (neighbor_positions.constSlice()) |neighbor_position| {
            const neighbor_data = map.getPosition(neighbor_position) orelse unreachable;
            if (neighbor_data == region_data) {
                try search_positions.append(neighbor_position);
            } else {
                position_borders += 1;
            }
        }

        try found_positions.put(position, position_borders);
    }

    var region_positions = std.ArrayList(Position).init(allocator);
    defer region_positions.deinit();

    var region_border: usize = 0;

    var iterator = found_positions.iterator();
    while (iterator.next()) |entry| {
        try region_positions.append(entry.key_ptr.*);
        region_border += entry.value_ptr.*;
    }

    return .{
        .data = region_data,
        .border = region_border,
        .positions = try region_positions.toOwnedSlice(),
    };
}

test "detect_region" {
    const input_data =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const region = try detect_region(std.testing.allocator, &map, .{ .x = 0, .y = 0 });
    defer region.deinit(std.testing.allocator);

    try std.testing.expectEqual('A', region.data);
    try std.testing.expectEqual(4, region.positions.len);
    try std.testing.expectEqual(10, region.border);
}

const RegionsUnamanaged = struct {
    const Self = @This();

    regions: []RegionUnmanaged,

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        for (self.regions) |region| {
            region.deinit(allocator);
        }

        allocator.free(self.regions);
    }
};

fn detect_regions(allocator: std.mem.Allocator, map: *const Map) !RegionsUnamanaged {
    var regions = std.ArrayList(RegionUnmanaged).init(allocator);
    errdefer {
        for (regions.items) |region| {
            region.deinit(allocator);
        }

        regions.deinit();
    }

    var position_searched = std.AutoHashMap(Position, bool).init(allocator);
    defer position_searched.deinit();

    for (0..map.width) |x| {
        for (0..map.height) |y| {
            const position = Position{ .x = x, .y = y };
            if (position_searched.get(position)) |_| {
                continue;
            }

            const region = try detect_region(allocator, map, position);
            errdefer region.deinit(allocator);

            try regions.append(region);
            for (region.positions) |region_position| {
                try position_searched.put(region_position, true);
            }
        }
    }

    return .{
        .regions = try regions.toOwnedSlice(),
    };
}

test "detect_regions_part1_example1" {
    const input_data =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const regions = try detect_regions(std.testing.allocator, &map);
    defer regions.deinit(std.testing.allocator);

    const RegionData = struct {
        area: usize,
        border: usize,
    };

    var expected_regions = std.AutoHashMap(Map.Data, RegionData).init(std.testing.allocator);
    defer expected_regions.deinit();

    try expected_regions.put('A', .{ .area = 4, .border = 10 });
    try expected_regions.put('B', .{ .area = 4, .border = 8 });
    try expected_regions.put('C', .{ .area = 4, .border = 10 });
    try expected_regions.put('D', .{ .area = 1, .border = 4 });
    try expected_regions.put('E', .{ .area = 3, .border = 8 });

    try std.testing.expectEqual(expected_regions.count(), regions.regions.len);
    for (regions.regions) |found_region| {
        const region_data = expected_regions.get(found_region.data) orelse {
            return error.InvalidFoundRegion;
        };

        try std.testing.expectEqual(region_data.area, found_region.positions.len);
        try std.testing.expectEqual(region_data.border, found_region.border);
    }
}

test "detect_regions_part1_example2" {
    const input_data =
        \\OOOOO
        \\OXOXO
        \\OOOOO
        \\OXOXO
        \\OOOOO
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const regions = try detect_regions(std.testing.allocator, &map);
    defer regions.deinit(std.testing.allocator);

    const RegionData = struct {
        area: usize,
        border: usize,
    };

    var expected_regions = std.AutoHashMap(Map.Data, RegionData).init(std.testing.allocator);
    defer expected_regions.deinit();

    try expected_regions.put('O', .{ .area = 21, .border = 36 });
    try expected_regions.put('X', .{ .area = 1, .border = 4 });

    try std.testing.expectEqual(5, regions.regions.len);
    for (regions.regions) |found_region| {
        const region_data = expected_regions.get(found_region.data) orelse {
            return error.InvalidFoundRegion;
        };

        try std.testing.expectEqual(region_data.area, found_region.positions.len);
        try std.testing.expectEqual(region_data.border, found_region.border);
    }
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    const map = try parse_map(allocator, input_data);
    defer map.deinit();

    const regions = try detect_regions(allocator, &map);
    defer regions.deinit(allocator);

    var total_price: usize = 0;
    for (regions.regions) |region| {
        total_price += (region.positions.len * region.border);
    }

    return total_price;
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const price = try part1(allocator, input_data);

    try std.testing.expectEqual(1449902, price);
    std.debug.print("price: {d}\n", .{price});

    // // part 2
    // const checksum_files = try part2(allocator, input_data);

    // try std.testing.expectEqual(6460170593016, checksum_files);
    // std.debug.print("checksum files: {d}\n", .{checksum_files});
}
