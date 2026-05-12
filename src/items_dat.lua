local Binary = require("src.binary")

local ItemsDat = {}

local SECRET = "PBG892FXX982ABC*"

local function make_reader(data)
    return {
        data = data,
        position = 1,
    }
end

local function ensure_available(reader, size)
    local remaining = #reader.data - reader.position + 1
    if remaining < size then
        Binary.fail("Unexpected end of items.dat at offset " .. (reader.position - 1) .. ": need " .. size .. " bytes, have " .. remaining)
    end
end

local function read_u8(reader)
    ensure_available(reader, 1)
    local value = reader.data:byte(reader.position)
    reader.position = reader.position + 1
    return value
end

local function read_u16(reader)
    ensure_available(reader, 2)
    local value = string.unpack("<I2", reader.data, reader.position)
    reader.position = reader.position + 2
    return value
end

local function read_u32(reader)
    ensure_available(reader, 4)
    local value = string.unpack("<I4", reader.data, reader.position)
    reader.position = reader.position + 4
    return value
end

local function skip_bytes(reader, size)
    ensure_available(reader, size)
    reader.position = reader.position + size
end

local function read_string(reader)
    local length = read_u16(reader)
    ensure_available(reader, length)
    local value = reader.data:sub(reader.position, reader.position + length - 1)
    reader.position = reader.position + length
    return value
end

local function read_encrypted_item_name(reader, item_id)
    local length = read_u16(reader)
    local output = {}
    for index = 0, length - 1 do
        local secret_position = ((index + item_id) % #SECRET) + 1
        output[#output + 1] = string.char(read_u8(reader) ~ SECRET:byte(secret_position))
    end
    return table.concat(output)
end

local function parse_flags(bits)
    return {
        bits = bits,
        flippable = (bits & 0x1) ~= 0,
        editable = (bits & 0x2) ~= 0,
        seedless = (bits & 0x4) ~= 0,
        permanent = (bits & 0x8) ~= 0,
        dropless = (bits & 0x10) ~= 0,
        no_self = (bits & 0x20) ~= 0,
        no_shadow = (bits & 0x40) ~= 0,
        world_locked = (bits & 0x80) ~= 0,
        beta = (bits & 0x100) ~= 0,
        auto_pickup = (bits & 0x200) ~= 0,
        mod_flag = (bits & 0x400) ~= 0,
        random_grow = (bits & 0x800) ~= 0,
        public = (bits & 0x1000) ~= 0,
        foreground = (bits & 0x2000) ~= 0,
        holiday = (bits & 0x4000) ~= 0,
        untradeable = (bits & 0x8000) ~= 0,
    }
end

local function read_item(reader, version)
    local item = {}
    item.id = read_u32(reader)
    item.flags = parse_flags(read_u16(reader))
    item.action_type = read_u8(reader)
    item.material = read_u8(reader)
    item.name = read_encrypted_item_name(reader, item.id)
    item.texture_file_name = read_string(reader)
    item.texture_hash = read_u32(reader)
    item.visual_effect = read_u8(reader)
    item.cooking_ingredient = read_u32(reader)
    item.texture_x = read_u8(reader)
    item.texture_y = read_u8(reader)
    item.render_type = read_u8(reader)
    item.is_stripey_wallpaper = read_u8(reader)
    item.collision_type = read_u8(reader)
    item.block_health = read_u8(reader)
    item.drop_chance = read_u32(reader)
    item.clothing_type = read_u8(reader)
    item.rarity = read_u16(reader)
    item.max_item = read_u8(reader)
    item.file_name = read_string(reader)
    item.file_hash = read_u32(reader)
    item.audio_volume = read_u32(reader)
    item.pet_name = read_string(reader)
    item.pet_prefix = read_string(reader)
    item.pet_suffix = read_string(reader)
    item.pet_ability = read_string(reader)
    item.seed_base_sprite = read_u8(reader)
    item.seed_overlay_sprite = read_u8(reader)
    item.tree_base_sprite = read_u8(reader)
    item.tree_overlay_sprite = read_u8(reader)
    item.base_color = read_u32(reader)
    item.overlay_color = read_u32(reader)
    item.ingredient = read_u32(reader)
    item.grow_time = read_u32(reader)

    item.unknown_1 = read_u16(reader)
    item.is_rayman = read_u16(reader)
    item.extra_options = read_string(reader)
    item.texture_path_2 = read_string(reader)
    item.extra_option2 = read_string(reader)

    skip_bytes(reader, 80)

    if version >= 11 then
        item.punch_option = read_string(reader)
    else
        item.punch_option = ""
    end
    if version >= 12 then
        skip_bytes(reader, 13)
    end
    if version >= 13 then
        skip_bytes(reader, 4)
    end
    if version >= 14 then
        skip_bytes(reader, 4)
    end
    if version >= 15 then
        skip_bytes(reader, 25)
        item.unknown_version_15_string = read_string(reader)
    end
    if version >= 16 then
        item.unknown_version_16_string = read_string(reader)
    end
    if version >= 17 then
        skip_bytes(reader, 4)
    end
    if version >= 18 then
        skip_bytes(reader, 4)
    end
    if version >= 19 then
        skip_bytes(reader, 9)
    end
    if version >= 21 then
        skip_bytes(reader, 2)
    end
    if version >= 22 then
        item.description = read_string(reader)
    else
        item.description = ""
    end
    if version >= 23 then
        item.recipe = {
            ingredient_1 = read_u16(reader),
            ingredient_2 = read_u16(reader),
        }
    end
    if version >= 24 then
        item.version_24_flag = read_u8(reader)
    end
    if version >= 25 then
        item.hit_sound_fx = read_string(reader)
        item.hit_sound_fx_hash = read_u32(reader)
    else
        item.hit_sound_fx = ""
        item.hit_sound_fx_hash = 0
    end
    if version >= 26 then
        item.version_26_flag = read_u8(reader)
    end

    return item
end

function ItemsDat.load_bytes(data)
    local reader = make_reader(data)
    local database = {
        version = read_u16(reader),
        item_count = read_u32(reader),
        items = {},
        loaded = false,
    }

    for index = 0, database.item_count - 1 do
        local item = read_item(reader, database.version)
        if item.id ~= index then
            Binary.fail("Item ID mismatch at index " .. index .. ": got " .. item.id)
        end
        database.items[item.id + 1] = item
    end

    database.loaded = true
    database.bytes_read = reader.position - 1
    return database
end

function ItemsDat.load_file(path)
    return ItemsDat.load_bytes(Binary.read_file(path))
end

function ItemsDat.get_item(database, id)
    return database.items[id + 1]
end

return ItemsDat
