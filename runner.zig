const std = @import("std");

const solution_2024_01 = @import("2024/01/main.zig");
const solution_2024_02 = @import("2024/02/main.zig");
const solution_2024_03 = @import("2024/03/main.zig");
const solution_2024_04 = @import("2024/04/main.zig");

test {
    std.testing.refAllDecls(@This());
}

const Solution = struct {
    const Self = @This();

    year: u16,
    day: u8,
    run: *const fn (std.mem.Allocator, []const u8) anyerror!void,
};

const solutions = std.StaticStringMap(Solution).initComptime(&.{
    .{ "2024-01", .{ .year = 2024, .day = 1, .run = &solution_2024_01.run } },
    .{ "2024-02", .{ .year = 2024, .day = 2, .run = &solution_2024_02.run } },
    .{ "2024-03", .{ .year = 2024, .day = 3, .run = &solution_2024_03.run } },
    .{ "2024-04", .{ .year = 2024, .day = 4, .run = &solution_2024_04.run } },
});

fn fetch_input_data(
    allocator: std.mem.Allocator,
    aoc_session: []const u8,
    solution: Solution,
) ![]const u8 {
    // create the HTTP client
    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();

    // allocate a buffer for formatting strings and storing HTTP request data
    const buffer = try allocator.alloc(u8, 4 * 1024 * 1024);
    defer allocator.free(buffer);

    // determine the input data request uri based on the solution date
    const input_uri_buffer = buffer;
    const input_uri_raw = try std.fmt.bufPrint(
        input_uri_buffer,
        "https://adventofcode.com/{d}/day/{d}/input",
        .{ solution.year, solution.day },
    );

    const input_uri = try std.Uri.parse(input_uri_raw);

    // determine the input data request cookie header value based on the api token
    const input_cookie_buffer = input_uri_buffer[input_uri_raw.len..];
    const input_cookie_value = try std.fmt.bufPrint(
        input_cookie_buffer,
        "session={s}",
        .{aoc_session},
    );

    // create the input data request
    const input_request_buffer = input_cookie_buffer[input_cookie_value.len..];
    var input_request = try http_client.open(
        .GET,
        input_uri,
        .{
            .server_header_buffer = input_request_buffer,
            .extra_headers = &.{
                .{ .name = "User-Agent", .value = "github.com/CtrlC-Root/advent-of-code" },
                .{ .name = "Cookie", .value = input_cookie_value },
            },
        },
    );

    defer input_request.deinit();

    // send input data request and wait for it to complete
    try input_request.send();
    try input_request.finish();
    try input_request.wait();

    switch (input_request.response.status) {
        .ok => {},
        else => {
            std.debug.print("fetching input data failed (http status {})\n", .{input_request.response.status});
            return error.FetchInputFailed;
        },
    }

    // retrieve input data from input data response and store in an allocated
    // buffer which the caller owns
    var input_reader = input_request.reader();
    const input_data = try input_reader.readAllAlloc(allocator, 4 * 1024 * 1024);
    // errdefer allocator.free(input_data);

    // return solution input data
    return input_data;
}

pub fn main() !void {
    // create the general purpose allocator
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const allocator = general_purpose_allocator.allocator();

    // retrieve the advent of code session token from the environment
    const aoc_session = std.process.getEnvVarOwned(allocator, "AOC_SESSION") catch {
        std.debug.print("failed to get Advent of Code API session from $AOC_SESSION environment variable\n", .{});
        return error.MissingApiSession;
    };

    defer allocator.free(aoc_session);

    // parse command line arguments
    var argument_iterator = try std.process.argsWithAllocator(allocator);
    defer argument_iterator.deinit();

    const program_name = argument_iterator.next() orelse {
        std.debug.print("program name not found in arguments\n", .{});
        return error.InvalidArguments;
    };

    _ = program_name;

    const solution_name = argument_iterator.next() orelse {
        std.debug.print("solution name not found in arguments\n", .{});
        return error.InvalidArguments;
    };

    std.debug.assert(argument_iterator.next() == null);

    // lookup details of the requested solution
    const solution = solutions.get(solution_name) orelse {
        std.debug.print("invalid solution: {s}\n", .{solution_name});
        return error.InvalidSolution;
    };

    // determine the path to the input data file
    var year_buffer: [4]u8 = undefined;
    _ = std.fmt.bufPrint(&year_buffer, "{d:0>4}", .{solution.year}) catch unreachable;

    var day_buffer: [2]u8 = undefined;
    _ = std.fmt.bufPrint(&day_buffer, "{d:0>2}", .{solution.day}) catch unreachable;

    const cwd_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_path);

    const input_data_path = try std.fs.path.join(allocator, &[_][]const u8{
        cwd_path,
        &year_buffer,
        &day_buffer,
        "input",
    });

    defer allocator.free(input_data_path);

    // fetch the input data from advent of code if necessary and cache it locally
    const input_file_exists = if (std.fs.accessAbsolute(input_data_path, .{})) true else |_| false;
    const input_data = if (input_file_exists) read_file: {
        std.debug.print("reading input data from file: {s}\n", .{input_data_path});
        const input_data_file = try std.fs.openFileAbsolute(input_data_path, .{});
        defer input_data_file.close();

        const input_data = try input_data_file.readToEndAlloc(allocator, 4 * 1024 * 1024);
        break :read_file input_data;
    } else fetch_and_write_file: {
        std.debug.print("fetching input data from advent of code\n", .{});
        const input_data = try fetch_input_data(allocator, aoc_session, solution);
        errdefer allocator.free(input_data);

        std.debug.print("writing input data to file: {s}\n", .{input_data_path});
        const input_data_file = try std.fs.createFileAbsolute(input_data_path, .{});
        defer input_data_file.close();

        try input_data_file.writeAll(input_data);
        break :fetch_and_write_file input_data;
    };

    defer allocator.free(input_data);

    // run the solution
    try solution.run(allocator, input_data);
}
