const std = @import("std");

// COMMON DATA TYPES
const Tile = enum(u8) {
    none = '.',
    obstacle = '#',
};

const Direction = enum(u8) {
    const Self = @This();

    north = '^',
    east = '>',
    south = 'v',
    west = '<',

    pub fn turnRight(self: Self) Self {
        return switch (self) {
            .north => .east,
            .east => .south,
            .south => .west,
            .west => .north,
        };
    }
};

const Position = struct {
    const Self = @This();

    row: isize,
    column: isize,

    pub fn move(self: Self, direction: Direction) Position {
        return switch (direction) {
            .north => .{ .row = self.row - 1, .column = self.column },
            .south => .{ .row = self.row + 1, .column = self.column },

            .east => .{ .row = self.row, .column = self.column + 1 },
            .west => .{ .row = self.row, .column = self.column - 1 },
        };
    }
};

const Guard = struct {
    position: Position,
    direction: Direction,
};

const TileMapUnmanaged = struct {
    const Self = @This();

    width: usize = undefined,
    height: usize = undefined,
    tiles: []Tile = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, width: usize, height: usize) !void {
        const tiles = try allocator.alloc(Tile, width * height);
        for (0..(width * height)) |index| {
            tiles[index] = .none;
        }

        self.* = .{
            .width = width,
            .height = height,
            .tiles = tiles,
        };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.tiles);
    }

    pub fn dupe(self: *Self, allocator: std.mem.Allocator, other: *const Self) !void {
        try self.init(allocator, other.width, other.height);
        errdefer self.deinit();

        std.mem.copyForwards(Tile, self.tiles, other.tiles);
    }

    pub fn get(self: Self, row: usize, column: usize) Tile {
        std.debug.assert(row < self.height);
        std.debug.assert(column < self.width);

        const index = (row * self.width) + column;
        return self.tiles[index];
    }

    pub fn set(self: *Self, row: usize, column: usize, value: Tile) void {
        std.debug.assert(row < self.height);
        std.debug.assert(column < self.width);

        const index = (row * self.width) + column;
        self.tiles[index] = value;
    }

    pub fn containsPosition(self: Self, position: Position) bool {
        return (position.row >= 0 and position.row < self.height and position.column >= 0 and position.column < self.width);
    }

    pub fn getPosition(self: Self, position: Position) ?Tile {
        return if (self.containsPosition(position)) self.get(@intCast(position.row), @intCast(position.column)) else null;
    }

    pub fn setPosition(self: *Self, position: Position, value: Tile) void {
        std.debug.assert(self.containsPosition(position));
        self.set(@intCast(position.row), @intCast(position.column), value);
    }
};

const Input = struct {
    const Self = @This();

    allocator: std.mem.Allocator = undefined,
    map: TileMapUnmanaged = undefined,
    guard: Guard = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        // look for newlines to determine map dimensions
        const trimmed_input = std.mem.trim(u8, input_data, &.{'\n'});
        const index_first_newline = std.mem.indexOfScalar(u8, trimmed_input, '\n') orelse {
            return error.InvalidFormat;
        };

        const newlines = std.mem.count(u8, trimmed_input, &.{'\n'});

        std.debug.assert(index_first_newline > 0 and index_first_newline < 256);
        std.debug.assert(newlines > 0 and newlines < 256);

        // allocate and initialize map
        var map: TileMapUnmanaged = .{};
        try map.init(allocator, index_first_newline, newlines + 1);
        errdefer map.deinit(allocator);

        // fill in map data one line at a time and keep track of the initial
        // guard position if we find it
        var row: usize = 0;
        var guard: ?Guard = null;
        var line_iterator = std.mem.splitScalar(u8, trimmed_input, '\n');

        while (line_iterator.next()) |line| {
            for (0..line.len) |column| {
                const value = line[column];
                const sanitized_value = switch (value) {
                    '-', '|', '+' => '.',
                    'O' => '#',
                    else => value,
                };

                if (std.meta.intToEnum(Direction, sanitized_value)) |direction| {
                    std.debug.assert(guard == null);
                    guard = .{
                        .position = .{ .row = @intCast(row), .column = @intCast(column) },
                        .direction = direction,
                    };

                    map.set(row, column, .none);
                } else |_| {
                    const tile = std.meta.intToEnum(Tile, sanitized_value) catch {
                        return error.InvalidFormat;
                    };

                    map.set(row, column, tile);
                }
            }

            row += 1;
        }

        std.debug.assert(guard != null);

        // initialize the input
        self.* = .{
            .allocator = allocator,
            .map = map,
            .guard = guard.?,
        };
    }

    pub fn deinit(self: Self) void {
        self.map.deinit(self.allocator);
    }
};

test "input_parse" {
    const sample_input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, sample_input);
    defer input.deinit();

    try std.testing.expectEqual(10, input.map.width);
    try std.testing.expectEqual(10, input.map.height);
    try std.testing.expectEqual(6, input.guard.position.row);
    try std.testing.expectEqual(4, input.guard.position.column);
    try std.testing.expectEqual(.north, input.guard.direction);
}

// COMMON ALGORITHMS
const SimulationResults = struct {
    const Self = @This();

    const Record = union(enum) {
        visit: Guard,
        turn: Direction,
    };

    const Termination = enum(u8) {
        guard_left_map,
        guard_entered_loop,
    };

    records: []Record,
    unique_positions: usize,
    termination: Self.Termination,

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.records);
    }
};

fn simulate(
    allocator: std.mem.Allocator,
    map: *const TileMapUnmanaged,
    initial_guard: *const Guard,
) !SimulationResults {
    var records = std.ArrayList(SimulationResults.Record).init(allocator);
    defer records.deinit();

    var last_seen = std.AutoHashMap(Position, Direction).init(allocator);
    defer last_seen.deinit();

    // simulate the guard and track the path it follows
    var guard = initial_guard.*;
    var loop_detected = false;

    while (map.containsPosition(guard.position)) {
        // detect whether the guard is about to enter a loop by visiting
        // a position from earlier while facing the same way
        if (last_seen.get(guard.position)) |last_seen_direction| {
            if (guard.direction == last_seen_direction) {
                loop_detected = true;
                break;
            }
        }

        // track visited positions
        try records.append(SimulationResults.Record{ .visit = guard });
        try last_seen.put(guard.position, guard.direction);

        // turn the guard clockwise until it's not facing an obstable
        turn: for (0..std.meta.fields(Direction).len) |_| {
            const forward_tile = map.getPosition(guard.position.move(guard.direction)) orelse {
                // position is off the map
                break :turn;
            };

            switch (forward_tile) {
                .none => break :turn,
                .obstacle => {
                    guard.direction = guard.direction.turnRight();
                    try records.append(SimulationResults.Record{ .turn = guard.direction });
                },
            }
        } else {
            // ensure we didn't just turn in a complete loop which should be impossible
            // unless the guard starts surrounded by obstables
            unreachable;
        }

        // move the guard one position in the direction it's currently facing
        guard.position = guard.position.move(guard.direction);
    }

    // return the simulation results with caller owned memory
    return .{
        .records = try records.toOwnedSlice(),
        .unique_positions = last_seen.count(),
        .termination = if (loop_detected) .guard_entered_loop else .guard_left_map,
    };
}

test "part1_example" {
    const sample_input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var input: Input = .{};
    try input.init(std.testing.allocator, sample_input);
    defer input.deinit();

    const results = try simulate(std.testing.allocator, &input.map, &input.guard);
    defer results.deinit(std.testing.allocator);

    try std.testing.expectEqual(.guard_left_map, results.termination);
    try std.testing.expectEqual(41, results.unique_positions);
}

fn identify_loops(
    allocator: std.mem.Allocator,
    initial_map: *const TileMapUnmanaged,
    initial_guard: *const Guard,
) !usize {
    const baseline = try simulate(allocator, initial_map, initial_guard);
    defer baseline.deinit(allocator);

    std.debug.assert(baseline.records.len > 1);
    std.debug.assert(baseline.termination == .guard_left_map);

    var obstacles = std.AutoHashMap(Position, bool).init(allocator);
    defer obstacles.deinit();

    for (baseline.records[1..]) |record| {
        const guard = switch (record) {
            .visit => |guard| guard,
            else => continue,
        };

        if (obstacles.get(guard.position)) |_| {
            continue;
        }

        var map: TileMapUnmanaged = .{};
        try map.dupe(allocator, initial_map);
        defer map.deinit(allocator);

        map.setPosition(guard.position, .obstacle);

        const results = try simulate(allocator, &map, initial_guard);
        defer results.deinit(allocator);

        if (results.termination == .guard_entered_loop) {
            try obstacles.put(guard.position, true);
        }
    }

    return obstacles.count();
}

test "part2_example" {
    const no_loop =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    const loop_option_one =
        \\....#.....
        \\....+---+#
        \\....|...|.
        \\..#.|...|.
        \\....|..#|.
        \\....|...|.
        \\.#.O^---+.
        \\........#.
        \\#.........
        \\......#...
    ;

    const loop_option_two =
        \\....#.....
        \\....+---+#
        \\....|...|.
        \\..#.|...|.
        \\..+-+-+#|.
        \\..|.|.|.|.
        \\.#+-^-+-+.
        \\......O.#.
        \\#.........
        \\......#...
    ;

    const loop_option_three =
        \\....#.....
        \\....+---+#
        \\....|...|.
        \\..#.|...|.
        \\..+-+-+#|.
        \\..|.|.|.|.
        \\.#+-^-+-+.
        \\.+----+O#.
        \\#+----+...
        \\......#...
    ;

    const loop_option_four =
        \\....#.....
        \\....+---+#
        \\....|...|.
        \\..#.|...|.
        \\..+-+-+#|.
        \\..|.|.|.|.
        \\.#+-^-+-+.
        \\..|...|.#.
        \\#O+---+...
        \\......#...
    ;

    const loop_option_five =
        \\....#.....
        \\....+---+#
        \\....|...|.
        \\..#.|...|.
        \\..+-+-+#|.
        \\..|.|.|.|.
        \\.#+-^-+-+.
        \\....|.|.#.
        \\#..O+-+...
        \\......#...
    ;

    const loop_option_six =
        \\....#.....
        \\....+---+#
        \\....|...|.
        \\..#.|...|.
        \\..+-+-+#|.
        \\..|.|.|.|.
        \\.#+-^-+-+.
        \\.+----++#.
        \\#+----++..
        \\......#O..
    ;

    // simulations
    const TestCaseData = struct {
        input_data: []const u8,
    };

    const simulations: []const TestCaseData = &.{
        .{ .input_data = loop_option_one },
        .{ .input_data = loop_option_two },
        .{ .input_data = loop_option_three },
        .{ .input_data = loop_option_four },
        .{ .input_data = loop_option_five },
        .{ .input_data = loop_option_six },
    };

    // confirm the loop is detected for each example simulation
    for (simulations) |simulation| {
        var input: Input = .{};
        try input.init(std.testing.allocator, simulation.input_data);
        defer input.deinit();

        const results = try simulate(std.testing.allocator, &input.map, &input.guard);
        defer results.deinit(std.testing.allocator);

        try std.testing.expectEqual(.guard_entered_loop, results.termination);
    }

    // XXX
    var input: Input = .{};
    try input.init(std.testing.allocator, no_loop);
    defer input.deinit();

    const possible_loops = try identify_loops(std.testing.allocator, &input.map, &input.guard);
    try std.testing.expectEqual(simulations.len, possible_loops);
}

// IMPLEMENTATION
fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit();

    try std.testing.expectEqual(130, input.map.height);
    try std.testing.expectEqual(130, input.map.width);

    const results = try simulate(allocator, &input.map, &input.guard);
    defer results.deinit(allocator);

    try std.testing.expectEqual(.guard_left_map, results.termination);
    return results.unique_positions;
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit();

    try std.testing.expectEqual(130, input.map.height);
    try std.testing.expectEqual(130, input.map.width);

    return try identify_loops(allocator, &input.map, &input.guard);
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const unique_positions = try part1(allocator, input_data);

    try std.testing.expectEqual(5329, unique_positions);
    std.debug.print("unique positions: {d}\n", .{unique_positions});

    // part 2
    const possible_loops = try part2(allocator, input_data);

    try std.testing.expectEqual(2162, possible_loops);
    std.debug.print("possible loops: {d}\n", .{possible_loops});
}
