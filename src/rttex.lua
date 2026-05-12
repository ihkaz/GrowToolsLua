local Binary = require("src.binary")
local Png = require("src.png")
local Zlib = require("src.zlib")

local Rttex = {}

local RTTEX_HEADER_SIZE = 0x7c
local RTPACK_HEADER_SIZE = 32

local function write_le_i32(bytes, offset_zero_based, value)
    local packed = string.pack("<i4", value)
    for index = 1, 4 do
        bytes[offset_zero_based + index] = packed:byte(index)
    end
end

local function write_le_u32(bytes, offset_zero_based, value)
    local packed = Binary.le_u32_bytes(value)
    for index = 1, 4 do
        bytes[offset_zero_based + index] = packed:byte(index)
    end
end

local function make_rttex_header(width, height, pixel_count)
    local header = "RTTXTR" .. string.rep("\0", RTTEX_HEADER_SIZE - 6)
    local bytes = { header:byte(1, #header) }

    bytes[29] = 1
    bytes[30] = 0
    write_le_i32(bytes, 8, Binary.lowest_power_of_2(height))
    write_le_i32(bytes, 12, Binary.lowest_power_of_2(width))
    write_le_i32(bytes, 16, 5121)
    write_le_i32(bytes, 20, height)
    write_le_i32(bytes, 24, width)
    write_le_i32(bytes, 32, 1)
    write_le_i32(bytes, 100, height)
    write_le_i32(bytes, 104, width)
    write_le_i32(bytes, 108, pixel_count)
    write_le_i32(bytes, 112, 0)

    return Binary.bytes_to_string(bytes)
end

local function make_rtpack_header(compressed_size, decompressed_size)
    local header = "RTPACK" .. string.rep("\0", RTPACK_HEADER_SIZE - 6)
    local bytes = { header:byte(1, #header) }

    write_le_u32(bytes, 8, compressed_size)
    write_le_u32(bytes, 12, decompressed_size)
    bytes[17] = 1

    return Binary.bytes_to_string(bytes)
end

local function read_rttex_size(data)
    local fallback_height = Binary.le_i32(data, 21)
    local fallback_width = Binary.le_i32(data, 25)
    local height = Binary.le_i32(data, 101)
    local width = Binary.le_i32(data, 105)
    if width <= 0 then
        width = fallback_width
    end
    if height <= 0 then
        height = fallback_height
    end
    return width, height
end

function Rttex.pack_png_bytes(png_data)
    local image = Png.decode(png_data)
    local rttex_header = make_rttex_header(image.width, image.height, #image.pixels)
    local rttex_data = rttex_header .. image.pixels
    local compressed = Zlib.deflate(rttex_data)
    return make_rtpack_header(#compressed, #rttex_data) .. compressed
end

function Rttex.unpack_bytes(data)
    if data:sub(1, 6) == "RTPACK" then
        data = Zlib.inflate(data:sub(RTPACK_HEADER_SIZE + 1))
    end
    if data:sub(1, 6) ~= "RTTXTR" then
        Binary.fail("This is not a RTTEX file")
    end

    local width, height = read_rttex_size(data)
    local channels = 3 + Binary.u8(data, 29)
    local pixel_count = Binary.le_i32(data, 109)
    local pixels = data:sub(RTTEX_HEADER_SIZE + 1, RTTEX_HEADER_SIZE + pixel_count)
    local expected_size = width * height * channels
    if #pixels ~= expected_size then
        Binary.fail("Invalid RTTEX pixel data: expected " .. expected_size .. " bytes, got " .. #pixels)
    end

    return Png.encode(width, height, channels, pixels)
end

function Rttex.RTTEXPack(name_png)
    return Rttex.pack_png_bytes(Binary.read_file(name_png))
end

function Rttex.RTTEXUnpack(name_file)
    return Rttex.unpack_bytes(Binary.read_file(name_file))
end

return Rttex
