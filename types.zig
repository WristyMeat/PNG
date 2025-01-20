//! This file stores all the types and constant values for a PNG file
const ArrayList = @import("std").ArrayList;
pub const PNG_SIGNATURE: u64 = 0x89504E470D0A1A0A;

pub const ColorType = enum(u8) { Greyscale = 0, TrueColor = 2, IndexedColor = 3, GreyscaleAlpha = 4, TrueColorAlpha = 6 };

pub const RenderingIntent = enum(u8) { Perceptual = 0, RelativeColorimetric = 1, Saturation = 2, AbsoluteColorimetric = 3 };

pub const UnitSpecifier = enum(u8) { Unknown = 0, Metre = 1 };

pub const FilterType = enum(u8) { None = 0, Sub = 1, Up = 2, Average = 3, Paeth = 4 };

pub const ChunkType = enum(u32) {
    IHDR = 0x49484452, // Image header
    cHRM = 0x6348524D, // chromaticities
    PLTE = 0x504C5445, // palette entries.  Will appear for color type 3, may appear for 2 and 6, and will not appear for 0 and 4
    IEND = 0x49454E44, // Image end
    IDAT = 0x49444154, // Image data
    TRNS = 0x74524E53, // Transparency. Not valid for types 4 and 6
    gAMA = 0x67414D41, // Gamma
    iCCP = 0x69434350, // International color consortium (ICC)
    sBIT = 0x73424954, // Significant bits
    sRGB = 0x73524742, // RGB color space
    tEXt = 0x74455874, // Text strings
    zTXt = 0x7A545874, // Compressed text data
    iTXt = 0x69545874, // International text data
    bKGD = 0x62494544, // Background color
    hIST = 0x68475354, // Image histogram
    pHYs = 0x70485973, // Physical pixel dimensions
    sPLT = 0x73504C54, // Suggested palette
    tIME = 0x74494D45, // Image last modification time
};

pub const ParsingErrors = error{};

pub const DeflateCompression = struct { code: u8, flags: u8, data: ArrayList(u8), checkValue: u16 };
// year is full year. eg. 1995
pub const tIME = struct { year: u16, month: u8, day: u8, hour: u8, minute: u8, second: u8 };
// the size of rgba will be either 1 or 2 bytes long as specified by the depth
pub const sPLT = struct { name: [80]u8, depth: u8, entry: struct { rgb: RGB, alpha: u16, frequency: u16 } };
// specifier is either 0 or 1
pub const pHYs = struct { x: u32, y: u32, specifier: UnitSpecifier };
pub const bKGD = union { greyscale: u16, rgb: RGB, palleteIndex: u8 };
// keyword and flag are separated by a null character. language and translatedKeyword are separated by a null character,
//  translatedKeyword and text are separated by a null character
// flag is 1 for compressed text and 0 for uncompressed
pub const iTXt = struct { keyword: [80]u8, flag: u8, method: u8, language: []u8, translatedKeyword: []u8, text: []u8 };
// keyword and method will be separated by a null character
pub const zTXt = struct { keyword: [80]u8, method: u8, text: []u8 };
// keyword and string will be separated by a null character
pub const tEXt = struct { keyword: [80]u8, textString: []u8 };
pub const sRGB = struct { intent: RenderingIntent };
// g for color type 0, rgb for color types 2 and 3, ga for color type 4, and rgba for color type 6
pub const sBIT = union { g: u8, rgb: struct { sRB: u8, sGB: u8, sBB: u8 }, ga: struct { sGB: u8, sAB: u8 }, rgba: struct { sRB: u8, sGB: u8, sBB: u8, sAB: u8 } };
// When processing profile name and compression method will be separated by a single null byte 0x0000
pub const iCCP = struct { profileName: []u8, compressionMethod: u8, compressedProfile: []u8 };
pub const gAMA = struct { imageGamma: u32 };
pub const RGB = struct { red: u16, green: u16, blue: u16 };
// grey for color type 0, rgb for color type 2, and alphas for color type 3
pub const tRNS = union { grey: u16, rgb: RGB, alphas: []u8 };
pub const cHRM = struct { whitePointX: u32, whitePointY: u32, redX: u32, redY: u32, greenX: u32, greenY: u32, blueX: u32, blueY: u32 };
pub const PLTE = struct { red: u8, green: u8, blue: u8 };
pub const IHDR = struct { width: u32, height: u32, bitDepth: u8, colorType: ColorType, compressionMethod: u8, filterMethod: u8, interlaceMethod: u8 };
pub const Chunk = struct { length: u32, chunkType: ChunkType, chunkData: ArrayList(u8), crc: u32 };
