const std = @import("std");

const Direction = enum {
    north,
    east,
    south,
    west,
};

const Position = struct {
    const Self = @This();

    x: isize,
    y: isize,

    pub fn equals(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn getNeighbor(self: Self, direction: Direction) Position {
        return switch (direction) {
            .north => .{ .x = self.x, .y = self.y - 1 },
            .south => .{ .x = self.x, .y = self.y + 1 },
            .east => .{ .x = self.x + 1, .y = self.y },
            .west => .{ .x = self.x - 1, .y = self.y },
        };
    }
};

const Map = struct {
    const Self = @This();
    const Data = u8;
    const CrossNeighborPositionArray = std.BoundedArray(Position, 4);

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
        return (position.x >= 0 and position.x < self.width and position.y >= 0 and position.y < self.height);
    }

    pub fn getPosition(self: Self, position: Position) ?Data {
        return if (self.containsPosition(position)) self.get(@intCast(position.x), @intCast(position.y)) else null;
    }

    pub fn setPosition(self: *Self, position: Position, value: Data) void {
        std.debug.assert(self.containsPosition(position));
        self.set(@intCast(position.x), @intCast(position.y), value);
    }

    pub fn crossNeighbors(self: Self, position: Position) CrossNeighborPositionArray {
        std.debug.assert(self.containsPosition(position));
        var neighbors = CrossNeighborPositionArray.init(0) catch unreachable;

        // north
        if (position.y > 0) {
            neighbors.append(position.getNeighbor(.north)) catch unreachable;
        }

        // south
        if (position.y < (self.height - 1)) {
            neighbors.append(position.getNeighbor(.south)) catch unreachable;
        }

        // west
        if (position.x > 0) {
            neighbors.append(position.getNeighbor(.west)) catch unreachable;
        }

        // east
        if (position.x < (self.width - 1)) {
            neighbors.append(position.getNeighbor(.east)) catch unreachable;
        }

        return neighbors;
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
    border_positions: []Position,
    interior_positions: []Position,

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.border_positions);
        allocator.free(self.interior_positions);
    }

    pub fn area(self: Self) usize {
        return self.border_positions.len + self.interior_positions.len;
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

    try search_positions.append(initial_position);
    while (search_positions.items.len > 0) {
        const position = search_positions.orderedRemove(0);
        if (found_positions.contains(position)) {
            continue;
        }

        const neighbors = map.crossNeighbors(position);
        const neighbor_positions = neighbors.constSlice();
        var position_borders: usize = 4 - neighbor_positions.len;

        for (neighbor_positions) |neighbor_position| {
            const neighbor_data = map.getPosition(neighbor_position) orelse unreachable;
            if (neighbor_data == region_data) {
                try search_positions.append(neighbor_position);
            } else {
                position_borders += 1;
            }
        }

        try found_positions.put(position, position_borders);
    }

    var region_border: usize = 0;

    var border_positions = std.ArrayList(Position).init(allocator);
    defer border_positions.deinit();

    var interior_positions = std.ArrayList(Position).init(allocator);
    defer interior_positions.deinit();

    var iterator = found_positions.iterator();
    while (iterator.next()) |entry| {
        region_border += entry.value_ptr.*;

        if (entry.value_ptr.* > 0) {
            try border_positions.append(entry.key_ptr.*);
        } else {
            try interior_positions.append(entry.key_ptr.*);
        }
    }

    return .{
        .data = region_data,
        .border = region_border,
        .border_positions = try border_positions.toOwnedSlice(),
        .interior_positions = try interior_positions.toOwnedSlice(),
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
    try std.testing.expectEqual(4, region.area());
    try std.testing.expectEqual(0, region.interior_positions.len);
    try std.testing.expectEqual(4, region.border_positions.len);
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
            const position = Position{ .x = @intCast(x), .y = @intCast(y) };
            if (position_searched.get(position)) |_| {
                continue;
            }

            const region = try detect_region(allocator, map, position);
            errdefer region.deinit(allocator);

            try regions.append(region);

            for (region.interior_positions) |region_position| {
                try position_searched.put(region_position, true);
            }

            for (region.border_positions) |region_position| {
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

        try std.testing.expectEqual(region_data.area, found_region.area());
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

        try std.testing.expectEqual(region_data.area, found_region.area());
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
        total_price += (region.area() * region.border);
    }

    return total_price;
}

const SideMap = struct {
    const Self = @This();
    const Data = bool;

    allocator: std.mem.Allocator = undefined,
    width: usize = undefined,
    height: usize = undefined,
    vertical: []Data = undefined,
    horizontal: []Data = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, width: usize, height: usize) !void {
        const vertical_size = (width + 1) * height;
        const vertical = try allocator.alloc(Data, vertical_size);
        errdefer allocator.free(vertical);

        for (0..vertical_size) |index| {
            vertical[index] = false;
        }

        const horizontal_size = width * (height + 1);
        const horizontal = try allocator.alloc(Data, horizontal_size);
        errdefer allocator.free(horizontal);

        for (0..horizontal_size) |index| {
            horizontal[index] = false;
        }

        self.* = .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .vertical = vertical,
            .horizontal = horizontal,
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.vertical);
        self.allocator.free(self.horizontal);
    }

    pub fn get(self: Self, position: Position, direction: Direction) Data {
        std.debug.assert(position.x >= 0 and position.x < self.width);
        std.debug.assert(position.y >= 0 and position.y < self.height);

        const px: usize = @intCast(position.x);
        const py: usize = @intCast(position.y);

        return switch (direction) {
            // vertical
            .east, .west => {
                const offset_x: usize = if (direction == .west) 0 else 1;
                std.debug.assert((px + offset_x) <= self.width);

                const index = (py * (self.width + 1)) + (px + offset_x);
                return self.vertical[index];
            },

            // horizontal
            .north, .south => {
                const offset_y: usize = if (direction == .north) 0 else 1;
                std.debug.assert((py + offset_y) <= self.height);

                const index = ((py + offset_y) * self.width) + px;
                return self.horizontal[index];
            },
        };
    }

    pub fn set(self: Self, position: Position, direction: Direction, value: Data) void {
        std.debug.assert(position.x >= 0 and position.x < self.width);
        std.debug.assert(position.y >= 0 and position.y < self.height);

        const px: usize = @intCast(position.x);
        const py: usize = @intCast(position.y);

        switch (direction) {
            // vertical
            .east, .west => {
                const offset_x: usize = if (direction == .west) 0 else 1;
                std.debug.assert((px + offset_x) <= self.width);

                const index = (py * (self.width + 1)) + (px + offset_x);
                self.vertical[index] = value;
            },

            // horizontal
            .north, .south => {
                const offset_y: usize = if (direction == .north) 0 else 1;
                std.debug.assert((py + offset_y) <= self.height);

                const index = ((py + offset_y) * self.width) + px;
                self.horizontal[index] = value;
            },
        }
    }
};

fn create_side_map(allocator: std.mem.Allocator, map: *const Map, region: *const RegionUnmanaged) !SideMap {
    // XXX
    var region_positions = std.AutoHashMap(Position, bool).init(allocator);
    defer region_positions.deinit();

    for (region.border_positions) |position| {
        try region_positions.put(position, true);
    }

    for (region.interior_positions) |position| {
        try region_positions.put(position, false);
    }

    // XXX
    var side_map: SideMap = .{};
    try side_map.init(allocator, map.width, map.height);
    errdefer side_map.deinit();

    for (0..map.width) |x| {
        for (0..map.height) |y| {
            const position = Position{ .x = @intCast(x), .y = @intCast(y) };
            const position_is_border = region_positions.get(position) orelse {
                continue;
            };

            if (!position_is_border) {
                continue;
            }

            inline for (std.meta.fields(Direction)) |direction_field| {
                const direction: Direction = @enumFromInt(direction_field.value);
                const neighbor = position.getNeighbor(direction);
                if (map.containsPosition(neighbor)) {
                    // side if the neighbor is not part of the region
                    const region_contains_neighbor = region_positions.contains(neighbor);
                    side_map.set(position, direction, !region_contains_neighbor);
                } else {
                    // neighbor position is out of bounds so this must be a side
                    side_map.set(position, direction, true);
                }
            }
        }
    }

    return side_map;
}

test "create_side_map" {
    const input_data =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const region = try detect_region(std.testing.allocator, &map, .{ .x = 2, .y = 1 });
    defer region.deinit(std.testing.allocator);

    try std.testing.expectEqual('C', region.data);
    try std.testing.expectEqual(4, region.area());
    try std.testing.expectEqual(0, region.interior_positions.len);
    try std.testing.expectEqual(4, region.border_positions.len);

    const side_map = try create_side_map(std.testing.allocator, &map, &region);
    defer side_map.deinit();

    const position_a = Position{ .x = 2, .y = 1};
    try std.testing.expect(side_map.get(position_a, .north));
    try std.testing.expect(side_map.get(position_a, .east));
    try std.testing.expect(side_map.get(position_a, .west));
    try std.testing.expect(!side_map.get(position_a, .south));

    const position_b = Position{ .x = 2, .y = 2};
    try std.testing.expect(!side_map.get(position_b, .north));
    try std.testing.expect(!side_map.get(position_b, .east));
    try std.testing.expect(side_map.get(position_b, .west));
    try std.testing.expect(side_map.get(position_b, .south));

    const position_c = Position{ .x = 3, .y = 2 };
    try std.testing.expect(side_map.get(position_c, .north));
    try std.testing.expect(side_map.get(position_c, .east));
    try std.testing.expect(!side_map.get(position_c, .west));
    try std.testing.expect(!side_map.get(position_c, .south));

    const position_d = Position{ .x = 3, .y = 3 };
    try std.testing.expect(!side_map.get(position_d, .north));
    try std.testing.expect(side_map.get(position_d, .east));
    try std.testing.expect(side_map.get(position_d, .west));
    try std.testing.expect(side_map.get(position_d, .south));

    for (0..map.width) |x| {
        try std.testing.expect(!side_map.get(.{ .x = @intCast(x), .y = 0 }, .north));
    }

    for (0..map.height) |y| {
        try std.testing.expect(!side_map.get(.{ .x = 0, .y = @intCast(y) }, .west));
        try std.testing.expect(!side_map.get(.{ .x = 0, .y = @intCast(y) }, .east));
    }
}

const Orientation = enum {
    vertical,
    horizontal,
};

const Side = struct {
    const Self = @This();

    orientation: Orientation,
    primary_axis: isize,
    cross_axis_start: isize,
    cross_axis_end: isize,
};

fn detect_sides(allocator: std.mem.Allocator, map: *const Map, region: *const RegionUnmanaged) ![]Side {
    // create a side map for this region
    const side_map = try create_side_map(allocator, map, region);
    defer side_map.deinit();

    // XXX
    var sides = std.ArrayList(Side).init(allocator);
    errdefer sides.deinit();

    // vertical axes
    for (0..(map.width + 1)) |primary_axis| {
        const px: isize = if (primary_axis == 0) 0 else @intCast(primary_axis - 1);
        const direction: Direction = if (primary_axis == 0) .west else .east;

        var side: ?Side = null;
        for (0..map.height) |cross_axis| {
            const position: Position = .{ .x = px, .y = @intCast(cross_axis) };
            if (side_map.get(position, direction)) {
                if (side) |*current_side| {
                    current_side.*.cross_axis_end = @intCast(cross_axis + 1);
                } else {
                    side = .{
                        .orientation = .vertical,
                        .primary_axis = @intCast(primary_axis),
                        .cross_axis_start = @intCast(cross_axis),
                        .cross_axis_end = @intCast(cross_axis + 1),
                    };
                }
            } else {
                if (side) |current_side| {
                    try sides.append(current_side);
                    side = null;
                }
            }
        }

        if (side) |current_side| {
            try sides.append(current_side);
            side = null;
        }
    }

    // horizontal axes
    for (0..(map.height + 1)) |primary_axis| {
        const py: isize = if (primary_axis == 0) 0 else @intCast(primary_axis - 1);
        const direction: Direction = if (primary_axis == 0) .north else .south;

        var side: ?Side = null;
        for (0..map.width) |cross_axis| {
            const position: Position = .{ .x = @intCast(cross_axis), .y = py };
            if (side_map.get(position, direction)) {
                if (side) |*current_side| {
                    current_side.cross_axis_end = @intCast(cross_axis + 1);
                } else {
                    side = .{
                        .orientation = .horizontal,
                        .primary_axis = @intCast(primary_axis),
                        .cross_axis_start = @intCast(cross_axis),
                        .cross_axis_end = @intCast(cross_axis + 1),
                    };
                }
            } else {
                if (side) |current_side| {
                    try sides.append(current_side);
                    side = null;
                }
            }
        }

        if (side) |current_side| {
            try sides.append(current_side);
            side = null;
        }
    }

    return try sides.toOwnedSlice();
}

test "detect_sides_part2_example1" {
    const input_data =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const region_c = try detect_region(std.testing.allocator, &map, .{ .x = 2, .y = 1 });
    defer region_c.deinit(std.testing.allocator);

    try std.testing.expectEqual('C', region_c.data);
    try std.testing.expectEqual(4, region_c.area());
    try std.testing.expectEqual(0, region_c.interior_positions.len);
    try std.testing.expectEqual(4, region_c.border_positions.len);

    const sides_c = try detect_sides(std.testing.allocator, &map, &region_c);
    defer std.testing.allocator.free(sides_c);

    try std.testing.expectEqual(8, sides_c.len);

    const region_e = try detect_region(std.testing.allocator, &map, .{ .x = 0, .y = 3 });
    defer region_e.deinit(std.testing.allocator);

    try std.testing.expectEqual('E', region_e.data);
    try std.testing.expectEqual(3, region_e.area());
    try std.testing.expectEqual(0, region_e.interior_positions.len);
    try std.testing.expectEqual(3, region_e.border_positions.len);

    const sides_e = try detect_sides(std.testing.allocator, &map, &region_e);
    defer std.testing.allocator.free(sides_e);

    try std.testing.expectEqual(4, sides_e.len);
}

test "detect_sides_part2_example2" {
    const input_data =
        \\EEEEE
        \\EXXXX
        \\EEEEE
        \\EXXXX
        \\EEEEE
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const regions = try detect_regions(std.testing.allocator, &map);
    defer regions.deinit(std.testing.allocator);

    const RegionData = struct {
        sides: usize,
        area: usize,
    };

    var expected_regions = std.AutoHashMap(Map.Data, RegionData).init(std.testing.allocator);
    defer expected_regions.deinit();

    try expected_regions.put('E', .{ .sides = 12, .area = 17 });
    try expected_regions.put('X', .{ .sides = 4, .area = 4 });

    try std.testing.expectEqual(3, regions.regions.len);
    for (regions.regions) |found_region| {
        const region_data = expected_regions.get(found_region.data) orelse {
            return error.InvalidFoundRegion;
        };

        const sides = try detect_sides(std.testing.allocator, &map, &found_region);
        defer std.testing.allocator.free(sides);

        try std.testing.expectEqual(region_data.area, found_region.area());
        try std.testing.expectEqual(region_data.sides, sides.len);
    }
}

fn region_less_than(_: void, lhs: RegionUnmanaged, rhs: RegionUnmanaged) bool {
    if (lhs.data != rhs.data) {
        return lhs.data < rhs.data;
    }

    return lhs.area() < rhs.area();
}

const RegionTestData = struct {
    data: Map.Data,
    sides: usize,
    area: usize,
};

fn region_test_data_less_than(_: void, lhs: RegionTestData, rhs: RegionTestData) bool {
    if (lhs.data != rhs.data) {
        return lhs.data < rhs.data;
    }

    return lhs.area < rhs.area;
}

test "part2_example2" {
    const input_data =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const regions = try detect_regions(std.testing.allocator, &map);
    defer regions.deinit(std.testing.allocator);

    var region_test_data: [11]RegionTestData = .{
        .{ .data = 'R', .area = 12, .sides = 10 },
        .{ .data = 'I', .area = 4,  .sides = 4 },
        .{ .data = 'C', .area = 14, .sides = 22 },
        .{ .data = 'F', .area = 10, .sides = 12 },
        .{ .data = 'V', .area = 13, .sides = 10 },
        .{ .data = 'J', .area = 11, .sides = 12 },
        .{ .data = 'C', .area = 1,  .sides = 4 },
        .{ .data = 'E', .area = 13, .sides = 8 },
        .{ .data = 'I', .area = 14, .sides = 16 },
        .{ .data = 'M', .area = 5,  .sides = 6 },
        .{ .data = 'S', .area = 3,  .sides = 6 },
    };

    std.sort.block(RegionUnmanaged, regions.regions, {}, region_less_than);
    std.sort.block(RegionTestData, &region_test_data, {}, region_test_data_less_than);

    var total_price: usize = 0;
    try std.testing.expectEqual(11, regions.regions.len);
    for (region_test_data, regions.regions) |expected, actual| {
        try std.testing.expectEqual(expected.data, actual.data);
        try std.testing.expectEqual(expected.area, actual.area());

        const sides = try detect_sides(std.testing.allocator, &map, &actual);
        defer std.testing.allocator.free(sides);

        try std.testing.expectEqual(expected.sides, sides.len);
        total_price += (actual.area() * sides.len);
    }

    try std.testing.expectEqual(1206, total_price);
}

test "part2_example1" {
    const input_data =
        \\AAAAAA
        \\AAABBA
        \\AAABBA
        \\ABBAAA
        \\ABBAAA
        \\AAAAAA
    ;

    const map = try parse_map(std.testing.allocator, input_data);
    defer map.deinit();

    const regions = try detect_regions(std.testing.allocator, &map);
    defer regions.deinit(std.testing.allocator);

    var region_test_data: [3]RegionTestData = .{
        .{ .data = 'A', .area = 28, .sides = 12 },
        .{ .data = 'B', .area = 4,  .sides = 4 },
        .{ .data = 'B', .area = 4,  .sides = 4 },
    };

    std.sort.block(RegionUnmanaged, regions.regions, {}, region_less_than);
    std.sort.block(RegionTestData, &region_test_data, {}, region_test_data_less_than);

    var total_price: usize = 0;
    for (region_test_data, regions.regions) |expected, actual| {
        try std.testing.expectEqual(expected.data, actual.data);
        try std.testing.expectEqual(expected.area, actual.area());

        const sides = try detect_sides(std.testing.allocator, &map, &actual);
        defer std.testing.allocator.free(sides);

        try std.testing.expectEqual(expected.sides, sides.len);
        total_price += (actual.area() * sides.len);
    }

    try std.testing.expectEqual(368, total_price);
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    const map = try parse_map(allocator, input_data);
    defer map.deinit();

    try std.testing.expectEqual(140, map.width);
    try std.testing.expectEqual(140, map.height);

    const regions = try detect_regions(allocator, &map);
    defer regions.deinit(allocator);

    var total_price: usize = 0;
    for (regions.regions) |region| {
        const sides = try detect_sides(allocator, &map, &region);
        defer allocator.free(sides);

        total_price += (region.area() * sides.len);
    }

    return total_price; 
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const price_border = try part1(allocator, input_data);

    try std.testing.expectEqual(1449902, price_border);
    std.debug.print("price border: {d}\n", .{price_border});

    // part 2
    const price_sides = try part2(allocator, input_data);

    // try std.testing.expectEqual(897612, price_sides); // too low
    std.debug.print("price sides: {d}\n", .{price_sides});
}
