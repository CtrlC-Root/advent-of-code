const std = @import("std");

const Vec2d = struct {
    const Self = @This();

    x: isize,
    y: isize,

    pub fn equals(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn add(self: Self, other: Self) Self {
        return .{
            .x = (self.x + other.x),
            .y = (self.y + other.y),
        };
    }

    pub fn subtract(self: Self, other: Self) Self {
        return .{
            .x = (self.x - other.x),
            .y = (self.y - other.y),
        };
    }
};

const AntennaId = u8;

const Map2d = struct {
    const Self = @This();
    const PositionArrayList = std.ArrayListUnmanaged(Vec2d);
    const TileHashMap = std.AutoHashMapUnmanaged(Vec2d, AntennaId);
    const AntennaHashMap = std.AutoHashMapUnmanaged(AntennaId, PositionArrayList);

    allocator: std.mem.Allocator = undefined,
    size: Vec2d = undefined,
    tiles: TileHashMap = undefined,
    antennas: AntennaHashMap = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, size: Vec2d) void {
        std.debug.assert(size.x >= 0);
        std.debug.assert(size.y >= 0);

        self.* = .{
            .allocator = allocator,
            .size = size,
            .tiles = .{},
            .antennas = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        var antenna_iterator = self.antennas.iterator();
        while (antenna_iterator.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
        }

        self.antennas.deinit(self.allocator);
        self.tiles.deinit(self.allocator);
    }

    pub fn containsPosition(self: Self, position: Vec2d) bool {
        return (position.x >= 0 and position.x < self.size.x and position.y >= 0 and position.y < self.size.y);
    }

    pub fn placeAntenna(self: *Self, position: Vec2d, antenna: AntennaId) !void {
        std.debug.assert(self.containsPosition(position));

        if (!self.antennas.contains(antenna)) {
            try self.antennas.putNoClobber(self.allocator, antenna, .{});
        }

        try self.antennas.getPtr(antenna).?.append(self.allocator, position);
        try self.tiles.putNoClobber(self.allocator, position, antenna);
    }
};

const Input = struct {
    const Self = @This();

    map: Map2d = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        // determine map dimensions
        const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
        const index_first_newline = std.mem.indexOfScalar(u8, trimmed_input, '\n') orelse {
            return error.InvalidFormat;
        };

        const newlines = std.mem.count(u8, trimmed_input, &.{'\n'});

        std.debug.assert(index_first_newline > 0 and index_first_newline < 256);
        std.debug.assert(newlines > 0 and newlines < 256);

        // create antenna map and store identified antinodes
        var map: Map2d = .{};
        map.init(allocator, .{ .x = @intCast(index_first_newline), .y = @intCast(newlines + 1) });
        errdefer map.deinit();

        // parse input data
        var row: usize = 0;
        var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');

        while (line_iterator.next()) |line| {
            for (0..line.len) |column| {
                const position = Vec2d{ .x = @intCast(column), .y = @intCast(row) };
                const value = line[column];

                if (std.ascii.isAlphanumeric(value)) {
                    try map.placeAntenna(position, value);
                } else if (value == '#' or value == '.') {
                    // ignore antinode positions
                    continue;
                } else {
                    @panic("unknown input character");
                }
            }

            row += 1;
        }

        // initialize input data
        self.* = .{
            .map = map,
        };
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }
};

test "parse_input" {
    const input_data =
        \\..........
        \\...#......
        \\#.........
        \\....a.....
        \\........a.
        \\.....a....
        \\..#.......
        \\......#...
        \\..........
        \\..........
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, input_data);
    defer input.deinit();

    try std.testing.expect(input.map.size.equals(Vec2d{ .x = 10, .y = 10}));
    try std.testing.expectEqual(3, input.map.tiles.count());
    try std.testing.expectEqual(1, input.map.antennas.count());

    try std.testing.expectEqual('a', input.map.tiles.get(Vec2d{ .x = 4, .y = 3 }));
    try std.testing.expectEqual('a', input.map.tiles.get(Vec2d{ .x = 8, .y = 4 }));
    try std.testing.expectEqual('a', input.map.tiles.get(Vec2d{ .x = 5, .y = 5 }));

    const antenna_positions = input.map.antennas.get('a') orelse unreachable; // XXX: std.testing for this?
    try std.testing.expectEqual(3, antenna_positions.items.len);
    try std.testing.expect(antenna_positions.items[0].equals(Vec2d{ .x = 4, .y = 3 }));
    try std.testing.expect(antenna_positions.items[1].equals(Vec2d{ .x = 8, .y = 4 }));
    try std.testing.expect(antenna_positions.items[2].equals(Vec2d{ .x = 5, .y = 5 }));
}

fn calculate_antinodes(
    allocator: std.mem.Allocator,
    map: *const Map2d,
    antenna: AntennaId,
    repeating: bool,
) ![]const Vec2d {
    const antenna_locations = map.antennas.get(antenna) orelse {
        return error.InvalidAntennaId;
    };

    var antinodes = std.AutoHashMap(Vec2d, bool).init(allocator);
    defer antinodes.deinit();

    var position: Vec2d = undefined;
    for (0..antenna_locations.items.len) |index_a| {
        for ((index_a + 1)..antenna_locations.items.len) |index_b| {
            const location_a = antenna_locations.items[index_a];
            const location_b = antenna_locations.items[index_b];
            const delta = location_b.subtract(location_a);

            if (repeating) {
                try antinodes.put(location_a, true);
                try antinodes.put(location_b, true);
            }

            position = location_a.subtract(delta);
            while (map.containsPosition(position)) {
                try antinodes.put(position, true);

                if (!repeating) {
                    break;
                }

                position = position.subtract(delta);
            }

            position = location_b.add(delta);
            while (map.containsPosition(position)) {
                try antinodes.put(position, true);

                if (!repeating) {
                    break;
                }

                position = position.add(delta);
            }
        }
    }

    var positions = std.ArrayList(Vec2d).init(allocator);
    errdefer positions.deinit();

    var antinode_iterator = antinodes.iterator();
    while (antinode_iterator.next()) |entry| {
        try positions.append(entry.key_ptr.*);
    }

    return positions.toOwnedSlice();
}

test "calculate_antinodes" {
    // simple example (part1)
    const simple_input_data =
        \\..........
        \\...#......
        \\#.........
        \\....a.....
        \\........a.
        \\.....a....
        \\..#.......
        \\......#...
        \\..........
        \\..........
    ;

    var simple_input: Input = .{};
    try simple_input.init(std.testing.allocator, simple_input_data);
    defer simple_input.deinit();

    const simple_antinode_positions = try calculate_antinodes(std.testing.allocator, &simple_input.map, 'a', false);
    defer std.testing.allocator.free(simple_antinode_positions);

    try std.testing.expectEqual(4, simple_antinode_positions.len);
    try std.testing.expect(simple_antinode_positions[0].equals(Vec2d{ .x = 3, .y = 1 }));
    try std.testing.expect(simple_antinode_positions[1].equals(Vec2d{ .x = 6, .y = 7 }));
    try std.testing.expect(simple_antinode_positions[2].equals(Vec2d{ .x = 0, .y = 2 }));
    try std.testing.expect(simple_antinode_positions[3].equals(Vec2d{ .x = 2, .y = 6 }));

    // complex example (part1)
    const complex_input_data =
        \\......#....#
        \\...#....0...
        \\....#0....#.
        \\..#....0....
        \\....0....#..
        \\.#....A.....
        \\...#........
        \\#......#....
        \\........A...
        \\.........A..
        \\..........#.
        \\..........#.
    ;

    var complex_input: Input = .{};
    try complex_input.init(std.testing.allocator, complex_input_data);
    defer complex_input.deinit();

    const complex_antinode_positions = try calculate_antinodes(std.testing.allocator, &complex_input.map, '0', false);
    defer std.testing.allocator.free(complex_antinode_positions);

    try std.testing.expectEqual(10, complex_antinode_positions.len);

    // repeating example (part2)
    const repeating_input_data =
        \\T....#....
        \\...T......
        \\.T....#...
        \\.........#
        \\..#.......
        \\..........
        \\...#......
        \\..........
        \\....#.....
        \\..........
    ;

    var repeating_input: Input = .{};
    try repeating_input.init(std.testing.allocator, repeating_input_data);
    defer repeating_input.deinit();

    const repeating_antinode_positions = try calculate_antinodes(std.testing.allocator, &repeating_input.map, 'T', true);
    defer std.testing.allocator.free(repeating_antinode_positions);

    try std.testing.expectEqual(9, repeating_antinode_positions.len);
}

fn calculate_unique_antinodes(allocator: std.mem.Allocator, map: *const Map2d, repeating: bool) !usize {
    var positions = std.AutoHashMap(Vec2d, bool).init(allocator);
    defer positions.deinit();

    var antenna_id_iterator = map.antennas.keyIterator();
    while (antenna_id_iterator.next()) |antenna_id| {
        const antinode_positions = try calculate_antinodes(allocator, map, antenna_id.*, repeating);
        defer allocator.free(antinode_positions);

        for (antinode_positions) |position| {
            try positions.put(position, true);
        }
    }

    return positions.count();
}

test "calculate_unique_antinodes" {
    // simple example (part1)
    const simple_input_data =
        \\..........
        \\...#......
        \\#.........
        \\....a.....
        \\........a.
        \\.....a....
        \\..#.......
        \\......#...
        \\..........
        \\..........
    ;

    var simple_input: Input = .{};
    try simple_input.init(std.testing.allocator, simple_input_data);
    defer simple_input.deinit();

    const simple_unique_antinodes = try calculate_unique_antinodes(std.testing.allocator, &simple_input.map, false);
    try std.testing.expectEqual(4, simple_unique_antinodes);

    // complex example (part1)
    const complex_input_data =
        \\......#....#
        \\...#....0...
        \\....#0....#.
        \\..#....0....
        \\....0....#..
        \\.#....A.....
        \\...#........
        \\#......#....
        \\........A...
        \\.........A..
        \\..........#.
        \\..........#.
    ;

    var complex_input: Input = .{};
    try complex_input.init(std.testing.allocator, complex_input_data);
    defer complex_input.deinit();

    const complex_unique_antinodes = try calculate_unique_antinodes(std.testing.allocator, &complex_input.map, false);
    try std.testing.expectEqual(14, complex_unique_antinodes);

    // repeating example (part2)
    const repeating_input_data =
        \\##....#....#
        \\.#.#....0...
        \\..#.#0....#.
        \\..##...0....
        \\....0....#..
        \\.#...#A....#
        \\...#..#.....
        \\#....#.#....
        \\..#.....A...
        \\....#....A..
        \\.#........#.
        \\...#......##
    ;

    var repeating_input: Input = .{};
    try repeating_input.init(std.testing.allocator, repeating_input_data);
    defer repeating_input.deinit();

    const repeating_unique_antinodes = try calculate_unique_antinodes(std.testing.allocator, &repeating_input.map, true);
    try std.testing.expectEqual(34, repeating_unique_antinodes);
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit();

    return try calculate_unique_antinodes(allocator, &input.map, false);
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit();

    return try calculate_unique_antinodes(allocator, &input.map, true);
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const unique_antinodes = try part1(allocator, input_data);

    try std.testing.expectEqual(305, unique_antinodes);
    std.debug.print("unique antinodes: {d}\n", .{unique_antinodes});

    // part 2
    const unique_repeating = try part2(allocator, input_data);

    try std.testing.expectEqual(1150, unique_repeating);
    std.debug.print("unique repeating: {d}\n", .{unique_repeating});
}
