const Types = @import("types.zig");
const ChunkType = @import("types.zig").ChunkType;
const ColorType = @import("types.zig").ColorType;
const ArrayList = @import("std").ArrayList;
const page_allocator = @import("std").heap.page_allocator;
const std = @import("std");

var header: Types.IHDR = undefined;
var chrm: Types.cHRM = undefined;
var gamma: Types.gAMA = undefined;
var iccp: Types.iCCP = undefined;
var sbit: Types.sBIT = undefined;

// TODO learn to setup errors
// parses a png data file into its respective chunks
pub fn parseIntoChunks(data: []u8) ArrayList(Types.Chunk) {
    var currentIndex: u64 = 0;
    var chunks = ArrayList(Types.Chunk).init(page_allocator);

    // check first eight bytes to make sure the signature is correct
    var sig: u64 = 0;
    for (data[0..8]) |val| {
        sig = sig << 8;
        sig = sig | val;
    }
    currentIndex += 8;

    if (sig != Types.PNG_SIGNATURE) {
        // throw an error. Not a png file
        std.log.err("Incorrect Signature", .{});
    }

    // loop through the data
    var currentType: u32 = undefined;
    while (currentType != @intFromEnum(ChunkType.IEND) and currentIndex < data.len) {
        // check the length
        var length: u32 = 0;
        for (data[currentIndex .. currentIndex + 4]) |val| {
            length = length << 8;
            length = length | val;
        }
        currentIndex += 4;

        // check the chunk type
        currentType = 0;
        for (data[currentIndex .. currentIndex + 4]) |val| {
            currentType = currentType << 8;
            currentType = currentType | val;
        }
        currentIndex += 4;

        var chunkData: ArrayList(u8) = undefined;
        if (length != 0) {
            chunkData = ArrayList(u8).init(page_allocator);
            _ = chunkData.appendSlice(data[currentIndex .. currentIndex + length]) catch null;
            currentIndex += length;
        }

        // check the crc
        var crc: u32 = 0;
        for (data[currentIndex .. currentIndex + 4]) |val| {
            crc = crc << 8;
            crc = crc | val;
        }
        currentIndex += 4;
        var chunk = .{ .chunkData = chunkData, .chunkType = @as(Types.ChunkType, @enumFromInt(currentType)), .length = length, .crc = crc };
        chunk = chunk;
        _ = chunks.append(chunk) catch null;
    }

    return chunks;
}

fn parseHeaderFromChunk(chunk: Types.Chunk) Types.IHDR {
    if (chunk.length != 13) {
        // TODO theres a problem. return an error
    }

    const width = u8ToU32(chunk.chunkData.items[0..4]);
    const height = u8ToU32(chunk.chunkData.items[4..8]);

    return Types.IHDR{ .width = width, .height = height, .bitDepth = chunk.chunkData.items[8], .colorType = @enumFromInt(chunk.chunkData.items[9]), .compressionMethod = chunk.chunkData.items[10], .filterMethod = chunk.chunkData.items[11], .interlaceMethod = chunk.chunkData.items[12] };
}

fn parseCHRM(chunk: Types.Chunk) Types.cHRM {
    // parse cHRM from data
    if (chunk.length != 32) {
        // TODO There is either to much data or not enough. Throw an error
    }
    const wX = u8ToU32(chunk.chunkData.items[0..4]);
    const wY = u8ToU32(chunk.chunkData.items[4..8]);
    const rX = u8ToU32(chunk.chunkData.items[8..12]);
    const rY = u8ToU32(chunk.chunkData.items[12..16]);
    const gX = u8ToU32(chunk.chunkData.items[16..20]);
    const gY = u8ToU32(chunk.chunkData.items[20..24]);
    const bX = u8ToU32(chunk.chunkData.items[24..28]);
    const bY = u8ToU32(chunk.chunkData.items[28..32]);

    return Types.cHRM{ .whitePointX = wX, .whitePointY = wY, .redX = rX, .redY = rY, .greenX = gX, .greenY = gY, .blueX = bX, .blueY = bY };
}

fn parseGAMA(chunk: Types.Chunk) Types.gAMA {
    if (chunk.length != 4) {
        // TODO throw an error.  Either too much or not enought data
    }
    const gam: u32 = u8ToU32(chunk.chunkData.items[0..4]);
    return Types.gAMA{ .imageGamma = gam };
}

// TODO implement error handling
fn parseICCP(chunk: Types.Chunk) Types.iCCP {
    var name = ArrayList(u8).init(page_allocator);
    var index: usize = undefined;
    for (chunk.chunkData.items, 0..) |val, i| {
        if (chunk.chunkData.items[i] != 0x00) {
            _ = name.append(val) catch null;
        } else {
            index = i + 1;
        }
    }

    const compressionMethod: u8 = chunk.chunkData.items[index];
    index += 1;
    var comp = ArrayList(u8).init(page_allocator);
    _ = comp.appendSlice(chunk.chunkData.items[index..chunk.length]) catch null;

    return Types.iCCP{ .profileName = name.items, .compressionMethod = compressionMethod, .compressedProfile = comp.items };
}

fn parseSBIT(chunk: Types.Chunk, colorType: ColorType) Types.sBIT {
    var sBit: Types.sBIT = undefined;
    if (colorType == ColorType.Greyscale) {
        // color 0
        sBit = Types.sBIT{ .g = chunk.chunkData.items[0] };
    } else if (colorType == ColorType.TrueColor or colorType == ColorType.IndexedColor) {
        // color 2 or 3
        sBit = Types.sBIT{ .rgb = .{ .sRB = chunk.chunkData.items[0], .sGB = chunk.chunkData.items[1], .sBB = chunk.chunkData.items[2] } };
    } else if (colorType == ColorType.GreyscaleAlpha) {
        // color 4
        sBit = Types.sBIT{ .ga = .{ .sGB = chunk.chunkData.items[0], .sAB = chunk.chunkData.items[1] } };
    } else if (colorType == ColorType.TrueColorAlpha) {
        // color 6
        sBit = Types.sBIT{ .rgba = .{ .sRB = chunk.chunkData.items[0], .sGB = chunk.chunkData.items[1], .sBB = chunk.chunkData.items[2], .sAB = chunk.chunkData.items[3] } };
    } else {
        // TODO throw an error signifying an incorrect color type
        std.log.err("{s}", .{"Incorrect color type provided"});
    }

    return sBit;
}

fn parseSRGB(chunk: Types.Chunk) Types.sRGB {
    if (chunk.length != 1) {
        // TODO throw an error that'll need to be handled
        std.log.err("{s}", .{"incorrect amount of data provided for SRGB"});
    }
    return Types.sRGB{ .intent = @enumFromInt(chunk.chunkData.items[0]) };
}

fn parsePLTE(chunk: Types.Chunk) ArrayList(Types.PLTE) {
    if (chunk.length % 3 != 0) {
        // there's an error.  value must be divisible by 3
        std.log.err("{s}", .{"The length of PLTE must be divisible by three"});
        // TODO throw an error
    }

    var pltes = ArrayList(Types.PLTE).init(page_allocator);

    var i: usize = 0;
    for (0..chunk.length / 3) |_| {
        _ = pltes.append(Types.PLTE{ .red = chunk.chunkData.items[i + 0], .green = chunk.chunkData.items[i + 1], .blue = chunk.chunkData.items[i + 2] }) catch null;
        i += 3;
    }

    return pltes;
}

fn parseBKGD(chunk: Types.Chunk, color: ColorType) Types.bKGD {
    if (color == ColorType.Greyscale or color == ColorType.GreyscaleAlpha) {
        return Types.bKGD{ .greyscale = u8ToU16(chunk.chunkData.items[0..2]) };
    } else if (color == ColorType.TrueColor or color == ColorType.TrueColorAlpha) {
        return Types.bKGD{ .rgb = .{ .red = u8ToU16(chunk.chunkData.items[0..2]), .green = u8ToU16(chunk.chunkData.items[2..4]), .blue = u8ToU16(chunk.chunkData.items[4..6]) } };
    } else if (color == ColorType.IndexedColor) {
        return Types.bKGD{ .palleteIndex = chunk.chunkData.items[0] };
    } else {
        // TODO throw an error
        std.log.err("{s}", .{"The bKGD cannot be parsed because an incorrect color type was provided."});
        return undefined;
    }
}

fn parseTRNS(chunk: Types.Chunk, color: ColorType) Types.tRNS {
    if (color == ColorType.Greyscale and chunk.length == 2) {
        return Types.tRNS{ .grey = u8ToU16(chunk.chunkData.items[0..2]) };
    } else if (color == ColorType.TrueColor and chunk.length == 6) {
        return Types.tRNS{ .rgb = Types.RGB{ .red = u8ToU16(chunk.chunkData.items[0..2]), .blue = u8ToU16(chunk.chunkData.items[2..4]), .green = u8ToU16(chunk.chunkData.items[4..6]) } };
    } else if (color == ColorType.IndexedColor and chunk.length == 3) {
        return Types.tRNS{ .alphas = chunk.chunkData.items };
    } else {
        // TODO throw an error
        return undefined;
    }
}

// TODO turn this into a generic
fn u8ToU32(vals: *[4]u8) u32 {
    var combinedVal: u32 = 0;
    for (vals) |val| {
        combinedVal <<= 8;
        combinedVal |= val;
    }
    return combinedVal;
}

fn u8ToU16(vals: *[2]u8) u16 {
    var combinedVal: u16 = 0;
    for (vals) |val| {
        combinedVal <<= 8;
        combinedVal |= val;
    }
    return combinedVal;
}

// parse a set of chunks in there corresponding data structures
pub fn parseChunks(chunks: ArrayList(Types.Chunk)) void {
    for (chunks.items) |val| {
        std.log.debug("0x{x}", .{@intFromEnum(val.chunkType)});
    }

    const headerChunk = chunks.items[0];
    if (headerChunk.chunkType != ChunkType.IHDR) {
        // return an error. The first chunk must be the header
        std.log.err("{s}", .{"The first chunk must be IHDR"});
    }
    header = parseHeaderFromChunk(headerChunk);

    for (chunks.items[1..]) |chunk| {
        if (chunk.chunkType == ChunkType.cHRM) {
            // parse cHRM
            chrm = parseCHRM(chunk);
            continue;
        } else if (chunk.chunkType == ChunkType.gAMA) {
            // parse gAMA
            gamma = parseGAMA(chunk);
            continue;
        } else if (chunk.chunkType == ChunkType.iCCP) {
            // parse iCCP
            iccp = parseICCP(chunk);
            continue;
        } else if (chunk.chunkType == ChunkType.sBIT) {
            // parse sBIT
            sbit = parseSBIT(chunk, header.colorType);
            continue;
        } else if (chunk.chunkType == ChunkType.sRGB) {
            // parse sRGB
            _ = parseSRGB(chunk);
            continue;
        } else if (header.colorType != ColorType.Greyscale and header.colorType != ColorType.TrueColorAlpha and chunk.chunkType == ChunkType.PLTE) {
            // parse PLTE
            _ = parsePLTE(chunk);
            continue;
        } else if (chunk.chunkType == ChunkType.bKGD) {
            // parse bKGD
            _ = parseBKGD(chunk, header.colorType);
            continue;
        } else if (chunk.chunkType == ChunkType.TRNS) {
            // parse TRNS
            _ = parseTRNS(chunk, header.colorType);
        } else if (chunk.chunkType == ChunkType.pHYs) {
            // parse pHYs
        } else if (chunk.chunkType == ChunkType.sPLT) {
            // parse sPLT
        } else if (chunk.chunkType == ChunkType.IDAT) {
            // parse IDAT
        } else {
            std.log.info("{s} : 0x{x}", .{ "Unrecognized type", @intFromEnum(chunk.chunkType) });
        }
    }
}
