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

return Inspect
