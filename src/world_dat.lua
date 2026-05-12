local Binary = require("src.binary")
local Cbor = require("src.cbor")

local WorldDat = {}

local TILE_FLAGS = {
    has_extra_data = 0x01,
    has_parent = 0x02,
    was_spliced = 0x04,
    will_spawn_seeds_too = 0x08,
    is_seedling = 0x10,
    flipped_x = 0x20,
    is_on = 0x40,
    is_open_to_public = 0x80,
    bg_is_on = 0x100,
    fg_alt_mode = 0x200,
    is_wet = 0x400,
    glued = 0x800,
    on_fire = 0x1000,
    painted_red = 0x2000,
    painted_green = 0x4000,
    painted_blue = 0x8000,
}

local CBOR_FOREGROUND_IDS = {
    [15376] = true,
    [15546] = true,
    [3548] = true,
    [12598] = true,
    [14662] = true,
    [14666] = true,
    [8624] = true,
    [8630] = true,
    [8636] = true,
    [8642] = true,
    [8648] = true,
    [8654] = true,
    [8660] = true,
    [8666] = true,
    [8672] = true,
    [8678] = true,
    [8684] = true,
    [8690] = true,
    [8696] = true,
    [8702] = true,
    [8708] = true,
    [8714] = true,
}

local WEATHER_NAMES = {
    [0] = "Default",
    [1] = "Sunset",
    [2] = "Night",
    [3] = "Desert",
    [4] = "Sunny",
    [5] = "RainyCity",
    [6] = "Harvest",
    [7] = "Mars",
    [8] = "Spooky",
    [9] = "Maw",
    [10] = "Blank",
    [11] = "Snowy",
    [12] = "Growch",
    [13] = "GrowchHappy",
    [14] = "Undersea",
    [15] = "Warp",
    [16] = "Comet",
    [17] = "Comet2",
    [18] = "Party",
    [19] = "Pineapple",
    [20] = "SnowyNight",
    [21] = "Spring",
    [22] = "Wolf",
    [23] = "NotInitialized",
    [24] = "PurpleHaze",
    [25] = "FireHaze",
    [26] = "GreenHaze",
    [27] = "AquaHaze",
    [28] = "CustomHaze",
    [29] = "CustomItems",
    [30] = "Pagoda",
    [31] = "Apocalypse",
    [32] = "Jungle",
    [33] = "BalloonWarz",
    [34] = "Background",
    [35] = "Autumn",
    [36] = "Hearth",
    [37] = "StPatricks",
    [38] = "IceAge",
    [39] = "Volcano",
    [40] = "FloatingIslands",
    [41] = "Mascot",
    [42] = "DigitalRain",
    [43] = "MonoChrome",
    [44] = "Treasure",
    [45] = "Surgery",
    [46] = "Bountiful",
    [47] = "Meteor",
    [48] = "Stars",
    [49] = "Ascended",
    [50] = "Destroyed",
    [51] = "GrowtopiaSign",
    [52] = "Dungeon",
    [53] = "LegendaryCity",
    [54] = "BloodDragon",
    [55] = "PopCity",
    [56] = "Anzu",
    [57] = "TmntCity",
    [58] = "RadCity",
    [59] = "Plaze",
    [60] = "Nebula",
    [61] = "ProtoStar",
    [62] = "DarkMountains",
    [63] = "Ac15",
    [64] = "MountGrowMore",
    [65] = "CrackInReality",
    [66] = "LnyNian",
    [67] = "RaymanLock",
    [68] = "Steampunk",
    [69] = "RealmOfSpirits",
    [70] = "Blackhole",
    [71] = "Gems",
    [72] = "HolidayHaven",
    [73] = "FenyxLock",
    [74] = "EnchantedLock",
    [75] = "RoyalEnchantedLock",
    [76] = "NeptunesAtlantis",
    [77] = "PinuskiPetalPerfectHaven",
    [78] = "Candyland",
}

local function make_reader(data)
    return { data = data, position = 1 }
end

local function ensure_available(reader, size)
    local remaining = #reader.data - reader.position + 1
    if remaining < size then
        Binary.fail("Unexpected end of world.dat at offset " .. (reader.position - 1) .. ": need " .. size .. " bytes, have " .. remaining)
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

local function read_i32(reader)
    ensure_available(reader, 4)
    local value = string.unpack("<i4", reader.data, reader.position)
    reader.position = reader.position + 4
    return value
end

local function read_u32(reader)
    ensure_available(reader, 4)
    local value = string.unpack("<I4", reader.data, reader.position)
    reader.position = reader.position + 4
    return value
end

local function read_f32(reader)
    ensure_available(reader, 4)
    local value = string.unpack("<f", reader.data, reader.position)
    reader.position = reader.position + 4
    return value
end

local function read_bytes(reader, size)
    ensure_available(reader, size)
    local value = reader.data:sub(reader.position, reader.position + size - 1)
    reader.position = reader.position + size
    return value
end

local function skip_bytes(reader, size)
    ensure_available(reader, size)
    reader.position = reader.position + size
end

local function read_string(reader)
    local length = read_u16(reader)
    return read_bytes(reader, length)
end

local function read_u32_list(reader, count)
    local values = {}
    for index = 1, count do
        values[index] = read_u32(reader)
    end
    return values
end

local function flags_to_table(bits)
    local flags = { bits = bits }
    for name, mask in pairs(TILE_FLAGS) do
        flags[name] = (bits & mask) ~= 0
    end
    return flags
end

local function read_string_triplet_extra(reader, type_name)
    return {
        type = type_name,
        unknown_1 = read_string(reader),
        unknown_2 = read_string(reader),
        unknown_3 = read_string(reader),
        unknown_4 = read_u8(reader),
    }
end

local function parse_extra_data(reader, extra_type, foreground_item_id)
    if extra_type == 1 then
        return { type = "Sign", text = read_string(reader), flags = read_u8(reader) }
    elseif extra_type == 2 then
        return { type = "Door", text = read_string(reader), owner_uid = read_u32(reader) }
    elseif extra_type == 3 then
        local data = {
            type = "Lock",
            settings = read_u8(reader),
            owner_uid = read_u32(reader),
            access_count = read_u32(reader),
            access_uids = {},
        }
        data.access_uids = read_u32_list(reader, data.access_count)
        data.minimum_level = read_u8(reader)
        data.unknown_1 = read_bytes(reader, 7)
        if foreground_item_id == 5814 then
            data.guild_data = read_bytes(reader, 16)
        end
        return data
    elseif extra_type == 4 then
        return { type = "Seed", time_passed = read_u32(reader), item_on_tree = read_u8(reader) }
    elseif extra_type == 6 then
        return read_string_triplet_extra(reader, "Mailbox")
    elseif extra_type == 7 then
        return read_string_triplet_extra(reader, "Bulletin")
    elseif extra_type == 8 then
        return { type = "Dice", symbol = read_u8(reader) }
    elseif extra_type == 9 then
        return { type = "ChemicalSource", time_passed = read_u32(reader) }
    elseif extra_type == 10 then
        return { type = "AchievementBlock", unknown_1 = read_u32(reader), tile_type = read_u8(reader) }
    elseif extra_type == 11 then
        return { type = "HearthMonitor", unknown_1 = read_u32(reader), player_name = read_string(reader) }
    elseif extra_type == 12 then
        return read_string_triplet_extra(reader, "DonationBox")
    elseif extra_type == 14 then
        return {
            type = "Mannequin",
            text = read_string(reader),
            unknown_1 = read_u8(reader),
            clothing_1 = read_u32(reader),
            clothing_2 = read_u16(reader),
            clothing_3 = read_u16(reader),
            clothing_4 = read_u16(reader),
            clothing_5 = read_u16(reader),
            clothing_6 = read_u16(reader),
            clothing_7 = read_u16(reader),
            clothing_8 = read_u16(reader),
            clothing_9 = read_u16(reader),
            clothing_10 = read_u16(reader),
        }
    elseif extra_type == 15 then
        return { type = "BunnyEgg", egg_placed = read_u32(reader) }
    elseif extra_type == 16 then
        return { type = "GamePack", team = read_u8(reader) }
    elseif extra_type == 17 then
        return { type = "GameGenerator" }
    elseif extra_type == 18 then
        return { type = "XenoniteCrystal", unknown_1 = read_u8(reader), unknown_2 = read_u32(reader) }
    elseif extra_type == 19 then
        return {
            type = "PhoneBooth",
            clothing_1 = read_u16(reader),
            clothing_2 = read_u16(reader),
            clothing_3 = read_u16(reader),
            clothing_4 = read_u16(reader),
            clothing_5 = read_u16(reader),
            clothing_6 = read_u16(reader),
            clothing_7 = read_u16(reader),
            clothing_8 = read_u16(reader),
            clothing_9 = read_u16(reader),
        }
    elseif extra_type == 20 then
        return { type = "Crystal", unknown_1 = read_string(reader) }
    elseif extra_type == 21 then
        return { type = "CrimeInProgress", unknown_1 = read_string(reader), unknown_2 = read_u32(reader), unknown_3 = read_u8(reader) }
    elseif extra_type == 23 then
        return { type = "DisplayBlock", item_id = read_u32(reader) }
    elseif extra_type == 24 then
        return { type = "VendingMachine", item_id = read_u32(reader), price = read_i32(reader) }
    elseif extra_type == 25 then
        local data = { type = "FishTankPort", flags = read_u8(reader), fishes = {} }
        local fish_count = read_u32(reader)
        for index = 1, fish_count // 2 do
            data.fishes[index] = { fish_item_id = read_u32(reader), lbs = read_u32(reader) }
        end
        return data
    elseif extra_type == 26 then
        return { type = "SolarCollector", unknown_1 = read_bytes(reader, 5) }
    elseif extra_type == 27 then
        return { type = "Forge", temperature = read_u32(reader) }
    elseif extra_type == 28 then
        return { type = "GivingTree", unknown_1 = read_u16(reader), unknown_2 = read_u32(reader) }
    elseif extra_type == 30 then
        return { type = "SteamOrgan", instrument_type = read_u8(reader), note = read_u32(reader) }
    elseif extra_type == 31 then
        return {
            type = "SilkWorm",
            worm_type = read_u8(reader),
            name = read_string(reader),
            age = read_u32(reader),
            unknown_1 = read_u32(reader),
            unknown_2 = read_u32(reader),
            can_be_fed = read_u8(reader),
            food_saturation = read_u32(reader),
            water_saturation = read_u32(reader),
            color = read_u32(reader),
            sick_duration = read_u32(reader),
        }
    elseif extra_type == 32 then
        return { type = "SewingMachine", bolt_id_list = read_u32_list(reader, read_u16(reader)) }
    elseif extra_type == 33 then
        return { type = "CountryFlag", country = read_string(reader) }
    elseif extra_type == 34 then
        return { type = "LobsterTrap" }
    elseif extra_type == 35 then
        return { type = "PaintingEasel", item_id = read_u32(reader), label = read_string(reader) }
    elseif extra_type == 36 then
        return { type = "PetBattleCage", label = read_string(reader), unknown_1 = read_bytes(reader, 12) }
    elseif extra_type == 37 then
        local data = { type = "PetTrainer", name = read_string(reader), pet_total_count = read_u32(reader), unknown_1 = read_u32(reader) }
        data.pets_id = read_u32_list(reader, data.pet_total_count)
        return data
    elseif extra_type == 38 then
        return { type = "SteamEngine", temperature = read_u32(reader) }
    elseif extra_type == 39 then
        return { type = "LockBot", time_passed = read_u32(reader) }
    elseif extra_type == 40 then
        return { type = "WeatherMachine", settings = read_u32(reader) }
    elseif extra_type == 41 then
        return { type = "SpiritStorageUnit", ghost_jar_count = read_u32(reader) }
    elseif extra_type == 42 then
        return { type = "DataBedrock", unknown_1 = read_bytes(reader, 21) }
    elseif extra_type == 43 then
        return {
            type = "Shelf",
            top_left_item_id = read_u32(reader),
            top_right_item_id = read_u32(reader),
            bottom_left_item_id = read_u32(reader),
            bottom_right_item_id = read_u32(reader),
        }
    elseif extra_type == 44 then
        local data = { type = "VipEntrance", unknown_1 = read_u8(reader), owner_uid = read_u32(reader) }
        data.access_uids = read_u32_list(reader, read_u32(reader))
        return data
    elseif extra_type == 45 then
        return { type = "ChallangeTimer" }
    elseif extra_type == 47 then
        return { type = "FishWallMount", label = read_string(reader), item_id = read_u32(reader), lb = read_u8(reader) }
    elseif extra_type == 48 then
        return {
            type = "Portrait",
            label = read_string(reader),
            unknown_1 = read_u32(reader),
            unknown_2 = read_u32(reader),
            unknown_3 = read_u32(reader),
            unknown_4 = read_u32(reader),
            face = read_u32(reader),
            hat = read_u32(reader),
            hair = read_u32(reader),
            unknown_5 = read_u16(reader),
            unknown_6 = read_u16(reader),
        }
    elseif extra_type == 49 then
        return { type = "GuildWeatherMachine", unknown_1 = read_u32(reader), gravity = read_u32(reader), flags = read_u8(reader) }
    elseif extra_type == 50 then
        return { type = "FossilPrepStation", unknown_1 = read_u32(reader) }
    elseif extra_type == 51 then
        return { type = "DnaExtractor" }
    elseif extra_type == 52 then
        return { type = "Howler" }
    elseif extra_type == 53 then
        return { type = "ChemsynthTank", current_chem = read_u32(reader), target_chem = read_u32(reader) }
    elseif extra_type == 54 then
        local data = { type = "StorageBlock", items = {} }
        local data_len = read_u16(reader)
        for index = 1, data_len // 13 do
            skip_bytes(reader, 3)
            local id = read_u32(reader)
            skip_bytes(reader, 2)
            data.items[index] = { id = id, amount = read_u32(reader) }
        end
        return data
    elseif extra_type == 55 then
        local data = { type = "CookingOven", temperature_level = read_u32(reader), ingredients = {} }
        local ingredient_count = read_u32(reader)
        for index = 1, ingredient_count do
            data.ingredients[index] = { item_id = read_u32(reader), time_added = read_u32(reader) }
        end
        data.unknown_1 = read_u32(reader)
        data.unknown_2 = read_u32(reader)
        data.unknown_3 = read_u32(reader)
        return data
    elseif extra_type == 56 then
        return { type = "AudioRack", note = read_string(reader), volume = read_u32(reader) }
    elseif extra_type == 57 then
        return { type = "GeigerCharger", raw = read_u32(reader) }
    elseif extra_type == 58 then
        return { type = "AdventureBegins" }
    elseif extra_type == 59 then
        return { type = "TombRobber" }
    elseif extra_type == 60 then
        return { type = "BalloonOMatic", total_rarity = read_u32(reader), team_type = read_u8(reader) }
    elseif extra_type == 61 then
        return {
            type = "TrainingPort",
            fish_lb = read_u32(reader),
            fish_status = read_u16(reader),
            fish_id = read_u32(reader),
            fish_total_exp = read_u32(reader),
            fish_level = read_u32(reader),
            unknown_2 = read_u32(reader),
        }
    elseif extra_type == 62 then
        return { type = "ItemSucker", item_id_to_suck = read_u32(reader), item_amount = read_u32(reader), flags = read_u16(reader), limit = read_u32(reader) }
    elseif extra_type == 63 then
        local data = { type = "CyBot", sync_timer = read_u32(reader), activated = read_u32(reader), command_datas = {} }
        local command_data_count = read_u32(reader)
        for index = 1, command_data_count do
            data.command_datas[index] = { command_id = read_u32(reader), is_command_used = read_u32(reader) }
            skip_bytes(reader, 7)
        end
        return data
    elseif extra_type == 65 then
        return { type = "GuildItem", raw = read_bytes(reader, 17) }
    elseif extra_type == 66 then
        return { type = "Growscan", unknown_1 = read_u8(reader) }
    elseif extra_type == 67 then
        return { type = "ContainmentFieldPowerNode", ghost_jar_count = read_u32(reader), unknown_1 = read_u32_list(reader, read_u32(reader)) }
    elseif extra_type == 68 then
        return { type = "SpiritBoard", unknown_1 = read_u32(reader), unknown_2 = read_u32(reader), unknown_3 = read_u32(reader) }
    elseif extra_type == 69 then
        return { type = "TesseractManipulator", gems = read_u32(reader), unknown_2 = read_u32(reader), item_id = read_u32(reader), unknown_4 = read_u32(reader) }
    elseif extra_type == 72 then
        return { type = "StormyCloud", sting_duration = read_u32(reader), is_solid = read_u32(reader), non_solid_duration = read_u32(reader) }
    elseif extra_type == 73 then
        return { type = "TemporaryPlatform", unknown_1 = read_u32(reader) }
    elseif extra_type == 74 then
        return { type = "SafeVault" }
    elseif extra_type == 75 then
        return { type = "AngelicCountingCloud", is_raffling = read_u32(reader), unknown_1 = read_u16(reader), ascii_code = read_u8(reader) }
    elseif extra_type == 77 then
        return { type = "InfinityWeatherMachine", interval_minutes = read_u32(reader), weather_machine_list = read_u32_list(reader, read_u32(reader)) }
    elseif extra_type == 79 then
        return { type = "PineappleGuzzler" }
    elseif extra_type == 80 then
        return { type = "KrakenGalaticBlock", pattern_index = read_u8(reader), unknown_1 = read_u32(reader), r = read_u8(reader), g = read_u8(reader), b = read_u8(reader) }
    elseif extra_type == 81 then
        return { type = "FriendsEntrance", owner_user_id = read_u32(reader), unknown_1 = read_u16(reader), unknown_2 = read_u16(reader) }
    end

    Binary.fail("Unsupported world tile extra type " .. extra_type .. " at offset " .. (reader.position - 1))
end

local function parse_tile(reader, world, index)
    local tile = {
        index = index,
        x = index % world.width,
        y = index // world.width,
        foreground_item_id = read_u16(reader),
        background_item_id = read_u16(reader),
        parent_block_index = read_u16(reader),
    }
    tile.flags_number = read_u16(reader)
    tile.flags = flags_to_table(tile.flags_number)
    tile.tile_type = { type = "Basic" }

    if tile.flags.has_parent then
        tile.parent_index_2 = read_u16(reader)
    end
    if tile.flags.has_extra_data then
        tile.extra_tile_type = read_u8(reader)
        tile.tile_type = parse_extra_data(reader, tile.extra_tile_type, tile.foreground_item_id)
    end
    if CBOR_FOREGROUND_IDS[tile.foreground_item_id] then
        local cbor_size = read_u32(reader)
        tile.cbor_raw = read_bytes(reader, cbor_size)
        tile.cbor = Cbor.decode(tile.cbor_raw)
    end
    return tile
end

local function read_weather(value)
    return {
        id = value,
        name = WEATHER_NAMES[value] or "Default",
    }
end

function WorldDat.load_bytes(data)
    local reader = make_reader(data)
    local world = {
        version = read_u16(reader),
        flags = read_u32(reader),
        name = read_string(reader),
        width = read_u32(reader),
        height = read_u32(reader),
        tile_count = read_u32(reader),
        tiles = {},
    }

    if world.version < 0x19 then
        Binary.fail("Unsupported world.dat version " .. world.version .. ": expected >= 25")
    end
    if world.tile_count ~= world.width * world.height then
        Binary.fail("Invalid world tile count: expected " .. (world.width * world.height) .. ", got " .. world.tile_count)
    end
    if world.tile_count > 0xfe01 then
        Binary.fail("World tile count too large: " .. world.tile_count)
    end

    skip_bytes(reader, 5)
    for index = 0, world.tile_count - 1 do
        world.tiles[index + 1] = parse_tile(reader, world, index)
    end

    world.unknown_after_tiles = read_bytes(reader, 12)
    world.dropped = {
        items_count = read_u32(reader),
        last_dropped_item_uid = read_u32(reader),
        items = {},
    }

    for index = 1, world.dropped.items_count do
        world.dropped.items[index] = {
            id = read_u16(reader),
            x = read_f32(reader),
            y = read_f32(reader),
            count = read_u8(reader),
            flags = read_u8(reader),
            uid = read_u32(reader),
        }
    end

    world.base_weather = read_weather(read_u16(reader))
    world.weather_unknown = read_u16(reader)
    world.current_weather = read_weather(read_u16(reader))
    world.bytes_read = reader.position - 1
    return world
end

function WorldDat.load_file(path)
    return WorldDat.load_bytes(Binary.read_file(path))
end

function WorldDat.get_tile(world, x, y)
    if x < 0 or y < 0 or x >= world.width or y >= world.height then
        return nil
    end
    return world.tiles[(y * world.width) + x + 1]
end

return WorldDat
