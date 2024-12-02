const std = @import("std");

const input_data = @embedFile("./input");

const Level = u32;
const LevelArray = std.ArrayListUnmanaged(Level);
const ReportArray = std.ArrayListUnmanaged(LevelArray);

const Input = struct {
    const Self = @This();

    allocator: std.mem.Allocator = undefined,
    reports: ReportArray = undefined,

    pub fn init(self: *Self, allocator: std.mem.Allocator, data: []const u8) !usize {
        var reports: ReportArray = .{};
        errdefer {
            for (reports.items) |*report| {
                report.deinit(allocator);
            }

            reports.deinit(allocator);
        }

        // parse input data
        var line_iterator = std.mem.tokenizeScalar(u8, data, '\n');
        while (line_iterator.next()) |line_data| {
            var levels: LevelArray = .{};
            var level_iterator = std.mem.tokenizeScalar(u8, line_data, ' ');
            while (level_iterator.next()) |level_data| {
                const level = try std.fmt.parseInt(Level, level_data, 10);
                try levels.append(allocator, level);
            }

            try reports.append(allocator, levels);
        }

        // initialize input data struct
        self.* = .{
            .allocator = allocator,
            .reports = reports,
        };

        // return total number of loaded reports
        return self.reports.items.len;
    }

    pub fn deinit(self: *Self) void {
        for (self.reports.items) |*report| {
            report.deinit(self.allocator);
        }

        self.reports.deinit(self.allocator);
    }
};

fn part1_report_safe(levels: []const Level) bool {
    std.debug.assert(levels.len >= 2);

    const report_sign: i64 = std.math.sign(@as(i64, @intCast(levels[1])) - @as(i64, @intCast(levels[0])));
    if (report_sign == 0) {
        return false;
    }

    for (
        levels[0..(levels.len - 1)],
        levels[1..levels.len],
    ) |level_a, level_b| {
        const difference: i64 = @as(i64, @intCast(level_b)) - @as(i64, @intCast(level_a));
        const signs_match = (std.math.sign(difference) == report_sign);
        const difference_in_range = (@abs(difference) >= 1 and @abs(difference) <= 3);

        if (!signs_match or !difference_in_range) {
            return false;
        }
    }

    return true;
}

fn part1(allocator: std.mem.Allocator) !usize {
    // load input data
    var input: Input = .{};
    const loaded_reports = try input.init(allocator, input_data);
    defer input.deinit();

    std.debug.assert(loaded_reports == 1000);

    // count safe reports
    var safe_reports: usize = 0;
    for (input.reports.items) |report| {
        if (part1_report_safe(report.items)) {
            safe_reports += 1;
        }
    }

    return safe_reports;
}

fn part2_report_safe(levels: []const Level) bool {
    var sample_report = std.BoundedArray(Level, 32).init(0) catch unreachable;

    std.debug.assert(levels.len >= 3);
    std.debug.assert(levels.len <= sample_report.capacity());

    for (0..levels.len) |index_to_remove| {
        sample_report.resize(0) catch unreachable;
        for (0..levels.len) |index| {
            if (index != index_to_remove) {
                sample_report.append(levels[index]) catch unreachable;
            }
        }

        const report_safe = part1_report_safe(sample_report.constSlice());
        if (report_safe) {
            return true;
        }
    }

    return false;
}

fn part2(allocator: std.mem.Allocator) !usize {
    // load input data
    var input: Input = .{};
    const loaded_reports = try input.init(allocator, input_data);
    defer input.deinit();

    std.debug.assert(loaded_reports == 1000);

    // count safe reports
    var safe_reports: usize = 0;
    for (input.reports.items) |report| {
        if (part2_report_safe(report.items)) {
            safe_reports += 1;
        }
    }

    return safe_reports;
}

pub fn main() !void {
    // create the general purpose allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    // part1
    const safe_reports = try part1(allocator);

    std.debug.assert(safe_reports == 332);
    std.debug.print("safe reports: {}\n", .{ safe_reports });

    // part2
    const safe_reports_with_damper = try part2(allocator);

    std.debug.assert(safe_reports_with_damper == 398);
    std.debug.print("safe reports with damper: {}\n", .{ safe_reports_with_damper });
}
