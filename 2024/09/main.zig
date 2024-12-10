const std = @import("std");

const DiskBlock = union(enum) {
    const Self = @This();

    empty: void,
    file: usize,

    pub fn equals(self: Self, other: Self) bool {
        return switch (self) {
            .file => |self_index| switch (other) {
                .file => |other_index| self_index == other_index,
                else => false,
            },
            .empty => switch (other) {
                .empty => true,
                else => false,
            },
        };
    }
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

fn defragment_blocks(disk_map: *DiskMapUnmanaged) usize {
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
        // leading_block.* = trailing_block.*;
        // trailing_block.* = DiskBlock.empty;
        std.mem.swap(DiskBlock, leading_block, trailing_block);
        moved_blocks += 1;
    }

    return moved_blocks;
}

test "defragment_blocks" {
    // simple example
    const simple_layout = "12345";
    var simple_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, simple_layout);
    defer simple_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(132, simple_disk_map.checksum());

    const simple_moved_blocks = defragment_blocks(&simple_disk_map);
    try std.testing.expectEqual(5, simple_moved_blocks);
    try std.testing.expectEqual(60, simple_disk_map.checksum());

    // complex example
    const complex_layout = "2333133121414131402";
    var complex_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, complex_layout);
    defer complex_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(4116, complex_disk_map.checksum());

    const complex_moved_blocks = defragment_blocks(&complex_disk_map);
    try std.testing.expectEqual(12, complex_moved_blocks);
    try std.testing.expectEqual(1928, complex_disk_map.checksum());
}

fn part1(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    const layout = std.mem.trim(u8, input_data, &.{ '\n' });
    var disk_map = try DiskMapUnmanaged.init(allocator, layout);
    defer disk_map.deinit(allocator);

    _ = defragment_blocks(&disk_map);
    return disk_map.checksum();
}

const FileExtent = struct {
    const Self = @This();

    index: usize,
    size: usize,

    pub fn equals(self: Self, other: Self) bool {
        return (self.index == other.index and self.size == other.size);
    }
};

fn file_extents(allocator: std.mem.Allocator, disk_map: *const DiskMapUnmanaged) ![]FileExtent {
    var extents = std.AutoHashMap(usize, FileExtent).init(allocator);
    defer extents.deinit();

    var block_index: usize = 0;
    while (block_index < disk_map.blocks.len) {
        const block = &disk_map.blocks[block_index];
        const file_index = switch (block.*) {
            .file => |index| index,
            else => {
                block_index += 1;
                continue;
            },
        };

        if (extents.get(file_index)) |_| {
            return error.FilesNotContiguous;
        }

        var extent: FileExtent = .{ .index = block_index, .size = 0 };
        while (block_index < disk_map.blocks.len and block.equals(disk_map.blocks[block_index])) {
            extent.size += 1;
            block_index += 1;
        }

        try extents.put(file_index, extent);
    }

    std.debug.assert(extents.count() == disk_map.files);
    const effective = try allocator.alloc(FileExtent, disk_map.files);
    errdefer allocator.free(effective);

    for (0.., effective) |index, *target_extent| {
        target_extent.* = extents.get(index) orelse unreachable;
    }

    return effective;
}

test "file_extents" {
    // simple example
    const simple_layout = "12345";
    var simple_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, simple_layout);
    defer simple_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(132, simple_disk_map.checksum());
    const simple_extents = try file_extents(std.testing.allocator, &simple_disk_map);
    defer std.testing.allocator.free(simple_extents);

    try std.testing.expectEqual(simple_disk_map.files, simple_extents.len);
    try std.testing.expect(simple_extents[0].equals(FileExtent{ .index = 0, .size = 1 }));
    try std.testing.expect(simple_extents[1].equals(FileExtent{ .index = 3, .size = 3 }));
    try std.testing.expect(simple_extents[2].equals(FileExtent{ .index = 10, .size = 5 }));
}

fn defragment_files(allocator: std.mem.Allocator, disk_map: *DiskMapUnmanaged) !usize {
    var extents = try file_extents(allocator, disk_map);
    defer allocator.free(extents);

    var moved_files: usize = 0;
    for (0..extents.len) |index| {
        const file_extent = &extents[extents.len - index - 1];

        var target_extent: FileExtent = .{ .index = 0, .size = 0 };
        for (0..file_extent.*.index) |block_index| {
            switch (disk_map.blocks[block_index]) {
                .file => |_| {
                    target_extent.index = block_index + 1;
                    target_extent.size = 0;
                },
                .empty => {
                    target_extent.size += 1;
                }
            }

            if (target_extent.size >= file_extent.*.size) {
                for (0..file_extent.size) |offset| {
                    std.mem.swap(
                        DiskBlock,
                        &disk_map.blocks[target_extent.index + offset],
                        &disk_map.blocks[file_extent.*.index + offset],
                    );
                }

                file_extent.*.index = target_extent.index;
                moved_files += 1;
                break;
            }
        }
    }

    return moved_files;
}

test "defragment_files" {
    // simple example
    const simple_layout = "12345";
    var simple_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, simple_layout);
    defer simple_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(132, simple_disk_map.checksum());

    const simple_moved_files = defragment_files(std.testing.allocator, &simple_disk_map);
    try std.testing.expectEqual(0, simple_moved_files);
    try std.testing.expectEqual(132, simple_disk_map.checksum());

    // complex example
    const complex_layout = "2333133121414131402";
    var complex_disk_map = try DiskMapUnmanaged.init(std.testing.allocator, complex_layout);
    defer complex_disk_map.deinit(std.testing.allocator);

    try std.testing.expectEqual(4116, complex_disk_map.checksum());

    const complex_moved_files = defragment_files(std.testing.allocator, &complex_disk_map);
    try std.testing.expectEqual(4, complex_moved_files);
    try std.testing.expectEqual(2858, complex_disk_map.checksum());
}

fn part2(allocator: std.mem.Allocator, input_data: []const u8) !usize {
    const layout = std.mem.trim(u8, input_data, &.{ '\n' });
    var disk_map = try DiskMapUnmanaged.init(allocator, layout);
    defer disk_map.deinit(allocator);

    _ = try defragment_files(allocator, &disk_map);
    return disk_map.checksum();
}

pub fn run(allocator: std.mem.Allocator, input_data: []const u8) !void {
    // part 1
    const checksum_blocks = try part1(allocator, input_data);

    try std.testing.expectEqual(6430446922192, checksum_blocks);
    std.debug.print("checksum blocks: {d}\n", .{checksum_blocks});

    // part 2
    const checksum_files = try part2(allocator, input_data);

    try std.testing.expectEqual(6460170593016, checksum_files);
    std.debug.print("checksum files: {d}\n", .{checksum_files});
}
