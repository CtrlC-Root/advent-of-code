const std = @import("std");

const DiskBlock = union(enum) {
    empty: void,
    file: usize,
};

const DiskMapUnmanaged = struct {
    const Self = @This();

    files: usize,
    blocks: []DiskBlock,

    pub fn init(allocator: std.mem.Allocator, layout: []const u8) !Self {
        var blocks = std.ArrayList(DiskBlock).init(allocator);
        errdefer blocks.deinit();

        var file_index: usize = 0;
        for (0.., layout) |index, entry| {
            const value = try std.fmt.parseInt(u8, &.{entry}, 10);
            if (index % 2 == 0) {
                for (0..value) |_| {
                    try blocks.append(DiskBlock{ .file = file_index });
                }

                file_index += 1;
            } else {
                for (0..value) |_| {
                    try blocks.append(DiskBlock.empty);
                }
            }
        }

        return .{
            .files = file_index,
            .blocks = try blocks.toOwnedSlice(),
        };
    }

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        allocator.free(self.blocks);
    }

    pub fn checkFreeSpace(self: Self) usize {
        var total_blocks: usize = 0;
        for (self.blocks) |block| {
            switch (block) {
                .empty => { total_blocks += 1; },
                else => {},
            }
        }

        return total_blocks;
    }

    pub fn checkFileSize(self: Self, file: usize) usize {
        std.debug.assert(file < self.files);

        var total_blocks: usize = 0;
        for (self.blocks) |block| {
            const block_file = switch (block) {
                .file => |index| index,
                else => continue,
            };

            if (block_file == file) {
                total_blocks += 1;
            }
        }

        return total_blocks;
    }

    pub fn checksum(self: Self) usize {
        var value: usize = 0;

        for (0.., self.blocks) |block_index, block| {
            switch (block) {
                .file => |file_index| {
                    value += block_index * file_index;
                },
                else => {},
            }
        }

        return value;
    }
};

test "input_parse" {
    // simple example
    const simple_layout = "12345";
    const simple_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, simple_layout);
    defer simple_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(3, simple_disk_map.files);
    try std.testing.expectEqual(6, simple_disk_map.checkFreeSpace());
    try std.testing.expectEqual(1, simple_disk_map.checkFileSize(0));
    try std.testing.expectEqual(3, simple_disk_map.checkFileSize(1));
    try std.testing.expectEqual(5, simple_disk_map.checkFileSize(2));

    // complex example
    const complex_layout = "2333133121414131402";
    const complex_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, complex_layout);
    defer complex_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(10, complex_disk_map.files);
    try std.testing.expectEqual(14, complex_disk_map.checkFreeSpace());
    try std.testing.expectEqual(2, complex_disk_map.checkFileSize(0));
    try std.testing.expectEqual(3, complex_disk_map.checkFileSize(1));
    try std.testing.expectEqual(1, complex_disk_map.checkFileSize(2));
    try std.testing.expectEqual(3, complex_disk_map.checkFileSize(3));
    try std.testing.expectEqual(2, complex_disk_map.checkFileSize(4));
    try std.testing.expectEqual(4, complex_disk_map.checkFileSize(5));
    try std.testing.expectEqual(4, complex_disk_map.checkFileSize(6));
    try std.testing.expectEqual(3, complex_disk_map.checkFileSize(7));
    try std.testing.expectEqual(4, complex_disk_map.checkFileSize(8));
    try std.testing.expectEqual(2, complex_disk_map.checkFileSize(9));
}

fn defragment(disk_map: *DiskMapUnmanaged) usize {
    var moved_blocks: usize = 0;
    var leading_index: usize = 0;
    var trailing_index: usize = disk_map.blocks.len - 1;

    while (leading_index < trailing_index) {
        // locate the first empty block
        const leading_block = &disk_map.blocks[leading_index];
        if (leading_block.* != DiskBlock.empty) {
            leading_index += 1;
            continue;
        }

        // locate the last non-empty block
        const trailing_block = &disk_map.blocks[trailing_index];
        if (trailing_block.* == DiskBlock.empty) {
            trailing_index -= 1;
            continue;
        }

        // move the file index from the trailing block to the leading block
        leading_block.* = trailing_block.*;
        trailing_block.* = DiskBlock.empty;
        moved_blocks += 1;
    }

    return moved_blocks;
}

test "defragment" {
    // simple example
    const simple_layout = "12345";
    var simple_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, simple_layout);
    defer simple_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(132, simple_disk_map.checksum());

    const simple_moved_blocks = defragment(&simple_disk_map);
    try std.testing.expectEqual(5, simple_moved_blocks);
    try std.testing.expectEqual(60, simple_disk_map.checksum());

    // complex example
    const complex_layout = "2333133121414131402";
    var complex_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, complex_layout);
    defer complex_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(4116, complex_disk_map.checksum());

    const complex_moved_blocks = defragment(&complex_disk_map);
    try std.testing.expectEqual(12, complex_moved_blocks);
    try std.testing.expectEqual(1928, complex_disk_map.checksum());
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    const layout = std.mem.trim(u8, input_data, &.{ '\n' });
    var disk_map = try DiskMapUnmanaged.init(allocator, layout);
    defer disk_map.deinit(allocator);

    _ = defragment(&disk_map);
    return disk_map.checksum();
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const checksum = try part1(allocator, input_data);

    // try std.testing.expectEqual(1111, checksum);
    std.debug.print("checksum: {d}\n", .{checksum});

    // part 2
    // const possible_loops = try part2(allocator, input_data);

    // try std.testing.expectEqual(2162, possible_loops);
    // std.debug.print("possible loops: {d}\n", .{possible_loops});
}
