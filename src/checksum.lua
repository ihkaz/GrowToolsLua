local Binary = require("src.binary")

local Checksum = {}

local function make_crc32_table()
    local table_values = {}
    for index = 0, 255 do
        local crc = index
        for _ = 1, 8 do
            if (crc & 1) ~= 0 then
                crc = (crc >> 1) ~ 0xedb88320
            else
                crc = crc >> 1
            end
        end
        table_values[index] = crc & 0xffffffff
    end
    return table_values
end

local CRC32_TABLE = make_crc32_table()

function Checksum.crc32(data)
    local crc = 0xffffffff
    for index = 1, #data do
        crc = ((crc >> 8) ~ CRC32_TABLE[(crc ~ data:byte(index)) & 0xff]) & 0xffffffff
    end
    return (~crc) & 0xffffffff
end

function Checksum.adler32(data)
    local s1 = 1
    local s2 = 0
    for index = 1, #data do
        s1 = (s1 + data:byte(index)) % 65521
        s2 = (s2 + s1) % 65521
    end
    return ((s2 << 16) | s1) & 0xffffffff
end

function Checksum.crc32_bytes(data)
    return Binary.be_u32_bytes(Checksum.crc32(data))
end

function Checksum.adler32_bytes(data)
    return Binary.be_u32_bytes(Checksum.adler32(data))
end

return Checksum
