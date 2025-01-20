const std = @import("std");
const fs = @import("std").fs;
const debug = @import("std").debug;
const ArrayList = @import("std").ArrayList;
const page_allocator = @import("std").heap.page_allocator;
const decoder = @import("decoder.zig");

const MAX_FILE_SIZE: u32 = 100000000;

fn readFile(fileName: []u8) !ArrayList(u8) {
    const file = fs.cwd().openFile(fileName, .{}) catch null;
    if (file == null) {
        std.log.err("{s}", .{"File doesn't exist"});
        return error.FileNotFound;
    }
    defer file.?.close();

    var data = ArrayList(u8).init(page_allocator);
    // TODO do something with this error
    const err = file.?.reader().readAllArrayList(&data, MAX_FILE_SIZE) catch null;
    if (err == null) {
        std.log.err("{s}", .{"Failed to read data from file"});
        return error.ParsingErrors;
    }

    return data;
}

pub fn main() void {
    var args = std.process.args();
    if (!args.skip()) {
        return;
    }

    const fileLocation = args.next().?;
    const data = readFile(@constCast(fileLocation)) catch null;
    if (data == null) {
        return;
    }
    const chunks = decoder.parseIntoChunks(data.?.items);
    decoder.parseChunks(chunks);
}
