local Binary = require("src.binary")
local ItemsDat = require("src.items_dat")
local Inspect = require("src.inspect")
local Rttex = require("src.rttex")
local WorldDat = require("src.world_dat")

local Cli = {}

function Cli.run(args)
    local command = args[1]
    local input_path = args[2]
    local output_path = args[3]
    if command == nil or input_path == nil then
        Binary.fail("Usage: lua5.4 main.lua pack input.png output.rttex | unpack input.rttex output.png | items items.dat [item_id] | world world.dat | world-tile world.dat x y")
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
    elseif command == "world" then
        Inspect.print_world(WorldDat.load_file(input_path))
    elseif command == "world-tile" then
        local x = tonumber(output_path)
        local y = tonumber(args[4])
        if x == nil or y == nil then
            Binary.fail("Usage: lua5.4 main.lua world-tile world.dat x y")
        end
        local world = WorldDat.load_file(input_path)
        local tile = WorldDat.get_tile(world, x, y)
        if tile == nil then
            Binary.fail("Tile coordinate is outside world: x=" .. x .. ", y=" .. y)
        end
        Inspect.print_tile(tile)
    else
        Binary.fail("Unknown command '" .. command .. "'. Expected 'pack', 'unpack', 'items', 'world', or 'world-tile'")
    end
end

return Cli
