local Binary = require("src.binary")
local Checksum = require("src.checksum")

local Zlib = {}

local function make_bit_reader(data, start_position, end_position)
    return {
        data = data,
        position = start_position,
        limit = end_position,
        bit_buffer = 0,
        bit_count = 0,
    }
end

local function read_bits(reader, count)
    while reader.bit_count < count do
        if reader.position > reader.limit then
            Binary.fail("Unexpected end of deflate stream while reading bits")
        end
        reader.bit_buffer = reader.bit_buffer | (reader.data:byte(reader.position) << reader.bit_count)
        reader.position = reader.position + 1
        reader.bit_count = reader.bit_count + 8
    end

    local mask = (1 << count) - 1
    local value = reader.bit_buffer & mask
    reader.bit_buffer = reader.bit_buffer >> count
    reader.bit_count = reader.bit_count - count
    return value
end

local function align_to_byte(reader)
    reader.bit_buffer = 0
    reader.bit_count = 0
end

local function reverse_bits(value, count)
    local result = 0
    for _ = 1, count do
        result = (result << 1) | (value & 1)
        value = value >> 1
    end
    return result
end

local function build_huffman(lengths)
    local max_bits = 0
    local bl_count = {}
    for _, length in ipairs(lengths) do
        if length > 0 then
            bl_count[length] = (bl_count[length] or 0) + 1
            if length > max_bits then
                max_bits = length
            end
        end
    end

    local code = 0
    local next_code = {}
    for bits = 1, max_bits do
        code = (code + (bl_count[bits - 1] or 0)) << 1
        next_code[bits] = code
    end

    local tree = {}
    for symbol, length in ipairs(lengths) do
        if length > 0 then
            local canonical_code = next_code[length]
            next_code[length] = canonical_code + 1
            local reversed = reverse_bits(canonical_code, length)
            tree[length .. ":" .. reversed] = symbol - 1
        end
    end

    return { tree = tree, max_bits = max_bits }
end

local function decode_symbol(reader, huffman)
    local code = 0
    for length = 1, huffman.max_bits do
        code = code | (read_bits(reader, 1) << (length - 1))
        local symbol = huffman.tree[length .. ":" .. code]
        if symbol ~= nil then
            return symbol
        end
    end
    Binary.fail("Invalid deflate Huffman code")
end

local function make_inflate_output()
    return { bytes = {}, size = 0 }
end

local function append_inflate_byte(output, value)
    output.size = output.size + 1
    output.bytes[output.size] = value
end

local function append_inflate_string(output, value)
    for index = 1, #value do
        append_inflate_byte(output, value:byte(index))
    end
end

local function inflate_output_to_string(output)
    local chunks = {}
    local chunk = {}
    local chunk_size = 0
    for index = 1, output.size do
        chunk_size = chunk_size + 1
        chunk[chunk_size] = string.char(output.bytes[index])
        if chunk_size == 8192 then
            chunks[#chunks + 1] = table.concat(chunk)
            chunk = {}
            chunk_size = 0
        end
    end
    if chunk_size > 0 then
        chunks[#chunks + 1] = table.concat(chunk)
    end
    return table.concat(chunks)
end

local FIXED_LITERAL_LENGTHS = {}
for symbol = 0, 287 do
    if symbol <= 143 then
        FIXED_LITERAL_LENGTHS[symbol + 1] = 8
    elseif symbol <= 255 then
        FIXED_LITERAL_LENGTHS[symbol + 1] = 9
    elseif symbol <= 279 then
        FIXED_LITERAL_LENGTHS[symbol + 1] = 7
    else
        FIXED_LITERAL_LENGTHS[symbol + 1] = 8
    end
end

local FIXED_DISTANCE_LENGTHS = {}
for index = 1, 32 do
    FIXED_DISTANCE_LENGTHS[index] = 5
end

local FIXED_LITERAL_HUFFMAN = build_huffman(FIXED_LITERAL_LENGTHS)
local FIXED_DISTANCE_HUFFMAN = build_huffman(FIXED_DISTANCE_LENGTHS)

local LENGTH_BASES = {
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
    35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
}

local LENGTH_EXTRA_BITS = {
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
}

local DISTANCE_BASES = {
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129,
    193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097,
    6145, 8193, 12289, 16385, 24577,
}

local DISTANCE_EXTRA_BITS = {
    0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6,
    6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
}

local function inflate_codes(reader, literal_huffman, distance_huffman, output)
    while true do
        local symbol = decode_symbol(reader, literal_huffman)
        if symbol < 256 then
            append_inflate_byte(output, symbol)
        elseif symbol == 256 then
            return
        elseif symbol <= 285 then
            local length_index = symbol - 257 + 1
            local length = LENGTH_BASES[length_index] + read_bits(reader, LENGTH_EXTRA_BITS[length_index])
            local distance_symbol = decode_symbol(reader, distance_huffman)
            local distance = DISTANCE_BASES[distance_symbol + 1] + read_bits(reader, DISTANCE_EXTRA_BITS[distance_symbol + 1])
            if distance > output.size then
                Binary.fail("Invalid deflate distance " .. distance .. " for output size " .. output.size)
            end
            for _ = 1, length do
                append_inflate_byte(output, output.bytes[output.size - distance + 1])
            end
        else
            Binary.fail("Invalid deflate literal symbol " .. symbol)
        end
    end
end

local function build_dynamic_huffman(reader)
    local hlit = read_bits(reader, 5) + 257
    local hdist = read_bits(reader, 5) + 1
    local hclen = read_bits(reader, 4) + 4
    local order = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }
    local code_lengths = {}
    for index = 1, 19 do
        code_lengths[index] = 0
    end
    for index = 1, hclen do
        code_lengths[order[index] + 1] = read_bits(reader, 3)
    end

    local code_huffman = build_huffman(code_lengths)
    local lengths = {}
    while #lengths < hlit + hdist do
        local symbol = decode_symbol(reader, code_huffman)
        if symbol <= 15 then
            lengths[#lengths + 1] = symbol
        elseif symbol == 16 then
            local repeat_count = read_bits(reader, 2) + 3
            local previous = lengths[#lengths]
            if previous == nil then
                Binary.fail("Invalid dynamic Huffman repeat with no previous length")
            end
            for _ = 1, repeat_count do
                lengths[#lengths + 1] = previous
            end
        elseif symbol == 17 then
            local repeat_count = read_bits(reader, 3) + 3
            for _ = 1, repeat_count do
                lengths[#lengths + 1] = 0
            end
        elseif symbol == 18 then
            local repeat_count = read_bits(reader, 7) + 11
            for _ = 1, repeat_count do
                lengths[#lengths + 1] = 0
            end
        else
            Binary.fail("Invalid dynamic Huffman code length symbol " .. symbol)
        end
    end

    local literal_lengths = {}
    local distance_lengths = {}
    for index = 1, hlit do
        literal_lengths[index] = lengths[index]
    end
    for index = 1, hdist do
        distance_lengths[index] = lengths[hlit + index]
    end
    return build_huffman(literal_lengths), build_huffman(distance_lengths)
end

function Zlib.inflate(data)
    if #data < 6 then
        Binary.fail("Invalid zlib stream: too short")
    end

    local cmf = data:byte(1)
    local flg = data:byte(2)
    if (cmf & 0x0f) ~= 8 then
        Binary.fail("Invalid zlib stream: compression method is not deflate")
    end
    if (((cmf << 8) + flg) % 31) ~= 0 then
        Binary.fail("Invalid zlib stream: bad header check")
    end
    if (flg & 0x20) ~= 0 then
        Binary.fail("Unsupported zlib stream: preset dictionary is not supported")
    end

    local reader = make_bit_reader(data, 3, #data - 4)
    local output = make_inflate_output()
    local final = false
    while not final do
        final = read_bits(reader, 1) == 1
        local block_type = read_bits(reader, 2)
        if block_type == 0 then
            align_to_byte(reader)
            local len = read_bits(reader, 16)
            local nlen = read_bits(reader, 16)
            if ((len ~ nlen) & 0xffff) ~= 0xffff then
                Binary.fail("Invalid deflate stored block length")
            end
            if reader.position + len - 1 > reader.limit then
                Binary.fail("Invalid deflate stored block: block exceeds stream")
            end
            append_inflate_string(output, data:sub(reader.position, reader.position + len - 1))
            reader.position = reader.position + len
        elseif block_type == 1 then
            inflate_codes(reader, FIXED_LITERAL_HUFFMAN, FIXED_DISTANCE_HUFFMAN, output)
        elseif block_type == 2 then
            local literal_huffman, distance_huffman = build_dynamic_huffman(reader)
            inflate_codes(reader, literal_huffman, distance_huffman, output)
        else
            Binary.fail("Invalid deflate block type 3")
        end
    end

    local inflated = inflate_output_to_string(output)
    local expected_adler = Binary.be_u32(data, #data - 3)
    local actual_adler = Checksum.adler32(inflated)
    if expected_adler ~= actual_adler then
        Binary.fail("Invalid zlib stream: Adler-32 mismatch")
    end
    return inflated
end

function Zlib.deflate_stored(data)
    local output = { string.char(0x78, 0x01) }
    local position = 1
    if #data == 0 then
        output[#output + 1] = string.char(1, 0, 0, 255, 255)
        output[#output + 1] = Checksum.adler32_bytes(data)
        return table.concat(output)
    end

    while position <= #data do
        local remaining = #data - position + 1
        local block_size = math.min(65535, remaining)
        local final = position + block_size > #data
        local nlen = (~block_size) & 0xffff
        output[#output + 1] = string.char(final and 1 or 0)
        output[#output + 1] = string.pack("<I2I2", block_size, nlen)
        output[#output + 1] = data:sub(position, position + block_size - 1)
        position = position + block_size
    end

    output[#output + 1] = Checksum.adler32_bytes(data)
    return table.concat(output)
end

local function make_bit_writer()
    return {
        chunks = {},
        bit_buffer = 0,
        bit_count = 0,
    }
end

local function write_bits(writer, value, count)
    writer.bit_buffer = writer.bit_buffer | ((value & ((1 << count) - 1)) << writer.bit_count)
    writer.bit_count = writer.bit_count + count
    while writer.bit_count >= 8 do
        writer.chunks[#writer.chunks + 1] = string.char(writer.bit_buffer & 0xff)
        writer.bit_buffer = writer.bit_buffer >> 8
        writer.bit_count = writer.bit_count - 8
    end
end

local function finish_bit_writer(writer)
    if writer.bit_count > 0 then
        writer.chunks[#writer.chunks + 1] = string.char(writer.bit_buffer & 0xff)
    end
    return table.concat(writer.chunks)
end

local function fixed_literal_code(symbol)
    if symbol <= 143 then
        return reverse_bits(0x30 + symbol, 8), 8
    elseif symbol <= 255 then
        return reverse_bits(0x190 + (symbol - 144), 9), 9
    elseif symbol <= 279 then
        return reverse_bits(symbol - 256, 7), 7
    end
    return reverse_bits(0xc0 + (symbol - 280), 8), 8
end

local function write_fixed_symbol(writer, symbol)
    local code, code_length = fixed_literal_code(symbol)
    write_bits(writer, code, code_length)
end

local function length_to_symbol(length)
    for index = 1, #LENGTH_BASES do
        local extra_bits = LENGTH_EXTRA_BITS[index]
        local max_length = LENGTH_BASES[index] + ((1 << extra_bits) - 1)
        if length <= max_length then
            return 257 + index - 1, length - LENGTH_BASES[index], extra_bits
        end
    end
    Binary.fail("Invalid deflate match length " .. length)
end

local function distance_to_symbol(distance)
    for index = 1, #DISTANCE_BASES do
        local extra_bits = DISTANCE_EXTRA_BITS[index]
        local max_distance = DISTANCE_BASES[index] + ((1 << extra_bits) - 1)
        if distance <= max_distance then
            return index - 1, distance - DISTANCE_BASES[index], extra_bits
        end
    end
    Binary.fail("Invalid deflate match distance " .. distance)
end

local function write_fixed_match(writer, length, distance)
    local length_symbol, length_extra, length_extra_bits = length_to_symbol(length)
    local distance_symbol, distance_extra, distance_extra_bits = distance_to_symbol(distance)

    write_fixed_symbol(writer, length_symbol)
    write_bits(writer, length_extra, length_extra_bits)
    write_bits(writer, reverse_bits(distance_symbol, 5), 5)
    write_bits(writer, distance_extra, distance_extra_bits)
end

local function hash_at(data, position)
    if position + 2 > #data then
        return nil
    end
    local a, b, c = data:byte(position, position + 2)
    return (a << 16) | (b << 8) | c
end

local function match_length_at(data, left, right)
    local length = 0
    local max_length = math.min(258, #data - right + 1)
    while length < max_length and data:byte(left + length) == data:byte(right + length) do
        length = length + 1
    end
    return length
end

local function find_match(data, position, hash_table)
    local key = hash_at(data, position)
    if key == nil then
        return 0, 0
    end

    local previous = hash_table[key]
    if previous == nil or position - previous > 32768 then
        return 0, 0
    end

    local length = match_length_at(data, previous, position)
    if length < 3 then
        return 0, 0
    end
    return length, position - previous
end

local function remember_position(data, position, hash_table)
    local key = hash_at(data, position)
    if key ~= nil then
        hash_table[key] = position
    end
end

local function deflate_fixed_block(data)
    local writer = make_bit_writer()
    local hash_table = {}
    local position = 1

    write_bits(writer, 1, 1)
    write_bits(writer, 1, 2)

    while position <= #data do
        local length, distance = find_match(data, position, hash_table)
        if length >= 3 then
            write_fixed_match(writer, length, distance)
            for offset = 0, length - 1 do
                remember_position(data, position + offset, hash_table)
            end
            position = position + length
        else
            write_fixed_symbol(writer, data:byte(position))
            remember_position(data, position, hash_table)
            position = position + 1
        end
    end

    write_fixed_symbol(writer, 256)
    return finish_bit_writer(writer)
end

function Zlib.deflate(data)
    local compressed = deflate_fixed_block(data)
    return string.char(0x78, 0x5e) .. compressed .. Checksum.adler32_bytes(data)
end

return Zlib
