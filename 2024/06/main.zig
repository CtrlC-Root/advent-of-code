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

const MapUnmanaged = struct {
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
};

const Input = struct {
    const Self = @This();

    allocator: std.mem.Allocator = undefined,
    map: MapUnmanaged = undefined,
    guard: Guard = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, input_data: []const u8) !void {
        // look for newlines to determine map dimensions
        const index_first_newline = std.mem.indexOfScalar(u8, input_data, '\n') orelse {
            return error.InvalidFormat;
        };

        const newlines = std.mem.count(u8, input_data, &.{'\n'});

        std.debug.assert(index_first_newline > 0 and index_first_newline < 256);
        std.debug.assert(newlines > 0 and newlines < 256);

        // allocate and initialize map
        var map: MapUnmanaged = .{};
        try map.init(allocator, index_first_newline, newlines + 1);
        errdefer map.deinit(allocator);

        // fill in map data one line at a time and keep track of the initial
        // guard position if we find it
        var row: usize = 0;
        var guard: ?Guard = null;
        var line_iterator = std.mem.splitScalar(u8, input_data, '\n');

        while (line_iterator.next()) |line| {
            for (0..line.len) |column| {
                const value = line[column];
                if (std.meta.intToEnum(Direction, value)) |direction| {
                    std.debug.assert(guard == null);
                    guard = .{
                        .position = .{ .row = @intCast(row), .column = @intCast(column) },
                        .direction = direction,
                    };
                } else |_| {
                    const tile = std.meta.intToEnum(Tile, value) catch {
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
const SimulatedGuard = struct {
    const Self = @This();

    positions: []Position,

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.positions);
    }
};

fn simulate_guard(allocator: std.mem.Allocator, input: *const Input) !SimulatedGuard {
    var positions = std.ArrayList(Position).init(allocator);
    defer positions.deinit();

    // simulate the guard and track the path it follows
    var guard = input.guard;
    while (input.map.containsPosition(guard.position)) {
        // track visited positions
        try positions.append(guard.position);

        // turn the guard clockwise until it's not facing an obstable
        turn: for (0..std.meta.fields(Direction).len) |_| {
            const forward_tile = input.map.getPosition(guard.position.move(guard.direction)) orelse {
                // position is off the map
                break :turn;
            };

            switch (forward_tile) {
                .none => break :turn,
                .obstacle => {
                    guard.direction = guard.direction.turnRight();
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
        .positions = try positions.toOwnedSlice(),
    };
}

fn count_unique_positions(allocator: std.mem.Allocator, positions: []const Position) !usize {
    var seen = std.AutoHashMap(Position, bool).init(allocator);
    defer seen.deinit();

    for (positions) |position| {
        try seen.put(position, true);
    }

    return seen.count();
}

fn debug_print_results(input: *const Input, simulated_guard: *const SimulatedGuard) void {
    std.debug.print("\n", .{});

    for (0..input.map.height) |row| {
        for (0..input.map.width) |column| {
            const position: Position = .{ .row = @intCast(row), .column = @intCast(column) };
            for (simulated_guard.positions) |visited_position| {
                if (position.row == visited_position.row and position.column == visited_position.column) {
                    std.debug.print("X", .{});
                    break;
                }
            } else {
                const tile = input.map.getPosition(position) orelse unreachable;
                switch (tile) {
                    .none => std.debug.print(".", .{}),
                    .obstacle => std.debug.print("#", .{}),
                }
            }
        }

        std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
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

    const simulated_guard = try simulate_guard(std.testing.allocator, &input);
    defer simulated_guard.deinit(std.testing.allocator);

    const unique_positions = try count_unique_positions(std.testing.allocator, simulated_guard.positions);
    try std.testing.expectEqual(41, unique_positions);

    // XXX debugging
    debug_print_results(&input, &simulated_guard);
}

// IMPLEMENTATION
fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    var input: Input = .{};
    try input.init(allocator, input_data);
    defer input.deinit();

    const simulated_guard = try simulate_guard(allocator, &input);
    defer simulated_guard.deinit(allocator);

    return try count_unique_positions(allocator, simulated_guard.positions);
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const unique_positions = try part1(allocator, input_data);

    try std.testing.expectEqual(5329, unique_positions);
    std.debug.print("unique positions: {d}\n", .{unique_positions});

    // // part 2
    // const total_invalid = try part2(allocator, input_data);

    // std.debug.assert(total_invalid == 5770);
    // std.debug.print("total invalid: {d}\n", .{total_invalid});
}
