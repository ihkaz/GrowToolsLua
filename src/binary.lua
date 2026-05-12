local Binary = {}

function Binary.fail(message)
    error(message, 2)
end

function Binary.read_file(path)
    local file = assert(io.open(path, "rb"))
    local data = file:read("a")
    file:close()
    return data
end

function Binary.write_file(path, data)
    local file = assert(io.open(path, "wb"))
    file:write(data)
    file:close()
end

function Binary.u8(data, offset)
    return data:byte(offset, offset)
end

function Binary.be_u32(data, offset)
    local a, b, c, d = data:byte(offset, offset + 3)
    return ((a << 24) | (b << 16) | (c << 8) | d) & 0xffffffff
end

function Binary.le_i32(data, offset)
    return string.unpack("<i4", data, offset)
end

function Binary.le_u32_bytes(value)
    return string.pack("<I4", value & 0xffffffff)
end

function Binary.be_u32_bytes(value)
    return string.pack(">I4", value & 0xffffffff)
end

function Binary.lowest_power_of_2(value)
    local lowest = 1
    while lowest < value do
        lowest = lowest << 1
    end
    return lowest
end

function Binary.bytes_to_string(bytes)
    for index = 1, #bytes do
        bytes[index] = string.char(bytes[index])
    end
    return table.concat(bytes)
end

return Binary
