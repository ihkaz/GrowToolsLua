local Inspect = {}

local function scalar_to_string(value)
    if type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

function Inspect.print_item(item)
    local fields = {
        "id",
        "name",
        "action_type",
        "material",
        "texture_file_name",
        "texture_hash",
        "texture_x",
        "texture_y",
        "render_type",
        "collision_type",
        "block_health",
        "drop_chance",
        "rarity",
        "max_item",
        "file_name",
        "file_hash",
        "grow_time",
        "description",
    }

    for _, field in ipairs(fields) do
        if item[field] ~= nil then
            print(field .. " = " .. scalar_to_string(item[field]))
        end
    end
    print("flags_bits = " .. item.flags.bits)
end

function Inspect.print_world(world)
    print("name = " .. string.format("%q", world.name))
    print("version = " .. world.version)
    print("flags = " .. world.flags)
    print("width = " .. world.width)
    print("height = " .. world.height)
    print("tile_count = " .. world.tile_count)
    print("dropped_items_count = " .. world.dropped.items_count)
    print("last_dropped_item_uid = " .. world.dropped.last_dropped_item_uid)
    print("base_weather = " .. world.base_weather.name .. " (" .. world.base_weather.id .. ")")
    print("current_weather = " .. world.current_weather.name .. " (" .. world.current_weather.id .. ")")
    print("bytes_read = " .. world.bytes_read)
end

function Inspect.print_tile(tile)
    print("index = " .. tile.index)
    print("x = " .. tile.x)
    print("y = " .. tile.y)
    print("foreground_item_id = " .. tile.foreground_item_id)
    print("background_item_id = " .. tile.background_item_id)
    print("parent_block_index = " .. tile.parent_block_index)
    print("flags_number = " .. tile.flags_number)
    print("tile_type = " .. tile.tile_type.type)
    if tile.extra_tile_type ~= nil then
        print("extra_tile_type = " .. tile.extra_tile_type)
    end
end

return Inspect
