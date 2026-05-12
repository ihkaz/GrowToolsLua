local Binary = require("src.binary")
local ItemsDat = require("src.items_dat")
local Inspect = require("src.inspect")
local Rttex = require("src.rttex")

local Cli = {}

function Cli.run(args)
    local command = args[1]
    local input_path = args[2]
    local output_path = args[3]
    if command == nil or input_path == nil then
        Binary.fail("Usage: lua5.4 main.lua pack input.png output.rttex | unpack input.rttex output.png | items items.dat [item_id]")
    end

    if command == "pack" then
        if output_path == nil then
            Binary.fail("Missing output path for pack command")
        end
        Binary.write_file(output_path, Rttex.RTTEXPack(input_path))
    elseif command == "unpack" then
        if output_path == nil then
            Binary.fail("Missing output path for unpack command")
        end
        Binary.write_file(output_path, Rttex.RTTEXUnpack(input_path))
    elseif command == "items" then
        local database = ItemsDat.load_file(input_path)
        print("version = " .. database.version)
        print("item_count = " .. database.item_count)
        print("bytes_read = " .. database.bytes_read)
        if output_path ~= nil then
            local item_id = tonumber(output_path)
            if item_id == nil then
                Binary.fail("Invalid item id '" .. output_path .. "'")
            end
            local item = ItemsDat.get_item(database, item_id)
            if item == nil then
                Binary.fail("Item id " .. item_id .. " does not exist")
            end
            Inspect.print_item(item)
        end
    else
        Binary.fail("Unknown command '" .. command .. "'. Expected 'pack', 'unpack', or 'items'")
    end
end

return Cli
