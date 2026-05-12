local Binary = require("src.binary")
local Checksum = require("src.checksum")
local Zlib = require("src.zlib")

local Png = {}

local PNG_SIGNATURE = "\137PNG\r\n\026\n"

local function paeth_predictor(a, b, c)
    local p = a + b - c
    local pa = math.abs(p - a)
    local pb = math.abs(p - b)
    local pc = math.abs(p - c)
    if pa <= pb and pa <= pc then
        return a
    elseif pb <= pc then
        return b
    end
    return c
end

local function unfilter_scanlines(data, width, height, bytes_per_pixel, stride)
    local rows = {}
    local position = 1
    local previous = {}
    for _ = 1, height do
        local filter_type = data:byte(position)
        position = position + 1
        local row = {}
        for index = 1, stride do
            local raw = data:byte(position)
            position = position + 1
            local left = index > bytes_per_pixel and row[index - bytes_per_pixel] or 0
            local up = previous[index] or 0
            local upper_left = index > bytes_per_pixel and previous[index - bytes_per_pixel] or 0
            if filter_type == 0 then
                row[index] = raw
            elseif filter_type == 1 then
                row[index] = (raw + left) & 0xff
            elseif filter_type == 2 then
                row[index] = (raw + up) & 0xff
            elseif filter_type == 3 then
                row[index] = (raw + ((left + up) >> 1)) & 0xff
            elseif filter_type == 4 then
                row[index] = (raw + paeth_predictor(left, up, upper_left)) & 0xff
            else
                Binary.fail("Unsupported PNG filter type " .. filter_type)
            end
        end
        rows[#rows + 1] = row
        previous = row
    end
    return rows
end

local function read_chunks(data)
    local chunks = {
        idat = {},
    }
    local position = #PNG_SIGNATURE + 1
    while position <= #data do
        local length = Binary.be_u32(data, position)
        local chunk_type = data:sub(position + 4, position + 7)
        local chunk_data = data:sub(position + 8, position + 7 + length)
        position = position + 12 + length

        if chunk_type == "IHDR" then
            chunks.width = Binary.be_u32(chunk_data, 1)
            chunks.height = Binary.be_u32(chunk_data, 5)
            chunks.bit_depth = chunk_data:byte(9)
            chunks.color_type = chunk_data:byte(10)
        elseif chunk_type == "PLTE" then
            chunks.palette = chunk_data
        elseif chunk_type == "tRNS" then
            chunks.transparency = chunk_data
        elseif chunk_type == "IDAT" then
            chunks.idat[#chunks.idat + 1] = chunk_data
        elseif chunk_type == "IEND" then
            break
        end
    end
    return chunks
end

local function palette_rgba(chunks, palette_index)
    if chunks.palette == nil then
        Binary.fail("Invalid PNG file: indexed image is missing PLTE")
    end

    local palette_base = (palette_index * 3) + 1
    local alpha = chunks.transparency ~= nil and chunks.transparency:byte(palette_index + 1) or 255
    if alpha == nil then
        alpha = 255
    end
    return chunks.palette:byte(palette_base),
        chunks.palette:byte(palette_base + 1),
        chunks.palette:byte(palette_base + 2),
        alpha
end

local function row_pixel_to_rgba(chunks, row, base)
    if chunks.color_type == 0 then
        local gray = row[base]
        return gray, gray, gray, 255
    elseif chunks.color_type == 2 then
        return row[base], row[base + 1], row[base + 2], 255
    elseif chunks.color_type == 3 then
        return palette_rgba(chunks, row[base])
    elseif chunks.color_type == 4 then
        local gray = row[base]
        return gray, gray, gray, row[base + 1]
    end
    return row[base], row[base + 1], row[base + 2], row[base + 3]
end

function Png.decode(data)
    if data:sub(1, #PNG_SIGNATURE) ~= PNG_SIGNATURE then
        Binary.fail("Invalid PNG file: signature mismatch")
    end

    local chunks = read_chunks(data)
    if chunks.width == nil or chunks.height == nil or chunks.bit_depth == nil or chunks.color_type == nil then
        Binary.fail("Invalid PNG file: missing IHDR")
    end
    if chunks.bit_depth ~= 8 then
        Binary.fail("Unsupported PNG file: only 8-bit channels are supported")
    end

    local source_channels_by_type = { [0] = 1, [2] = 3, [3] = 1, [4] = 2, [6] = 4 }
    local source_channels = source_channels_by_type[chunks.color_type]
    if source_channels == nil then
        Binary.fail("Unsupported PNG color type " .. chunks.color_type)
    end

    local inflated = Zlib.inflate(table.concat(chunks.idat))
    local stride = chunks.width * source_channels
    local rows = unfilter_scanlines(inflated, chunks.width, chunks.height, source_channels, stride)
    local pixels = {}

    for y = chunks.height, 1, -1 do
        local row = rows[y]
        for x = 0, chunks.width - 1 do
            local base = (x * source_channels) + 1
            pixels[#pixels + 1] = string.char(row_pixel_to_rgba(chunks, row, base))
        end
    end

    return {
        width = chunks.width,
        height = chunks.height,
        channels = 4,
        pixels = table.concat(pixels),
    }
end

local function png_chunk(chunk_type, chunk_data)
    return Binary.be_u32_bytes(#chunk_data)
        .. chunk_type
        .. chunk_data
        .. Binary.be_u32_bytes(Checksum.crc32(chunk_type .. chunk_data))
end

function Png.encode(width, height, channels, raw_pixels_flipped)
    if channels ~= 4 then
        Binary.fail("Unsupported RTTEX channel count " .. channels .. ": only RGBA is supported")
    end

    local scanlines = {}
    local stride = width * channels
    for y = height, 1, -1 do
        local start = ((y - 1) * stride) + 1
        scanlines[#scanlines + 1] = "\0" .. raw_pixels_flipped:sub(start, start + stride - 1)
    end

    local ihdr = Binary.be_u32_bytes(width)
        .. Binary.be_u32_bytes(height)
        .. string.char(8, 6, 0, 0, 0)

    return PNG_SIGNATURE
        .. png_chunk("IHDR", ihdr)
        .. png_chunk("IDAT", Zlib.deflate(table.concat(scanlines)))
        .. png_chunk("IEND", "")
end

return Png
